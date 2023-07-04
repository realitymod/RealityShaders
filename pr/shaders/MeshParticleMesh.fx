#include "shaders/RealityGraphics.fxh"
#include "shaders/FXCommon.fxh"

/*
	Description:
	- Renders 3D particle debris in explosions
	- Instanced to render up to to 26 particles in a drawcall
	- TIP: Test the shader with PRBot4/Num6 weapon
*/

/*
	[Attributes from app]
*/

uniform float4x4 _WorldViewProj : WorldViewProjection;
uniform float4 _GlobalScale : GlobalScale;

// Once per system instance
// TemplateParameters
uniform float4 m_color1AndLightFactor : COLOR1;
uniform float4 m_color2 : COLOR2;
uniform float4 m_colorBlendGraph : COLORBLENDGRAPH;
uniform float4 m_transparencyGraph : TRANSPARENCYGRAPH;

uniform float4 _AgeAndAlphaArray[26] : AgeAndAlphaArray;
uniform float _LightmapIntensityOffset : LightmapIntensityOffset;
uniform float4x3 _MatOneBoneSkinning[26]: matONEBONESKINNING; /* : register(c50) < bool sparseArray = true; int arrayStart = 50; >; */

struct APP2VS
{
	float4 Pos : POSITION;
	float3 Normal : NORMAL;
	float4 BlendIndices : BLENDINDICES;
	float2 TexCoord : TEXCOORD0;
	float3 Tan : TANGENT;
	float3 Binorm : BINORMAL;
};

struct VS2PS
{
	float4 HPos : POSITION;
	float3 WorldPos : TEXCOORD0;
	float3 ViewPos : TEXCOORD1;
	float4 Color : TEXCOORD2;

	float2 Tex0 : TEXCOORD3;
};

struct PS2FB
{
	float4 Color : COLOR;
};

VS2PS VS_Diffuse(APP2VS Input)
{
	VS2PS Output = (VS2PS)0;

	// Compensate for lack of UBYTE4 on Geforce3
	int4 IndexVector = D3DCOLORtoUBYTE4(Input.BlendIndices);
	int IndexArray[4] = (int[4])IndexVector;

	float3 Pos = mul(Input.Pos * _GlobalScale, _MatOneBoneSkinning[IndexArray[0]]);
	Output.HPos = mul(float4(Pos.xyz, 1.0), _WorldViewProj);
	Output.WorldPos = Pos.xyz;
	Output.ViewPos = Output.HPos.xyz;

	// Compute Cubic polynomial factors.
	float Age = _AgeAndAlphaArray[IndexArray[0]][0];
	float4 CubicPolynomial = float4(pow(Age, float3(3.0, 2.0, 1.0)), 1.0);
	float ColorBlendFactor = min(dot(m_colorBlendGraph, CubicPolynomial), 1.0);
	Output.Color.rgb = lerp(m_color1AndLightFactor.rgb, m_color2.rgb, ColorBlendFactor);
	Output.Color.a = _AgeAndAlphaArray[IndexArray[0]][1];
	Output.Color = saturate(Output.Color);

	// Pass-through texcoords
	Output.Tex0 = Input.TexCoord;

	// Output depth (VS)
	#if defined(LOG_DEPTH)
		Output.HPos.z = ApplyLogarithmicDepth(Output.HPos.w + 1.0) * Output.HPos.w;
	#endif

	return Output;
}

// Renders 3D debris found in explosions like in PRBot4/Num6
PS2FB PS_Diffuse(VS2PS Input)
{
	PS2FB Output = (PS2FB)0;

	// Textures
	float2 HemiTex = GetHemiTex(Input.WorldPos, 0.0, _HemiMapInfo, false);
	float4 DiffuseMap = tex2D(SampleDiffuseMap, Input.Tex0);
	float4 HemiMap = tex2D(SampleLUT, HemiTex);

	// Lighting
	float LightMapOffset = GetAltitude(Input.WorldPos, _LightmapIntensityOffset);
	float3 Lighting = GetParticleLighting(HemiMap.a, LightMapOffset, saturate(m_color1AndLightFactor.a));
	float4 LightColor = (Input.Color.rgb * Lighting, Input.Color.a);
	float4 OutputColor = DiffuseMap * LightColor;

	Output.Color = OutputColor;
	ApplyFog(Output.Color.rgb, GetFogValue(Input.ViewPos, 0.0));

	return Output;
}

// Renders circular shockwave found in explosions like in PRBot4/Num6
PS2FB PS_Additive(VS2PS Input)
{
	PS2FB Output = (PS2FB)0;

	// Textures
	float4 DiffuseMap = tex2D(SampleDiffuseMap, Input.Tex0) * Input.Color;
	DiffuseMap.rgb = (_EffectSunColor.b < -0.1) ? float3(1.0, 0.0, 0.0) : DiffuseMap.rgb;

	// Mask with alpha since were doing an add
	float3 AlphaMask = DiffuseMap.a * Input.Color.a;
	float4 OutputColor = DiffuseMap * float4(AlphaMask, 1.0);

	Output.Color = OutputColor;

	return Output;
}

#define GET_RENDERSTATES_MESH_PARTICLES(ZWRITE, SRCBLEND, DESTBLEND) \
	ColorWriteEnable = RED|GREEN|BLUE; \
	CullMode = NONE; \
	ZEnable = TRUE; \
	ZWriteEnable = ZWRITE; \
	AlphaTestEnable = TRUE; \
	AlphaRef = 0; \
	AlphaFunc = GREATER; \
	AlphaBlendEnable = TRUE; \
	SrcBlend = SRCBLEND; \
	DestBlend = DESTBLEND; \

technique Diffuse
{
	pass Pass0
	{
		GET_RENDERSTATES_MESH_PARTICLES(FALSE, SRCALPHA, INVSRCALPHA)
		VertexShader = compile vs_3_0 VS_Diffuse();
		PixelShader = compile ps_3_0 PS_Diffuse();
	}
}

technique Additive
{
	pass Pass0
	{
		GET_RENDERSTATES_MESH_PARTICLES(FALSE, ONE, ONE)
		VertexShader = compile vs_3_0 VS_Diffuse();
		PixelShader = compile ps_3_0 PS_Additive();
	}
}

technique DiffuseWithZWrite
{
	pass Pass0
	{
		GET_RENDERSTATES_MESH_PARTICLES(TRUE, SRCALPHA, INVSRCALPHA)
		VertexShader = compile vs_3_0 VS_Diffuse();
		PixelShader = compile ps_3_0 PS_Diffuse();
	}
}
