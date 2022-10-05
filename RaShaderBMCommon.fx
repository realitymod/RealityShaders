// Common BundledMesh samplers

texture HemiMap;
sampler HemiMapSampler = sampler_state
{
	Texture = (HemiMap);
	MipFilter = LINEAR;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	AddressU = CLAMP;
	AddressV = CLAMP;
};

texture GIMap;
sampler GIMapSampler = sampler_state
{
	Texture = (GIMap);
	MipFilter = LINEAR;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	AddressU = CLAMP;
	AddressV = CLAMP;
};

texture CubeMap;
sampler CubeMapSampler = sampler_state
{
	Texture = (CubeMap);
	MipFilter = LINEAR;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	AddressU = WRAP;
	AddressV = WRAP;
	AddressW = WRAP;
};

texture DiffuseMap;
sampler DiffuseMapSampler = sampler_state
{
	Texture = (DiffuseMap);
	MipFilter = LINEAR;
	MinFilter = FILTER_BM_DIFF_MIN;
	MagFilter = FILTER_BM_DIFF_MAG;
	MaxAnisotropy = 16;
	AddressU = CLAMP;
	AddressV = CLAMP;
};

texture NormalMap;
sampler NormalMapSampler = sampler_state
{
	Texture = (NormalMap);
	MipFilter = LINEAR;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	AddressU = CLAMP;
	AddressV = CLAMP;
};

float4 ObjectSpaceCamPos;
float4 WorldSpaceCamPos;

bool AlphaBlendEnable = false;
int AlphaTestRef = 0;
bool DepthWrite = 1;
bool DoubleSided = 2;

float4 DiffuseColor;
float4 DiffuseColorAndAmbient;
float4 SpecularColor;
float SpecularPower;
float4 StaticGloss;
float4 Ambient;

float4 HemiMapSkyColor;
float InvHemiHeightScale = 100;
float HeightOverTerrain = 0;

float Reflectivity;

float4x3 GeomBones[26];
struct
{
	float4x4 uvMatrix[7] : UVMatrix;
}
UserData;

Light Lights[1];
float4 PosUnpack;
float TexUnpack;
float2 NormalUnpack;
