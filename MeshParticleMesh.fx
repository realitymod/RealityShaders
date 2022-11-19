
/*
	Description:
	- Renders 3D particle debris in explosions
	- Instanced to render up to to 26 particles in a drawcall
	- TIP: Test the shader with PRBot4's Num6 weapon
*/

#include "shaders/RealityGraphics.fxh"

#include "shaders/FXCommon.fxh"

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
	float2 Tex0 : TEXCOORD0;
	float3 VertexPos : TEXCOORD1;
	float4 Color : COLOR0;
};

VS2PS Diffuse_VS(APP2VS Input)
{
	VS2PS Output = (VS2PS)0;

   	// Compensate for lack of UBYTE4 on Geforce3
	int4 IndexVector = D3DCOLORtoUBYTE4(Input.BlendIndices);
	int IndexArray[4] = (int[4])IndexVector;

	float3 Pos = mul(Input.Pos * _GlobalScale, _MatOneBoneSkinning[IndexArray[0]]);
	Output.HPos = mul(float4(Pos.xyz, 1.0f), _WorldViewProj);
	Output.VertexPos = Pos.xyz;

	// Compute Cubic polynomial factors.
	float Age = _AgeAndAlphaArray[IndexArray[0]][0];
	float4 PC = float4(pow(Age, float3(3.0, 2.0, 1.0)), 1.0);
	float ColorBlendFactor = min(dot(m_colorBlendGraph, PC), 1.0);
 	Output.Color.rgb = lerp(m_color1AndLightFactor.rgb, m_color2.rgb, ColorBlendFactor);
 	Output.Color.a = _AgeAndAlphaArray[IndexArray[0]][1];
	Output.Color = saturate(Output.Color);

	// Pass-through texcoords
	Output.Tex0 = Input.TexCoord;

	return Output;
}

float2 GetGroundUV(float3 Pos)
{
	return ((Pos.xyz + (_HemiMapInfo.z * 0.5)).xz - _HemiMapInfo.xy) / _HemiMapInfo.z;
}

float GetLMOffset(float3 Pos)
{
	return saturate(saturate((Pos.y - _HemiShadowAltitude) / 10.0f) + _LightmapIntensityOffset);
}

float4 Diffuse_PS(VS2PS Input) : COLOR
{
	float2 GroundUV = GetGroundUV(Input.VertexPos);
	float LMOffset = GetLMOffset(Input.VertexPos);
	float4 HPos = mul(float4(Input.VertexPos.xyz, 1.0f), _WorldViewProj);

	float4 Diffuse = tex2D(SampleDiffuseMap, Input.Tex0) * Input.Color; // Diffuse map
	float4 TLUT = tex2D(SampleLUT, GroundUV); // Hemi map
	Diffuse.rgb *= GetParticleLighting(TLUT.a, LMOffset, saturate(m_color1AndLightFactor.a));

	ApplyFog(Diffuse.rgb, GetFogValue(HPos, 0.0));

	return Diffuse;
}

float4 Additive_PS(VS2PS Input) : COLOR
{
	float4 HPos = mul(float4(Input.VertexPos.xyz, 1.0f), _WorldViewProj);

	float4 Diffuse = tex2D(SampleDiffuseMap, Input.Tex0) * Input.Color;
	Diffuse.rgb = (_EffectSunColor.bbb < -0.1) ? float3(1.0, 0.0, 0.0) : Diffuse.rgb;

	Diffuse.rgb *= Diffuse.a; // Mask with alpha since were doing an add
	Diffuse.rgb *= GetFogValue(HPos, 0.0);

	return Diffuse;
}

#define GET_RENDERSTATES_MESH_PARTICLES(ZWRITE, SRCBLEND, DESTBLEND) \
	CullMode = CCW; \
	ZEnable = TRUE; \
	ZWriteEnable = ZWRITE; \
	AlphaTestEnable = TRUE; \
	AlphaRef = 0; \
	AlphaFunc = GREATER; \
	AlphaBlendEnable = TRUE; \
	SrcBlend = SRCBLEND; \
	DestBlend = DESTBLEND; \
	SRGBWriteEnable = FALSE; \

technique Diffuse
{
	pass Pass0
	{
		GET_RENDERSTATES_MESH_PARTICLES(FALSE, SRCALPHA, INVSRCALPHA)
		VertexShader = compile vs_3_0 Diffuse_VS();
		PixelShader = compile ps_3_0 Diffuse_PS();
	}
}

technique DiffuseWithZWrite
{
	pass Pass0
	{
		GET_RENDERSTATES_MESH_PARTICLES(TRUE, SRCALPHA, INVSRCALPHA)
		VertexShader = compile vs_3_0 Diffuse_VS();
		PixelShader = compile ps_3_0 Diffuse_PS();
	}
}

technique Additive
{
	pass Pass0
	{
		GET_RENDERSTATES_MESH_PARTICLES(FALSE, ONE, ONE)
		VertexShader = compile vs_3_0 Diffuse_VS();
		PixelShader = compile ps_3_0 Additive_PS();
	}
}
