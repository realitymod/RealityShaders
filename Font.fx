#line 2 "Font.fx"

#include "shaders/RaCommon.fx"

/*
	[Attributes from app]
*/

uniform float4x4 _WorldView : TRANSFORM;
uniform float4 _DiffuseColor : DIFFUSE;

/*
	[Textures and samplers]
*/

uniform texture TexMap : TEXTURE;

sampler Sampler_TexMap = sampler_state
{
	Texture = (TexMap);
	AddressU = CLAMP;
	AddressV = CLAMP;
	MinFilter = POINT;
	MagFilter = POINT;
	MipFilter = NONE;
};

sampler Sampler_TexMap_Bilinear = sampler_state
{
	Texture = (TexMap);
	AddressU = CLAMP;
	AddressV = CLAMP;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = NONE;
};

struct APP2VS
{
	float4 Position : POSITION;
	float4 Color : COLOR;
	float2 TexCoord : TEXCOORD0;
};

struct VS2PS_REGULAR
{
	float4 Position : POSITION;
	float4 Diffuse : COLOR0;
	float2 TexCoord : TEXCOORD0;
};

VS2PS_REGULAR Regular_VS(APP2VS Input)
{
	VS2PS_REGULAR Output = (VS2PS_REGULAR)0;
	// Output.Position = mul( float4(Position.xy, 0.5f, 1.0f), _WorldView);
	Output.Position = float4(Input.Position.xy, 0.5f, 1.0f);
	Output.Diffuse = saturate(Input.Color);
	Output.TexCoord = Input.TexCoord;
	return Output;
}

float4 Regular_PS(VS2PS_REGULAR Input) : COLOR
{
	return tex2D(Sampler_TexMap, Input.TexCoord) * Input.Diffuse;
}

float4 Regular_Scaled_PS(VS2PS_REGULAR Input) : COLOR
{
	return tex2D(Sampler_TexMap_Bilinear, Input.TexCoord) * Input.Diffuse;
}

float4 SelectionQuad_VS(float3 Pos : POSITION) : POSITION
{
	return mul(float4(Pos.xy, 0.0f, 1.0), _WorldView);
}

float4 SelectionQuad_PS() : COLOR
{
	return saturate(_DiffuseColor);
}

technique Regular
{
	pass P0
	{
		VertexShader = compile vs_3_0 Regular_VS();
		PixelShader = compile ps_3_0 Regular_PS();
		AlphaTestEnable = FALSE;
		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;
	}
}

technique RegularScaled
{
	pass P0
	{
		VertexShader = compile vs_3_0 Regular_VS();
		PixelShader = compile ps_3_0 Regular_Scaled_PS();
		AlphaTestEnable = FALSE;
		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;
	}
}

technique SelectionQuad
{
	pass P0
	{
		VertexShader = compile vs_3_0 SelectionQuad_VS();
		PixelShader = compile ps_3_0 SelectionQuad_PS();
		AlphaTestEnable = FALSE;
		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;
	}
}
