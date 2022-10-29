
/*
	Description: Shared code in particle shaders
*/

#if !defined(FXCOMMON_FX)
	#define FXCOMMON_FX

	#include "shaders/RaCommon.fx"

	// Particle Texture
	uniform texture Tex0: Texture0;

	// Groundhemi Texture
	uniform texture Tex1: Texture1;

	// commonparams
	uniform float4x4 _ViewMat : ViewMat;
	uniform float4x4 _ProjMat : ProjMat;

	uniform float _UVScale = rsqrt(2.0f);
	uniform float4 _HemiMapInfo : HemiMapInfo;
	uniform float _HemiShadowAltitude : HemiShadowAltitude;
	uniform float _AlphaPixelTestRef : AlphaPixelTestRef = 0;

	const float _OneOverShort = 1.0 / 32767.0;

	sampler SampleDiffuseMap = sampler_state
	{
		Texture = (Tex0);
		MinFilter = LINEAR;
		MagFilter = LINEAR;
		MipFilter = LINEAR;
		AddressU = CLAMP;
		AddressV = CLAMP;
	};

	sampler SampleLUT = sampler_state
	{
		Texture = (Tex1);
		MinFilter = LINEAR;
		MagFilter = LINEAR;
		MipFilter = LINEAR;
		AddressU = CLAMP;
		AddressV = CLAMP;
	};

	uniform float3 _EffectSunColor : EffectSunColor;
	uniform float3 _EffectShadowColor : EffectShadowColor;

	float3 GetParticleLighting(float LM, float LMOffset, float LightFactor)
	{
		float LUT = saturate(LM + LMOffset);
		float3 Diffuse = lerp(_EffectShadowColor, _EffectSunColor, LUT);
		return lerp(1.0, Diffuse, LightFactor);
	}
#endif
