
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
#endif
