#line 2 "RaShaderLeaf.fx"

/*
    This shader renders objects with leaf-like characteristics, including foliage and overgrowth. It handles wind animation for leaves, dynamic lighting with shadow support, and specialized alpha testing for foliage rendering. The shader includes features for both regular leaf objects and overgrowth patches.
*/

#include "shaders/RealityGraphics.fxh"
#include "shaders/shared/RealityDirectXTK.fxh"
#include "shaders/shared/RealityDepth.fxh"
#include "shaders/shared/RealityPixel.fxh"
#include "shaders/RaCommon.fxh"
#if !defined(_HEADERS_)
	#include "RealityGraphics.fxh"
	#include "shared/RealityDirectXTK.fxh"
	#include "shared/RealityDepth.fxh"
	#include "shared/RealityPixel.fxh"
	#include "RaCommon.fxh"
#endif

#undef _DEBUG_
// #define _DEBUG_
#if defined(_DEBUG_)
	#define OVERGROWTH
	#define _POINTLIGHT_ 1
	#define _HASSHADOW_ 1
	#define HASALPHA2MASK 1
#endif

// Speed to always add to wind, decrease for less movement
#define WIND_ADD 5

#define LEAF_MOVEMENT 1024

#if !defined(_HASSHADOW_)
	#define _HASSHADOW_ 0
#endif

// float3 TreeSkyColor;
float4 OverGrowthAmbient;

float4 PosUnpack;
float2 NormalUnpack;
float TexUnpack;

float4 ObjectSpaceCamPos;
float4 WorldSpaceCamPos;

float ObjRadius = 2;
Light Lights[1];

texture DiffuseMap;
sampler SampleDiffuseMap = sampler_state
{
	Texture = (DiffuseMap);
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = LINEAR;
	AddressU = WRAP;
	AddressV = WRAP;
};

string GlobalParameters[] =
{
	#if _HASSHADOW_
		"ShadowMap",
	#endif
	"GlobalTime",
	"FogRange",
	#if !_POINTLIGHT_
		"FogColor",
	#endif
	"WorldSpaceCamPos",
};

string InstanceParameters[] =
{
	#if _HASSHADOW_
		"ShadowProjMat",
		"ShadowTrapMat",
	#endif
	"World",
	"WorldViewProjection",
	"Transparency",
	"WindSpeed",
	"Lights",
	"ObjectSpaceCamPos",
	#if !_POINTLIGHT_
		"OverGrowthAmbient"
	#endif
};

string TemplateParameters[] =
{
	"DiffuseMap",
	"PosUnpack",
	"NormalUnpack",
	"TexUnpack"
};

// INPUTS TO THE VERTEX SHADER FROM THE APP
string reqVertexElement[] =
{
	#if defined(OVERGROWTH) // tl: TODO - Compress overgrowth patches as well.
		"Position",
		"Normal",
		"TBase2D"
	#else
		"PositionPacked",
		"NormalPacked8",
		"TBasePacked2D"
	#endif
};

struct APP2VS
{
	float4 Pos : POSITION0;
	float3 Normal : NORMAL;
	float2 Tex0 : TEXCOORD0;
};

struct WorldSpace
{
	float3 Pos;
	float3 LightVec;
	float3 LightDir;
	float3 ViewDir;
	float3 Normal;
};

struct VS2PS
{
	float4 HPos : POSITION;
	float4 Pos : TEXCOORD0;
	float4 Tex0 : TEXCOORD1;
	#if _HASSHADOW_
		float4 TexShadow : TEXCOORD2;
	#endif
};

struct PS2FB
{
	float4 Color : COLOR0;
	#if PR_LOG_DEPTH
		float Depth : DEPTH;
	#endif
};

// NOTE: This returns un-normalized for point, because point needs to be attenuated.
float3 GetWorldLightVec(float3 WorldPos)
{
	#if _POINTLIGHT_
		return Ra_GetWorldLightPos(Lights[0].pos.xyz) - WorldPos;
	#else
		return Ra_GetWorldLightDir(-Lights[0].dir.xyz);
	#endif
}

WorldSpace GetWorldSpaceData(float3 ObjectPos, float3 ObjectNormal)
{
	WorldSpace Output = (WorldSpace)0.0;

	// Get OverGrowth world-space position
	#if defined(OVERGROWTH)
		ObjectPos *= PosUnpack.xyz;
		Output.Pos = ObjectPos + (WorldSpaceCamPos.xyz - ObjectSpaceCamPos.xyz);
	#else
		Output.Pos = mul(float4(ObjectPos.xyz, 1.0), World).xyz;
	#endif

	Output.LightVec = GetWorldLightVec(Output.Pos);
	Output.LightDir = normalize(Output.LightVec);
	Output.ViewDir = normalize(WorldSpaceCamPos.xyz - Output.Pos);
	Output.Normal = Ra_GetWorldNormal(ObjectNormal);

	return Output;
}

