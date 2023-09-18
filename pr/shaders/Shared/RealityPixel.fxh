
/*
	Shared functions that process/generate data in the pixel shader
*/

#if !defined(REALITY_PIXEL)
	#define REALITY_PIXEL

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

	/*
		Get procedural terrain
		---
		Source: https://iquilezles.org/articles/texturerepetition/
	*/

	float4 GetHash4(float2 P)
	{ 
		float4 DP;
		DP[0] = 1.0 + dot(P, float2(37.0, 17.0));
		DP[1] = 2.0 + dot(P, float2(11.0, 47.0));
		DP[2] = 3.0 + dot(P, float2(41.0, 29.0));
		DP[3] = 4.0 + dot(P, float2(23.0, 31.0));
		return frac(sin(DP) * 103.0);
	}

	float4 GetProceduralTiles(sampler2D Source, float2 Tex)
	{
		// Get uv data
		int2 IntTex = int2(floor(Tex));
		float2 FracTex = frac(Tex);
		float2 TexIx = ddx(Tex);
		float2 TexIy = ddy(Tex);

		float4 Offset[4];
		// Generate per-tile transform
		Offset[0] = GetHash4(IntTex + int2(0, 0));
		Offset[1] = GetHash4(IntTex + int2(1, 0));
		Offset[2] = GetHash4(IntTex + int2(0, 1));
		Offset[3] = GetHash4(IntTex + int2(1, 1));
		// Transform per-tile uvs
		Offset[0].zw = sign(Offset[0].zw - 0.5);
		Offset[1].zw = sign(Offset[1].zw - 0.5);
		Offset[2].zw = sign(Offset[2].zw - 0.5);
		Offset[3].zw = sign(Offset[3].zw - 0.5);
		
		// uv's, and derivatives (for correct mipmapping)
		float4 OutColor[4];
		for(int i = 0; i < 4; i++)
		{
			float2 FetchTex = Tex * Offset[i].zw + Offset[i].xy;
			float2 GradX = TexIx * Offset[i].zw;
			float2 GradY = TexIy * Offset[i].zw;
			OutColor[i] = tex2Dgrad(Source, FetchTex, GradX, GradY);
		}
			
		// Fetch and blend
		float2 Blend = smoothstep(0.25, 0.75, FracTex);
		return lerp(lerp(OutColor[0], OutColor[1], Blend.x), 
					lerp(OutColor[2], OutColor[3], Blend.x), Blend.y);
	}
#endif
