
/*
	Shared functions that process/generate data in the pixel shader
*/

#if !defined(REALITY_PIXEL)
	#define REALITY_PIXEL

	/*
		Hash function, optimized for instructions
		---
		Sources:
			> http://www.cwyman.org/papers/i3d17_hashedAlpha.pdf
			> https://developer.download.nvidia.com/assets/gameworks/downloads/regular/GDC17/RealTimeRenderingAdvances_HashedAlphaTesting_GDC2017_FINAL.pdf
	*/
	float GetHash(float2 Input)
	{
		float2 H = 0.0;
		H.x = dot(Input, float2(17.0, 0.1));
		H.y = dot(Input, float2(1.0, 13.0));
		H = sin(H);
		return frac(1.0e4 * H.x * (0.1 + abs(H.y)));
	}

	/*
		GetProceduralTiles(): https://iquilezles.org/articles/texturerepetition
		GetSmootherStep(): https://iquilezles.org/articles/texture/

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

	float2 GetSmootherStep(float2 X)
	{
		return X * X * X * (X * (X * 6.0 - 15.0) + 10.0);
	}

	float GradientNoise(float2 Tex)
	{
		float2 I = floor(Tex);
		float2 F = frac(Tex);
		float A = GetHash(I + float2(0.0, 0.0));
		float B = GetHash(I + float2(1.0, 0.0));
		float C = GetHash(I + float2(0.0, 1.0));
		float D = GetHash(I + float2(1.0, 1.0));
		float2 UV = GetSmootherStep(F);
		return lerp(lerp(A, B, UV.x), lerp(C, D, UV.x), UV.y);
	}

	float4 GetProceduralTiles(sampler2D Source, float2 Tex)
	{
		// Sample variation pattern
		float Variation = GradientNoise(Tex);

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

	/*
		Interleaved Gradient Noise Dithering
		---
		http://www.iryoku.com/downloads/Next-Generation-Post-Processing-in-Call-of-Duty-Advanced-Warfare-v18.pptx
	*/
	float GetGradientNoise(float2 Position)
	{
		return frac(52.9829189 * frac(dot(Position, float2(0.06711056, 0.00583715))));
	}

	float2 GetPixelSize(float2 Tex)
	{
		return abs(float2(ddx(Tex.x), ddy(Tex.y)));
	}

	int2 GetScreenSize(float2 Tex)
	{
		return int2(1.0 / GetPixelSize(Tex));
	}

	float GetAspectRatio(float2 ScreenSize)
	{
		return float(ScreenSize.y) / float(ScreenSize.x);
	}

	/*
		Convolutions
	*/

	float4 GetLinearGaussianBlur(sampler2D Source, float2 Tex, bool IsHorizontal)
	{
		const float2 Offsets[5] =
		{
			float2(0.0, 0.0),
			float2(0.0, 1.4584295167832),
			float2(0.0, 3.4039848066734835),
			float2(0.0, 5.351805780136256),
			float2(0.0, 7.302940716034593)
		};

		const float Weights[5] =
		{
			0.1329807601338109,
			0.2322770777384485,
			0.13532693306504567,
			0.05115603510197893,
			0.012539291705835646
		};

		float4 OutputColor = 0.0;
		float4 TotalWeights = 0.0;
		float2 PixelSize = GetPixelSize(Tex);

		OutputColor += tex2D(Source, Tex + (Offsets[0].xy * PixelSize)) * Weights[0];
		TotalWeights += Weights[0];

		for(int i = 1; i < 5; i++)
		{
			float2 Offset = (IsHorizontal) ? Offsets[i].yx : Offsets[i].xy;
			OutputColor += tex2D(Source, Tex + (Offset * PixelSize)) * Weights[i];
			OutputColor += tex2D(Source, Tex - (Offset * PixelSize)) * Weights[i];
			TotalWeights += (Weights[i] * 2.0);
		}

		return OutputColor / TotalWeights;
	}

	float4 GetSpiralBlur(sampler Source, float2 Pos, float2 Tex, float Bias)
	{
		// Initialize values
		float4 OutputColor = 0.0;
		float4 Weight = 0.0;

		// Get constants
		const float Pi2 = acos(-1.0) * 2.0;

		// Get texcoord data
		float Noise = Pi2 * GetGradientNoise(Pos);
		float AspectRatio = GetAspectRatio(GetScreenSize(Tex));

		float2 Rotation = 0.0;
		sincos(Noise, Rotation.y, Rotation.x);
		float2x2 RotationMatrix = float2x2(Rotation.x, Rotation.y, -Rotation.y, Rotation.x);

		for(int i = 1; i < 4; ++i)
		{
			for(int j = 0; j < 4 * i; ++j)
			{
				const float Shift = (Pi2 / (4.0 * float(i))) * float(j);
				float2 AngleShift = 0.0;
				sincos(Shift, AngleShift.x, AngleShift.y);
				AngleShift *= float(i);

				float2 Offset = mul(AngleShift, RotationMatrix);
				Offset.x *= AspectRatio;
				Offset *= Bias;
				OutputColor += tex2D(Source, Tex + (Offset * 0.01));
				Weight++;
			}
		}

		return OutputColor / Weight;
	}

	float2 GetHemiTex(float3 WorldPos, float3 WorldNormal, float3 HemiInfo, bool InvertY)
	{
		// HemiInfo: Offset x/y heightmapsize z / hemilerpbias w
		float2 HemiTex = 0.0;
		HemiTex.xy = ((WorldPos + (HemiInfo.z * 0.5) + WorldNormal).xz - HemiInfo.xy) / HemiInfo.z;
		HemiTex.y = (InvertY) ? 1.0 - HemiTex.y : HemiTex.y;
		return HemiTex;
	}

	// Gets radial light attenuation value for pointlights
	float GetLightAttenuation(float3 LightVec, float Attenuation)
	{
		return saturate(1.0 - dot(LightVec, LightVec) * Attenuation);
	}

	/*
		Sorry DICE, we're yoinking your code - Project Reality
		Function to generate world-space normals from terrain heightmap
		---
		https://media.contentapi.ea.com/content/dam/eacom/frostbite/files/chapter5-andersson-terrain-rendering-in-frostbite.pdf
	*/
	float3 GetNormalsFromHeight(sampler SampleHeight, float2 TexCoord)
	{
		float2 TexelSize = float2(ddx(TexCoord.x), ddy(TexCoord.y));
		float4 H;
		H[0] = tex2D(SampleHeight, TexCoord + (TexelSize * float2( 0.0,-1.0))).a;
		H[1] = tex2D(SampleHeight, TexCoord + (TexelSize * float2(-1.0, 0.0))).a;
		H[2] = tex2D(SampleHeight, TexCoord + (TexelSize * float2( 1.0, 0.0))).a;
		H[3] = tex2D(SampleHeight, TexCoord + (TexelSize * float2( 0.0, 1.0))).a;

		float3 N;
		N.z = H[0] - H[3];
		N.x = H[1] - H[2];
		N.y = 2.0;
		return normalize(N);
	}
#endif
