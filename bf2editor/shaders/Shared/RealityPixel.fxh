
/*
	Shared functions that process/generate data in the pixel shader
*/

#include "shaders/shared/RealityDirectXTK.fxh"
#if !defined(_HEADERS_)
	#include "RealityDirectXTK.fxh"
#endif

#if !defined(_HEADERS_)
	#define _HEADERS_
#endif

#if !defined(REALITY_PIXEL)
	#define REALITY_PIXEL


	float GetMax3(float3 Input)
	{
		return max(Input.x, max(Input.y, Input.z));
	}

	float GetMin3(float3 Input)
	{
		return max(Input.x, max(Input.y, Input.z));
	}

	float GetMean3(float3 Input)
	{
		return dot(Input, 1.0 / 3.0);
	}

	float Desaturate(float3 Input)
	{
		return lerp(GetMin3(Input), GetMax3(Input), 1.0 / 2.0);
	}

	float3 QuantizeRGB(float3 Color, float Depth)
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

	float GetHash1(float2 P, float Bias)
	{
		float3 P3 = frac(P.xyx * 0.1031);
		P3 += dot(P3, P3.yzx + 33.33);
		return frac(((P3.x + P3.y) * P3.z) + Bias);
	}

	float2 GetHash2(float2 P, float2 Bias)
	{
		float3 P3 = frac(P.xyx * float3(0.1031, 0.1030, 0.0973));
		P3 += dot(P3, P3.yzx + 33.33);
		return frac(((P3.xx + P3.yz) * P3.zy) + Bias);
	}

	float3 GetHash3(float2 P, float3 Bias)
	{
		float3 P3 = frac(P.xyx * float3(0.1031, 0.1030, 0.0973));
		P3 += dot(P3, P3.yxz + 33.33);
		return frac(((P3.xxy + P3.yzz) * P3.zyx) + Bias);
	}

	/*
		GetGradientNoise(): https://iquilezles.org/articles/gradientnoise/
		GetProceduralTiles(): https://iquilezles.org/articles/texturerepetition
		GetQuintic(): https://iquilezles.org/articles/texture/

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

	float2 GetQuintic(float2 X)
	{
		return X * X * X * (X * (X * 6.0 - 15.0) + 10.0);
	}

	float GetValueNoise1(float2 Tex, float Bias)
	{
		float2 I = floor(Tex);
		float2 F = frac(Tex);
		float A = GetHash1(I + float2(0.0, 0.0), Bias);
		float B = GetHash1(I + float2(1.0, 0.0), Bias);
		float C = GetHash1(I + float2(0.0, 1.0), Bias);
		float D = GetHash1(I + float2(1.0, 1.0), Bias);
		float2 UV = GetQuintic(F);
		return lerp(lerp(A, B, UV.x), lerp(C, D, UV.x), UV.y);
	}

	float2 GetValueNoise2(float2 Tex, float Bias)
	{
		float2 I = floor(Tex);
		float2 F = frac(Tex);
		float2 A = GetHash2(I + float2(0.0, 0.0), Bias);
		float2 B = GetHash2(I + float2(1.0, 0.0), Bias);
		float2 C = GetHash2(I + float2(0.0, 1.0), Bias);
		float2 D = GetHash2(I + float2(1.0, 1.0), Bias);
		float2 UV = GetQuintic(F);
		return lerp(lerp(A, B, UV.x), lerp(C, D, UV.x), UV.y);
	}

	float GetGradient1(float2 I, float2 F, float2 O, float Bias)
	{
		// Get constants
		const float TwoPi = acos(-1.0) * 2.0;

		// Calculate random hash rotation
		float Hash = GetHash1(I + O, Bias) * TwoPi;
		float2 HashSinCos = float2(sin(Hash), cos(Hash));
		float2 Gradient = F - O;

		// Calculate final dot-product
		return dot(HashSinCos, Gradient);
	}

	float2 GetGradient2(float2 I, float2 F, float2 O, float Bias)
	{
		// Get constants
		const float TwoPi = acos(-1.0) * 2.0;

		// Calculate random hash rotation
		float2 Hash = GetHash2(I + O, Bias) * TwoPi;
		float4 HashSinCos = float4(sin(Hash), cos(Hash));
		float2 Gradient = F - O;

		// Calculate final dot-product
		return float2(dot(HashSinCos.xz, Gradient), dot(HashSinCos.yw, Gradient));
	}

	float GetGradientNoise1(float2 Input, float Bias, bool NormalizeOutput)
	{
		float2 I = floor(Input);
		float2 F = frac(Input);
		float A = GetGradient1(I, F, float2(0.0, 0.0), Bias);
		float B = GetGradient1(I, F, float2(1.0, 0.0), Bias);
		float C = GetGradient1(I, F, float2(0.0, 1.0), Bias);
		float D = GetGradient1(I, F, float2(1.0, 1.0), Bias);
		float2 UV = GetQuintic(F);
		float Noise = lerp(lerp(A, B, UV.x), lerp(C, D, UV.x), UV.y);
		Noise = (NormalizeOutput) ? saturate((Noise * 0.5) + 0.5) : Noise;
		return Noise;
	}

	float2 GetGradientNoise2(float2 Input, float Bias, bool NormalizeOutput)
	{
		float2 I = floor(Input);
		float2 F = frac(Input);
		float2 A = GetGradient2(I, F, float2(0.0, 0.0), Bias);
		float2 B = GetGradient2(I, F, float2(1.0, 0.0), Bias);
		float2 C = GetGradient2(I, F, float2(0.0, 1.0), Bias);
		float2 D = GetGradient2(I, F, float2(1.0, 1.0), Bias);
		float2 UV = GetQuintic(F);
		float2 Noise = lerp(lerp(A, B, UV.x), lerp(C, D, UV.x), UV.y);
		Noise = (NormalizeOutput) ? saturate((Noise * 0.5) + 0.5) : Noise;
		return Noise;
	}

	float4 GetProceduralTiles(sampler2D Source, float2 Tex)
	{
		// Sample variation pattern
		float Variation = GetValueNoise1(Tex, 0.0);

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

	float2 GetPixelSize(float2 Tex)
	{
		return fwidth(Tex);
	}

	int2 GetScreenSize(float2 Tex)
	{
		return max(round(1.0 / fwidth(Tex)), 0.0);
	}

	float GetAspectRatio(float2 ScreenSize)
	{
		return float(ScreenSize.y) / float(ScreenSize.x);
	}

	/*
		Convolutions
	*/

	float4 GetSpiralBlur(sampler Source, float2 Tex, float Bias, bool UseHash)
	{
		// Initialize values
		float4 OutputColor = 0.0;
		float4 Weight = 0.0;

		// Get constants
		const float Pi2 = acos(-1.0) * 2.0;

		// Get texcoord data
		float2 ScreenSize = GetScreenSize(Tex);
		float2 Cells = Tex * (ScreenSize * 0.25);
		float Random = Pi2 * GetGradientNoise1(Cells, 0.0, false);
		float AspectRatio = GetAspectRatio(ScreenSize);

		float2 Rotation = 0.0;
		sincos(Random, Rotation.y, Rotation.x);
		float2x2 RotationMatrix = float2x2(Rotation.x, Rotation.y, -Rotation.y, Rotation.x);

		float Shift = 0.0;
		for(int i = 1; i < 4; ++i)
		{
			for(int j = 0; j < 4 * i; ++j)
			{
				Shift = (Pi2 / (4.0 * float(i))) * float(j);
				float2 AngleShift = 0.0;
				sincos(Shift, AngleShift.x, AngleShift.y);
				AngleShift *= float(i);

				float2 Offset = (UseHash) ? mul(AngleShift, RotationMatrix) : AngleShift;
				Offset.x *= AspectRatio;
				Offset *= Bias;
				OutputColor += SRGBToLinearEst(tex2D(Source, Tex + (Offset * 0.01)));
				Weight++;
			}
		}

		OutputColor /= Weight;

		LinearToSRGBEst(OutputColor);
		return OutputColor;
	}

	float2 GetHemiTex(float3 WorldPos, float3 WorldNormal, float3 HemiInfo, bool InvertY)
	{
		// HemiInfo: Offset x/y heightmapsize z / hemilerpbias w
		float2 HemiTex = 0.0;
		HemiTex.xy = ((WorldPos + (HemiInfo.z * 0.5) + WorldNormal).xz - HemiInfo.xy) / HemiInfo.z;
		HemiTex.y = (InvertY == true) ? 1.0 - HemiTex.y : HemiTex.y;
		return HemiTex;
	}

	// Gets radial light attenuation value for pointlights
	float GetLightAttenuation(float3 LightVec, float Attenuation)
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
	float2 GetParallaxTex(sampler HeightMap, float2 Tex, float3 ViewDir, float2 Scale, float2 Bias)
	{
		// Caculate number of laters
		float Layers = 16.0;
		// Calculate the size of each layer
		float LayerDepth = 1.0 / Layers;
		// Depth of current layer
		float CurrentLayerDepth = 0.0;
		// The amount to shift the texture coordinates per layer (from vector P)
		float2 P = (ViewDir.xy * Scale) + Bias; 
		float2 DeltaTex = P / Layers;

		// Get initial values
		float2 CurrentTex = Tex;
		float2 TexIx = ddx(CurrentTex);
		float2 TexIy = ddy(CurrentTex);
		float CurrentDepthValue = saturate(tex2D(HeightMap, CurrentTex).a);

		while (CurrentDepthValue < CurrentLayerDepth)
		{
			// Shift texture coordinates along direction of P
			CurrentTex -= DeltaTex;
			// Get depthmap value at current texture coordinates
			CurrentDepthValue = tex2Dgrad(HeightMap, CurrentTex, TexIx, TexIy).a;  
			// Get depth of next layer
			CurrentLayerDepth += LayerDepth;  
		}

		// Get texture coordinates before collision (reverse operations)
		float2 PreviousTex = CurrentTex + DeltaTex;

		// Get depth after and before collision for linear interpolation
		float AfterDepth = CurrentDepthValue - CurrentLayerDepth;
		float BeforeDepth = tex2D(HeightMap, PreviousTex).a - CurrentLayerDepth + LayerDepth;

		// Interpolation of texture coordinates
		float Weight = AfterDepth / (AfterDepth - BeforeDepth);
		float2 FinalTex = lerp(CurrentTex, PreviousTex, Weight);

		return FinalTex;
	}

	/*
		Get hashed alpha testing (Chris Wyman, NVIDIA, 2017)
		---
		https://developer.download.nvidia.com/assets/gameworks/downloads/regular/GDC17/RealTimeRenderingAdvances_HashedAlphaTesting_GDC2017_FINAL.pdf
	*/
	void SetHashedAlphaTest(float2 Tex, inout float AlphaChannel)
	{
		const float G_HashScale = 1.0;
		float MaxD = max(length(ddx(Tex)), length(ddy(Tex)));
		float PixScale = 1.0 / (G_HashScale * MaxD);

		// Find two nearest log-discretized noise scales
		float2 PixScales = 0.0;
		PixScales.x = floor(log2(PixScale));
		PixScales.y = ceil(log2(PixScale));
		PixScales = exp2(PixScales);

		// Compute alpha thresholds to our noise scales
		float2 AlphaThresholds = 0.0;
		AlphaThresholds.x = GetHash1(floor(Tex * PixScales.x), 0.0);
		AlphaThresholds.y = GetHash1(floor(Tex * PixScales.y), 0.0);

		// Factor to interpolate lerp() with
		float LerpFactor = frac(log2(PixScale));

		// Interpolate alpha threshold from noise at two scales
		float X = lerp(AlphaThresholds.x, AlphaThresholds.y, LerpFactor);

		// Pass into CDF to compute uniformly distribute threshold
		float A = min(LerpFactor, 1.0 - LerpFactor);
		float InvA = 1.0 - A;
		float InvX = 1.0 - X;
		float Divisor = (2.0 * A * InvA);

		float3 Cases = 0.0;
		Cases.x = X*X / Divisor;
		Cases.y = (X - 0.5 * A) / InvA;
		Cases.z = 1.0 - (InvX*InvX / Divisor);

		// Find our final, uniformly distributed alpha threshold
		float Threshold = (X < InvA) ? ((X < A) ? Cases.x : Cases.y) : Cases.z;

		// Avoids `threshold == 0`. Could also do `threshold = 1.0 - threshold`
		float AlphaTest = clamp(Threshold, 1.0 - Threshold, 1.0);

		// Output new alpha
		AlphaChannel = (AlphaChannel < AlphaTest) ? 0.0 : 1.0;
	}

	/*
		Rescale alpha by partial derivative
		Source: Anti-aliased Alpha Test: The Esoteric Alpha To Coverage
		https://bgolus.medium.com/anti-aliased-alpha-test-the-esoteric-alpha-to-coverage-8b177335ae4f
	*/
	void RescaleAlpha(inout float AlphaChannel)
	{
		const float Cutoff = 0.4;
		AlphaChannel = (AlphaChannel - Cutoff) / max(fwidth(AlphaChannel), 1e-4) + 0.5;
	}

#endif
