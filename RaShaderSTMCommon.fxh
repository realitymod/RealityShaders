#define nbase 0x1
#define ndetail 0x10

// common staticMesh samplers
texture LightMap;
sampler SampleLightMap = sampler_state
{
	Texture = (LightMap);
	MipFilter = LINEAR;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	AddressU = WRAP;
	AddressV = WRAP;
};

texture DetailMap;
sampler SampleDetailMap = sampler_state
{
	Texture = (DetailMap);
	MipFilter = LINEAR;
	MinFilter = FILTER_STM_DIFF_MIN;
	MagFilter = FILTER_STM_DIFF_MAG;
	MaxAnisotropy = 16;
	AddressU = WRAP;
	AddressV = WRAP;
};

texture DirtMap;
sampler SampleDirtMap = sampler_state
{
	Texture = (DirtMap);
	MipFilter = LINEAR;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	AddressU = WRAP;
	AddressV = WRAP;
};

texture CrackMap;
sampler SampleCrackMap = sampler_state
{
	Texture = (CrackMap);
	MipFilter = LINEAR;
	MinFilter = FILTER_STM_DIFF_MIN;
	MagFilter = FILTER_STM_DIFF_MAG;
	MaxAnisotropy = 16;
	AddressU = WRAP;
	AddressV = WRAP;
};

texture CrackNormalMap;
sampler SampleCrackNormalMap = sampler_state
{
	Texture = (CrackNormalMap);
	MipFilter = LINEAR;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	AddressU = WRAP;
	AddressV = WRAP;
};

texture DiffuseMap;
sampler SampleDiffuseMap = sampler_state
{
	Texture = (DiffuseMap);
	MipFilter = LINEAR;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	AddressU = WRAP;
	AddressV = WRAP;
};

texture NormalMap;
sampler SampleNormalMap = sampler_state
{
	Texture = (NormalMap);
	MipFilter = LINEAR;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	AddressU = WRAP;
	AddressV = WRAP;
};

float4 ObjectSpaceCamPos;
float4 PosUnpack;
float TexUnpack;
float2 NormalUnpack;
float4 LightMapOffset;
bool AlphaBlendEnable;
float4 StaticSkyColor;
float4 StaticSpecularColor;
float SpecularPower;
float4 PointColor;
float4 StaticSunColor;
float4 SinglePointColor;
float4 ParallaxScaleBias;
float StaticGloss;
