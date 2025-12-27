#line 2 "RaShaderSM.fxh"

/*
	Include header files
*/

#include "shaders/RaCommon.fxh"
#if !defined(_HEADERS_)
	#include "RaCommon.fxh"
#endif

/*
	Description: Provides data for the RaShaderSM shader.
*/

// Fallback stuff
string DeprecationList[] =
{
	{ "hasnormalmap", "objspacenormalmap", "" },
	{ "usehemimap", "hasenvmap", "" },
	{ "hasshadow", "" },
	{ "hascolormapgloss", "" },
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

// Common SkinnedMesh samplers

#define CREATE_SAMPLER(SAMPLER_NAME, TEXTURE, ADDRESS) \
	sampler SAMPLER_NAME = sampler_state \
	{ \
		Texture = (TEXTURE); \
		MinFilter = LINEAR; \
		MagFilter = LINEAR; \
		MipFilter = LINEAR; \
		AddressU = ADDRESS; \
		AddressV = ADDRESS; \
		AddressW = ADDRESS; \
	}; \

texture HemiMap;
CREATE_SAMPLER(SampleHemiMap, HemiMap, CLAMP)

texture CubeMap;
CREATE_SAMPLER(SampleCubeMap, CubeMap, WRAP)

texture DiffuseMap;
CREATE_SAMPLER(SampleDiffuseMap, DiffuseMap, CLAMP)

texture NormalMap;
CREATE_SAMPLER(SampleNormalMap, NormalMap, CLAMP)
