
#include "shaders/RaCommon.fx"

#define LIGHT_MUL float3(0.8, 0.8, 0.4)
#define LIGHT_ADD float3(0.4, 0.4, 0.4)

float3 TerrainSunColor;
float2 RoadFadeOut;
float4 WorldSpaceCamPos;
// float RoadDepthBias;
// float RoadSlopeScaleDepthBias;

float4 PosUnpack;
float TexUnpack;

texture	LightMap;
sampler LightMapSampler = sampler_state
{
	Texture = (LightMap);
	MipFilter = LINEAR;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	AddressU = WRAP;
	AddressV = WRAP;
};

texture	DetailMap;
sampler DetailMapSampler = sampler_state
{
	Texture = (DetailMap);
	MipFilter = LINEAR;
	MinFilter = FILTER_STM_DIFF_MIN;
	MagFilter = FILTER_STM_DIFF_MAG;
	MaxAnisotropy = 16;
	AddressU = WRAP;
	AddressV = WRAP;
};

texture	DiffuseMap;
sampler DiffuseMapSampler = sampler_state
{
	Texture = (DiffuseMap);
	MipFilter = LINEAR;
	MinFilter = FILTER_STM_DIFF_MIN;
	MagFilter = FILTER_STM_DIFF_MAG;
	MaxAnisotropy = 16;
	AddressU = WRAP;
	AddressV = WRAP;
};

string GlobalParameters[] =
{
	"FogRange",
	"FogColor",
	"ViewProjection",
	"TerrainSunColor",
	"RoadFadeOut",
	"WorldSpaceCamPos",
	// "RoadDepthBias",
	// "RoadSlopeScaleDepthBias"
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
	"LightMap",
	"PosUnpack",
	"TexUnpack",
};

// INPUTS TO THE VERTEX SHADER FROM THE APP
string reqVertexElement[] =
{
 	"PositionPacked",
 	"TBasePacked2D",
 	"TDetailPacked2D"
};

struct APP2VS
{
	float4 Pos : POSITION0;
	float2 Tex0 : TEXCOORD0;
	float2 Tex1 : TEXCOORD1;
};

struct VS2PS
{
	float4 Pos : POSITION0;
	float3 P_Tex0_ZFade	: TEXCOORD0;
	float3 P_Tex1_Fog : TEXCOORD1;
	float4 LightTex : TEXCOORD2;
};

VS2PS Editor_Road_Detail_NoBlend_VS(APP2VS Input)
{
	VS2PS Output = (VS2PS)0;

	float4 WorldPos = mul(Input.Pos * PosUnpack, World);
	WorldPos.y += 0.01;

 	Output.Pos = mul(WorldPos, ViewProjection);
	Output.P_Tex0_ZFade.xy = Input.Tex0 * TexUnpack;
	Output.P_Tex1_Fog.xy = Input.Tex1 * TexUnpack;

	Output.LightTex.xy = Output.Pos.xy / Output.Pos.w;
 	Output.LightTex.xy = Output.LightTex.xy * float2(0.5, -0.5) + float2(0.5, 0.5);
 	Output.LightTex.xy = Output.LightTex.xy * Output.Pos.w;
	Output.LightTex.zw = Output.Pos.zw;

	Output.P_Tex0_ZFade.z = 1.0 - saturate((distance(WorldPos.xyz, WorldSpaceCamPos.xyz) * RoadFadeOut.x) - RoadFadeOut.y);
	Output.P_Tex1_Fog.z = GetFogValue(WorldPos.xyz, WorldSpaceCamPos.xyz);

	return Output;
}


float4 Editor_Road_Detail_NoBlend_PS(VS2PS Input) : COLOR
{
	float4 Color = tex2D(DiffuseMapSampler, Input.P_Tex0_ZFade.xy);
	Color *= tex2D(DetailMapSampler, Input.P_Tex1_Fog.xy);

	Color.rgb = ApplyFog(Color.rgb, Input.P_Tex1_Fog.z);
	Color.a *= Input.P_Tex0_ZFade.z;
	return Color;
};

technique defaultTechnique
{
	pass P0
	{
		VertexShader = compile vs_3_0 Editor_Road_Detail_NoBlend_VS();
		PixelShader = compile ps_3_0 Editor_Road_Detail_NoBlend_PS();

		#if defined(ENABLE_WIREFRAME)
			FillMode = WireFrame;
		#endif

		CullMode = CCW;
		AlphaBlendEnable = TRUE;
		AlphaTestEnable = FALSE;

		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		ZEnable	= TRUE;
		ZWriteEnable = FALSE;

		// DepthBias = < RoadDepthBias >;
		// SlopeScaleDepthBias = < RoadSlopeScaleDepthBias >;
	}
}
