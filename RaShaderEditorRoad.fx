
/*
	Description: Renders road for editor
*/

#include "shaders/RealityGraphics.fx"

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
sampler SampleLightMap = sampler_state
{
	Texture = (LightMap);
	MipFilter = LINEAR;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	AddressU = WRAP;
	AddressV = WRAP;
};

#if defined(USE_DETAIL)
	texture	DetailMap;
	sampler SampleDetailMap = sampler_state
	{
		Texture = (DetailMap);
		MipFilter = LINEAR;
		MinFilter = FILTER_STM_DIFF_MIN;
		MagFilter = FILTER_STM_DIFF_MAG;
		MaxAnisotropy = 16;
		AddressU = WRAP;
		AddressV = WRAP;
	};
#endif

texture DiffuseMap;
sampler SampleDiffuseMap = sampler_state
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
	#if defined(USE_DETAIL)
		"DetailMap",
	#endif
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
	#if defined(USE_DETAIL)
		"TDetailPacked2D",
	#endif
};

struct APP2VS
{
	float4 Pos : POSITION0;
	float2 Tex0 : TEXCOORD0;
	#if defined(USE_DETAIL)
		float2 Tex1 : TEXCOORD1;
	#endif
};

struct VS2PS
{
	float4 HPos : POSITION0;
	float4 P_Tex0_Tex1 : TEXCOORD0; // .xy = Tex0; .zw = Tex1;
	float3 VertexPos : TEXCOORD1;
	float4 LightTex : TEXCOORD2;
};

VS2PS Editor_Road_VS(APP2VS Input)
{
	VS2PS Output = (VS2PS)0;

	float4 WorldPos = mul(Input.Pos * PosUnpack, World);
	WorldPos.y += 0.01;

	Output.HPos = mul(WorldPos, ViewProjection);
	Output.P_Tex0_Tex1.xy = Input.Tex0 * TexUnpack;
	#if defined(USE_DETAIL)
		Output.P_Tex0_Tex1.zw = Input.Tex1 * TexUnpack;
	#endif

	Output.LightTex.xy = Output.HPos.xy / Output.HPos.w;
	Output.LightTex.xy = Output.LightTex.xy * float2(0.5, -0.5) + float2(0.5, 0.5);
	Output.LightTex.xy = Output.LightTex.xy * Output.HPos.w;
	Output.LightTex.zw = Output.HPos.zw;

	Output.VertexPos.xyz = WorldPos.xyz;

	return Output;
}

float4 Editor_Road_PS(VS2PS Input) : COLOR
{
	float4 Diffuse = tex2D(SampleDiffuseMap, Input.P_Tex0_Tex1.xy);

	#if defined(USE_DETAIL)
		float4 Detail = tex2D(SampleDetailMap, Input.P_Tex0_Tex1.zw);
		float4 OutputColor = Diffuse * Detail;
	#else
		float4 OutputColor = Diffuse;
	#endif

	OutputColor.rgb = ApplyFog(OutputColor.rgb, GetFogValue(Input.VertexPos.xyz, WorldSpaceCamPos.xyz));
	OutputColor.a *= GetRoadZFade(Input.VertexPos.xyz, WorldSpaceCamPos.xyz, RoadFadeOut);
	return OutputColor;
};

technique defaultTechnique
{
	pass P0
	{
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

		VertexShader = compile vs_3_0 Editor_Road_VS();
		PixelShader = compile ps_3_0 Editor_Road_PS();
	}
}
