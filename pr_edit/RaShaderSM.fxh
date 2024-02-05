
/*
	Include header files
*/

#include "shaders/RaCommon.fxh"
#if !defined(_HEADERS_)
	#include "RaCommon.fxh"
#endif

/*
	Data for RaShaderSM
*/

// Fallback stuff
string DeprecationList[] =
{
	{ "hasnormalmap", "objspacenormalmap", "" },
	{ "usehemimap", "hasenvmap", "" },
	{ "hasshadow", "" },
	{ "hascolormapgloss", "" },
};

uniform float4 ObjectSpaceCamPos;
uniform float4 WorldSpaceCamPos;

uniform int AlphaTestRef = 0;
uniform bool DepthWrite = 1;
uniform bool DoubleSided = 2;

uniform float4 DiffuseColor;
uniform float4 SpecularColor;
uniform float SpecularPower;
uniform float StaticGloss;
uniform float4 Ambient;

uniform float4 HemiMapSkyColor;
uniform float HeightOverTerrain = 0;

uniform float Reflectivity;

uniform float4x3 MatBones[26];

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

uniform texture HemiMap;
CREATE_SAMPLER(SampleHemiMap, HemiMap, CLAMP)

uniform texture CubeMap;
CREATE_SAMPLER(SampleCubeMap, CubeMap, WRAP)

uniform texture DiffuseMap;
CREATE_SAMPLER(SampleDiffuseMap, DiffuseMap, CLAMP)

uniform texture NormalMap;
CREATE_SAMPLER(SampleNormalMap, NormalMap, CLAMP)