VS2PS VS_Leaf(APP2VS Input)
{
	VS2PS Output = (VS2PS)0.0;

	// Calculate object-space position data
	#if !defined(OVERGROWTH)
		Input.Pos *= PosUnpack;
		float Wind = WindSpeed + WIND_ADD;
		float ObjRadii = ObjRadius + Input.Pos.y;
		Input.Pos.xyz += sin((GlobalTime / ObjRadii) * Wind) * ObjRadii * ObjRadii / LEAF_MOVEMENT;
	#endif

	Output.HPos = mul(float4(Input.Pos.xyz, 1.0), WorldViewProjection);

	// Calculate texture surface data
	Output.Tex0.xy = Input.Tex0;
	#if defined(OVERGROWTH)
		Input.Normal = normalize((Input.Normal * 2.0) - 1.0);
		Output.Tex0.xy = DECODE_SHORT(Output.Tex0.xy);
	#else
		Input.Normal = normalize((Input.Normal * NormalUnpack.x) + NormalUnpack.y);
		Output.Tex0.xy *= TexUnpack;
	#endif

	// Calculate the LOD scale for far-away leaf objects
	#if defined(OVERGROWTH)
		Output.Tex0.z = DECODE_SHORT(Input.Pos.w);
	#else
		Output.Tex0.z = 1.0;
	#endif

	// Transform our object-space vertex position and normal into world-space
	WorldSpace WS = GetWorldSpaceData(Input.Pos.xyz, Input.Normal);

	// Compute and pre-combine other lighting factors
	Output.Tex0.w = RDirectXTK_GetHalfNL(WS.Normal, WS.LightDir);

	// Calculate vertex position data
	Output.Pos = float4(WS.Pos, Output.HPos.w);

	// Output Depth
	#if PR_LOG_DEPTH
		Output.Pos.w = Output.HPos.w + 1.0;
	#endif

	#if _HASSHADOW_
		Output.TexShadow = Ra_GetShadowProjection(float4(Input.Pos.xyz, 1.0));
	#endif

	return Output;
}

PS2FB PS_Leaf(VS2PS Input)
{
	PS2FB Output = (PS2FB)0.0;

	float LodScale = Input.Tex0.z;
	float4 WorldPos = Input.Pos;

	float4 DiffuseMap = RDirectXTK_SRGBToLinearEst(tex2D(SampleDiffuseMap, Input.Tex0.xy));
	#if _HASSHADOW_
		float Shadow = RDepth_GetShadowFactor(SampleShadowMap, Input.TexShadow);
	#else
		float Shadow = 1.0;
	#endif

	float HalfNL = Input.Tex0.w * LodScale;
	float3 LightColor = Lights[0].color * LodScale;
	float3 AmbientRGB = OverGrowthAmbient.rgb * LodScale;
	float3 DiffuseRGB = (HalfNL * Shadow) * LightColor;

	float4 OutputColor = 0.0;
	OutputColor.rgb = RDirectXTK_CompositeLights(DiffuseMap.rgb, AmbientRGB, DiffuseRGB, 0.0);
	OutputColor.a = (DiffuseMap.a * 2.0) * Transparency.r;
	#if defined(OVERGROWTH) && HASALPHA2MASK
		OutputColor.a *= (DiffuseMap.a * 2.0);
	#endif

	Output.Color = OutputColor;
	float FogValue = Ra_GetFogValue(WorldPos, WorldSpaceCamPos);
	#if _POINTLIGHT_
		float3 WorldLightVec = Ra_GetWorldLightPos(Lights[0].pos.xyz) - WorldPos.xyz;
		Output.Color.rgb *= RPixel_GetLightAttenuation(WorldLightVec, Lights[0].attenuation);
		Output.Color.rgb *= FogValue;
	#else
		Ra_ApplyFog(Output.Color.rgb, FogValue);
	#endif
	RDirectXTK_TonemapAndLinearToSRGBEst(Output.Color);
	RPixel_SetHashedAlphaTest(Input.Tex0.xy, Output.Color.a);

	#if PR_LOG_DEPTH
		Output.Depth = RDepth_ApplyLogarithmicDepth(Input.Pos.w);
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

		ZEnable = TRUE;
		ZFunc = PR_ZFUNC_WITHEQUAL;

		CullMode = NONE;
		AlphaTestEnable = TRUE;
		AlphaRef = PR_ALPHA_REF_LEAF;
		AlphaFunc = GREATER;

		#if _POINTLIGHT_
			AlphaBlendEnable = TRUE;
			SrcBlend = ONE;
			DestBlend = ONE;
		#else
			AlphaBlendEnable = FALSE;
			SrcBlend = (srcBlend);
			DestBlend = (destBlend);
		#endif

		VertexShader = compile vs_3_0 VS_Leaf();
		PixelShader = compile ps_3_0 PS_Leaf();
	}
}
