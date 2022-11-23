
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

#define CREATE_DYNAMIC_SAMPLER(SAMPLER_NAME, TEXTURE, ADDRESS, IS_SRGB) \
	sampler SAMPLER_NAME = sampler_state \
	{ \
		Texture = (TEXTURE); \
		MinFilter = FILTER_STM_DIFF_MIN; \
		MagFilter = FILTER_STM_DIFF_MAG; \
		MipFilter = LINEAR; \
		MaxAnisotropy = 16; \
		AddressU = ADDRESS; \
		AddressV = ADDRESS; \
		SRGBTexture = IS_SRGB; \
	}; \

uniform texture LightMap;
CREATE_DYNAMIC_SAMPLER(SampleLightMap, LightMap, WRAP, FALSE)

#if defined(USE_DETAIL)
	uniform texture DetailMap;
	CREATE_DYNAMIC_SAMPLER(SampleDetailMap, DetailMap, WRAP, FALSE)
#endif

uniform texture DiffuseMap;
CREATE_DYNAMIC_SAMPLER(SampleDiffuseMap, DiffuseMap, WRAP, FALSE)

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
	float4 P_Tex0_Tex1 : TEXCOORD0; // .xy = Tex0; .zw = Tex1;
	float3 VertexPos : TEXCOORD1;
	float4 LightTex : TEXCOORD2;
};

VS2PS Road_VS(APP2VS Input)
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
	Output.LightTex.xy = (Output.LightTex.xy * 0.5) + 0.5;
	Output.LightTex.y = 1.0 - Output.LightTex.y;
	Output.LightTex.xy = Output.LightTex.xy * Output.HPos.w;
	Output.LightTex.zw = Output.HPos.zw;

	Output.VertexPos.xyz = WorldPos.xyz;

	return Output;
}

float4 Road_PS(VS2PS Input) : COLOR
{
	float4 AccumLights = tex2Dproj(SampleLightMap, Input.LightTex);
	float4 Diffuse = tex2D(SampleDiffuseMap, Input.P_Tex0_Tex1.xy);

	#if defined(USE_DETAIL)
		float4 Detail = tex2D(SampleDetailMap, Input.P_Tex0_Tex1.zw);
		#if defined(NO_BLEND)
			Diffuse.rgb *= Detail.rgb;
		#else
			Diffuse *= Detail;
		#endif
	#endif

	float4 TerrainColor = float4(TerrainSunColor, 1.0);
	float4 Light = ((TerrainColor * 2.0 * AccumLights.w) + AccumLights) * 2.0;

	// On thermals no shadows
	if (FogColor.r < 0.01)
	{
		Light.rgb = (TerrainColor * 2.0 + AccumLights) * 2.0;
		Diffuse.rgb *= Light.rgb;
		Diffuse.g = clamp(Diffuse.g, 0.0, 0.5);
	}
	else
	{
		Diffuse.rgb *= Light.rgb;
	}

	float ZFade = GetRoadZFade(Input.VertexPos.xyz, WorldSpaceCamPos.xyz, RoadFadeOut);

	#if defined(NO_BLEND)
		Diffuse.a = (Diffuse.a <= 0.95) ? 1.0 : ZFade;
	#else
		Diffuse.a *= ZFade;
	#endif

	ApplyFog(Diffuse.rgb, GetFogValue(Input.VertexPos.xyz, WorldSpaceCamPos.xyz));

	return Diffuse;
};

technique defaultTechnique
{
	pass Pass0
	{
		#if defined(ENABLE_WIREFRAME)
			FillMode = WireFrame;
		#endif

		CullMode = CCW;
		AlphaTestEnable = FALSE;

		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		ZEnable = TRUE;
		ZWriteEnable = FALSE;

		// DepthBias = < RoadDepthBias >;
		// SlopeScaleDepthBias = < RoadSlopeScaleDepthBias >;

		SRGBWriteEnable = FALSE;

		VertexShader = compile vs_3_0 Road_VS();
		PixelShader = compile ps_3_0 Road_PS();
	}
}
