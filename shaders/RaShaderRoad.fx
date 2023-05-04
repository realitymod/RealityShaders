#line 2 "RaShaderRoad.fx"

/*
	Description: Renders road for game
*/

#include "shaders/RealityGraphics.fxh"
#include "shaders/RaCommon.fxh"

#define LIGHT_MUL float3(0.8, 0.8, 0.4)
#define LIGHT_ADD float3(0.4, 0.4, 0.4)

uniform float3 TerrainSunColor;
uniform float2 RoadFadeOut;
uniform float4 WorldSpaceCamPos;
// uniform float RoadDepthBias;
// uniform float RoadSlopeScaleDepthBias;

uniform float4 PosUnpack;
uniform float TexUnpack;

uniform vector textureFactor = float4(1.0, 1.0, 1.0, 1.0);

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

#define CREATE_DYNAMIC_SAMPLER(SAMPLER_NAME, TEXTURE, ADDRESS) \
	sampler SAMPLER_NAME = sampler_state \
	{ \
		Texture = (TEXTURE); \
		MinFilter = FILTER_STM_DIFF_MIN; \
		MagFilter = FILTER_STM_DIFF_MAG; \
		MipFilter = LINEAR; \
		MaxAnisotropy = 16; \
		AddressU = ADDRESS; \
		AddressV = ADDRESS; \
	}; \

uniform texture LightMap;
CREATE_DYNAMIC_SAMPLER(SampleLightMap, LightMap, WRAP)

#if defined(USE_DETAIL)
	uniform texture DetailMap;
	CREATE_DYNAMIC_SAMPLER(SampleDetailMap, DetailMap, WRAP)
#endif

uniform texture DiffuseMap;
CREATE_DYNAMIC_SAMPLER(SampleDiffuseMap, DiffuseMap, WRAP)

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
	float4 HPos : POSITION;
	float4 Pos : TEXCOORD0;

	float4 TexA : TEXCOORD1; // .xy = Tex0; .zw = Tex1;
	float4 LightTex : TEXCOORD2;
};

struct PS2FB
{
	float4 Color : COLOR;
	#if defined(LOG_DEPTH)
		float Depth : DEPTH;
	#endif
};

VS2PS Road_VS(APP2VS Input)
{
	VS2PS Output = (VS2PS)0;

	float4 WorldPos = mul(Input.Pos * PosUnpack, World);
	WorldPos.y += 0.01;

	Output.HPos = mul(WorldPos, ViewProjection);

	Output.Pos.xyz = WorldPos.xyz;
	#if defined(LOG_DEPTH)
		Output.Pos.w = Output.HPos.w + 1.0; // Output depth
	#endif

	Output.TexA.xy = Input.Tex0 * TexUnpack;
	#if defined(USE_DETAIL)
		Output.TexA.zw = Input.Tex1 * TexUnpack;
	#endif

	Output.LightTex.xy = Output.HPos.xy / Output.HPos.w;
	Output.LightTex.xy = (Output.LightTex.xy * 0.5) + 0.5;
	Output.LightTex.y = 1.0 - Output.LightTex.y;
	Output.LightTex.xy = Output.LightTex.xy * Output.HPos.w;
	Output.LightTex.zw = Output.HPos.zw;

	return Output;
}

PS2FB Road_PS(VS2PS Input)
{
	PS2FB Output = (PS2FB)0;

	float3 WorldPos = Input.Pos.xyz;
	float ZFade = GetRoadZFade(WorldPos, WorldSpaceCamPos, RoadFadeOut);

	float4 AccumLights = tex2Dproj(SampleLightMap, Input.LightTex);
	float3 TerrainColor = TerrainSunColor * 2.0;
	float3 Light = ((TerrainColor * AccumLights.w) + AccumLights.rgb) * 2.0;

	float4 Diffuse = tex2D(SampleDiffuseMap, Input.TexA.xy);
	#if defined(USE_DETAIL)
		float4 Detail = tex2D(SampleDetailMap, Input.TexA.zw);
		Diffuse *= Detail;
	#endif

	// On thermals no shadows
	if (IsTisActive())
	{
		Light = (TerrainColor + AccumLights.rgb) * 2.0;
		Diffuse.rgb *= Light;
		Diffuse.g = clamp(Diffuse.g, 0.0, 0.5);
	}
	else
	{
		Diffuse.rgb *= Light;
	}

	#if defined(NO_BLEND)
		Diffuse.a = ZFade;
	#else
		Diffuse.a *= ZFade;
	#endif

	Output.Color = Diffuse;

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);
	#endif

	ApplyFog(Output.Color.rgb, GetFogValue(WorldPos, WorldSpaceCamPos));

	return Output;
};

technique defaultTechnique
{
	pass Pass0
	{
		#if defined(ENABLE_WIREFRAME)
			FillMode = WireFrame;
		#endif

		CullMode = CCW;
		ZEnable = TRUE;
		ZWriteEnable = FALSE;
		AlphaTestEnable = FALSE;

		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		// DepthBias = (RoadDepthBias);
		// SlopeScaleDepthBias = (RoadSlopeScaleDepthBias);

		VertexShader = compile vs_3_0 Road_VS();
		PixelShader = compile ps_3_0 Road_PS();
	}
}
