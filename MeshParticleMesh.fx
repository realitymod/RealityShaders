
/*
	Description:
	- Renders 3D particle debris in explosions
	- Instanced to render up to to 26 particles in a drawcall
	- TIP: Test the shader with PRBot4/Num6 weapon
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
	float4 Pos : TEXCOORD0;
	float2 Tex0 : TEXCOORD1;
	float4 Color : COLOR0;
};

struct PS2FB
{
	float4 Color : COLOR;
	// float Depth : DEPTH;
};

VS2PS Diffuse_VS(APP2VS Input)
{
	VS2PS Output = (VS2PS)0;

   	// Compensate for lack of UBYTE4 on Geforce3
	int4 IndexVector = D3DCOLORtoUBYTE4(Input.BlendIndices);
	int IndexArray[4] = (int[4])IndexVector;

	float3 Pos = mul(Input.Pos * _GlobalScale, _MatOneBoneSkinning[IndexArray[0]]);
	Output.HPos = mul(float4(Pos.xyz, 1.0), _WorldViewProj);
	Output.Pos.xyz = Pos.xyz;
	Output.Pos.w = Output.HPos.z;

	// Compute Cubic polynomial factors.
	float Age = _AgeAndAlphaArray[IndexArray[0]][0];
	float4 CubicPolynomial = float4(pow(Age, float3(3.0, 2.0, 1.0)), 1.0);
	float ColorBlendFactor = min(dot(m_colorBlendGraph, CubicPolynomial), 1.0);
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
	return saturate(saturate((Pos.y - _HemiShadowAltitude) / 10.0) + _LightmapIntensityOffset);
}

// Renders 3D debris found in explosions like in PRBot4/Num6
PS2FB Diffuse_PS(VS2PS Input)
{
	PS2FB Output;

	float2 GroundUV = GetGroundUV(Input.Pos.xyz);
	float LMOffset = GetLMOffset(Input.Pos.xyz);
	float4 HPos = mul(float4(Input.Pos.xyz, 1.0), _WorldViewProj);

	float4 Diffuse = tex2D(SampleDiffuseMap, Input.Tex0) * Input.Color; // Diffuse map
	float4 TLUT = tex2D(SampleLUT, GroundUV); // Hemi map
	Diffuse.rgb *= GetParticleLighting(TLUT.a, LMOffset, saturate(m_color1AndLightFactor.a));

	ApplyFog(Diffuse.rgb, GetFogValue(HPos, 0.0));

	Output.Color = Diffuse;
	// Output.Depth = 0.0;

	return Output;
}

// Renders circular shockwave found in explosions like in PRBot4/Num6
PS2FB Additive_PS(VS2PS Input)
{
	PS2FB Output;

	float4 Diffuse = tex2D(SampleDiffuseMap, Input.Tex0) * Input.Color;

	if(_EffectSunColor.b < -0.1)
	{
		Diffuse.rgb = float3(1.0, 0.0, 0.0);
	}

	// Mask with alpha since were doing an add
	Diffuse.rgb *= Diffuse.a;

	Output.Color = Diffuse;
	// Output.Depth = 0.0;

	return Output;
}

#define GET_RENDERSTATES_MESH_PARTICLES(ZWRITE, SRCBLEND, DESTBLEND) \
	ColorWriteEnable = RED|GREEN|BLUE; \
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

technique Additive
{
	pass Pass0
	{
		GET_RENDERSTATES_MESH_PARTICLES(FALSE, ONE, ONE)
		VertexShader = compile vs_3_0 Diffuse_VS();
		PixelShader = compile ps_3_0 Additive_PS();
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
