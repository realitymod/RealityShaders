#include "shaders/RaDefines.fx"

#include "shaders/dataTypes.fx"

#ifdef DISABLE_DIFFUSEMAP
	#ifdef DISABLE_BUMPMAP
		#ifndef DISABLE_SPECULAR
			#define DRAW_ONLY_SPEC
		#endif
	#endif
#endif

#ifdef DRAW_ONLY_SPEC
	#define DEFAULT_DIFFUSE_MAP_COLOR float4(0,0,0,1)
#else
	#define DEFAULT_DIFFUSE_MAP_COLOR float4(1,1,1,1)
#endif 

// VARIABLES
struct Light
{
	float3 pos;
	float3 dir;
	float3 color;
	float attenuation;
};

int srcBlend = 5;
int destBlend = 6;
bool alphaBlendEnable = true;

int alphaRef = 20;
int CullMode = 3;	// D3DCULL_CCW

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

float calcFog(float w)
{
	half2 fogVals = w*FogRange.xy + FogRange.zw;
	half close = max(fogVals.y, FogColor.w);
	half far = pow(fogVals.x,3);
	return close-far;
}

#ifdef PSVERSION
	#if PSVERSION >= 20
		#define CEXP(constant) constant
	#else
		// These are _d2 on CPU to fit [-1,+1] range
		#define CEXP(constant) (2.f * constant)
	#endif
#endif

#define NO_VAL float3(1, 1, 0)

float4 showChannel(
	float3 diffuse = NO_VAL, 
	float3 normal = NO_VAL, 
	float specular = 0, 
	float alpha = 0,
	float3 shadow = 0,
	float3 environment = NO_VAL)
{
	float4 returnVal = float4(0, 1, 1, 0);
#ifdef DIFFUSE_CHANNEL
	returnVal = float4(diffuse, 1);
#endif

#ifdef NORMAL_CHANNEL
	returnVal = float4(normal, 1);
#endif
	
#ifdef SPECULAR_CHANNEL
	returnVal = float4(specular, specular, specular, 1);
#endif
	
#ifdef ALPHA_CHANNEL
	returnVal = float4(alpha, alpha, alpha, 1);
#endif
	
#ifdef ENVIRONMENT_CHANNEL
	returnVal = float4(environment, 1);
#endif
	
#ifdef SHADOW_CHANNEL
	returnVal = float4(shadow, 1);
#endif
	
	return returnVal;
}



// Common dynamic shadow stuff

#if !defined(SHADOWVERSION) && defined(PSVERSION)
#define SHADOWVERSION PSVERSION
#elif !defined(SHADOWVERSION)
#define SHADOWVERSION 0
#endif

float4x4 ShadowProjMat : ShadowProjMatrix;
float4x4 ShadowTrapMat : ShadowTrapMatrix;

texture ShadowMap : SHADOWMAP;
sampler ShadowMapSampler 
#ifdef _CUSTOMSHADOWSAMPLER_
: register(_CUSTOMSHADOWSAMPLER_)
#endif
= sampler_state
{
	Texture = (ShadowMap);
#if NVIDIA
	MinFilter = Linear;
	MagFilter = Linear;
#else
	MinFilter = Point;
	MagFilter = Point;
#endif
	MipFilter = None;
	AddressU = Clamp;
	AddressV = Clamp;
	AddressW = Clamp;
	MipMapLodBias = 0;	
};

// tl: Make _sure_ pos and matrices are in same space!
float4 calcShadowProjection(float4 pos, uniform float BIAS = -0.003)
{
	float4 texShadow1 =  mul(pos, ShadowTrapMat);
	float2 texShadow2 = mul(pos, ShadowProjMat).zw;
	texShadow2.x += BIAS;
#if !NVIDIA
	texShadow1.z = texShadow2.x;
#else
	texShadow1.z = (texShadow2.x*texShadow1.w)/texShadow2.y; 	// (zL*wT)/wL == zL/wL post homo
#endif

	return texShadow1;
}

// tl: Make _sure_ pos and matrices are in same space!
float4 calcShadowProjectionExact(float4 pos, uniform float BIAS = -0.003)
{
	float4 texShadow1 =  mul(pos, ShadowTrapMat);
	float2 texShadow2 = mul(pos, ShadowProjMat).zw;
	texShadow2.x += BIAS;
	texShadow1.z = texShadow2.x;

	return texShadow1;
}

