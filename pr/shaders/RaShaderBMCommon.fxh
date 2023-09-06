#include "shaders/RealityGraphics.fxh"

/*
	Data for RaShaderBM
*/

uniform float4 WorldSpaceCamPos;

uniform bool AlphaBlendEnable = false;
uniform int AlphaTestRef = 0;
uniform bool DepthWrite = 1;
uniform bool DoubleSided = 2;

uniform float4 DiffuseColor;
uniform float4 DiffuseColorAndAmbient;
uniform float4 SpecularColor;
uniform float SpecularPower;
uniform float4 StaticGloss;
uniform float4 Ambient;

uniform float4 HemiMapSkyColor;
uniform float InvHemiHeightScale = 100;
uniform float HeightOverTerrain = 0;

uniform float Reflectivity;

uniform float4x3 GeomBones[26];
struct
{
	float4x4 uvMatrix[7] : UVMatrix;
} UserData;

Light Lights[1];
uniform float4 PosUnpack;
uniform float TexUnpack;
uniform float2 NormalUnpack;

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

uniform texture HemiMap;
CREATE_SAMPLER(SampleHemiMap, HemiMap, CLAMP)

uniform texture GIMap;
CREATE_SAMPLER(SampleGIMap, GIMap, CLAMP)

uniform texture CubeMap;
CREATE_SAMPLER(SampleCubeMap, CubeMap, WRAP)

uniform texture DiffuseMap;
CREATE_SAMPLER(SampleDiffuseMap, DiffuseMap, CLAMP)

uniform texture NormalMap;
CREATE_SAMPLER(SampleNormalMap, NormalMap, CLAMP)
