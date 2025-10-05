#line 2 "RealityEffects.fxh"

#include "shaders/RealityGraphics.fxh"
#include "shaders/shared/RealityPixel.fxh"
#if !defined(_HEADERS_)
	#include "../RealityGraphics.fxh"
	#include "shared/RealityPixel.fxh"
#endif

/*
	https://github.com/GPUOpen-LibrariesAndSDKs/FidelityFX-SDK

	This file is part of the FidelityFX SDK.

	Copyright (C) 2024 Advanced Micro Devices, Inc.

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files(the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and /or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions :

	The above copyright notice and this permission notice shall be included in
	all copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
	THE SOFTWARE.
*/

#if !defined(_HEADERS_)
	#define _HEADERS_
#endif

#if !defined(FIDELITYFX)
	#define FIDELITYFX

	// Simplex noise, transforms given position onto triangle grid
	// This logic should be kept at 32-bit floating point precision. 16 bits causes artifacting.
	float2 REffects_FFX_Lens_Simplex(float2 P)
	{
		// Skew and unskew factors are a bit hairy for 2D, so define them as constants
		float F2 = (sqrt(3.0) - 1.0) / 2.0;  // 0.36602540378
		float G2 = (3.0 - sqrt(3.0)) / 6.0;  // 0.2113248654

		// Skew the (x,y) space to determine which cell of 2 simplices we're in
		float U = (P.x + P.y) * F2;
		float2 Pi = round(P + U);
		float V = (Pi.x + Pi.y) * G2;
		float2 P0 = Pi - V; // Unskew the cell origin back to (x,y) space
		float2 Pf0 = P - P0; // The x,y distances from the cell origin

		return float2(Pf0);
	}

	float2 REffects_ToFloat16(float2 InputValue)
	{
		return float2(int2(InputValue) * (1.0 / 65536.0) - 0.5);
	}

	// Function call to calculate the red and green wavelength/channel sample offset values.
	float2 REffects_FFX_Lens_GetRGMag(
		float ChromAbIntensity // Intensity constant value for the chromatic aberration effect.
	)
	{
		float A = 1.5220;
		float B = 0.00459 * ChromAbIntensity; // um^2

		float3 WaveLengthUM = float3(0.612, 0.549, 0.464);
		float3 IdxRefraction = A + B / WaveLengthUM;
		float2 RedGreenMagnitude = (IdxRefraction.rg - 1.0) / (IdxRefraction.bb - 1.0);

		// float2 containing the red and green wavelength/channel magnitude values
		return RedGreenMagnitude;
	}

	// Function call to apply chromatic aberration effect when sampling the Color input texture.
	float3 REffects_FFX_Lens_SampleWithChromaticAberration(
		sampler2D Image,
		float2 HPos, // The input window coordinate [0, widthPixels), [0, heightPixels).
		float2 Tex, // The input window coordinate [0, 1), [0, 1).
		float2 CenterCoord, // The center window coordinate of the screen.
		float RedMagnitude, // Magnitude value for the offset calculation of the red wavelength (texture channel).
		float GreenMagnitude // Magnitude value for the offset calculation of the green wavelength (texture channel).
	)
	{
		float2 RedShift = (HPos - CenterCoord) * RedMagnitude + CenterCoord + 0.5;
		RedShift *= (1.0 / (2.0 * CenterCoord));
		float2 GreenShift = (HPos - CenterCoord) * GreenMagnitude + CenterCoord + 0.5;
		GreenShift *= (1.0 / (2.0 * CenterCoord));
		float2 BlueShift = Tex;

		float3 RGB = 0.0;
		RGB.r = tex2D(Image, RedShift).r;
		RGB.g = tex2D(Image, GreenShift).g;
		RGB.b = tex2D(Image, BlueShift).b;

		return RGB;
	}

	// Function call to apply film grain effect to inout Color. This call could be skipped entirely as the choice to use the film grain is optional.
	void REffects_FFX_Lens_ApplyFilmGrain(
		in float2 Pos, // The input window coordinate [0, Width), [0, Height).
		inout float3 Color, // The current running Color, or more clearly, the sampled input Color texture Color after being modified by chromatic aberration function.
		in float GrainScaleValue, // Scaling constant value for the grain's noise frequency.
		in float GrainAmountValue, // Intensity constant value of the grain effect.
		in float GrainSeedValue // Seed value for the grain noise, for example, to change how the noise functions effect the grain frame to frame.
	)
	{
		float2 RandomNumberFine = RPixel_GetHash_FLT2(Pos, 0.0);
		float2 GradientN = REffects_FFX_Lens_Simplex((Pos / GrainScaleValue) + RandomNumberFine);

		float GrainShape = 3.0;
		float Grain = exp2(-length(GradientN) * GrainShape);
		Grain = 1.0 - 2.0 * Grain;
		Color += Grain * min(Color, 1.0 - Color) * GrainAmountValue;
	}

	float REffects_FFX_Lens_GetVignetteMask(
		in float2 Coord, // The input window coordinate [-0.5, 0.5), [-0.5, 0.5).
		in float2 CenterCoord, // The center window coordinate of the screen.
		in float VignetteAmount // Intensity constant value of the vignette effect.
	)
	{
		float2 VignetteMask = 0.0;
		float2 CoordFromCenter = abs(Coord - CenterCoord);

		float PiOver2 = RGraphics_GetPi() * 0.5;
		float PiOver4 = RGraphics_GetPi() * 0.25;
		VignetteMask = cos(min(CoordFromCenter * VignetteAmount * PiOver4, PiOver2));
		VignetteMask *= VignetteMask;
		VignetteMask *= VignetteMask;

		return clamp(VignetteMask.x * VignetteMask.y, 0.0, 1.0);
	}

	// Function call to apply vignette effect to inout Color. This call could be skipped entirely as the choice to use the vignette is optional.
	void REffects_FFX_Lens_ApplyVignette(
		in float2 Coord, // The input window coordinate [-0.5, 0.5), [-0.5, 0.5).
		in float2 CenterCoord, // The center window coordinate of the screen.
		inout float3 Color, // The current running Color, or more clearly, the sampled input Color texture Color after being modified by chromatic aberration and film grain functions.
		in float VignetteAmount // Intensity constant value of the vignette effect.
	)
	{
		float VignetteMask = REffects_FFX_Lens_GetVignetteMask(Coord, CenterCoord, VignetteAmount);
		Color *= VignetteMask;
	}

	// Lens pass entry point.
	void FFX_Lens(
		inout float3 Color,
		in sampler2D Image,
		in float2 HPos,
		in float2 Tex,
		in float GrainScale,
		in float GrainAmount,
		in float ChromAb,
		in float Vignette,
		in float GrainSeed
	)
	{
		float2 RGMag = REffects_FFX_Lens_GetRGMag(ChromAb);
		float2 Center = RPixel_GetScreenSize(Tex) / 2.0;
		float2 UNormTex = Tex - 0.5;

		// Run Lens
		Color = REffects_FFX_Lens_SampleWithChromaticAberration(Image, HPos, Tex, Center, RGMag.r, RGMag.g);
		REffects_FFX_Lens_ApplyVignette(UNormTex, 0.0, Color, Vignette);
		REffects_FFX_Lens_ApplyFilmGrain(Tex, Color, GrainScale, GrainAmount, GrainSeed);
	}

