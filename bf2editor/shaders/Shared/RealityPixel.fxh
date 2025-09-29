#line 2 "RealityPixel.fxh"

#include "shaders/RealityGraphics.fxh"
#include "shaders/shared/RealityDirectXTK.fxh"
#if !defined(_HEADERS_)
	#include "RealityGraphics.fxh"
	#include "RealityDirectXTK.fxh"
#endif

/*
	Shared functions that process/generate data in the pixel shader
*/

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

	float GetHash_FLT1(float2 P, float Bias)
	{
		float3 P3 = frac(P.xyx * 0.1031);
		P3 += dot(P3, P3.yzx + 33.33);
		return frac(((P3.x + P3.y) * P3.z) + Bias);
	}

	float2 GetHash_FLT2(float2 P, float2 Bias)
	{
		float3 P3 = frac(P.xyx * float3(0.1031, 0.1030, 0.0973));
		P3 += dot(P3, P3.yzx + 33.33);
		return frac(((P3.xx + P3.yz) * P3.zy) + Bias);
	}

	float3 GetHash_FLT3(float2 P, float3 Bias)
	{
		float3 P3 = frac(P.xyx * float3(0.1031, 0.1030, 0.0973));
		P3 += dot(P3, P3.yxz + 33.33);
		return frac(((P3.xxy + P3.yzz) * P3.zyx) + Bias);
	}

	/*
		Interleaved Gradient Noise Dithering

		http://www.iryoku.com/downloads/Next-Generation-Post-Processing-in-Call-of-Duty-Advanced-Warfare-v18.pptx
	*/

	float GetInterleavedGradientNoise(float2 Position)
	{
		return frac(52.9829189 * frac(dot(Position, float2(0.06711056, 0.00583715))));
	}

	/*
		http://extremelearning.com.au/unreasonable-effectiveness-of-quasirandom-sequences/
		https://pbr-book.org/4ed/Sampling_Algorithms/Sampling_Multidimensional_Functions
	*/

	float GetGoldenRatioNoise(float2 Position)
	{
		float P2 = GetPhi(2);
		return frac(dot(Position, 1.0 / float2(P2, P2 * P2)));
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

	float GetValueNoise_FLT1(float2 Tex, float Bias)
	{
		float2 I = floor(Tex);
		float2 F = frac(Tex);
		float A = GetHash_FLT1(I + float2(0.0, 0.0), Bias);
		float B = GetHash_FLT1(I + float2(1.0, 0.0), Bias);
		float C = GetHash_FLT1(I + float2(0.0, 1.0), Bias);
		float D = GetHash_FLT1(I + float2(1.0, 1.0), Bias);
		float2 UV = GetQuintic(F);
		return lerp(lerp(A, B, UV.x), lerp(C, D, UV.x), UV.y);
	}

	float2 GetValueNoise_FLT2(float2 Tex, float Bias)
	{
		float2 I = floor(Tex);
		float2 F = frac(Tex);
		float2 A = GetHash_FLT2(I + float2(0.0, 0.0), Bias);
		float2 B = GetHash_FLT2(I + float2(1.0, 0.0), Bias);
		float2 C = GetHash_FLT2(I + float2(0.0, 1.0), Bias);
		float2 D = GetHash_FLT2(I + float2(1.0, 1.0), Bias);
		float2 UV = GetQuintic(F);
		return lerp(lerp(A, B, UV.x), lerp(C, D, UV.x), UV.y);
	}

	float GetGradient_FLT1(float2 I, float2 F, float2 O, float Bias)
	{
		// Get constants
		float TwoPi = acos(-1.0) * 2.0;

		// Calculate random hash rotation
		float Hash = GetHash_FLT1(I + O, Bias) * TwoPi;
		float2 HashSinCos = float2(sin(Hash), cos(Hash));
		float2 Gradient = F - O;

		// Calculate final dot-product
		return dot(HashSinCos, Gradient);
	}

	float2 GetGradient_FLT2(float2 I, float2 F, float2 O, float Bias)
	{
		// Get constants
		float TwoPi = acos(-1.0) * 2.0;

		// Calculate random hash rotation
		float2 Hash = GetHash_FLT2(I + O, Bias) * TwoPi;
		float4 HashSinCos = float4(sin(Hash), cos(Hash));
		float2 Gradient = F - O;

		// Calculate final dot-product
		return float2(dot(HashSinCos.xz, Gradient), dot(HashSinCos.yw, Gradient));
	}

	float GetGradientNoise_FLT1(float2 Input, float Bias, bool NormalizeOutput)
	{
		float2 I = floor(Input);
		float2 F = frac(Input);
		float A = GetGradient_FLT1(I, F, float2(0.0, 0.0), Bias);
		float B = GetGradient_FLT1(I, F, float2(1.0, 0.0), Bias);
		float C = GetGradient_FLT1(I, F, float2(0.0, 1.0), Bias);
		float D = GetGradient_FLT1(I, F, float2(1.0, 1.0), Bias);
		float2 UV = GetQuintic(F);
		float Noise = lerp(lerp(A, B, UV.x), lerp(C, D, UV.x), UV.y);
		Noise = (NormalizeOutput) ? saturate((Noise * 0.5) + 0.5) : Noise;
		return Noise;
	}

	float2 GetGradientNoise_FLT2(float2 Input, float Bias, bool NormalizeOutput)
	{
		float2 I = floor(Input);
		float2 F = frac(Input);
		float2 A = GetGradient_FLT2(I, F, float2(0.0, 0.0), Bias);
		float2 B = GetGradient_FLT2(I, F, float2(1.0, 0.0), Bias);
		float2 C = GetGradient_FLT2(I, F, float2(0.0, 1.0), Bias);
		float2 D = GetGradient_FLT2(I, F, float2(1.0, 1.0), Bias);
		float2 UV = GetQuintic(F);
		float2 Noise = lerp(lerp(A, B, UV.x), lerp(C, D, UV.x), UV.y);
		Noise = (NormalizeOutput) ? saturate((Noise * 0.5) + 0.5) : Noise;
		return Noise;
	}

	float4 GetProceduralTiles(sampler2D Source, float2 Tex)
	{
		// Sample variation pattern
		float Variation = GetValueNoise_FLT1(Tex, 0.0);

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

	int2 GetScreenSize(float2 Tex)
	{
		return max(round(1.0 / fwidth(Tex)), 1.0);
	}

	float2 GetPixelSize(float2 Tex)
	{
		return 1.0 / GetScreenSize(Tex);
	}

	float GetAspectRatio(float2 ScreenSize)
	{
		return float(ScreenSize.y) / float(ScreenSize.x);
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
		https://cwyman.org/papers/tvcg17_hashedAlphaExtended.pdf
	*/
	void SetHashedAlphaTest(float2 Tex, inout float AlphaChannel)
	{
		#if defined(HASHED_ALPHA)
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
			Alpha.x = GetHash_FLT1(floor(ScaleFloor * Tex), 0.0);
			Alpha.y = GetHash_FLT1(floor(ScaleCeil * Tex), 0.0);

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
	void RescaleAlpha(inout float AlphaChannel)
	{
		float Cutoff = 0.5;
		AlphaChannel = (AlphaChannel - Cutoff) / max(fwidth(AlphaChannel), 1e-4) + 0.5;
	}

#endif
