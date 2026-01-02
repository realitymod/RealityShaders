#line 2 "RaShaderBM.fxh"

/*
    This header file provides data structures and parameters for the RaShaderBM shader. It includes bone matrices, lighting parameters, material properties, and sampler definitions for bundled mesh rendering.
*/

#include "shaders/RaCommon.fxh"
#if !defined(_HEADERS_)
	#include "RaCommon.fxh"
#endif

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
} UserData;

Light Lights[1];
float4 PosUnpack;
float TexUnpack;
float2 NormalUnpack;

// Common BundledMesh samplers

#define CREATE_SAMPLER(SAMPLER_NAME, TEXTURE, ADDRESS) \
	sampler SAMPLER_NAME = sampler_state \
	{ \
		Texture = (TEXTURE); \
		MinFilter = FILTER_BM_DIFF_MIN; \
		MagFilter = FILTER_BM_DIFF_MAG; \
		MipFilter = LINEAR; \
		MaxAnisotropy = PR_MAX_ANISOTROPY; \
		AddressU = ADDRESS; \
		AddressV = ADDRESS; \
		AddressW = ADDRESS; \
	}; \

texture HemiMap;
CREATE_SAMPLER(SampleHemiMap, HemiMap, CLAMP)

texture GIMap;
CREATE_SAMPLER(SampleGIMap, GIMap, CLAMP)

texture CubeMap;
CREATE_SAMPLER(SampleCubeMap, CubeMap, WRAP)

texture DiffuseMap;
CREATE_SAMPLER(SampleDiffuseMap, DiffuseMap, CLAMP)

texture NormalMap;
CREATE_SAMPLER(SampleNormalMap, NormalMap, CLAMP)
