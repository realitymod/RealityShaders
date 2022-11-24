
/*
	Description: Renders water
*/

#include "shaders/RealityGraphics.fxh"
#include "shaders/RaCommon.fxh"

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

// Wether to use normalmap for transparency calculation or not
// #define FRESNEL_NORMALMAP

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

#define CREATE_SAMPLER(SAMPLER_TYPE, SAMPLER_NAME, TEXTURE, ADDRESS, IS_SRGB) \
	SAMPLER_TYPE SAMPLER_NAME = sampler_state \
	{ \
		Texture = (TEXTURE); \
		MinFilter = LINEAR; \
		MagFilter = LINEAR; \
		MipFilter = LINEAR; \
		AddressU = ADDRESS; \
		AddressV = ADDRESS; \
		AddressW = ADDRESS; \
		SRGBTexture = IS_SRGB; \
	}; \

uniform texture CubeMap;
CREATE_SAMPLER(samplerCUBE, SampleCubeMap, CubeMap, WRAP, FALSE)

#if defined(USE_3DTEXTURE)
	uniform texture WaterMap;
	CREATE_SAMPLER(sampler, SampleWaterMap, WaterMap, WRAP, FALSE)
#else
	uniform texture WaterMapFrame0;
	CREATE_SAMPLER(sampler, SampleWaterMap0, WaterMapFrame0, WRAP, FALSE)

	uniform texture WaterMapFrame1;
	CREATE_SAMPLER(sampler, SampleWaterMap1, WaterMapFrame1, WRAP, FALSE)
#endif

uniform texture LightMap;
CREATE_SAMPLER(sampler, SampleLightMap, LightMap, CLAMP, FALSE)

struct APP2VS
{
	float4 Pos : POSITION0;
	float2 LightMap : TEXCOORD1;
};

struct VS2PS
{
	float4 HPos : POSITION;
	float3 Tex : TEXCOORD0;
	float3 WorldPos : TEXCOORD1;
	float2 LightMapTex : TEXCOORD2;
	#if defined(USE_SHADOWS)
		float4 TexShadow : TEXCOORD3;
	#endif
};

struct PS2FB
{
	float4 Color : COLOR;
	// float Depth : DEPTH;
};

VS2PS Water_VS(APP2VS Input)
{
	VS2PS Output = (VS2PS)0;

	float4 WorldPos = mul(Input.Pos, World);
	Output.HPos = mul(WorldPos, ViewProjection);
	Output.WorldPos = WorldPos.xyz;

	float3 Tex = 0.0;
	#if defined(USE_3DTEXTURE)
		Tex.xy = (WorldPos.xz / float2(29.13, 31.81)) + (WaterScroll.xy * WaterCycleTime);
		Tex.z = WaterCycleTime * 10.0 + dot(Tex.xy, float2(0.7, 1.13));
	#else
		Tex.xy = (WorldPos.xz / float2(99.13, 71.81));
	#endif
	Output.Tex = Tex;

	#if defined(USE_LIGHTMAP)
		Output.LightMapTex = (Input.LightMap * LightMapOffset.xy) + LightMapOffset.zw;
	#endif

	#if defined(USE_SHADOWS)
		Output.TexShadow = GetShadowProjection(WorldPos);
	#endif

	return Output;
}

#define INV_LIGHTDIR float3(0.4, 0.5, 0.6)

float4 Water_PS(in VS2PS Input) : COLOR
{
	#if defined(USE_LIGHTMAP)
		float4 LightMap = tex2D(SampleLightMap, Input.LightMapTex);
	#else
		float4 LightMap = PointColor;
	#endif

	float ShadowFactor = LightMap.g;
	#if defined(USE_SHADOWS)
		ShadowFactor *= GetShadowFactor(SampleShadowMap, Input.TexShadow);
	#endif

	#if defined(USE_3DTEXTURE)
		float3 TangentNormal = tex3D(SampleWaterMap, Input.Tex);
	#else
		float3 Normal0 = tex2D(SampleWaterMap0, Input.Tex.xy).xyz;
		float3 Normal1 = tex2D(SampleWaterMap1, Input.Tex.xy).xyz;
		float3 TangentNormal = lerp(Normal0, Normal1, WaterCycleTime);
	#endif

	#if defined(TANGENTSPACE_NORMALS)
		// We flip the Y and Z components because the water-plane faces at the Y direction in world-space
		TangentNormal.xzy = normalize((TangentNormal.xyz * 2.0) - 1.0);
	#else
		TangentNormal.xyz = normalize((TangentNormal.xyz * 2.0) - 1.0);
	#endif

	float3 WorldPos = Input.WorldPos;
	float3 LightVec = normalize(-Lights[0].dir);
	float3 ViewVec = normalize(WorldSpaceCamPos.xyz - WorldPos.xyz);
	float3 HalfVec = normalize(LightVec + ViewVec);

	float3 Reflection = normalize(reflect(-ViewVec, TangentNormal));
	float3 EnvColor = texCUBE(SampleCubeMap, Reflection);

	float LightFactors = SpecularColor.a * ShadowFactor;
	float3 DotLR = saturate(dot(LightVec, Reflection));
	float3 Specular = pow(abs(DotLR), SpecularPower) * SpecularColor.rgb;

	float4 OutputColor = 0.0;
	float LerpMod = -(1.0 - saturate(ShadowFactor + SHADOW_FACTOR));
	float3 WaterLerp = lerp(_WaterColor.rgb, EnvColor, COLOR_ENVMAP_RATIO + LerpMod);
	OutputColor.rgb = WaterLerp + (Specular * LightFactors);

	// Thermals
	if (FogColor.r < 0.01)
	{
		OutputColor.rgb = float3(lerp(0.3, 0.1, TangentNormal.r), 1.0, 0.0);
	}

	ApplyFog(OutputColor.rgb, GetFogValue(WorldPos, WorldSpaceCamPos));

	#if defined(FRESNEL_NORMALMAP)
		float4 FresnelNormal = float4(TangentNormal, 1.0);
	#else
		float4 FresnelNormal = float4(0.0, 1.0, 0.0, 0.0);
	#endif

	float Fresnel = BASE_TRANSPARENCY - pow(dot(FresnelNormal.xyz, ViewVec), POW_TRANSPARENCY);
	OutputColor.a = saturate((LightMap.r * Fresnel) + _WaterColor.w);

	return OutputColor;
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

		SRGBWriteEnable = FALSE;

		VertexShader = compile vs_3_0 Water_VS();
		PixelShader = compile ps_3_0 Water_PS();
	}
}
