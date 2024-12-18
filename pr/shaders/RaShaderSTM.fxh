#line 2 "RaShaderSTM.fxh"

/*
	Include header files
*/

#include "shaders/RealityGraphics.fxh"

/*
	Data for RaShaderSTM
*/

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

texture LightMap;
CREATE_SAMPLER(SampleLightMap, LightMap)

texture DetailMap;
CREATE_SAMPLER(SampleDetailMap, DetailMap)

texture DirtMap;
CREATE_SAMPLER(SampleDirtMap, DirtMap)

texture CrackMap;
CREATE_SAMPLER(SampleCrackMap, CrackMap)

texture CrackNormalMap;
CREATE_SAMPLER(SampleCrackNormalMap, CrackNormalMap)

texture DiffuseMap;
CREATE_SAMPLER(SampleDiffuseMap, DiffuseMap)

texture NormalMap;
CREATE_SAMPLER(SampleNormalMap, NormalMap)

