#line 2 "RaShaderWaterBase.fx"

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
	Description: Renders water
*/

// Affects how transparency is claculated depending on camera height.
// Try increasing/decreasing ADD_ALPHA slighty for different results
#define MAX_HEIGHT 20
#define ADD_ALPHA 0.75

// Darkness of water shadows - Lower means darker
#define SHADOW_FACTOR 0.75

// Like Specular - higher values gives smaller, more distinct area of transparency
#define POW_TRANSPARENCY 30.0

// How much of the texture color to use (vs envmap color)
#define COLOR_ENVMAP_RATIO 0.4

// Modifies heightalpha (for tweaking transparancy depending on depth)
#define APOW 1.3

float4 LightMapOffset;
Light Lights[1];

float WaterHeight;
float4 WaterScroll;
float WaterCycleTime;
float4 WaterColor;

float4 WorldSpaceCamPos;

float4 SpecularColor;
float SpecularPower;
float4 PointColor;

#if defined(DEBUG)
	#define _WaterColor float4(1.0, 0.0, 0.0, 1.0)
#else
	#define _WaterColor WaterColor
#endif

#define CREATE_SAMPLER(SAMPLER_TYPE, SAMPLER_NAME, TEXTURE, ADDRESS) \
	SAMPLER_TYPE SAMPLER_NAME = sampler_state \
	{ \
		Texture = (TEXTURE); \
		MinFilter = LINEAR; \
		MagFilter = LINEAR; \
		MipFilter = LINEAR; \
		AddressU = ADDRESS; \
		AddressV = ADDRESS; \
		AddressW = ADDRESS; \
	}; \

texture CubeMap;
CREATE_SAMPLER(samplerCUBE, SampleCubeMap, CubeMap, WRAP)

#if defined(USE_3DTEXTURE)
	texture WaterMap;
	CREATE_SAMPLER(sampler, SampleWaterMap, WaterMap, WRAP)
#else
	texture WaterMapFrame0;
	CREATE_SAMPLER(sampler, SampleWaterMap0, WaterMapFrame0, WRAP)

	texture WaterMapFrame1;
	CREATE_SAMPLER(sampler, SampleWaterMap1, WaterMapFrame1, WRAP)
#endif

texture LightMap;
CREATE_SAMPLER(sampler, SampleLightMap, LightMap, CLAMP)

string GlobalParameters[] =
{
	"WorldSpaceCamPos",
	"FogRange",
	"FogColor",
	"WaterCycleTime",
	"WaterScroll",
	#if defined(USE_3DTEXTURE)
		"WaterMap",
	#else
		"WaterMapFrame0",
		"WaterMapFrame1",
	#endif
	"WaterHeight",
	"WaterColor",
	// "ShadowMap"
};

string InstanceParameters[] =
{
	"ViewProjection",
	"CubeMap",
	"LightMap",
	"LightMapOffset",
	"SpecularColor",
	"SpecularPower",
	#if defined(USE_SHADOWS)
		"ShadowProjMat",
		"ShadowTrapMat",
		"ShadowMap",
	#endif
	"PointColor",
	"Lights",
	"World"
};

string reqVertexElement[] =
{
	"Position",
	"TLightMap2D"
};

struct APP2VS
{
	float4 Pos : POSITION0;
	float2 LightMap : TEXCOORD1;
};

struct VS2PS
{
	float4 HPos : POSITION;
	float4 Pos : TEXCOORD0;

	#if defined(USE_LIGHTMAP)
		float2 LightMapTex : TEXCOORD1;
	#endif
	#if defined(USE_SHADOWS)
		float4 ShadowTex : TEXCOORD2;
	#endif
};

struct PS2FB
{
	float4 Color : COLOR0;
	#if defined(LOG_DEPTH)
		float Depth : DEPTH;
	#endif
};

VS2PS VS_Water(APP2VS Input)
{
	VS2PS Output = (VS2PS)0.0;

	// World-space data
	float4 WorldPos = mul(Input.Pos, World);
	Output.HPos = mul(WorldPos, ViewProjection);
	Output.Pos = float4(WorldPos.xyz, Output.HPos.w);

	// Output Depth
	#if defined(LOG_DEPTH)
		Output.Pos.w = Output.HPos.w + 1.0;
	#endif

	// Get texture surface data
	#if defined(USE_LIGHTMAP)
		Output.LightMapTex = (Input.LightMap * LightMapOffset.xy) + LightMapOffset.zw;
	#endif
	#if defined(USE_SHADOWS)
		Output.ShadowTex = Ra_GetShadowProjection(WorldPos);
	#endif

	return Output;
}

