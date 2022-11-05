
/*
	Description: Shared functions for BF2's main 3D shaders
*/

#if !defined(RACOMMON_FX)
	#define RACOMMON_FX

	#include "shaders/RaDefines.fx"
	#include "shaders/RealityGraphics.fx"

	#if defined(DISABLE_DIFFUSEMAP)
		#if defined(DISABLE_BUMPMAP)
			#ifndef DISABLE_SPECULAR
				#define DRAW_ONLY_SPEC
			#endif
		#endif
	#endif

	#if defined(DRAW_ONLY_SPEC)
		#define DEFAULT_DIFFUSE_MAP_COLOR float4(0, 0, 0, 1)
	#else
		#define DEFAULT_DIFFUSE_MAP_COLOR float4(1, 1, 1, 1)
	#endif

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

	int srcBlend = 5;
	int destBlend = 6;
	bool alphaBlendEnable = true;

	int alphaRef = 20;
	int CullMode = 3; // D3DCULL_CCW
	#define HARDCODED_PARALLAX_BIAS 0.004

	float GlobalTime;
	float WindSpeed = 0;

	float4 HemiMapConstants;

	float4 Transparency = 1.0f;

	float4x4 World;
	float4x4 ViewProjection;
	float4x4 WorldViewProjection;

	bool AlphaTest = false;

	float4 FogRange : fogRange;
	float4 FogColor : fogColor;

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
	float4x4 ShadowProjMat : ShadowProjMatrix;
	float4x4 ShadowOccProjMat : ShadowOccProjMatrix;
	float4x4 ShadowTrapMat : ShadowTrapMatrix;

	texture ShadowMap : SHADOWMAP;
	sampler SampleShadowMap
	#if defined(_CUSTOMSHADOWSAMPLER_)
		: register(_CUSTOMSHADOWSAMPLER_)
	#endif
	= sampler_state
	{
		Texture = (ShadowMap);
		MinFilter = LINEAR;
		MagFilter = LINEAR;
		MipFilter = LINEAR;
		AddressU = CLAMP;
		AddressV = CLAMP;
		AddressW = CLAMP;
	};

	texture ShadowOccluderMap : SHADOWOCCLUDERMAP;
	sampler ShadowOccluderMapSampler = sampler_state
	{
		Texture = (ShadowOccluderMap);
		MinFilter = LINEAR;
		MagFilter = LINEAR;
		MipFilter = LINEAR;
		AddressU = CLAMP;
		AddressV = CLAMP;
		AddressW = CLAMP;
	};

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
