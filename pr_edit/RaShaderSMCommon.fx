
// common StaticMesh samplers


// Fallback stuff
string DeprecationList[] =
{
	{"hasnormalmap", "objspacenormalmap", ""},
	{"usehemimap", "hasenvmap", ""},
	{"hasshadow", ""},
	{"hascolormapgloss", ""},
};

texture HemiMap;
sampler HemiMapSampler = sampler_state
{
	Texture = (HemiMap);
	MipFilter = LINEAR;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	AddressU = CLAMP;
	AddressV = CLAMP;
	MipMapLodBias = 0;
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
	MipMapLodBias = 0;
};

texture DiffuseMap;
sampler DiffuseMapSampler = sampler_state
{
	Texture = (DiffuseMap);
	MipFilter = LINEAR;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	AddressU = CLAMP;
	AddressV = CLAMP;
	MipMapLodBias = 0;
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
	MipMapLodBias = 0;
};

float4 ObjectSpaceCamPos;
float4 WorldSpaceCamPos;

int AlphaTestRef = 0;
bool DepthWrite = 1;
bool DoubleSided = 2;

float4 DiffuseColor;
float4 SpecularColor;
float SpecularPower;
float StaticGloss;
float4 Ambient;

float4 HemiMapSkyColor;
float HeightOverTerrain = 0;

float Reflectivity;

float4x3 MatBones[26];

Light Lights[1];
