#line 2 "RaShader2DifDet.fx"

#include "shaders/RealityGraphics.fxh"
#include "shaders/RaCommon.fxh"
#include "shaders/shared/RealityDepth.fxh"
#include "shaders/shared/RealityDirectXTK.fxh"
#if !defined(_HEADERS_)
	#include "RealityGraphics.fxh"
	#include "RaCommon.fxh"
	#include "shared/RealityDepth.fxh"
	#include "shared/RealityDirectXTK.fxh"
#endif

#define LIGHT_ADD float3(0.5, 0.5, 0.5)
bool AlphaBlendEnable = true;
Light Lights[1];

texture DiffuseMap;
sampler SampleDiffuseMap = sampler_state
{
	Texture = (DiffuseMap);
	MipFilter = LINEAR;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	AddressU = WRAP;
	AddressV = WRAP;
};

texture DetailMap;
sampler SampleDetailMap = sampler_state
{
	Texture = (DetailMap);
	MipFilter = LINEAR;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	AddressU = WRAP;
	AddressV = WRAP;
};

string GlobalParameters[] =
{
	"FogRange",
	"ViewProjection"
};

string TemplateParameters[] =
{
	"DiffuseMap",
	"DetailMap",
};

string InstanceParameters[] =
{
	"World",
	"Transparency",
	"AlphaBlendEnable",
	"Lights"
};

// INPUTS TO THE VERTEX SHADER FROM THE APP
string reqVertexElement[] =
{
 	"Position",
 	"Normal",
 	"TBase2D",
 	"TDetail2D",
};

struct APP2VS
{
	float3 Pos : POSITION0;
	float3 Normal : NORMAL;
	float2 Tex0 : TEXCOORD0;
	float2 Tex1 : TEXCOORD1;
};

struct VS2PS
{
	float4 HPos : POSITION;
	float4 Pos : TEXCOORD0;
	float3 Normal : TEXCOORD2;
	float4 Tex : TEXCOORD3; // .xy = Tex0; .zw = Tex1;
};

struct PS2FB
{
	float4 Color : COLOR0;
	#if defined(LOG_DEPTH)
		float Depth : DEPTH;
	#endif
};

VS2PS VS_Basic(APP2VS Input)
{
	VS2PS Output = (VS2PS)0.0;

	Output.HPos = mul(float4(Input.Pos.xyz, 1.0), mul(World, ViewProjection));

	// World-space data
	Output.Pos.xyz = GetWorldPos(Input.Pos.xyz);
	Output.Normal = mul(Input.Normal, (float3x3)World);
	Output.Tex = float4(Input.Tex0, Input.Tex1);

	// Output Depth
	#if defined(LOG_DEPTH)
		Output.Pos.w = Output.HPos.w + 1.0;
	#endif

	return Output;
}

PS2FB PS_Basic(VS2PS Input)
{

	PS2FB Output = (PS2FB)0.0;

	float3 WorldNormal = normalize(Input.Normal);
	float4 DiffuseMap = SRGBToLinearEst(tex2D(SampleDetailMap, Input.Tex.xy));
	float4 DetailMap = SRGBToLinearEst(tex2D(SampleDetailMap, Input.Tex.zw));

	float HalfNL = GetHalfNL(WorldNormal, -Lights[0].dir);
	float3 Diffuse = (Lights[0].color.rgb * HalfNL) + LIGHT_ADD;

	Output.Color.rgb = (DiffuseMap.rgb * DetailMap.rgb) * Diffuse;
	Output.Color.a = DiffuseMap.a;
	TonemapAndLinearToSRGBEst(Output.Color);
	RescaleAlpha(Output.Color.a);

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);
	#endif

	return Output;
};

technique defaultTechnique
{
	pass P0
	{
		#if defined(ENABLE_WIREFRAME)
			FillMode = WireFrame;
		#endif

		AlphaTestEnable = (AlphaTest);
		AlphaBlendEnable = (AlphaBlendEnable);
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;
		AlphaRef = PR_ALPHA_REF; // temporary hack by johan because "m_shaderSettings.m_alphaTestRef = 127" somehow doesn't work

		VertexShader = compile vs_3_0 VS_Basic();
		PixelShader = compile ps_3_0 PS_Basic();
	}
}
