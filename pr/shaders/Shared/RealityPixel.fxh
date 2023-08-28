
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
