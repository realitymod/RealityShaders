
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

	// VARIABLES
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
	#define FH2_HARDCODED_PARALLAX_BIAS 0.0025

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

	float3 ApplyFog(float3 Color, float FogValue)
	{
		return lerp(FogColor.rgb, Color.rgb, FogValue);
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
	sampler ShadowMapSampler
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

	/*
		Description: GetShadowProjection() transforms the vertex position's depth from World/Object space to light space
		tl: Make sure Pos and matrices are in same space!
	*/

	float4 GetShadowProjection(float4 Pos, uniform bool IsOccluder = false)
	{
		float4 TexShadow1 = mul(Pos, ShadowTrapMat);
		float2 TexShadow2 = (IsOccluder) ? mul(Pos, ShadowOccProjMat).zw : mul(Pos, ShadowProjMat).zw;

		#if NVIDIA
			TexShadow1.z = (TexShadow2.x * TexShadow1.w) / TexShadow2.y; // (zL*wT)/wL == zL/wL post homo
		#else
			TexShadow1.z = TexShadow2.x;
		#endif

		return TexShadow1;
	}

	/*
		Description: GetShadowFactor() compares the depth between the shadowmap's depth (ShadowSampler)
		and the vertex position's transformed, light-space depth (ShadowCoords.z)
	*/

	float4 GetShadowFactor(sampler ShadowSampler, float4 ShadowCoords)
	{
		float4 Texel = float4(0.5 / 1024.0, 0.5 / 1024.0, 0.0, 0.0);
		float4 Samples = 0.0;
		Samples.x = tex2Dproj(ShadowSampler, ShadowCoords);
		Samples.y = tex2Dproj(ShadowSampler, ShadowCoords + float4(Texel.x, 0.0, 0.0, 0.0));
		Samples.z = tex2Dproj(ShadowSampler, ShadowCoords + float4(0.0, Texel.y, 0.0, 0.0));
		Samples.w = tex2Dproj(ShadowSampler, ShadowCoords + Texel);

		// We need a bias to prevent shadow acne
		const float Bias = -0.001;
		float4 CMPBits = step(saturate(ShadowCoords.z + Bias), Samples);
		return dot(CMPBits, 0.25);
	}
#endif
