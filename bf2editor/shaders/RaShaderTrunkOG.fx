
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
	Description: Renders lighting for tree-trunk overgrowth
*/

float4 OverGrowthAmbient;
float4 ObjectSpaceCamPos;
float4 WorldSpaceCamPos;
float4 PosUnpack;
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
	"GlobalTime",
	"FogRange",
	"FogColor",
	"WorldSpaceCamPos",
};

string TemplateParameters[] =
{
	"PosUnpack",
	"DiffuseMap",
};

string InstanceParameters[] =
{
	"WorldViewProjection",
	"World",
	"Lights",
	"ObjectSpaceCamPos",
	"OverGrowthAmbient",
	"Transparency",
};

// INPUTS TO THE VERTEX SHADER FROM THE APP
string reqVertexElement[] =
{
	"Position",
	"Normal",
	"TBase2D"
};

struct APP2VS
{
	float4 Pos : POSITION0;
	float3 Normal : NORMAL;
	float2 Tex0 : TEXCOORD0;
};

struct VS2PS
{
	float4 HPos : POSITION;
	float4 Pos : TEXCOORD0;
	float2 Tex0 : TEXCOORD1;
	float3 Lighting : TEXCOORD2;
};

struct PS2FB
{
	float4 Color : COLOR0;
	#if defined(LOG_DEPTH)
		float Depth : DEPTH;
	#endif
};

VS2PS VS_TrunkOG(APP2VS Input)
{
	VS2PS Output = (VS2PS)0.0;

	Output.HPos = mul(float4(Input.Pos.xyz, 1.0), WorldViewProjection);

	// Get OverGrowth world-space position
	float3 ObjectPos = Input.Pos.xyz * PosUnpack.xyz;
	float3 WorldPos = ObjectPos + (WorldSpaceCamPos.xyz - ObjectSpaceCamPos.xyz);

	// World-space data
	Output.Pos = float4(WorldPos, Output.HPos.w);

	// Output Depth
	#if defined(LOG_DEPTH)
		Output.Pos.w = Output.HPos.w + 1.0;
	#endif

	// Pass-through tex
	Output.Tex0 = DECODE_SHORT(Input.Tex0);

	// Get lighting
	float LODScale = DECODE_SHORT(Input.Pos.w);
	float3 WorldNormal = GetWorldNormal((Input.Normal * 2.0) - 1.0);
	float3 WorldLightDir = normalize(GetWorldLightDir(-Lights[0].dir));

	float HalfNL = GetHalfNL(WorldNormal, WorldLightDir);
	float3 AmbientRGB = OverGrowthAmbient.rgb * LODScale;
	float3 DiffuseRGB = HalfNL * (Lights[0].color.rgb * LODScale);
	Output.Lighting = AmbientRGB + DiffuseRGB;

	return Output;
}

// There will be small differences between this lighting and the one produced by the static mesh shader,
// not enough to worry about, ambient is added here and lerped in the static mesh, etc
// NOTE: could be an issue at some point.
PS2FB PS_TrunkOG(VS2PS Input)
{
	PS2FB Output = (PS2FB)0.0;

	// World-space data
	float4 WorldPos = Input.Pos;

	// Get textures
	float4 DiffuseMap = SRGBToLinearEst(tex2D(SampleDiffuseMap, Input.Tex0.xy));

	float4 OutputColor = 0.0;
	OutputColor.rgb = CompositeLights(DiffuseMap.rgb, Input.Lighting, 0.0, 0.0) * 2.0;
	OutputColor.a = Transparency.a * 2.0;

	Output.Color = OutputColor;
	ApplyFog(Output.Color.rgb, GetFogValue(WorldPos, WorldSpaceCamPos));
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
		ZEnable = TRUE;
		ZFunc = LESSEQUAL;

		#if defined(ENABLE_WIREFRAME)
			FillMode = WireFrame;
		#endif

		VertexShader = compile vs_3_0 VS_TrunkOG();
		PixelShader = compile ps_3_0 PS_TrunkOG();
	}
}
