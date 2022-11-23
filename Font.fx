
/*
	Description: Renders game font
*/

#include "shaders/RealityGraphics.fxh"
#include "shaders/RaCommon.fxh"

/*
	[Attributes from app]
*/

uniform float4x4 _WorldView : TRANSFORM;
uniform float4 _DiffuseColor : DIFFUSE;

/*
	[Textures and samplers]
*/

#define CREATE_SAMPLER(SAMPLER_NAME, TEXTURE, FILTER, IS_SRGB) \
	sampler SAMPLER_NAME = sampler_state \
	{ \
		Texture = (TEXTURE); \
		MinFilter = FILTER; \
		MagFilter = FILTER; \
		MipFilter = NONE; \
		AddressU = CLAMP; \
		AddressV = CLAMP; \
		SRGBTexture = IS_SRGB; \
	}; \

uniform texture TexMap : TEXTURE;
CREATE_SAMPLER(SampleTexMap, TexMap, POINT, FALSE)
CREATE_SAMPLER(SampleTexMap_Linear, TexMap, LINEAR, FALSE)

struct APP2VS
{
	float4 Pos : POSITION;
	float4 Color : COLOR;
	float2 TexCoord : TEXCOORD0;
};

struct VS2PS_REGULAR
{
	float4 HPos : POSITION;
	float4 Diffuse : COLOR0;
	float2 TexCoord : TEXCOORD0;
};

VS2PS_REGULAR Regular_VS(APP2VS Input)
{
	VS2PS_REGULAR Output = (VS2PS_REGULAR)0;
	// Output.Output.HPos = mul(float4(Input.Pos.xy, 0.5, 1.0), _WorldView);
	Output.HPos = float4(Input.Pos.xy, 0.5, 1.0);
	Output.Diffuse = saturate(Input.Color);
	Output.TexCoord = Input.TexCoord;
	return Output;
}

float4 Regular_PS(VS2PS_REGULAR Input) : COLOR
{
	return tex2D(SampleTexMap, Input.TexCoord) * Input.Diffuse;
}

float4 Regular_Scaled_PS(VS2PS_REGULAR Input) : COLOR
{
	return tex2D(SampleTexMap_Linear, Input.TexCoord) * Input.Diffuse;
}

float4 SelectionQuad_VS(float3 Pos : POSITION) : POSITION
{
	return mul(float4(Pos.xy, 0.0, 1.0), _WorldView);
}

float4 SelectionQuad_PS() : COLOR
{
	return saturate(_DiffuseColor);
}

technique Regular
{
	pass Pass0
	{
		AlphaTestEnable = FALSE;

		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		VertexShader = compile vs_3_0 Regular_VS();
		PixelShader = compile ps_3_0 Regular_PS();
	}
}

technique RegularScaled
{
	pass Pass0
	{
		AlphaTestEnable = FALSE;

		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		VertexShader = compile vs_3_0 Regular_VS();
		PixelShader = compile ps_3_0 Regular_Scaled_PS();
	}
}

technique SelectionQuad
{
	pass Pass0
	{
		AlphaTestEnable = FALSE;

		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		VertexShader = compile vs_3_0 SelectionQuad_VS();
		PixelShader = compile ps_3_0 SelectionQuad_PS();
	}
}
