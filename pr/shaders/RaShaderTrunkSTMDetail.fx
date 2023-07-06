#include "shaders/RealityGraphics.fxh"
#include "shaders/RaCommon.fxh"

/*
	Description: Renders lighting for objects with characteristics of tree-trunks (poles)
*/

#if !defined(_HASSHADOW_)
	#define _HASSHADOW_ 0
#endif

// uniform float3 TreeSkyColor;
uniform float4 OverGrowthAmbient;
uniform float4 PosUnpack;
uniform float2 NormalUnpack;
uniform float TexUnpack;
uniform float4 WorldSpaceCamPos;
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

uniform texture DetailMap;
CREATE_SAMPLER(SampleDetailMap, DetailMap)

uniform texture DiffuseMap;
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

	float3 WorldNormal : TEXCOORD1;
	float4 Tex : TEXCOORD2; // .xy = Tex0 (Diffuse); .zw = Tex1 (Detail);
};

struct PS2FB
{
	float4 Color : COLOR;
	#if defined(LOG_DEPTH)
		float Depth : DEPTH;
	#endif
};

VS2PS VS_TrunkSTMDetail(APP2VS Input)
{
	VS2PS Output = (VS2PS)0;

	// Object-space data
	float4 ObjectPos = Input.Pos * PosUnpack;
	float3 ObjectNormal = Input.Normal * NormalUnpack.x + NormalUnpack.y;

	// Output HPos
	Output.HPos = mul(float4(ObjectPos.xyz, 1.0), WorldViewProjection);

	// World-space data
	Output.Pos.xyz = GetWorldPos(ObjectPos.xyz);
	#if defined(LOG_DEPTH)
		Output.Pos.w = Output.HPos.w + 1.0; // Output depth
	#endif
	Output.WorldNormal.xyz = GetWorldNormal(ObjectNormal);

	// Get texture-space data
	Output.Tex.xy = Input.Tex0 * TexUnpack;
	#if !defined(BASEDIFFUSEONLY)
		Output.Tex.zw = Input.Tex1 * TexUnpack;
	#endif

	return Output;
}

PS2FB PS_TrunkSTMDetail(VS2PS Input)
{
	PS2FB Output = (PS2FB)0;

	// World-space data
	float4 WorldPos = float4(Input.Pos.xyz, 1.0);
	float3 WorldNormal = normalize(Input.WorldNormal.xyz);
	float3 WorldLightVec = GetWorldLightDir(-Lights[0].dir);
	float3 WorldNLightVec = normalize(WorldLightVec);

	// Texture data
	float4 DiffuseMap = tex2D(SampleDiffuseMap, Input.Tex.xy);
	#if !defined(BASEDIFFUSEONLY)
		DiffuseMap *= tex2D(SampleDetailMap, Input.Tex.zw);
	#endif

	// Get diffuse lighting
	float3 Diffuse = ComputeLambert(WorldNormal, WorldNLightVec) * Lights[0].color;
	#if _HASSHADOW_
		float4 ShadowTex = GetShadowProjection(WorldPos);
		float Shadow = GetShadowFactor(SampleShadowMap, ShadowTex);
	#else
		float Shadow = 1.0;
	#endif
	Diffuse = saturate(OverGrowthAmbient.rgb + (Diffuse * Shadow));

	float4 OutputColor = 0.0;
	OutputColor.rgb = (DiffuseMap.rgb * Diffuse.rgb) * 2.0;
	OutputColor.a = Transparency.a * 2.0;

	Output.Color = OutputColor;
	ApplyFog(Output.Color.rgb, GetFogValue(WorldPos.xyz, WorldSpaceCamPos.xyz));

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);
	#endif

	return Output;
};

technique defaultTechnique
{
	pass Pass0
	{
		#if defined(ENABLE_WIREFRAME)
			FillMode = WireFrame;
		#endif

		AlphaTestEnable = (AlphaTest);
		AlphaRef = 127; // temporary hack by johan because "m_shaderSettings.m_alphaTestRef = 127" somehow doesn't work

		VertexShader = compile vs_3_0 VS_TrunkSTMDetail();
		PixelShader = compile ps_3_0 PS_TrunkSTMDetail();
	}
}
