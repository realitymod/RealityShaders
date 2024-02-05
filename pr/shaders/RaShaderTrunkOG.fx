
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

uniform float4 OverGrowthAmbient;
uniform float4 ObjectSpaceCamPos;
uniform float4 WorldSpaceCamPos;
uniform float4 PosUnpack;
Light Lights[1];

uniform texture DiffuseMap;
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
	float3 WorldNormal : TEXCOORD1;
	float3 Tex0 : TEXCOORD2; // .xy = Tex0; .z = LodScale;
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
	Output.Pos.xyz = WorldPos;

	// Output Depth
	#if defined(LOG_DEPTH)
		Output.Pos.w = Output.HPos.w + 1.0;
	#endif

	Output.WorldNormal = GetWorldNormal((Input.Normal * 2.0) - 1.0);

	Output.Tex0 = float3(Input.Tex0, Input.Pos.w) / 32767.0;

	return Output;
}

// There will be small differences between this lighting and the one produced by the static mesh shader,
// not enough to worry about, ambient is added here and lerped in the static mesh, etc
// NOTE: could be an issue at some point.
PS2FB PS_TrunkOG(VS2PS Input)
{
	PS2FB Output = (PS2FB)0.0;

	// World-space data
	float LodScale = Input.Tex0.z;
	float3 WorldPos = Input.Pos.xyz;
	float3 WorldNormal = normalize(Input.WorldNormal.xyz);
	float3 WorldLightDir = normalize(GetWorldLightDir(-Lights[0].dir));

	// Get textures
	float4 DiffuseMap = tex2D(SampleDiffuseMap, Input.Tex0.xy);

	// Get diffuse lighting
	float3 LightColor = Lights[0].color.rgb * LodScale;
	float3 Ambient = OverGrowthAmbient.rgb * LodScale;
	float3 Diffuse = GetHalfNL(WorldNormal, WorldLightDir) * LightColor;

	float4 OutputColor = 0.0;
	OutputColor.rgb = CompositeLights(DiffuseMap.rgb * 2.0, Ambient, Diffuse, 0.0);
	OutputColor.a = Transparency.a * 2.0;

	Output.Color = OutputColor;
	ApplyFog(Output.Color.rgb, GetFogValue(WorldPos, WorldSpaceCamPos.xyz));

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