float4 getShadowFactorNV(sampler shadowSampler, float4 shadowCoords, uniform int NSAMPLES = 4, uniform int VERSION = SHADOWVERSION)
{
	if(VERSION == 13)
		return tex2D(shadowSampler, shadowCoords);
	else if(VERSION >= 14)
		return tex2Dproj(shadowSampler, shadowCoords);

	// if(NSAMPLES <= 4)
}

float4 getShadowFactorExactNV(sampler shadowSampler, float4 shadowCoords, uniform int NSAMPLES = 4, uniform int VERSION = SHADOWVERSION)
{
	shadowCoords.z *= shadowCoords.w;
	
	if(VERSION == 13)
		return tex2D(shadowSampler, shadowCoords);
	else if(VERSION >= 14)
		return tex2Dproj(shadowSampler, shadowCoords);

	// if(NSAMPLES <= 4)
}

float4 getShadowFactorExactOther(sampler shadowSampler, float4 shadowCoords, uniform int NSAMPLES = 4, uniform int VERSION = SHADOWVERSION)
{
	if(VERSION == 13)
	{
		float samples = tex2D(shadowSampler, shadowCoords);
		return samples >= saturate(shadowCoords.z);
	}
	else if(VERSION == 14)
	{
		float samples = tex2Dproj(shadowSampler, shadowCoords);
		return samples >= saturate(shadowCoords.z);
	}
	else if(VERSION >= 20)
	{
		if(NSAMPLES == 1)
		{
			float samples = tex2Dproj(shadowSampler, shadowCoords);
			return samples >= saturate(shadowCoords.z);
		}
		else
		{
			float4 texel = float4(0.5 / 1024.0, 0.5 / 1024.0, 0, 0);
			float4 samples = 0;
			samples.x = tex2Dproj(shadowSampler, shadowCoords);
			samples.y = tex2Dproj(shadowSampler, shadowCoords + float4(texel.x, 0, 0, 0));
			samples.z = tex2Dproj(shadowSampler, shadowCoords + float4(0, texel.y, 0, 0));
			samples.w = tex2Dproj(shadowSampler, shadowCoords + texel);
			float4 cmpbits = samples >= saturate(shadowCoords.z);
			return dot(cmpbits, float4(0.25, 0.25, 0.25, 0.25));
		}
	}
}

// Currently fixed to 3 or 4.
float4 getShadowFactor(sampler shadowSampler, float4 shadowCoords, uniform int NSAMPLES = 4, uniform int VERSION = SHADOWVERSION)
{
#if NVIDIA
	return getShadowFactorNV(shadowSampler, shadowCoords, NSAMPLES, VERSION);
#else
	return getShadowFactorExactOther(shadowSampler, shadowCoords, NSAMPLES, VERSION);
#endif
}

float4 getShadowFactorExact(sampler shadowSampler, float4 shadowCoords, uniform int NSAMPLES = 4, uniform int VERSION = SHADOWVERSION)
{
#if NVIDIA
	return getShadowFactorExactNV(shadowSampler, shadowCoords, NSAMPLES, VERSION);
#else
	return getShadowFactorExactOther(shadowSampler, shadowCoords, NSAMPLES, VERSION);
#endif
}

texture SpecLUT64SpecularColor;
sampler SpecLUT64Sampler = sampler_state
{
	Texture = (SpecLUT64SpecularColor);
	MipFilter = NONE;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	AddressU = CLAMP;
	AddressV = CLAMP;
};

texture NormalizationCube;
sampler NormalizationCubeSampler = sampler_state
{
	Texture = (NormalizationCube);
	MipFilter = POINT;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	AddressU = WRAP;
	AddressV = WRAP;
	AddressW = WRAP;
};

#define NRMDONTCARE 0
#define NRMCUBE 1
#define NRMMATH 2
#define NRMCHEAP 3
float3 fastNormalize(float3 invec, uniform int preferMethod = NRMDONTCARE)
{
	if(preferMethod == NRMCUBE)
	{
		return texCUBE(NormalizationCubeSampler, invec) * 2 - 1;
	}
	else if(preferMethod == NRMMATH)
	{
		return normalize(invec);
	}
	else if(preferMethod == NRMCHEAP)
	{
		// Approximate renormalize: V + V * (1 - ||V||2) / 2
		return invec + invec * (1 - dot(invec, invec)) / 2;
	}
	else
	{
#if defined(PSVERSION) && PSVERSION > 20 && NVIDIA
		return normalize(invec);
#else
		return texCUBE(NormalizationCubeSampler, invec) * 2 - 1;
#endif
	}
}
