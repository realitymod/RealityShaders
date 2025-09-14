#line 2 "RaCommon.fxh"

/*
	Include header files
*/

#include "shaders/RaDefines.fx"
#include "shaders/RealityGraphics.fxh"
#if !defined(_HEADERS_)
	#include "RaDefines.fx"
	#include "RealityGraphics.fxh"
#endif

/*
	Description: Shared functions for BF2's main 3D shaders
*/

#if !defined(_HEADERS_)
	#define _HEADERS_
#endif

#if !defined(RACOMMON_FXH)
	#define RACOMMON_FXH

	/*
		Cached shader variables
	*/

	/*
		The Light struct stores the properties of the sun and/or point light
		RaShaderBM: World-Space
		RaShaderSM: Object-Space
		RaShaderSTM: Object-Space
	*/
	#if defined(_EDITOR_)
		struct Light
		{
			float3 pos;
			float3 dir;
			float3 color;
			float attenuation;
		};
	#else
		struct Light
		{
			float3 pos;
			float3 dir;
			float4 color;
			float4 specularColor;
			float attenuation;
		};
	#endif

	bool alphaBlendEnable = true;
	int srcBlend = 5;
	int destBlend = 6;

	bool AlphaTest = false;
	int alphaRef = 20;
	int CullMode = 3; // D3DCULL_CCW

	float GlobalTime;
	float WindSpeed = 0;

	float4 HemiMapConstants;
	float4 Transparency = 1.0;

	float4x4 World;
	float4x4 ViewProjection;
	float4x4 WorldViewProjection;

	float4 FogRange : fogRange;
	float4 FogColor : fogColor;

	/*
		Data manipulation
	*/

	// Decodes value from a Short integer to [-1,1]
	// (2 ^ (16 - 1)) - 1 == 32767.0
	#define DECODE_SHORT(SHORT) (SHORT / 32767.0)

	/*
		Shared transformation code
	*/

	float3 GetWorldPos(float3 ObjectPos)
	{
		return mul(float4(ObjectPos, 1.0), World).xyz;
	}

	float3 GetWorldNormal(float3 ObjectNormal)
	{
		return normalize(mul(ObjectNormal, (float3x3)World));
	}

	float3 GetWorldLightPos(float3 ObjectLightPos)
	{
		return mul(float4(ObjectLightPos, 1.0), World).xyz;
	}

	float3 GetWorldLightDir(float3 ObjectLightDir)
	{
		return mul(ObjectLightDir, (float3x3)World);
	}

	/*
		Shared thermal code
	*/

	bool IsTisActive()
	{
		#if defined(_EDITOR_)
			return false;
		#else
			return FogColor.r == 0.0;
		#endif
	}

	/*
		Shared fogging and fading functions
	*/

	float GetFogValue(float4 ObjectPos, float4 CameraPos)
	{
		#if defined(_EDITOR_)
			#if defined(LOG_DEPTH)
				float FogDistance = ObjectPos.w - 1.0;
			#else
				float FogDistance = ObjectPos.w;
			#endif
		#else
			float FogDistance = length(ObjectPos.xyz - CameraPos.xyz);
		#endif

		float2 FogValues = (FogDistance * FogRange.xy) + FogRange.zw;
		float Close = max(FogValues.y, FogColor.a);
		float Far = pow(FogValues.x, 3.0);
		return smoothstep(0.0, 1.0, Close - Far);
	}

	void ApplyFog(inout float3 Color, in float FogValue)
	{
		float3 Fog = FogColor;

		// Adjust fog for thermals same way as the sky in SkyDome
		if (IsTisActive())
		{
			// TIS uses Green + Red channel to determine heat
			Fog.r = 0.0;
			// Green = 1 means cold, Green = 0 hot. Invert channel so clouds (high green) become hot
			// Add constant to make everything colder
			Fog.g = (1.0 - Fog.g) + 0.5;
		}

		Color = lerp(Fog, Color, FogValue);
	}

	float GetRoadZFade(float3 ObjectPos, float3 CameraPos, float2 FadeValues)
	{
		return saturate(1.0 - saturate((distance(ObjectPos.xyz, CameraPos.xyz) * FadeValues.x) - FadeValues.y));
	}

	/*
		Shared shadowing functions
	*/

	// Common dynamic shadow stuff
	float4x4 ShadowProjMat : ShadowProjMatrix;
	float4x4 ShadowOccProjMat : ShadowOccProjMatrix;
	float4x4 ShadowTrapMat : ShadowTrapMatrix;

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
		}; \

	texture ShadowMap : SHADOWMAP;
	#if defined(_CUSTOMSHADOWSAMPLER_)
		CREATE_SHADOW_SAMPLER(SampleShadowMap : register(_CUSTOMSHADOWSAMPLER_), ShadowMap)
	#else
		CREATE_SHADOW_SAMPLER(SampleShadowMap, ShadowMap)
	#endif

	texture ShadowOccluderMap : SHADOWOCCLUDERMAP;
	CREATE_SHADOW_SAMPLER(SampleShadowOccluderMap, ShadowOccluderMap)

	// Description: Transforms the vertex position's depth from World/Object space to light space
	// tl: Make sure Pos and matrices are in same space!
	float4 GetShadowProjection(float4 Pos, uniform bool IsOccluder = false)
	{
		float4 ShadowCoords = mul(Pos, ShadowTrapMat);
		float4 LightCoords = (IsOccluder) ? mul(Pos, ShadowOccProjMat) : mul(Pos, ShadowProjMat);

		LightCoords.z += PR_DEPTHBIAS_OBJECT;
		ShadowCoords.z = LightCoords.z / LightCoords.w;

		return ShadowCoords;
	}
#endif
