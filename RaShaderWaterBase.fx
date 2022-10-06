#include "shaders/RaCommon.fx"

// Affects how transparency is claculated depending on camera height.
// Try increasing/decreasing ADD_ALPHA slighty for different results
#define MAX_HEIGHT 20
#define ADD_ALPHA 0.75

// Darkness of water shadows - Lower means darker
#define SHADOW_FACTOR 0.75

// Higher value means less transparent water
#define BASE_TRANSPARENCY 1.5F

// Like Specular - higher values gives smaller, more distinct area of transparency
#define POW_TRANSPARENCY 30.F

// How much of the texture color to use (vs envmap color)
#define COLOR_ENVMAP_RATIO 0.4F

// Modifies heightalpha (for tweaking transparancy depending on depth)
#define APOW 1.3

// Wether to use normalmap for transparency calculation or not
// #define FRESNEL_NORMALMAP

float4 LightMapOffset;

float WaterHeight;

Light Lights[1];

float4 WorldSpaceCamPos;
float4 WaterScroll;

float WaterCycleTime;

float4 SpecularColor;
float SpecularPower;
float4 WaterColor;
float4 PointColor;

#if defined(DEBUG)
	#define _WaterColor float4(1.0, 0.0, 0.0, 1.0)
#else
	#define _WaterColor WaterColor
#endif

texture CubeMap;
sampler CubeMapSampler = sampler_state
{
	Texture = (CubeMap);
	MipFilter = LINEAR; // Rasterizing speedup
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	AddressU = WRAP;
	AddressV = WRAP;
	AddressW = WRAP;
};

#if defined(USE_3DTEXTURE)
	texture WaterMap;
	sampler WaterMapSampler = sampler_state
	{
		Texture = (WaterMap);
		MipFilter = LINEAR; // Rasterizing speedup
		MinFilter = LINEAR;
		MagFilter = LINEAR;
		AddressU = WRAP;
		AddressV = WRAP;
		AddressW = WRAP;
	};
#else
	texture WaterMapFrame0;
	sampler WaterMapSampler0 = sampler_state
	{
		Texture = (WaterMapFrame0);
		MipFilter = LINEAR; // Rasterizing speedup
		MinFilter = LINEAR;
		MagFilter = LINEAR;
		AddressU = WRAP;
		AddressV = WRAP;
	};

	texture WaterMapFrame1;
	sampler WaterMapSampler1 = sampler_state
	{
		Texture = (WaterMapFrame1);
		MipFilter = LINEAR; // Rasterizing speedup
		MinFilter = LINEAR;
		MagFilter = LINEAR;
		AddressU = WRAP;
		AddressV = WRAP;
	};
#endif

texture LightMap;
sampler LightMapSampler = sampler_state
{
	Texture = (LightMap);
	MipFilter = LINEAR;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	AddressU = CLAMP;
	AddressV = CLAMP;
};

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
	#if defined(USE_SPECULAR)
		"SpecularColor",
		"SpecularPower",
	#endif

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
	float2 LMTex : TEXCOORD1;
};

struct VS2PS
{
	float4 Pos : POSITION;
	#if defined(USE_3DTEXTURE)
		float3 Tex : TEXCOORD0;
	#else
		float2 Tex : TEXCOORD0;
	#endif
	#if !defined(NO_LIGHTMAP)
		float2 LightMapTex : TEXCOORD1;
	#endif
	float3 VertexPos : TEXCOORD2;
	float3 EyeVec : TEXCOORD3;
	#if defined(USE_SHADOWS)
		float4 TexShadow : TEXCOORD4;
	#endif
};

