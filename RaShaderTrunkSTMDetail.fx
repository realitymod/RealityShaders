
/*
	Description: Renders lighting for objects with characteristics of tree-trunks (poles)
*/

#include "shaders/RealityGraphics.fxh"

#include "shaders/RaCommon.fxh"

#if !defined(_HASSHADOW_)
	#define _HASSHADOW_ 0
#endif

// uniform float3 TreeSkyColor;
uniform float4 OverGrowthAmbient;
uniform float4 PosUnpack;
uniform float2 NormalUnpack;
uniform float TexUnpack;
uniform float4 ObjectSpaceCamPos;
Light Lights[1];

#define CREATE_SAMPLER(SAMPLER_NAME, TEXTURE, IS_SRGB) \
	sampler SAMPLER_NAME = sampler_state \
	{ \
		Texture = (TEXTURE); \
		MinFilter = LINEAR; \
		MagFilter = LINEAR; \
		MipFilter = LINEAR; \
		AddressU = WRAP; \
		AddressV = WRAP; \
		SRGBTexture = IS_SRGB; \
	}; \

uniform texture DetailMap;
CREATE_SAMPLER(SampleDetailMap, DetailMap, FALSE)

uniform texture DiffuseMap;
CREATE_SAMPLER(SampleDiffuseMap, DiffuseMap, FALSE)

string GlobalParameters[] =
{
	#if _HASSHADOW_
		"ShadowMap",
	#endif
	"FogRange",
	"FogColor",
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
	"ObjectSpaceCamPos",
	"Lights",
	"OverGrowthAmbient",
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
	float4 P_Tex0_Tex1 : TEXCOORD0; // .xy = Tex0 (Diffuse); .zw = Tex1 (Detail);
	float3 Normals : TEXCOORD1;
	float3 VertexPos : TEXCOORD2;
	#if _HASSHADOW_
		float4 TexShadow : TEXCOORD3;
	#endif
};

VS2PS TrunkSTMDetail_VS(APP2VS Input)
{
	VS2PS Output = (VS2PS)0;

	Input.Pos *= PosUnpack;
	Output.HPos = mul(float4(Input.Pos.xyz, 1.0), WorldViewProjection);

	Output.P_Tex0_Tex1.xy = Input.Tex0 * TexUnpack;

	#if !defined(BASEDIFFUSEONLY)
		Output.P_Tex0_Tex1.zw = Input.Tex1 * TexUnpack;
	#endif

	Output.Normals.xyz = normalize(Input.Normal * NormalUnpack.x + NormalUnpack.y);
	Output.VertexPos = Input.Pos.xyz;

	#if _HASSHADOW_
		Output.TexShadow = GetShadowProjection(float4(Input.Pos.xyz, 1.0));
	#endif

	return Output;
}

float4 TrunkSTMDetail_PS(VS2PS Input) : COLOR
{
	float3 Normals = normalize(Input.Normals.xyz);
	float4 DiffuseMap = tex2D(SampleDiffuseMap, Input.P_Tex0_Tex1.xy);
	#if !defined(BASEDIFFUSEONLY)
		DiffuseMap *= tex2D(SampleDetailMap, Input.P_Tex0_Tex1.zw);
	#endif

	float3 Diffuse = LambertLighting(Normals.xyz, -Lights[0].dir) * Lights[0].color;
	#if _HASSHADOW_
		Diffuse = Diffuse * GetShadowFactor(SampleShadowMap, Input.TexShadow);
	#endif
	Diffuse = saturate(OverGrowthAmbient.rgb + Diffuse);

	float4 OutputColor = float4((DiffuseMap.rgb * Diffuse.rgb) * 2.0, Transparency.r * 2.0);
	ApplyFog(OutputColor.rgb, GetFogValue(Input.VertexPos.xyz, ObjectSpaceCamPos.xyz));

	return OutputColor;
};

technique defaultTechnique
{
	pass Pass0
	{
		#if defined(ENABLE_WIREFRAME)
			FillMode = WireFrame;
		#endif

		AlphaTestEnable = <AlphaTest>;
		AlphaRef = 127; // temporary hack by johan because "m_shaderSettings.m_alphaTestRef = 127" somehow doesn't work

		VertexShader = compile vs_3_0 TrunkSTMDetail_VS();
		PixelShader = compile ps_3_0 TrunkSTMDetail_PS();
	}
}
