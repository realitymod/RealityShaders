
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

	// tl: This is a float replicated to a float4 to make 1.3 shaders more efficient (they can't access .rg directly)
	float4 Transparency = 1.0f;

	float4x4 World;
	float4x4 ViewProjection;
	float4x4 WorldViewProjection;

	bool AlphaTest = false;

	float4 FogRange : fogRange;
	float4 FogColor : fogColor;

	/*
		Shared math functions
	*/

	float3x3 GetTangentBasis(float3 Tangent, float3 Normal, float Flip)
	{
		// Get Tangent and Normal
		Tangent = normalize(Tangent);
		Normal = normalize(Normal);

		// Re-orthogonalize Tangent with respect to Normal
		Tangent = normalize(Tangent - (Normal * dot(Tangent, Normal)));

		// Cross product * flip to create BiNormal
		float3 BiNormal = normalize(cross(Tangent, Normal)) * Flip;

		return float3x3(Tangent, BiNormal, Normal);
	}

	/*
		Shared lighting functions
	*/

	// Lambertian diffuse shader
	float GetDiffuseValue(float3 NormalVec, float3 LightVec)
	{
		return saturate(dot(NormalVec, LightVec));
	}

	// Blinn-Phong specular shader
	float GetSpecularValue(float3 NormalVec, float3 HalfVec, uniform float Exponent = 32.0)
	{
		return pow(saturate(dot(NormalVec, HalfVec)), Exponent);
	}

	// Gets radial light attenuation for pointlights
	float GetRadialAttenuation(float3 LightVec, float Attenuation)
	{
		return saturate(1.0 - saturate(length(LightVec) * Attenuation));
	}

	/*
		Shared fogging functions
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

	// tl: Make _sure_ Pos and matrices are in same space!
	float4 GetShadowProjection(float4 Pos, uniform float BIAS = -0.001, uniform bool ISOCCLUDER = false)
	{
		float4 TexShadow1 = mul(Pos, ShadowTrapMat);
		float2 TexShadow2 = (ISOCCLUDER) ? mul(Pos, ShadowOccProjMat).zw : mul(Pos, ShadowProjMat).zw;

		TexShadow2.x += BIAS;

		#if !NVIDIA
			TexShadow1.z = TexShadow2.x;
		#else
			TexShadow1.z = (TexShadow2.x * TexShadow1.w) / TexShadow2.y; // (zL*wT)/wL == zL/wL post homo
		#endif

		return TexShadow1;
	}

	float4 GetShadowFactor(sampler ShadowSampler, float4 ShadowCoords)
	{
		float4 Texel = float4(0.5 / 1024.0, 0.5 / 1024.0, 0.0, 0.0);
		float4 Samples = 0.0;
		Samples.x = tex2Dproj(ShadowSampler, ShadowCoords);
		Samples.y = tex2Dproj(ShadowSampler, ShadowCoords + float4(Texel.x, 0.0, 0.0, 0.0));
		Samples.z = tex2Dproj(ShadowSampler, ShadowCoords + float4(0.0, Texel.y, 0.0, 0.0));
		Samples.w = tex2Dproj(ShadowSampler, ShadowCoords + Texel);
		float4 CMPBits = Samples >= saturate(ShadowCoords.z);
		return dot(CMPBits, 0.25);
	}
#endif
