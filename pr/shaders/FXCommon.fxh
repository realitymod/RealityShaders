
/*
	Description: Shared code in particle shaders
*/

#if !defined(FXCOMMON_FXH)
	#define FXCOMMON_FXH
	#undef _HEADERS_
	#define _HEADERS_

	// Common parameters
	float4x4 _ViewMat : ViewMat;
	float4x4 _ProjMat : ProjMat;

	float _UVScale = rsqrt(2.0);
	float4 _HemiMapInfo : HemiMapInfo;
	float _HemiShadowAltitude : HemiShadowAltitude;
	float _AlphaPixelTestRef : AlphaPixelTestRef = 0;

	#define CREATE_SAMPLER(SAMPLER_NAME, TEXTURE) \
		sampler SAMPLER_NAME = sampler_state \
		{ \
			Texture = (TEXTURE); \
			MinFilter = LINEAR; \
			MagFilter = LINEAR; \
			MipFilter = LINEAR; \
			AddressU = CLAMP; \
			AddressV = CLAMP; \
		}; \

	// Particle Texture
	texture Tex0: Texture0;
	CREATE_SAMPLER(SampleDiffuseMap, Tex0)

	// Groundhemi Texture
	texture Tex1: Texture1;
	CREATE_SAMPLER(SampleLUT, Tex1)

	float3 _EffectSunColor : EffectSunColor;
	float3 _EffectShadowColor : EffectShadowColor;

	float3 GetParticleLighting(float LightMap, float LightMapOffset, float LightFactor)
	{
		float LUT = saturate(LightMap + LightMapOffset);
		float3 Diffuse = lerp(_EffectShadowColor, _EffectSunColor, LUT);
		return lerp(1.0, Diffuse, LightFactor);
	}

	float GetAltitude(float3 WorldPos, float Offset)
	{
		return saturate(saturate((WorldPos.y - _HemiShadowAltitude) / 10.0) + Offset);
	}
#endif
