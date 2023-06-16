
/*
	Data for RaShaderSTM
*/

#define nbase 0x1
#define ndetail 0x10

uniform float4 ObjectSpaceCamPos;
uniform float4 WorldSpaceCamPos;
uniform float4 PosUnpack;
uniform float TexUnpack;
uniform float2 NormalUnpack;
uniform float4 LightMapOffset;
uniform bool AlphaBlendEnable;
uniform float4 StaticSkyColor;
uniform float4 StaticSpecularColor;
uniform float SpecularPower;
uniform float4 PointColor;
uniform float4 StaticSunColor;
uniform float4 SinglePointColor;
uniform float4 ParallaxScaleBias;
uniform float StaticGloss;

// Common StaticMesh samplers
// NOTE: Anisotropic filtering does not bode well with HESCO barriers

#define CREATE_SAMPLER(SAMPLER_NAME, TEXTURE) \
	sampler SAMPLER_NAME = sampler_state \
	{ \
		Texture = (TEXTURE); \
		MinFilter = LINEAR; \
		MagFilter = LINEAR; \
		MipFilter = LINEAR; \
		AddressU = WRAP; \
		AddressV = WRAP; \
	}; \

#define CREATE_DYNAMIC_SAMPLER(SAMPLER_NAME, TEXTURE) \
	sampler SAMPLER_NAME = sampler_state \
	{ \
		Texture = (TEXTURE); \
		MinFilter = FILTER_STM_DIFF_MIN; \
		MagFilter = FILTER_STM_DIFF_MAG; \
		MipFilter = LINEAR; \
		MaxAnisotropy = 16; \
		AddressU = WRAP; \
		AddressV = WRAP; \
	}; \

uniform texture LightMap;
CREATE_SAMPLER(SampleLightMap, LightMap)

uniform texture DetailMap;
CREATE_DYNAMIC_SAMPLER(SampleDetailMap, DetailMap)

uniform texture DirtMap;
CREATE_SAMPLER(SampleDirtMap, DirtMap)

uniform texture CrackMap;
CREATE_DYNAMIC_SAMPLER(SampleCrackMap, CrackMap)

uniform texture CrackNormalMap;
CREATE_SAMPLER(SampleCrackNormalMap, CrackNormalMap)

uniform texture DiffuseMap;
CREATE_SAMPLER(SampleDiffuseMap, DiffuseMap)

uniform texture NormalMap;
CREATE_SAMPLER(SampleNormalMap, NormalMap)
