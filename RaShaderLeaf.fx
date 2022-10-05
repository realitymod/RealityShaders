
#include "shaders/RaCommon.fx"

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
float4 OverGrowthAmbient;
Light Lights[1];
float4 PosUnpack;
float2 NormalUnpack;
float TexUnpack;
float4 ObjectSpaceCamPos;
float ObjRadius = 2;

texture DiffuseMap;
sampler DiffuseMapSampler = sampler_state
{
	Texture = (DiffuseMap);
	MipFilter = LINEAR;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
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
		"FogColor"
	#endif
};

string InstanceParameters[] =
{
	#if _HASSHADOW_
		"ShadowProjMat",
		"ShadowTrapMat",
	#endif
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
	float4 Pos : POSITION0;
	float3 P_Tex0_Fog : TEXCOORD0; // .xy = Tex0; .z = Fog;
	#if _HASSHADOW_
		float4 TexShadow : TEXCOORD1;
	#endif
	float4 Color : COLOR0;
};

VS2PS Leaf_VS(APP2VS Input)
{
	VS2PS Output = (VS2PS)0;

	#if !defined(OVERGROWTH)
		Input.Pos *= PosUnpack;
		WindSpeed += WIND_ADD;
		float ObjRadii = ObjRadius + Input.Pos.y;
		Input.Pos.xyz += sin((GlobalTime / ObjRadii) * WindSpeed) * ObjRadii * ObjRadii / LEAF_MOVEMENT;
	#endif

	Output.Pos = mul(float4(Input.Pos.xyz, 1.0), WorldViewProjection);

	#if !defined(OVERGROWTH)
		float3 LocalPos = Input.Pos.xyz;
	#else
		float3 LocalPos = Input.Pos.xyz * PosUnpack.xyz;
	#endif

	Output.P_Tex0_Fog.xy = Input.Tex0;
	Output.P_Tex0_Fog.z = GetFogValue(LocalPos.xyz, ObjectSpaceCamPos.xyz);

	#if defined(OVERGROWTH)
		Input.Normal = normalize(Input.Normal * 2.0 - 1.0);
		Output.P_Tex0_Fog.xy /= 32767.0;
	#else
		Input.Normal = normalize(Input.Normal * NormalUnpack.x + NormalUnpack.y);
		Output.P_Tex0_Fog.xy *= TexUnpack;
	#endif

	float ScaleLN = Input.Pos.w / 32767.0;

	#if defined(_POINTLIGHT_)
		float Diffuse = saturate(dot(Input.Normal.xyz, normalize(Lights[0].pos.xyz - Input.Pos.xyz)));
	#else
		float Diffuse = saturate((dot(Input.Normal, -Lights[0].dir) + 0.6) / 1.4);
	#endif

	#if defined(OVERGROWTH)
		Output.Color.rgb = Lights[0].color * ScaleLN * Diffuse * ScaleLN;
		OverGrowthAmbient *= ScaleLN;
	#else
		Output.Color.rgb = Lights[0].color * Diffuse;
	#endif

	#if (!_HASSHADOW_) && !defined(_POINTLIGHT_)
		Output.Color.rgb += OverGrowthAmbient.rgb;
	#endif

	#if defined(_POINTLIGHT_)
		Output.Color.rgb *=  GetRadialAttenuation(Lights[0].pos.xyz - Input.Pos.xyz, Lights[0].attenuation);
		Output.Color.rgb *= GetFogValue(LocalPos.xyz, ObjectSpaceCamPos.xyz);
	#endif

	Output.Color = float4(Output.Color.rgb * 0.5, Transparency.a);

	#if _HASSHADOW_
		Output.TexShadow = GetShadowProjection(float4(Input.Pos.xyz, 1.0));
	#endif

	return Output;
}

float4 Leaf_PS(VS2PS Input) : COLOR
{
	float4 OutColor = 0.0;

	float4 DiffuseMap = tex2D(DiffuseMapSampler, Input.P_Tex0_Fog.xy);
	float4 VertexColor = Input.Color;

	#if _HASSHADOW_
		VertexColor.rgb *= saturate(GetShadowFactor(ShadowMapSampler, Input.TexShadow) + (2.0 / 3.0));
		VertexColor.rgb += OverGrowthAmbient.rgb * 0.5;
	#endif

	#if defined(_POINTLIGHT_)
		OutColor = DiffuseMap * VertexColor;
		OutColor.a *= 2.0;
	#else
		OutColor = (DiffuseMap * VertexColor) * 2.0;
	#endif

	#if defined(OVERGROWTH) && HASALPHA2MASK
		OutColor.a *= 2.0 * DiffuseMap.a;
	#endif

	#if !defined(_POINTLIGHT_)
		OutColor.rgb = ApplyFog(OutColor.rgb, Input.P_Tex0_Fog.z);
	#endif

	return OutColor;
};

technique defaultTechnique
{
	pass P0
	{
		VertexShader = compile vs_3_0 Leaf_VS();
		PixelShader = compile ps_3_0 Leaf_PS();

		#if defined(ENABLE_WIREFRAME)
			FillMode = WireFrame;
		#endif

		AlphaTestEnable = TRUE;
		AlphaRef = 127;
		SrcBlend = <srcBlend>;
		DestBlend = <destBlend>;

		#if defined(_POINTLIGHT_)
			AlphaBlendEnable = TRUE;
			SrcBlend = ONE;
			DestBlend = ONE;
		#else
			AlphaBlendEnable = FALSE;
		#endif

		CullMode = NONE;
	}
}
