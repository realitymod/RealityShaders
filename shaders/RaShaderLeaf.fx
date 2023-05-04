#include "shaders/RealityGraphics.fxh"
#include "shaders/RaCommon.fxh"
#line 4 "RaShaderLeaf.fx"

/*
	Description: Renders objects with leaf-like characteristics
	Special Thanks: [FH2]Remdul for the overgrowth fix
*/

// [Debug data]
// #define OVERGROWTH
// #define _POINTLIGHT_
// #define _HASSHADOW_ 1
// #define HASALPHA2MASK 1
// [Debug data]

// Speed to always add to wind, decrease for less movement
#define WIND_ADD 5

#define LEAF_MOVEMENT 1024

#if !defined(_HASSHADOW_)
	#define _HASSHADOW_ 0
#endif

// float3 TreeSkyColor;
uniform float4 OverGrowthAmbient;
uniform float4 PosUnpack;
uniform float2 NormalUnpack;
uniform float TexUnpack;
uniform float4 ObjectSpaceCamPos;
uniform float4 WorldSpaceCamPos;
uniform float ObjRadius = 2;
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
	#if _HASSHADOW_
		"ShadowMap",
	#endif
	"GlobalTime",
	"FogRange",
	#if !defined(_POINTLIGHT_)
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
	#if !defined(_POINTLIGHT_)
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
	float4 Color : COLOR;
	#if defined(LOG_DEPTH)
		float Depth : DEPTH;
	#endif
};

struct Vertex
{
	float3 WorldPos;
	float3 LightVec;
};

float3 GetWorldLightPos()
{
	return mul(float4(Lights[0].pos.xyz, 1.0), World);
}

Vertex GetVertexAttrib(float3 ObjectPos)
{
	Vertex Output = (Vertex)0;

	// Compute world-space position
	#if defined(OVERGROWTH)
		ObjectPos *= PosUnpack.xyz;
		Output.WorldPos = ObjectPos + (WorldSpaceCamPos.xyz - ObjectSpaceCamPos.xyz);
	#else
		Output.WorldPos = mul(float4(ObjectPos.xyz, 1.0), World).xyz;
	#endif

	// Compute world-space light vector
	#if defined(_POINTLIGHT_)
		Output.LightVec = GetWorldLightPos() - Output.WorldPos;
	#else
		Output.LightVec = mul(-Lights[0].dir.xyz, (float3x3)World);
	#endif

	return Output;
}

VS2PS Leaf_VS(APP2VS Input)
{
	VS2PS Output = (VS2PS)0;

	#if !defined(OVERGROWTH)
		Input.Pos *= PosUnpack;
		float Wind = WindSpeed + WIND_ADD;
		float ObjRadii = ObjRadius + Input.Pos.y;
		Input.Pos.xyz += sin((GlobalTime / ObjRadii) * Wind) * ObjRadii * ObjRadii / LEAF_MOVEMENT;
	#endif

	Output.HPos = mul(float4(Input.Pos.xyz, 1.0), WorldViewProjection);

	Vertex Vtx = GetVertexAttrib(Input.Pos.xyz);

	Output.Pos.xyz = Vtx.WorldPos;
	#if defined(LOG_DEPTH)
		Output.Pos.w = Output.HPos.w + 1.0; // Output depth
	#endif

	Output.Tex0.xy = Input.Tex0;
	#if defined(OVERGROWTH)
		Input.Normal = normalize((Input.Normal * 2.0) - 1.0);
		Output.Tex0.xy /= 32767.0;
	#else
		Input.Normal = normalize((Input.Normal * NormalUnpack.x) + NormalUnpack.y);
		Output.Tex0.xy *= TexUnpack;
	#endif

	#if defined(_POINTLIGHT_)
		float3 LightVec = normalize(Lights[0].pos.xyz - Input.Pos.xyz);
	#else
		float3 LightVec = -Lights[0].dir.xyz;
	#endif

	// Calculate per-vertex lighting
	Output.Tex0.z = dot(Input.Normal, LightVec);
	Output.Tex0.z = saturate((Output.Tex0.z * 0.5) + 0.5);

	#if defined(OVERGROWTH)
		Output.Tex0.w = Input.Pos.w / 32767.0;
	#else
		Output.Tex0.w = 1.0;
	#endif

	#if _HASSHADOW_
		Output.TexShadow = GetShadowProjection(float4(Input.Pos.xyz, 1.0));
	#endif

	return Output;
}

PS2FB Leaf_PS(VS2PS Input)
{
	PS2FB Output = (PS2FB)0;

	float DotLN = Input.Tex0.z;
	float LodScale = Input.Tex0.w;
	float3 WorldPos = Input.Pos.xyz;

	float4 DiffuseMap = tex2D(SampleDiffuseMap, Input.Tex0.xy);
	#if _HASSHADOW_
		float4 Shadow = GetShadowFactor(SampleShadowMap, Input.TexShadow);
	#else
		float4 Shadow = 1.0;
	#endif

	float3 Ambient = OverGrowthAmbient * LodScale;
	float3 Diffuse = (DotLN * LodScale) * (Lights[0].color * LodScale);
	float3 VertexColor = Ambient + (Diffuse * Shadow.rgb);
	float4 OutputColor = DiffuseMap * float4(VertexColor, Transparency.r * 2.0);

	#if defined(OVERGROWTH) && HASALPHA2MASK
		OutputColor.a *= 2.0 * DiffuseMap.a;
	#endif

	Output.Color = OutputColor;

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);
	#endif

	float FogValue = GetFogValue(WorldPos, WorldSpaceCamPos);

	#if defined(_POINTLIGHT_)
		float3 LightVec = GetWorldLightPos() - WorldPos;
		Output.Color.rgb *= GetLightAttenuation(LightVec, Lights[0].attenuation);
		Output.Color.rgb *= FogValue;
	#endif

	#if !defined(_POINTLIGHT_)
		ApplyFog(Output.Color.rgb, FogValue);
	#endif

	return Output;
};

technique defaultTechnique
{
	pass Pass0
	{
		#if defined(ENABLE_WIREFRAME)
			FillMode = WireFrame;
		#endif

		CullMode = NONE;
		AlphaTestEnable = TRUE;
		AlphaRef = 127;

		#if defined(_POINTLIGHT_)
			AlphaBlendEnable = TRUE;
			SrcBlend = ONE;
			DestBlend = ONE;
		#else
			AlphaBlendEnable = FALSE;
			SrcBlend = (srcBlend);
			DestBlend = (destBlend);
		#endif

		VertexShader = compile vs_3_0 Leaf_VS();
		PixelShader = compile ps_3_0 Leaf_PS();
	}
}
