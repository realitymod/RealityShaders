
/*
	Description: Shared functions for BF2's main 3D shaders
*/

#if !defined(RACOMMON_FXH)
	#define RACOMMON_FXH

	#include "shaders/RaDefines.fx"
	#include "shaders/RealityGraphics.fxh"

	/*
		Cached shader variables
	*/

	/*
		The Light struct stores the properties of the sun and/or point light
		RaShaderBM: World-Space
		RaShaderSM: Object-Space
		RaShaderSTM: Object-Space
	*/
	struct Light
	{
		float3 pos;
		float3 dir;
		float4 color;
		float4 specularColor;
		float attenuation;
	};

	uniform bool alphaBlendEnable = true;
	uniform int srcBlend = 5;
	uniform int destBlend = 6;

	uniform bool AlphaTest = false;
	uniform int alphaRef = 20;
	uniform int CullMode = 3; // D3DCULL_CCW
	#define HARDCODED_PARALLAX_BIAS 0.004

	uniform float GlobalTime;
	uniform float WindSpeed = 0;

	uniform float4 HemiMapConstants;
	uniform float4 Transparency = 1.0f;

	uniform float4x4 World;
	uniform float4x4 ViewProjection;
	uniform float4x4 WorldViewProjection;

	uniform float4 FogRange : fogRange;
	uniform float4 FogColor : fogColor;

	/*
		Shared fogging and fading functions
	*/

	float GetFogValue(float3 ObjectPos, float3 CameraPos)
	{
		float FogDistance = distance(ObjectPos, CameraPos);
		float2 FogValues = FogDistance * FogRange.xy + FogRange.zw;
		float Close = max(FogValues.y, FogColor.w);
		float Far = pow(FogValues.x, 3.0);
		return saturate(Close - Far);
	}

	void ApplyFog(inout float3 Color, in float FogValue)
	{
		Color = lerp(FogColor.rgb, Color, FogValue);
	}

	void ApplyLinearFog(inout float3 Color, in float FogValue)
	{
		Color = lerp(SRGBToLinearEst(FogColor.rgb), Color, FogValue);
	}

	float GetRoadZFade(float3 ObjectPos, float3 CameraPos, float2 FadeValues)
	{
		return saturate(1.0 - saturate((distance(ObjectPos.xyz, CameraPos.xyz) * FadeValues.x) - FadeValues.y));
	}

	/*
		Shared shadowing functions
	*/

	// Common dynamic shadow stuff
	uniform float4x4 ShadowProjMat : ShadowProjMatrix;
	uniform float4x4 ShadowOccProjMat : ShadowOccProjMatrix;
	uniform float4x4 ShadowTrapMat : ShadowTrapMatrix;

	#define CREATE_SHADOW_SAMPLER(SAMPLER_NAME, TEXTURE) \
		sampler SAMPLER_NAME = sampler_state \
		{ \
			Texture = (TEXTURE); \
			MinFilter = LINEAR; \
			MagFilter = LINEAR; \
			MipFilter = LINEAR; \
			AddressU = CLAMP; \
			AddressV = CLAMP; \
			AddressW = CLAMP; \
			SRGBTexture = FALSE; \
		}; \

	uniform texture ShadowMap : SHADOWMAP;
	#if defined(_CUSTOMSHADOWSAMPLER_)
		CREATE_SHADOW_SAMPLER(SampleShadowMap : register(_CUSTOMSHADOWSAMPLER_), ShadowMap)
	#else
		CREATE_SHADOW_SAMPLER(SampleShadowMap, ShadowMap)
	#endif

	uniform texture ShadowOccluderMap : SHADOWOCCLUDERMAP;
	CREATE_SHADOW_SAMPLER(SampleShadowOccluderMap, ShadowOccluderMap)

	// Description: Transforms the vertex position's depth from World/Object space to light space
	// tl: Make sure Pos and matrices are in same space!
	float4 GetShadowProjection(float4 Pos, uniform bool IsOccluder = false)
	{
		float4 ShadowCoords = mul(Pos, ShadowTrapMat);
		float4 LightCoords = (IsOccluder) ? mul(Pos, ShadowOccProjMat) : mul(Pos, ShadowProjMat);

		#if NVIDIA
			ShadowCoords.z = (LightCoords.z * ShadowCoords.w) / LightCoords.w; // (zL*wT)/wL == zL/wL post homo
		#else
			ShadowCoords.z = LightCoords.z;
		#endif

		return ShadowCoords;
	}
#endif
