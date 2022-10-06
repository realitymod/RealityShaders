
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

vector textureFactor = float4(1.0f, 1.0f, 1.0f, 1.0f);

texture LightMap;

sampler LightMapSampler = sampler_state
{
	Texture = (LightMap);
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
	// "DetailMap",
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
};

struct APP2VS
{
    float4 Pos : POSITION0;
    float2 Tex0 : TEXCOORD0;
};

struct VS2PS
{
	float4 Pos : POSITION0;
	float2 Tex0 : TEXCOORD0;
	float4 LightTex : TEXCOORD2;
	float4 P_VertexPos_ZFade : TEXCOORD3; // .xyz = VertexPos; .w = ZFade;
};

VS2PS Road_VS(APP2VS Input)
{
	VS2PS Output = (VS2PS)0;

	float4 WorldPos = mul(Input.Pos * PosUnpack, World);
	WorldPos.y += 0.01;

	Output.Pos = mul(WorldPos, ViewProjection);
	Output.Tex0 = Input.Tex0 * TexUnpack;

	Output.LightTex.xy = Output.Pos.xy / Output.Pos.w;
	Output.LightTex.xy = Output.LightTex.xy * 0.5 + 0.5;
	Output.LightTex.y = 1.0 - Output.LightTex.y;
	Output.LightTex.xy = Output.LightTex.xy * Output.Pos.w;
	Output.LightTex.zw = Output.Pos.zw;

	Output.P_VertexPos_ZFade.xyz = WorldPos.xyz;
	Output.P_VertexPos_ZFade.w = 1.0 - saturate((distance(WorldPos.xyz, WorldSpaceCamPos.xyz) * RoadFadeOut.x) - RoadFadeOut.y);

	return Output;
}

float4 Road_PS(VS2PS Input) : COLOR
{
	float4 Color = tex2D(DiffuseMapSampler, Input.Tex0);
	float4 Light = 0.0;
	float4 AccumLights = tex2Dproj(LightMapSampler, Input.LightTex);
	float4 TerrainColor = float4(TerrainSunColor, 1.0);

	if (FogColor.r < 0.01)
	{
		// On thermals no shadows
		Light = (TerrainColor * 2.0 + AccumLights) * 2.0;
		Color.rgb *= Light.xyz;
		Color.g = clamp(Color.g, 0.0, 0.5);
	}
	else
	{
		Light = ((AccumLights.w * TerrainColor * 2.0) + AccumLights) * 2.0;
		Color.rgb *= Light.xyz;
	}

	Color.a *= Input.P_VertexPos_ZFade.w;

    // Fog
    Color.rgb = ApplyFog(Color.rgb, GetFogValue(Input.P_VertexPos_ZFade.xyz, WorldSpaceCamPos.xyz));

	return Color;
};

technique defaultTechnique
{
	pass P0
	{
		VertexShader = compile vs_3_0 Road_VS();
		PixelShader = compile ps_3_0 Road_PS();

		#if defined(ENABLE_WIREFRAME)
			FillMode = WireFrame;
		#endif

		CullMode = CCW;
		AlphaBlendEnable = TRUE;
		AlphaTestEnable = FALSE;

		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		ZEnable = TRUE;
		ZWriteEnable = FALSE;

		// DepthBias = < RoadDepthBias >;
		// SlopeScaleDepthBias = < RoadSlopeScaleDepthBias >;
	}
}
