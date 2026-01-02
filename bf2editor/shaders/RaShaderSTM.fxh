#line 2 "RaShaderSTM.fxh"

/*
    This header file provides data structures and parameters for the RaShaderSTM shader. It includes material properties, texture sampling parameters, lighting constants, and sampler definitions for static mesh rendering with multiple texture layers.
*/

#include "shaders/RealityGraphics.fxh"

#define nbase 0x1
#define ndetail 0x10

float4 WorldSpaceCamPos;

float4 PosUnpack;
float TexUnpack;
float2 NormalUnpack;

float4 LightMapOffset;
bool AlphaBlendEnable;

float4 StaticSunColor;
float4 StaticSkyColor;
float4 StaticSpecularColor;
float4 PointColor;
float4 SinglePointColor;

float StaticGloss;
float SpecularPower;
float4 ParallaxScaleBias;

// Common StaticMesh samplers
#define CREATE_SAMPLER(SAMPLER_NAME, TEXTURE) \
	sampler SAMPLER_NAME = sampler_state \
	{ \
		Texture = (TEXTURE); \
		MinFilter = FILTER_STM_DIFF_MIN; \
		MagFilter = FILTER_STM_DIFF_MAG; \
		MipFilter = LINEAR; \
		MaxAnisotropy = PR_MAX_ANISOTROPY; \
		AddressU = WRAP; \
		AddressV = WRAP; \
	}; \

#define CREATE_SAMPLER_ANISOTROPIC(SAMPLER_NAME, TEXTURE) \
	sampler SAMPLER_NAME = sampler_state \
	{ \
		Texture = (TEXTURE); \
		MinFilter = LINEAR; \
		MagFilter = LINEAR; \
		MipFilter = LINEAR; \
		AddressU = WRAP; \
		AddressV = WRAP; \
	}; \

texture DiffuseMap;
CREATE_SAMPLER_ANISOTROPIC(SampleDiffuseMap, DiffuseMap)

texture DetailMap;
CREATE_SAMPLER_ANISOTROPIC(SampleDetailMap, DetailMap)

texture DirtMap;
CREATE_SAMPLER_ANISOTROPIC(SampleDirtMap, DirtMap)

texture CrackMap;
CREATE_SAMPLER_ANISOTROPIC(SampleCrackMap, CrackMap)

texture LightMap;
CREATE_SAMPLER_ANISOTROPIC(SampleLightMap, LightMap)

texture CrackNormalMap;
CREATE_SAMPLER(SampleCrackNormalMap, CrackNormalMap)

texture NormalMap;
CREATE_SAMPLER(SampleNormalMap, NormalMap)
