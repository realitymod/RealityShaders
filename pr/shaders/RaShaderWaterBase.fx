#include "shaders/RealityGraphics.fxh"
#include "shaders/RaCommon.fxh"

/*
	Description: Renders water
*/

// Affects how transparency is claculated depending on camera height.
// Try increasing/decreasing ADD_ALPHA slighty for different results
#define MAX_HEIGHT 20
#define ADD_ALPHA 0.75

// Darkness of water shadows - Lower means darker
#define SHADOW_FACTOR 0.75

// Higher value means less transparent water
#define BASE_TRANSPARENCY 1.5F

// Like Specular - higher values gives smaller, more distinct area of transparency
#define POW_TRANSPARENCY 30.0F

// How much of the texture color to use (vs envmap color)
#define COLOR_ENVMAP_RATIO 0.4F

// Modifies heightalpha (for tweaking transparancy depending on depth)
#define APOW 1.3

uniform float4 LightMapOffset;
Light Lights[1];

uniform float WaterHeight;
uniform float4 WaterScroll;
uniform float WaterCycleTime;
uniform float4 WaterColor;

uniform float4 WorldSpaceCamPos;

uniform float4 SpecularColor;
uniform float SpecularPower;
uniform float4 PointColor;

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

uniform texture CubeMap;
CREATE_SAMPLER(samplerCUBE, SampleCubeMap, CubeMap, WRAP)

#if defined(USE_3DTEXTURE)
	uniform texture WaterMap;
	CREATE_SAMPLER(sampler, SampleWaterMap, WaterMap, WRAP)
#else
	uniform texture WaterMapFrame0;
	CREATE_SAMPLER(sampler, SampleWaterMap0, WaterMapFrame0, WRAP)

	uniform texture WaterMapFrame1;
	CREATE_SAMPLER(sampler, SampleWaterMap1, WaterMapFrame1, WRAP)
#endif

uniform texture LightMap;
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

	float2 LightMapTex : TEXCOORD1;
	#if defined(USE_SHADOWS)
		float4 ShadowTex : TEXCOORD2;
	#endif
};

struct PS2FB
{
	float4 Color : COLOR;
	#if defined(LOG_DEPTH)
		float Depth : DEPTH;
	#endif
};

VS2PS VS_Water(APP2VS Input)
{
	VS2PS Output = (VS2PS)0;

	// World-space data
	float4 WorldPos = mul(Input.Pos, World);
	Output.HPos = mul(WorldPos, ViewProjection);
	Output.Pos.xyz = WorldPos.xyz;
	#if defined(LOG_DEPTH)
		Output.Pos.w = Output.HPos.w + 1.0; // Output depth
	#endif

	// Get texture surface data
	#if defined(USE_LIGHTMAP)
		Output.LightMapTex = (Input.LightMap * LightMapOffset.xy) + LightMapOffset.zw;
	#endif
	#if defined(USE_SHADOWS)
		Output.ShadowTex = GetShadowProjection(WorldPos);
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
	PS2FB Output = (PS2FB)0;

	float3 WorldPos = Input.Pos.xyz;
	float3 WorldLightDir = normalize(-Lights[0].dir);
	float3 WorldViewDir = normalize(WorldSpaceCamPos.xyz - WorldPos.xyz);
	float3 WaterTex = GetWaterTex(WorldPos);

	#if defined(USE_LIGHTMAP)
		float4 LightMap = tex2D(SampleLightMap, Input.LightMapTex);
	#else
		float4 LightMap = PointColor;
	#endif

	float ShadowFactor = LightMap.g;
	#if defined(USE_SHADOWS)
		ShadowFactor *= GetShadowFactor(SampleShadowMap, Input.ShadowTex);
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

	float3 Reflection = normalize(reflect(-WorldViewDir, TangentNormal));
	float3 EnvColor = texCUBE(SampleCubeMap, Reflection);

	float LightFactors = SpecularColor.a * ShadowFactor;
	float3 DotLR = saturate(dot(WorldLightDir, Reflection));
	float3 Specular = pow(abs(DotLR), SpecularPower) * SpecularColor.rgb;

	float4 OutputColor = 0.0;
	float LerpMod = -(1.0 - saturate(ShadowFactor + SHADOW_FACTOR));
	float3 WaterLerp = lerp(_WaterColor.rgb, EnvColor, COLOR_ENVMAP_RATIO + LerpMod);
	OutputColor.rgb = WaterLerp + (Specular * LightFactors);

	// Thermals
	if (IsTisActive())
	{
		OutputColor.rgb = float3(lerp(0.3, 0.1, TangentNormal.r), 1.0, 0.0);
	}

	float Fresnel = BASE_TRANSPARENCY - pow(dot(TangentNormal, WorldViewDir), POW_TRANSPARENCY);
	OutputColor.a = saturate((LightMap.r * Fresnel) + _WaterColor.w);

	Output.Color = OutputColor;
	ApplyFog(Output.Color.rgb, GetFogValue(WorldPos, WorldSpaceCamPos.xyz));

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);
	#endif

	return Output;
}

technique defaultShader
{
	pass Pass0
	{
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