#endif

#if !defined(REALITY_EFFECTS)
	#define REALITY_EFFECTS

	/*
		http://extremelearning.com.au/unreasonable-effectiveness-of-quasirandom-sequences/
		https://pbr-book.org/4ed/Sampling_Algorithms/Sampling_Multidimensional_Functions
	*/

	float2 REffects_MapUVtoConcentricDisk(
		float2 UV // UV [-1, 1)
	)
	{
		float Pi = RGraphics_GetPi();

		// Check if the coordinates are in the first or second half of the square
		float R;
		float Theta;

		if ((UV.x == 0.0) && (UV.y == 0.0))
		{
			R = 0.0;
			Theta = 0.0;
		}
		else if ((UV.x * UV.x) > (UV.y * UV.y))
		{
			R = UV.x;
			Theta = (Pi / 4.0) * (UV.y / UV.x);
		}
		else
		{
			R = UV.y;
			Theta = (Pi / 2.0) - (Pi / 4.0) * (UV.x / UV.y);
		}

		// Convert from polar to Cartesian coordinates
		return R * float2(cos(Theta), sin(Theta));
	}

	/*
		Convolutions
	*/

	float4 REffects_GetSpiralBlur(sampler Source, float2 Tex, float Bias, bool UseHash, bool Alternate)
	{
		// Initialize values
		float4 OutputColor = 0.0;
		float4 Weight = 0.0;

		// Get constants
		const float Pi2 = acos(-1.0) * 2.0;

		// Get texcoord data
		float2 ScreenSize = RPixel_GetScreenSize(Tex);
		float2 Cells = Tex * (ScreenSize * 0.25);
		float2 GradientNoise = Pi2 * RPixel_GetGradientNoise_FLT2(Cells, 0.0, false);
		float Random = Alternate ? GradientNoise.y : GradientNoise.x;
		float AspectRatio = RPixel_GetAspectRatio(ScreenSize);

		float2 Rotation = 0.0;
		sincos(Random, Rotation.y, Rotation.x);
		float2x2 RotationMatrix = float2x2(Rotation.x, Rotation.y, -Rotation.y, Rotation.x);

		float Shift = 0.0;
		for (int i = 1; i < 4; ++i)
		{
			for (int j = 0; j < 4 * i; ++j)
			{
				Shift = (Pi2 / (4.0 * float(i))) * float(j);
				float2 AngleShift = 0.0;
				sincos(Shift, AngleShift.x, AngleShift.y);
				AngleShift *= float(i);

				float2 Offset = (UseHash) ? mul(AngleShift, RotationMatrix) : AngleShift;
				Offset.x *= AspectRatio;
				Offset *= Bias;

				OutputColor += RDirectXTK_SRGBToLinearEst(tex2D(Source, Tex + (Offset * 0.01)));
				Weight++;
			}
		}

		OutputColor /= Weight;

		RDirectXTK_LinearToSRGBEst(OutputColor);
		return OutputColor;
	}

#endif