#define INV_LIGHTDIR float3(0.4, 0.5, 0.6)

float3 GetWaterTex(float3 WorldPos)
{
	float3 WaterTex = 0.0;
	#if defined(USE_3DTEXTURE)
		WaterTex.xy = (WorldPos.xz / float2(29.13, 31.81)) + (WaterScroll.xy * WaterCycleTime);
		WaterTex.z = WaterCycleTime * 10.0 + dot(WaterTex.xy, float2(0.7, 1.13));
	#else
		WaterTex.xy = (WorldPos.xz / float2(99.13, 71.81));
	#endif
	return WaterTex;
}

PS2FB PS_Water(in VS2PS Input)
{
	PS2FB Output = (PS2FB)0.0;

	float4 WorldPos = Input.Pos;
	float3 WaterTex = GetWaterTex(WorldPos.xyz);
	float3 WorldLightDir = normalize(-Lights[0].dir);
	float3 WorldViewDir = WorldSpaceCamPos.xyz - WorldPos.xyz;
	float3 NWorldViewDir = normalize(WorldSpaceCamPos.xyz - WorldPos.xyz);

	#if defined(USE_LIGHTMAP)
		float4 LightMap = tex2D(SampleLightMap, Input.LightMapTex);
	#else
		float4 LightMap = PointColor;
	#endif

	float Shadow = LightMap.g;
	#if defined(USE_SHADOWS)
		Shadow *= RDepth_GetShadowFactor(SampleShadowMap, Input.ShadowTex);
	#endif

	#if defined(USE_3DTEXTURE)
		float3 TangentNormal = tex3D(SampleWaterMap, WaterTex);
	#else
		float3 Normal0 = tex2D(SampleWaterMap0, WaterTex.xy).xyz;
		float3 Normal1 = tex2D(SampleWaterMap1, WaterTex.xy).xyz;
		float3 TangentNormal = lerp(Normal0, Normal1, WaterCycleTime);
	#endif

	#if defined(TANGENTSPACE_NORMALS)
		// We flip the Y and Z components because the water-plane faces at the Y direction in world-space
		TangentNormal.xzy = normalize((TangentNormal.xyz * 2.0) - 1.0);
	#else
		TangentNormal.xyz = normalize((TangentNormal.xyz * 2.0) - 1.0);
	#endif

	// Initialize output factor
	float4 OutputColor = 0.0;

	// Generate water color
	float3 Reflection = reflect(-WorldViewDir, TangentNormal);
	float3 EnvColor = RDirectXTK_SRGBToLinearEst(texCUBE(SampleCubeMap, Reflection));
	float LerpMod = -(1.0 - saturate(Shadow + SHADOW_FACTOR));
	float3 WaterLerp = lerp(_WaterColor.rgb, EnvColor, COLOR_ENVMAP_RATIO + LerpMod);

	// Composite light on water color
	float3 LightColors = SpecularColor.rgb * (SpecularColor.a * Shadow);
	RDirectXTK_ColorPair Light = ComputeLights(TangentNormal, WorldLightDir, NWorldViewDir, SpecularPower);
	OutputColor.rgb = WaterLerp + (Light.Specular * LightColors.rgb);

	// Thermals
	if (Ra_IsTisActive())
	{
		OutputColor.rgb = float3(lerp(0.3, 0.1, TangentNormal.r), 1.0, 0.0);
	}

	// Compute Fresnel
	#if defined(USE_FRESNEL)
		float Fresnel = RDirectXTK_ComputeFresnelFactor(TangentNormal, NWorldViewDir, POW_TRANSPARENCY);
	#else
		float Fresnel = 1.0;
	#endif
	OutputColor.a = saturate((LightMap.r * Fresnel) + _WaterColor.a);

	Output.Color = OutputColor;
	Ra_ApplyFog(Output.Color.rgb, Ra_GetFogValue(WorldPos, WorldSpaceCamPos));
	RDirectXTK_TonemapAndLinearToSRGBEst(Output.Color);

	#if defined(LOG_DEPTH)
		Output.Depth = RDepth_ApplyLogarithmicDepth(Input.Pos.w);
	#endif

	return Output;
}

technique defaultShader
{
	pass p0
	{
		ZEnable = TRUE;
		ZFunc = PR_ZFUNC_WITHEQUAL;

		#if defined(ENABLE_WIREFRAME)
			FillMode = WireFrame;
		#endif

		CullMode = NONE;
		AlphaTestEnable = TRUE;
		AlphaRef = 1;

		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		VertexShader = compile vs_3_0 VS_Water();
		PixelShader = compile ps_3_0 PS_Water();
	}
}
