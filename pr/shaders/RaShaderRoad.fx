#line 2 "RaShaderRoad.fx"

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
	Description: Renders road for game
*/

#define LIGHT_MUL float3(0.8, 0.8, 0.4)
#define LIGHT_ADD float3(0.4, 0.4, 0.4)

float3 TerrainSunColor;
float2 RoadFadeOut;
float4 WorldSpaceCamPos;
// float RoadDepthBias;
// float RoadSlopeScaleDepthBias;

float4 PosUnpack;
float TexUnpack;

#define CREATE_SAMPLER(SAMPLER_NAME, TEXTURE, ADDRESS) \
	sampler SAMPLER_NAME = sampler_state \
	{ \
		Texture = (TEXTURE); \
		MinFilter = FILTER_STM_DIFF_MIN; \
		MagFilter = FILTER_STM_DIFF_MAG; \
		MipFilter = LINEAR; \
		MaxAnisotropy = PR_MAX_ANISOTROPY; \
		AddressU = ADDRESS; \
		AddressV = ADDRESS; \
	}; \

texture DiffuseMap;
CREATE_SAMPLER(SampleDiffuseMap, DiffuseMap, WRAP)

#if defined(USE_DETAIL)
	texture DetailMap;
	CREATE_SAMPLER(SampleDetailMap, DetailMap, WRAP)
#endif

// .rgb = Colors; .a = Lighting;
texture LightMap;
CREATE_SAMPLER(SampleAccumLightMap, LightMap, WRAP)

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
	float4 HPos : POSITION;
	float4 Pos : TEXCOORD0;

	float4 Tex0 : TEXCOORD1; // .xy = Tex0; .zw = Tex1;
	float4 LightTex : TEXCOORD2;
};

struct PS2FB
{
	float4 Color : COLOR0;
	#if defined(LOG_DEPTH)
		float Depth : DEPTH;
	#endif
};

VS2PS VS_Road(APP2VS Input)
{
	VS2PS Output = (VS2PS)0.0;

	float4 WorldPos = mul(Input.Pos * PosUnpack, World);
	WorldPos.y += 0.01;

	Output.HPos = mul(WorldPos, ViewProjection);
	Output.Pos.xyz = WorldPos.xyz;

	// Output Depth
	#if defined(LOG_DEPTH)
		Output.Pos.w = Output.HPos.w + 1.0;
	#endif

	Output.Tex0.xy = Input.Tex0 * TexUnpack;
	#if defined(USE_DETAIL)
		Output.Tex0.zw = Input.Tex1 * TexUnpack;
	#endif

	Output.LightTex.xy = Output.HPos.xy / Output.HPos.w;
	Output.LightTex.xy = (Output.LightTex.xy * 0.5) + 0.5;
	Output.LightTex.y = 1.0 - Output.LightTex.y;
	Output.LightTex.xy = Output.LightTex.xy * Output.HPos.w;
	Output.LightTex.zw = Output.HPos.zw;

	return Output;
}

PS2FB PS_Road(VS2PS Input)
{
	PS2FB Output = (PS2FB)0.0;

	float3 WorldPos = Input.Pos.xyz;
	float ZFade = GetRoadZFade(WorldPos, WorldSpaceCamPos.xyz, RoadFadeOut);

	float4 AccumLights = tex2Dproj(SampleAccumLightMap, Input.LightTex);
	float3 Light = ((TerrainSunColor * (AccumLights.a * 2.0)) + AccumLights.rgb) * 2.0;

	float4 Diffuse = SRGBToLinearEst(tex2D(SampleDiffuseMap, Input.Tex0.xy));
	#if defined(USE_DETAIL)
		float4 Detail = SRGBToLinearEst(tex2D(SampleDetailMap, Input.Tex0.zw));
		Diffuse *= Detail;
	#endif

	// On thermals no shadows
	if (IsTisActive())
	{
		Light = (TerrainSunColor + AccumLights.rgb) * 2.0;
		Diffuse.rgb *= Light;
		Diffuse.g = clamp(Diffuse.g, 0.0, 0.5);
	}
	else
	{
		Diffuse.rgb *= Light;
	}

	#if defined(NO_BLEND)
		Diffuse.a = (Diffuse.a <= 0.95) ? 1.0 : ZFade;
	#else
		Diffuse.a *= ZFade;
	#endif

	Output.Color = Diffuse;
	ApplyFog(Output.Color.rgb, GetFogValue(WorldPos, WorldSpaceCamPos.xyz));
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
		#if defined(ENABLE_WIREFRAME)
			FillMode = WireFrame;
		#endif

		CullMode = CCW;
		ZEnable = TRUE;
		ZFunc = PR_ZFUNC_WITHEQUAL;
		ZWriteEnable = FALSE;

		AlphaTestEnable = FALSE;
		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		// DepthBias = (RoadDepthBias);
		// SlopeScaleDepthBias = (RoadSlopeScaleDepthBias);

		VertexShader = compile vs_3_0 VS_Road();
		PixelShader = compile ps_3_0 PS_Road();
	}
}

