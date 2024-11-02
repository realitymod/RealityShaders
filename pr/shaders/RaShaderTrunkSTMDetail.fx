
/*
	Include header files
*/

#include "shaders/RealityGraphics.fxh"
#include "shaders/shared/RealityDepth.fxh"
#include "shaders/shared/RealityDirectXTK.fxh"
#include "shaders/RaCommon.fxh"
#if !defined(_HEADERS_)
	#include "RealityGraphics.fxh"
	#include "shared/RealityDepth.fxh"
	#include "shared/RealityDirectXTK.fxh"
	#include "RaCommon.fxh"
#endif

/*
	Description: Renders lighting for objects with characteristics of tree-trunks (poles)
*/

#if !defined(_HASSHADOW_)
	#define _HASSHADOW_ 0
#endif

// float3 TreeSkyColor;
float4 OverGrowthAmbient;
float4 PosUnpack;
float2 NormalUnpack;
float TexUnpack;
float4 WorldSpaceCamPos;
Light Lights[1];

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

texture DetailMap;
CREATE_SAMPLER(SampleDetailMap, DetailMap)

texture DiffuseMap;
CREATE_SAMPLER(SampleDiffuseMap, DiffuseMap)

string GlobalParameters[] =
{
	#if _HASSHADOW_
		"ShadowMap",
	#endif
	"FogRange",
	"FogColor",
	"WorldSpaceCamPos"
};

string TemplateParameters[] =
{
	"PosUnpack",
	"NormalUnpack",
	"TexUnpack",
	"DiffuseMap",
	#if !defined(BASEDIFFUSEONLY)
		"DetailMap",
	#endif
};

string InstanceParameters[] =
{
	#if _HASSHADOW_
		"ShadowProjMat",
		"ShadowTrapMat",
	#endif
	"WorldViewProjection",
	"Transparency",
	"Lights",
	"OverGrowthAmbient",
	"World"
};

// INPUTS TO THE VERTEX SHADER FROM THE APP
string reqVertexElement[] =
{
	"PositionPacked",
	"NormalPacked8",
	"TBasePacked2D",
	#if !defined(BASEDIFFUSEONLY)
		"TDetailPacked2D",
	#endif
};

struct APP2VS
{
	float4 Pos : POSITION0;
	float3 Normal : NORMAL;
	float2 Tex0 : TEXCOORD0;
	#if !defined(BASEDIFFUSEONLY)
		float2 Tex1 : TEXCOORD1;
	#endif
};

struct VS2PS
{
	float4 HPos : POSITION;
	float4 Pos : TEXCOORD0;
	float4 Tex0 : TEXCOORD1; // .xy = Tex0 (Diffuse); .zw = Tex1 (Detail);
	float3 Lighting : TEXCOORD2;
	#if _HASSHADOW_
		float4 TexShadow : TEXCOORD3;
	#endif
};

struct PS2FB
{
	float4 Color : COLOR0;
	#if defined(LOG_DEPTH)
		float Depth : DEPTH;
	#endif
};

VS2PS VS_TrunkSTMDetail(APP2VS Input)
{
	VS2PS Output = (VS2PS)0.0;

	// Object-space data
	float4 ObjectPos = Input.Pos * PosUnpack;
	float3 ObjectNormal = Input.Normal * NormalUnpack.x + NormalUnpack.y;

	// Output HPos
	Output.HPos = mul(float4(ObjectPos.xyz, 1.0), WorldViewProjection);
	// World-space data
	float3 WorldPos = GetWorldPos(ObjectPos.xyz);
	Output.Pos = float4(WorldPos, Output.HPos.w);

	// Output Depth
	#if defined(LOG_DEPTH)
		Output.Pos.w = Output.HPos.w + 1.0;
	#endif

	// Get surface-space data
	Output.Tex0.xy = Input.Tex0 * TexUnpack;
	#if !defined(BASEDIFFUSEONLY)
		Output.Tex0.zw = Input.Tex1 * TexUnpack;
	#endif

	// Get lighting
	float3 WorldNormal = GetWorldNormal(ObjectNormal);
	float3 WorldLightDir = normalize(GetWorldLightDir(-Lights[0].dir));
	float3 WorldViewDir = normalize(WorldSpaceCamPos.xyz - WorldPos);

	// Get lighting
	float HalfNL = GetHalfNL(WorldNormal, WorldLightDir);
	Output.Lighting = Lights[0].color.rgb * HalfNL;

	#if _HASSHADOW_
		Output.TexShadow = GetShadowProjection(float4(ObjectPos.xyz, 1.0));
	#endif

	return Output;
}

PS2FB PS_TrunkSTMDetail(VS2PS Input)
{
	PS2FB Output = (PS2FB)0.0;

	// World-space data
	float4 WorldPos = Input.Pos;

	// Texture data
	float4 DiffuseMap = SRGBToLinearEst(tex2D(SampleDiffuseMap, Input.Tex0.xy));
	#if !defined(BASEDIFFUSEONLY)
		float4 DetailMap = SRGBToLinearEst(tex2D(SampleDetailMap, Input.Tex0.zw));
		DiffuseMap *= DetailMap;
	#endif

	// Get diffuse lighting
	#if _HASSHADOW_
		float Shadow = GetShadowFactor(SampleShadowMap, Input.TexShadow);
	#else
		float Shadow = 1.0;
	#endif

	float4 OutputColor = 0.0;
	OutputColor.rgb = CompositeLights(DiffuseMap.rgb, OverGrowthAmbient.rgb, Input.Lighting * Shadow, 0.0) * 2.0;
	OutputColor.a = Transparency.a * 2.0;

	Output.Color = OutputColor;
	ApplyFog(Output.Color.rgb, GetFogValue(WorldPos, WorldSpaceCamPos));
	TonemapAndLinearToSRGBEst(Output.Color);

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);
	#endif

	return Output;
};

technique defaultTechnique
{
	pass p0
	{
		ZEnable = TRUE;
		ZFunc = PR_ZFUNC_WITHEQUAL;

		#if defined(ENABLE_WIREFRAME)
			FillMode = WireFrame;
		#endif

		AlphaTestEnable = (AlphaTest);
		AlphaRef = PR_ALPHA_REF; // temporary hack by johan because "m_shaderSettings.m_alphaTestRef = 127" somehow doesn't work

		VertexShader = compile vs_3_0 VS_TrunkSTMDetail();
		PixelShader = compile ps_3_0 PS_TrunkSTMDetail();
	}
}
