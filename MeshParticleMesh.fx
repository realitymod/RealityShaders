
/*
	Description: Renders particle lighting
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

struct VS2PS_Diffuse
{
	float4 HPos : POSITION;
	float4 DiffuseMap_GroundUV : TEXCOORD0; // .xy = DiffuseMap; .zw = GroundUV
	float3 Lerp_LMapIntOffset: TEXCOORD1;
	float3 VertexPos : TEXCOORD2;

	float4 Color : COLOR0;
	float4 LightFactor : COLOR1;
};

VS2PS_Diffuse Diffuse_VS(APP2VS Input)
{
	VS2PS_Diffuse Output = (VS2PS_Diffuse)0;

   	// Compensate for lack of UBYTE4 on Geforce3
	int4 IndexVector = D3DCOLORtoUBYTE4(Input.BlendIndices);
	int IndexArray[4] = (int[4])IndexVector;

	float3 Pos = mul(Input.Pos * _GlobalScale, _MatOneBoneSkinning[IndexArray[0]]);

	Output.HPos = mul(float4(Pos.xyz, 1.0f), _WorldViewProj);
	Output.VertexPos = Output.HPos.xyz;

	// Compute Cubic polynomial factors.
	float Age = _AgeAndAlphaArray[IndexArray[0]][0];
	float4 PC = float4(pow(Age, float3(3.0, 2.0, 1.0)), 1.0);

	float ColorBlendFactor = min(dot(m_colorBlendGraph, PC), 1.0);
	float3 Color = ColorBlendFactor * m_color2.rgb;
	Color += (1.0 - ColorBlendFactor) * m_color1AndLightFactor.rgb;
 	Output.Color.rgb = Color;
 	Output.Color.a = _AgeAndAlphaArray[IndexArray[0]][1];
	Output.Color = saturate(Output.Color);

	Output.LightFactor = saturate(m_color1AndLightFactor.a);

	// Pass-through texcoords
	Output.DiffuseMap_GroundUV.xy = Input.TexCoord.xy;

	// Hemi lookup coords
 	Output.DiffuseMap_GroundUV.zw = ((Pos.xyz + (_HemiMapInfo.z / 2.0)).xz - _HemiMapInfo.xy)/ _HemiMapInfo.z;
 	Output.Lerp_LMapIntOffset = saturate(saturate((Pos.y - _HemiShadowAltitude) / 10.0f) + _LightmapIntensityOffset);

	return Output;
}

float4 Diffuse_PS(VS2PS_Diffuse Input) : COLOR
{
	float4 Diffuse = tex2D(SampleDiffuseMap, Input.DiffuseMap_GroundUV.xy) * Input.Color; // Diffuse Map
	float4 TLUT = tex2D(SampleLUT, Input.DiffuseMap_GroundUV.zw); // Hemi map
	Diffuse.rgb *= GetParticleLighting(TLUT.a, Input.Lerp_LMapIntOffset, Input.LightFactor.a);
	ApplyFog(Diffuse.rgb, GetFogValue(Input.VertexPos, 0.0));

	return Diffuse;
}

float4 Additive_PS(VS2PS_Diffuse Input) : COLOR
{
	float4 Diffuse = tex2D(SampleDiffuseMap, Input.DiffuseMap_GroundUV.xy) * Input.Color;
	Diffuse.rgb = (_EffectSunColor.bbb < -0.1) ? float3(1.0, 0.0, 0.0) : Diffuse.rgb;
	Diffuse.rgb *= Diffuse.a; // Mask with alpha since were doing an add
	Diffuse.rgb *= GetFogValue(Input.VertexPos, 0.0);

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
