#line 2 "MeshParticleMesh.fx"

/*
	Include header files
*/

#include "shaders/RealityGraphics.fxh"
#include "shaders/shared/RealityDepth.fxh"
#include "shaders/shared/RealityDirectXTK.fxh"
#include "shaders/shared/RealityPixel.fxh"
#include "shaders/RaCommon.fxh"
#include "shaders/FXCommon.fxh"
#if !defined(_HEADERS_)
	#include "RealityGraphics.fxh"
	#include "shared/RealityDepth.fxh"
	#include "shared/RealityDirectXTK.fxh"
	#include "shared/RealityPixel.fxh"
	#include "RaCommon.fxh"
	#include "FXCommon.fxh"
#endif

/*
	Description:
	- Renders 3D particle debris in explosions
	- Instanced to render up to to 26 particles in a drawcall
	- TIP: Test the shader with PRBot4/Num6 weapon
*/

/*
	[Attributes from app]
*/

float4x4 _WorldViewProj : WorldViewProjection;
float4 _GlobalScale : GlobalScale;

// Once per system instance
// TemplateParameters
float4 m_color1AndLightFactor : COLOR1;
float4 m_color2 : COLOR2;
float4 m_colorBlendGraph : COLORBLENDGRAPH;
float4 m_transparencyGraph : TRANSPARENCYGRAPH;

float4 _AgeAndAlphaArray[26] : AgeAndAlphaArray;
float _LightmapIntensityOffset : LightmapIntensityOffset;
float4x3 _MatOneBoneSkinning[26]: matONEBONESKINNING; /* : register(c50) < bool sparseArray = true; int arrayStart = 50; >; */

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
	float4 ViewPos : TEXCOORD0;
	float4 Tex0 : TEXCOORD1; // .xy = DiffuseTex; .zw = HemiTex;
	float4 Color : TEXCOORD2;
	float Altitude : TEXCOORD3;
};

struct PS2FB
{
	float4 Color : COLOR0;
};

VS2PS VS_Diffuse(APP2VS Input)
{
	VS2PS Output = (VS2PS)0.0;

	// Compensate for lack of UBYTE4 on Geforce3
	int4 IndexVector = D3DCOLORtoUBYTE4(Input.BlendIndices);
	int IndexArray[4] = (int[4])IndexVector;

	float3 WorldPos = mul(Input.Pos * _GlobalScale, _MatOneBoneSkinning[IndexArray[0]]);
	Output.HPos = mul(float4(WorldPos.xyz, 1.0), _WorldViewProj);
	Output.ViewPos = Output.HPos;

	// Compute Cubic polynomial factors.
	float Age = _AgeAndAlphaArray[IndexArray[0]][0];
	float4 CubicPolynomial = float4(pow(Age, float3(3.0, 2.0, 1.0)), 1.0);
	float ColorBlendFactor = min(dot(m_colorBlendGraph, CubicPolynomial), 1.0);
	Output.Color.rgb = lerp(m_color1AndLightFactor.rgb, m_color2.rgb, ColorBlendFactor);
	Output.Color.a = _AgeAndAlphaArray[IndexArray[0]][1];
	Output.Color = saturate(Output.Color);

	// Get particle lighting
	Output.Altitude = GetAltitude(WorldPos, _LightmapIntensityOffset);

	// Pass-through texcoords
	Output.Tex0.xy = Input.TexCoord;
	Output.Tex0.zw = GetHemiTex(WorldPos, 0.0, _HemiMapInfo.xyz, false);

	// Output Depth
	#if defined(LOG_DEPTH)
		Output.HPos.z = ApplyLogarithmicDepth(Output.HPos.w + 1.0) * Output.HPos.w;
	#endif

	return Output;
}

// Renders 3D debris found in explosions like in PRBot4/Num6
PS2FB PS_Diffuse(VS2PS Input)
{
	PS2FB Output = (PS2FB)0.0;

	// Textures
	float4 DiffuseMap = SRGBToLinearEst(tex2D(SampleDiffuseMap, Input.Tex0.xy));
	float4 HemiMap = SRGBToLinearEst(tex2D(SampleLUT, Input.Tex0.zw));

	// Lighting
	float3 Lighting = GetParticleLighting(HemiMap.a, Input.Altitude, saturate(m_color1AndLightFactor.a));
	float4 LightColor = (Input.Color.rgb * Lighting, Input.Color.a);
	float4 OutputColor = DiffuseMap * LightColor;

	Output.Color = OutputColor;
	ApplyFog(Output.Color.rgb, GetFogValue(Input.ViewPos, 0.0));
	TonemapAndLinearToSRGBEst(Output.Color);

	return Output;
}

// Renders circular shockwave found in explosions like in PRBot4/Num6
PS2FB PS_Additive(VS2PS Input)
{
	PS2FB Output = (PS2FB)0.0;

	// Textures
	float4 DiffuseMap = tex2D(SampleDiffuseMap, Input.Tex0.xy) * Input.Color;
	DiffuseMap.rgb = (_EffectSunColor.b < -0.1) ? float3(1.0, 0.0, 0.0) : DiffuseMap.rgb;

	// Mask with alpha since were doing an add
	float3 AlphaMask = DiffuseMap.aaa * Input.Color.aaa;
	float4 OutputColor = DiffuseMap;

	Output.Color = OutputColor;
	TonemapAndLinearToSRGBEst(Output.Color);
	Output.Color *= float4(AlphaMask, 1.0);

	return Output;
}

#define GET_RENDERSTATES_MESH_PARTICLES(ZWRITE, SRCBLEND, DESTBLEND) \
	ColorWriteEnable = RED|GREEN|BLUE; \
	CullMode = NONE; \
	ZEnable = TRUE; \
	ZFunc = PR_ZFUNC_WITHEQUAL; \
	ZWriteEnable = ZWRITE; \
	AlphaTestEnable = TRUE; \
	AlphaRef = 0; \
	AlphaFunc = GREATER; \
	AlphaBlendEnable = TRUE; \
	SrcBlend = SRCBLEND; \
	DestBlend = DESTBLEND; \

technique Diffuse
{
	pass p0
	{
		GET_RENDERSTATES_MESH_PARTICLES(FALSE, SRCALPHA, INVSRCALPHA)
		VertexShader = compile vs_3_0 VS_Diffuse();
		PixelShader = compile ps_3_0 PS_Diffuse();
	}
}

technique Additive
{
	pass p0
	{
		GET_RENDERSTATES_MESH_PARTICLES(FALSE, ONE, ONE)
		VertexShader = compile vs_3_0 VS_Diffuse();
		PixelShader = compile ps_3_0 PS_Additive();
	}
}

technique DiffuseWithZWrite
{
	pass p0
	{
		GET_RENDERSTATES_MESH_PARTICLES(TRUE, SRCALPHA, INVSRCALPHA)
		VertexShader = compile vs_3_0 VS_Diffuse();
		PixelShader = compile ps_3_0 PS_Diffuse();
	}
}