VS2PS Water_VS(APP2VS Input)
{
	VS2PS Output = (VS2PS)0;

	float4 WorldPos = mul(Input.Pos, World);

	Output.Pos = mul(WorldPos, ViewProjection);

	Output.EyeVec = normalize(WorldSpaceCamPos.xyz - WorldPos.xyz);

	Output.VertexPos = WorldPos.xyz;

	#if defined(USE_3DTEXTURE)
		float3 Tex;
		Tex.xy = (WorldPos.xz / float2(29.13, 31.81));
		Tex.xy += (WaterScroll.xy * WaterCycleTime);
		Tex.z = WaterCycleTime * 10.0 + dot(Tex.xy, float2(0.7, 1.13));
	#else
		float2 Tex;
		Tex.xy = (WorldPos.xz / float2(99.13, 71.81));
	#endif

	Output.Tex = Tex;

	#if !defined(NO_LIGHTMAP)
		Output.LightMapTex = Input.LMTex * LightMapOffset.xy + LightMapOffset.zw;
	#endif

	#if defined(USE_SHADOWS)
		Output.TexShadow = GetShadowProjection(WorldPos);
	#endif

	return Output;
}

#define INV_LIGHTDIR float3(0.4, 0.5, 0.6)

float4 Water_PS(in VS2PS Input) : COLOR
{
	float4 FinalColor = 0.0;

	#if defined(NO_LIGHTMAP)
		float4 LightMap = PointColor;
	#else
		float4 LightMap = tex2D(LightMapSampler, Input.LightMapTex);
	#endif

	#if defined(USE_3DTEXTURE)
		float3 TN = tex3D(WaterMapSampler, Input.Tex);
	#else
		float3 TN = lerp(tex2D(WaterMapSampler0, Input.Tex), tex2D(WaterMapSampler1, Input.Tex), WaterCycleTime);
	#endif

	#if defined(TANGENTSPACE_NORMALS)
		TN.rbg = normalize((TN.rgb * 2.0) - 1.0);
	#else
		TN.rgb = (TN.rgb * 2.0) - 1.0;
	#endif

	#if defined(USE_FRESNEL)
		#if defined(FRESNEL_NORMALMAP)
			float4 TN2 = float4(TN, 1.0);
		#else
			float4 TN2 = float4(0.0, 1.0, 0.0, 0.0);
		#endif
	#endif

	float3 EyeVec = normalize(Input.EyeVec);

	float3 Reflection = reflect(-EyeVec, TN);
	float3 EnvColor = texCUBE(CubeMapSampler, Reflection);

	#if defined(USE_SPECULAR)
		float Specular = saturate(dot(-Lights[0].dir, normalize(Reflection)));
		Specular = pow(Specular, SpecularPower) * SpecularColor.a;
	#endif

	float ShadFac = LightMap.g;

	#if defined(USE_SHADOWS)
		ShadFac *= GetShadowFactor(ShadowMapSampler, Input.TexShadow);
	#endif

	float LerpMod = -(1.0 - saturate(ShadFac + SHADOW_FACTOR));

	#if defined(USE_SPECULAR)
		FinalColor.rgb = (Specular * SpecularColor.rgb * ShadFac) + lerp(_WaterColor.rgb, EnvColor, COLOR_ENVMAP_RATIO + LerpMod);
	#else
		FinalColor.rgb = lerp(_WaterColor.rgb, EnvColor, COLOR_ENVMAP_RATIO + LerpMod);
	#endif

	#if defined(USE_FRESNEL)
		float Fresnel = BASE_TRANSPARENCY - pow(dot(EyeVec, TN2.xyz), POW_TRANSPARENCY);
		FinalColor.a = LightMap.r * Fresnel + _WaterColor.w;
	#else
		FinalColor.a = LightMap.r + _WaterColor.w;
	#endif

	if (FogColor.r < 0.01)
	{
		FinalColor.rgb = float3(lerp(0.3, 0.1, TN.r), 1.0, 0.0);
	}

	FinalColor.rgb = ApplyFog(FinalColor.rgb, GetFogValue(Input.VertexPos.xyz, WorldSpaceCamPos.xyz));

	return FinalColor;
}

technique defaultShader
{
	pass P0
	{
		VertexShader = compile vs_3_0 Water_VS();
		PixelShader = compile ps_3_0 Water_PS();

		#if defined(ENABLE_WIREFRAME)
			FillMode = WireFrame;
		#endif
		CullMode = NONE;
		AlphaBlendEnable = TRUE;
		AlphaTestEnable = TRUE;
		AlphaRef = 1;

		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;
	}
}
