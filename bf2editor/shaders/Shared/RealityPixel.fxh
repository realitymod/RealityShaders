#line 2 "RealityPixel.fxh"

/*
    This file contains pixel shader utility functions used for various pixel processing operations.
*/

#include "shaders/RealityGraphics.fxh"
#include "shaders/shared/RealityDirectXTK.fxh"
#if !defined(_HEADERS_)
	#include "RealityGraphics.fxh"
	#include "RealityDirectXTK.fxh"
#endif

#if !defined(_HEADERS_)
	#define _HEADERS_
#endif

#if !defined(REALITY_PIXEL)
	#define REALITY_PIXEL

	float RPixel_GetMax3(float3 Input)
	{
		return max(Input.x, max(Input.y, Input.z));
	}

	float RPixel_GetMin3(float3 Input)
	{
		return max(Input.x, max(Input.y, Input.z));
	}

	float RPixel_GetMean3(float3 Input)
	{
		return dot(Input, 1.0 / 3.0);
	}

	float RPixel_Desaturate(float3 Input)
	{
		return lerp(RPixel_GetMin3(Input), RPixel_GetMax3(Input), 1.0 / 2.0);
	}

	float3 RPixel_QuantizeRGB(float3 Color, float Depth)
	{
		return floor(Color * Depth) / Depth;
	}

	/*
		https://www.shadertoy.com/view/4djSRW

		Copyright (c) 2014 David Hoskins

		Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

		The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

		THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

	*/

	float RPixel_GetHash_FLT1(float2 P, float Bias)
	{
		float3 P3 = frac(P.xyx * 0.1031);
		P3 += dot(P3, P3.yzx + 33.33);
		return frac(((P3.x + P3.y) * P3.z) + Bias);
	}

	float2 RPixel_GetHash_FLT2(float2 P, float2 Bias)
	{
		float3 P3 = frac(P.xyx * float3(0.1031, 0.1030, 0.0973));
		P3 += dot(P3, P3.yzx + 33.33);
		return frac(((P3.xx + P3.yz) * P3.zy) + Bias);
	}

	float3 RPixel_GetHash_FLT3(float2 P, float3 Bias)
	{
		float3 P3 = frac(P.xyx * float3(0.1031, 0.1030, 0.0973));
		P3 += dot(P3, P3.yxz + 33.33);
		return frac(((P3.xxy + P3.yzz) * P3.zyx) + Bias);
	}

	/*
		Interleaved Gradient Noise Dithering

		http://www.iryoku.com/downloads/Next-Generation-Post-Processing-in-Call-of-Duty-Advanced-Warfare-v18.pptx
	*/

	float RPixel_GetInterleavedGradientNoise(float2 Position)
	{
		return frac(52.9829189 * frac(dot(Position, float2(0.06711056, 0.00583715))));
	}

	/*
		http://extremelearning.com.au/unreasonable-effectiveness-of-quasirandom-sequences/
		https://pbr-book.org/4ed/Sampling_Algorithms/Sampling_Multidimensional_Functions
	*/

	float RPixel_GetGoldenRatioNoise(float2 Position)
	{
		float P2 = RGraphics_GetPhi(2);
		return frac(dot(Position, 1.0 / float2(P2, P2 * P2)));
	}

	/*
		GetGradientNoise(): https://iquilezles.org/articles/gradientnoise/
		RPixel_GetProceduralTiles(): https://iquilezles.org/articles/texturerepetition
		RPixel_GetQuintic(): https://iquilezles.org/articles/texture/

		The MIT License (MIT)

		Copyright (c) 2017 Inigo Quilez

		Permission is hereby granted, free of charge, to any person obtaining a copy of this
		software and associated documentation files (the "Software"), to deal in the Software
		without restriction, including without limitation the rights to use, copy, modify,
		merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
		permit persons to whom the Software is furnished to do so, subject to the following
		conditions:

		The above copyright notice and this permission notice shall be included in all copies
		or substantial portions of the Software.

		THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
		INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
		PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
		HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
		CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE
		OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
	*/

	float2 RPixel_GetQuintic(float2 X)
	{
		return X * X * X * (X * (X * 6.0 - 15.0) + 10.0);
	}

	float RPixel_GetValueNoise_FLT1(float2 Tex, float Bias)
	{
		float2 I = floor(Tex);
		float2 F = frac(Tex);
		float A = RPixel_GetHash_FLT1(I + float2(0.0, 0.0), Bias);
		float B = RPixel_GetHash_FLT1(I + float2(1.0, 0.0), Bias);
		float C = RPixel_GetHash_FLT1(I + float2(0.0, 1.0), Bias);
		float D = RPixel_GetHash_FLT1(I + float2(1.0, 1.0), Bias);
		float2 UV = RPixel_GetQuintic(F);
		return lerp(lerp(A, B, UV.x), lerp(C, D, UV.x), UV.y);
	}

	float2 RPixel_GetValueNoise_FLT2(float2 Tex, float Bias)
	{
		float2 I = floor(Tex);
		float2 F = frac(Tex);
		float2 A = RPixel_GetHash_FLT2(I + float2(0.0, 0.0), Bias);
		float2 B = RPixel_GetHash_FLT2(I + float2(1.0, 0.0), Bias);
		float2 C = RPixel_GetHash_FLT2(I + float2(0.0, 1.0), Bias);
		float2 D = RPixel_GetHash_FLT2(I + float2(1.0, 1.0), Bias);
		float2 UV = RPixel_GetQuintic(F);
		return lerp(lerp(A, B, UV.x), lerp(C, D, UV.x), UV.y);
	}

	float RPixel_GetGradient_FLT1(float2 I, float2 F, float2 O, float Bias)
	{
		// Get constants
		float TwoPi = acos(-1.0) * 2.0;

		// Calculate random hash rotation
		float Hash = RPixel_GetHash_FLT1(I + O, Bias) * TwoPi;
		float2 HashSinCos = float2(sin(Hash), cos(Hash));
		float2 Gradient = F - O;

		// Calculate final dot-product
		return dot(HashSinCos, Gradient);
	}

	float2 RPixel_GetGradient_FLT2(float2 I, float2 F, float2 O, float Bias)
	{
		// Get constants
		float TwoPi = acos(-1.0) * 2.0;

		// Calculate random hash rotation
		float2 Hash = RPixel_GetHash_FLT2(I + O, Bias) * TwoPi;
		float4 HashSinCos = float4(sin(Hash), cos(Hash));
		float2 Gradient = F - O;

		// Calculate final dot-product
		return float2(dot(HashSinCos.xz, Gradient), dot(HashSinCos.yw, Gradient));
	}

	float RPixel_GetGradientNoise_FLT1(float2 Input, float Bias, bool NormalizeOutput)
	{
		float2 I = floor(Input);
		float2 F = frac(Input);
		float A = RPixel_GetGradient_FLT1(I, F, float2(0.0, 0.0), Bias);
		float B = RPixel_GetGradient_FLT1(I, F, float2(1.0, 0.0), Bias);
		float C = RPixel_GetGradient_FLT1(I, F, float2(0.0, 1.0), Bias);
		float D = RPixel_GetGradient_FLT1(I, F, float2(1.0, 1.0), Bias);
		float2 UV = RPixel_GetQuintic(F);
		float Noise = lerp(lerp(A, B, UV.x), lerp(C, D, UV.x), UV.y);
		Noise = (NormalizeOutput) ? saturate((Noise * 0.5) + 0.5) : Noise;
		return Noise;
	}

	float2 RPixel_GetGradientNoise_FLT2(float2 Input, float Bias, bool NormalizeOutput)
	{
		float2 I = floor(Input);
		float2 F = frac(Input);
		float2 A = RPixel_GetGradient_FLT2(I, F, float2(0.0, 0.0), Bias);
		float2 B = RPixel_GetGradient_FLT2(I, F, float2(1.0, 0.0), Bias);
		float2 C = RPixel_GetGradient_FLT2(I, F, float2(0.0, 1.0), Bias);
		float2 D = RPixel_GetGradient_FLT2(I, F, float2(1.0, 1.0), Bias);
		float2 UV = RPixel_GetQuintic(F);
		float2 Noise = lerp(lerp(A, B, UV.x), lerp(C, D, UV.x), UV.y);
		Noise = (NormalizeOutput) ? saturate((Noise * 0.5) + 0.5) : Noise;
		return Noise;
	}

	float4 RPixel_GetProceduralTiles(sampler2D Source, float2 Tex)
	{
		// Sample variation pattern
		float Variation = RPixel_GetValueNoise_FLT1(Tex, 0.0);

		// Compute index
		float Index = Variation * 8.0;
		float I = floor(Index);
		float F = frac(Index);

		// Offsets for the different virtual patterns
		float2 Offset1 = sin(float2(3.0, 7.0) * (I + 0.0));
		float2 Offset2 = sin(float2(3.0, 7.0) * (I + 1.0));

		// Compute derivatives for mip-mapping
		float2 Ix = ddx(Tex);
		float2 Iy = ddy(Tex);

		float4 Color1 = tex2Dgrad(Source, Tex + Offset1, Ix, Iy);
		float4 Color2 = tex2Dgrad(Source, Tex + Offset2, Ix, Iy);
		float Blend = dot(Color1.rgb - Color2.rgb, 1.0);
		return lerp(Color1, Color2, smoothstep(0.2, 0.8, F - (0.1 * Blend)));
	}

	int2 RPixel_GetScreenSize(float2 Tex)
	{
		return max(round(1.0 / fwidth(Tex)), 1.0);
	}

	float2 RPixel_GetPixelSize(float2 Tex)
	{
		return 1.0 / RPixel_GetScreenSize(Tex);
	}

	float RPixel_GetAspectRatio(float2 ScreenSize)
	{
		return float(ScreenSize.y) / float(ScreenSize.x);
	}

	float2 RPixel_GetHemiTex(float3 WorldPos, float3 WorldNormal, float3 HemiInfo, bool InvertY)
	{
		// HemiInfo: Offset x/y heightmapsize z / hemilerpbias w
		float2 HemiTex = 0.0;
		HemiTex.xy = ((WorldPos + (HemiInfo.z * 0.5) + WorldNormal).xz - HemiInfo.xy) / HemiInfo.z;
		HemiTex.y = (InvertY == true) ? 1.0 - HemiTex.y : HemiTex.y;
		return HemiTex;
	}

	// Gets radial light attenuation value for pointlights
	float RPixel_GetLightAttenuation(float3 LightVec, float Attenuation)
	{
		return saturate(1.0 - dot(LightVec, LightVec) * Attenuation);
	}

	/*
		HLSL implementation LearnOpenGL's Parallax Occlusion Mapping (POM)
		---
		Source: https://learnopengl.com/Advanced-Lighting/Parallax-Mapping
		---
		License: CC BY-NC 4.0
	*/
	float2 RPixel_GetParallaxTex(sampler HeightMap, float2 Tex, float3 ViewDir, float2 HeightScale)
	{
		#if defined(PR_PARALLAX)
			// Optimization: Adaptive Layer Count (Steeper angle needs more layers)
			// The number of layers is a critical performance vs. quality tradeoff.
			// A steeper view angle (shallow Z component) requires more layers.
			float NumLayers = lerp(32.0, 8.0, max(dot(float3(0.0, 0.0, 1.0), ViewDir.z), 0.0));

			float LayerDepth = 1.0 / NumLayers;
			float CurrentLayerDepth = 0.0;

			// Calculate the amount to shift the texture coordinates per layer.
			float2 P = ViewDir.xy * (HeightScale * PR_HARDCODED_PARALLAX_BIAS);
			float2 DeltaTex = P / NumLayers;

			float2 CurrentTex = Tex;

			// The derivatives of the original UV are used for correct MIP level selection
			// during the ray march (though simple tex2D is often used for performance).
			float2 TexIx = ddx(Tex);
			float2 TexIy = ddy(Tex);

			// Get initial height value.
			float CurrentDepthValue = tex2Dgrad(HeightMap, CurrentTex, TexIx, TexIy).a;

			// The ray steps while the surface height (CurrentDepthValue) is ABOVE the ray depth.
			// Ray depth (CurrentLayerDepth) starts at 0.0 (surface plane) and increases.
			// The heightmap is H in [0, 1], where 0 is lowest and 1 is highest displacement.
			// We step while the surface height is GREATER than the current ray depth.
			while (CurrentDepthValue > CurrentLayerDepth)
			{
				// Advance the ray's depth
				CurrentLayerDepth += LayerDepth;

				// Shift texture coordinates along the direction of P
				CurrentTex -= DeltaTex;

				// Get heightmap value at new texture coordinates
				CurrentDepthValue = tex2Dgrad(HeightMap, CurrentTex, TexIx, TexIy).a;
			}

			// --- Linear Interpolation (Refined for clarity and robustness) ---

			// TexCoords after collision (Hit point)
			float2 PreviousTex = CurrentTex + DeltaTex;

			// The two steps that bracket the intersection:
			// P1 (Miss): Height is H_Miss (H_prev), Ray Depth is D_Miss (D_prev)
			// P2 (Hit):  Height is H_Hit (H_curr), Ray Depth is D_Hit (D_curr)

			// H_Miss is the height before the step that caused the collision (previous step)
			float H_Miss = tex2Dgrad(HeightMap, PreviousTex, TexIx, TexIy).a;
			// D_Miss is the layer depth before the step that caused the collision
			float D_Miss = CurrentLayerDepth - LayerDepth;

			// M: The 'miss' distance (surface is above the ray). Should be positive.
			float M = H_Miss - D_Miss;

			// I: The 'hit' distance (surface is below the ray). Should be negative.
			float I = CurrentDepthValue - CurrentLayerDepth;

			// The weight 'w' is the interpolation factor from the MISS point to the HIT point.
			// w = Miss distance / Total distance
			float Weight = M / (M - I); // Since I is negative, (M - I) = M + |I|

			// Lerp from the MISS coordinate (PreviousTex) to the HIT coordinate (CurrentTex)
			return lerp(PreviousTex, CurrentTex, Weight);
		#else
			return Tex;
		#endif
	}

	/*
		Get hashed alpha testing (Chris Wyman, NVIDIA, 2017)
		---
		https://cwyman.org/papers/tvcg17_hashedAlphaExtended.pdf
	*/
	void RPixel_SetHashedAlphaTest(float2 Tex, inout float AlphaChannel)
	{
		#if PR_HASHED_ALPHA
			float HashScale = 1.0;
			float2 DX = ddx(Tex);
			float2 DY = ddy(Tex);
			float2 AnisoDeriv = max(abs(DX), abs(DY));
			float2 AnisoScales = rsqrt(2.0) / (HashScale * AnisoDeriv);

			// Find log-discretized noise scales
			float2 ScaleLog = log2(AnisoScales);
			float2 ScaleFloor = exp2(floor(ScaleLog));
			float2 ScaleCeil = exp2(ceil(ScaleLog));

			// Compute alpha Thresholds at our 2 noise scales
			float2 Alpha = 0.0;
			Alpha.x = RPixel_GetHash_FLT1(floor(ScaleFloor * Tex), 0.0);
			Alpha.y = RPixel_GetHash_FLT1(floor(ScaleCeil * Tex), 0.0);

			// Factor to linearly interpolate with
			float2 FracLoc = frac(ScaleLog);
			float2 ToCorners = float2(length(FracLoc), length(1.0 - FracLoc));
			float LerpFactor = ToCorners.x / dot(ToCorners, 1.0);

			// Interpolate alpha threshold from noise at two scales
			float X = lerp(Alpha.x, Alpha.y, LerpFactor);

			// Pass into CDF to compute uniformly distributed threshold
			float A = min(LerpFactor, 1.0 - LerpFactor);
			float InvA = 1.0 - A;
			float InvX = 1.0 - X;
			float Divisor = 1.0 / (2.0 * A * InvA);
			float3 Cases = 0.0;
			Cases.x = (X * X) * Divisor;
			Cases.y = (X - 0.5 * A) / InvA;
			Cases.z = 1.0 - ((InvA * InvA) / Divisor);

			// Find our final, uniformly distributed alpha threshold
			float AlphaT = (X < InvA) ? ((X < A) ? Cases.x : Cases.y) : Cases.z;

			// Avoids AT == 0. Could also do AT = 1-AT
			AlphaT = clamp(AlphaT, 1.0e-6, 1.0);

			// Modify inputs to HashWeight(x) based on degree of aniso
			float2 DLength = float2(length(DX), length(DY));
			float Aniso = max(DLength.x / DLength.y, DLength.y / DLength.x);
			X = Aniso * X;

			// Compute HashWeight(x)
			float N = 6.0;
			float XN = X / N;
			float HashWeight = (X <= 0.0) ? 0.0 : ((0.0 < X) && (X < N)) ? XN * XN : 1.0;

			// Apply fading [0.0, 1.0)
			AlphaT = saturate(0.5 + ((AlphaT - 0.5) * HashWeight));

			// Output new alpha if it is greater than 0.0
			AlphaChannel = (AlphaChannel > 0.0) ? AlphaChannel > AlphaT : 0.0;
		#endif
	}

	/*
		Rescale alpha by partial derivative
		Source: Anti-aliased Alpha Test: The Esoteric Alpha To Coverage
		https://bgolus.medium.com/anti-aliased-alpha-test-the-esoteric-alpha-to-coverage-8b177335ae4f
	*/
	void RPixel_RescaleAlpha(inout float AlphaChannel)
	{
		float Cutoff = 0.5;
		AlphaChannel = (AlphaChannel - Cutoff) / max(fwidth(AlphaChannel), 1e-4) + 0.5;
	}

	/*
		Bicubic sampling in 4 taps

		Thank you Felix Westin (Fewes)!
	*/

	float4 RPixel_Cubic(float V)
	{
		float4 N = float4(1.0, 2.0, 3.0, 4.0) - V;
		float4 S = N * N * N;
		float X = S.x;
		float Y = S.y - 4.0 * S.x;
		float Z = S.z - 4.0 * S.y + 6.0 * S.x;
		float W = 6.0 - X - Y - Z;
		return float4(X, Y, Z, W) * (1.0 / 6.0);
	}

	struct RPixel_ProjTex
	{
		float2 UV;
		float2 Dx;
		float2 Dy;
	};

	RPixel_ProjTex RPixel_GetProjTex(float4 Tex)
	{
		RPixel_ProjTex Output;

		// 1. Calculate the projected UV coordinates
		Output.UV = Tex.xy / Tex.w;

		// 2. Compute explicit derivatives using the Quotient Rule: 
		// d(u/w) = (w * du - u * dw) / w^2
		float3 Ix = ddx(Tex.xyw);
		float3 Iy = ddy(Tex.xyw);
		float W2 = 1.0 / (Tex.w * Tex.w);
		Output.Dx = (Ix.xy * Tex.w - Tex.xy * Ix.z) * W2;
		Output.Dy = (Iy.xy * Tex.w - Tex.xy * Iy.z) * W2;

		return Output;
	}

	float4 RPixel_SampleCubicTex2D(sampler2D Source, float2 Tex, float4 TexSize)
	{
		float2 Dx = ddx(Tex);
		float2 Dy = ddy(Tex);

		Tex = Tex * TexSize.zw - 0.5;
		float2 Fxy = frac(Tex);
		Tex -= Fxy;
		float4 XCubic = RPixel_Cubic(Fxy.x);
		float4 YCubic = RPixel_Cubic(Fxy.y);
		float4 C = Tex.xxyy + float2(-0.5, +1.5).xyxy;
		float4 S = float4(XCubic.xz + XCubic.yw, YCubic.xz + YCubic.yw);
		float4 Offset = (C + float4(XCubic.yw, YCubic.yw) / S) * TexSize.xxyy;
		float4 Sample0 = tex2Dgrad(Source, Offset.xz, Dx, Dy);
		float4 Sample1 = tex2Dgrad(Source, Offset.yz, Dx, Dy);
		float4 Sample2 = tex2Dgrad(Source, Offset.xw, Dx, Dy);
		float4 Sample3 = tex2Dgrad(Source, Offset.yw, Dx, Dy);
		float Sx = S.x / (S.x + S.y);
		float Sy = S.z / (S.z + S.w);
		return lerp(lerp(Sample3, Sample2, Sx), lerp(Sample1, Sample0, Sx), Sy);
	}

	float4 RPixel_SampleLightMap(sampler2D Source, float2 Tex, float4 TexSize)
	{
		#if PR_BICUBIC_LIGHTMAPPING
			return RPixel_SampleCubicTex2D(Source, Tex, TexSize);
		#else
			return tex2D(Source, Tex);
		#endif
	}

	float4 RPixel_SampleCubicTex2DProj(sampler2D Source, float4 Tex, float4 TexSize)
	{
		RPixel_ProjTex ProjTex = RPixel_GetProjTex(Tex);
		float2 UV = ProjTex.UV;
		float2 Dx = ProjTex.Dx;
		float2 Dy = ProjTex.Dy;

		UV = UV * TexSize.zw - 0.5;
		float2 Fxy = frac(UV);
		UV -= Fxy;
		float4 XCubic = RPixel_Cubic(Fxy.x);
		float4 YCubic = RPixel_Cubic(Fxy.y);
		float4 C = UV.xxyy + float2(-0.5, +1.5).xyxy;
		float4 S = float4(XCubic.xz + XCubic.yw, YCubic.xz + YCubic.yw);
		float4 Offset = (C + float4(XCubic.yw, YCubic.yw) / S) * TexSize.xxyy;
		float4 Sample0 = tex2Dgrad(Source, Offset.xz, Dx, Dy);
		float4 Sample1 = tex2Dgrad(Source, Offset.yz, Dx, Dy);
		float4 Sample2 = tex2Dgrad(Source, Offset.xw, Dx, Dy);
		float4 Sample3 = tex2Dgrad(Source, Offset.yw, Dx, Dy);
		float Sx = S.x / (S.x + S.y);
		float Sy = S.z / (S.z + S.w);
		return lerp(lerp(Sample3, Sample2, Sx), lerp(Sample1, Sample0, Sx), Sy);
	}

	float4 RPixel_SampleLightMapProj(sampler2D Source, float4 Tex, float4 TexSize)
	{
		#if PR_BICUBIC_LIGHTMAPPING
			return RPixel_SampleCubicTex2DProj(Source, Tex, TexSize);
		#else
			return tex2Dproj(Source, Tex);
		#endif
	}

#endif
