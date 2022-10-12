
/*
	Description: Renders lighting for objects with characteristics of tree-trunks (poles)
*/

#include "shaders/RealityGraphics.fx"

#include "shaders/RaCommon.fx"

#if !defined(_HASSHADOW_)
	#define _HASSHADOW_ 0
#endif

// float3 TreeSkyColor;
float4 OverGrowthAmbient;
Light Lights[1];
float4 PosUnpack;
float2 NormalUnpack;
float TexUnpack;
float4 ObjectSpaceCamPos;

texture DetailMap;

sampler DetailMapSampler = sampler_state
{
	Texture = (DetailMap);
	MipFilter = LINEAR;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	AddressU = WRAP;
	AddressV = WRAP;
};

texture DiffuseMap;

sampler DiffuseMapSampler = sampler_state
{
	Texture = (DiffuseMap);
	MipFilter = LINEAR;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	AddressU = WRAP;
	AddressV = WRAP;
};

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
	float3 Diffuse = GetDiffuseValue(Normals.xyz, -Lights[0].dir) * Lights[0].color;

	#if !_HASSHADOW_
		Diffuse.rgb += OverGrowthAmbient.rgb;
	#endif

	Diffuse = saturate(Diffuse * 0.5);

	float4 DiffuseMap = tex2D(DiffuseMapSampler, Input.P_Tex0_Tex1.xy);
	#if !defined(BASEDIFFUSEONLY)
		DiffuseMap *= tex2D(DetailMapSampler, Input.P_Tex0_Tex1.zw);
	#endif

	#if _HASSHADOW_
		Diffuse.rgb *= GetShadowFactor(ShadowMapSampler, Input.TexShadow);
		Diffuse.rgb += OverGrowthAmbient.rgb * 0.5;
	#endif

	float4 FinalColor = float4((Diffuse.rgb * DiffuseMap.rgb) * 4.0, Transparency.r * 2.0);

	FinalColor.rgb = ApplyFog(FinalColor.rgb, GetFogValue(Input.VertexPos.xyz, ObjectSpaceCamPos.xyz));
	return FinalColor;
};

technique defaultTechnique
{
	pass P0
	{
		VertexShader = compile vs_3_0 TrunkSTMDetail_VS();
		PixelShader = compile ps_3_0 TrunkSTMDetail_PS();

		#if defined(ENABLE_WIREFRAME)
			FillMode = WireFrame;
		#endif
		AlphaTestEnable = <AlphaTest>;
		AlphaRef = 127; // temporary hack by johan because "m_shaderSettings.m_alphaTestRef = 127" somehow doesn't work
	}
}
