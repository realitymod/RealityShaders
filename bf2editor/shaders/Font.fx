#line 2 "Font.fx"

/*
	Description: Renders game font
*/

#include "shaders/RealityGraphics.fxh"
#include "shaders/shared/RealityDirectXTK.fxh"
#if !defined(_HEADERS_)
	#include "RealityGraphics.fxh"
	#include "shared/RealityDirectXTK.fxh"
#endif

/*
	[Attributes from app]
*/

float4x4 _WorldView : TRANSFORM;
float4 _DiffuseColor : DIFFUSE;

/*
	[Textures and samplers]
*/

#define CREATE_SAMPLER(SAMPLER_NAME, TEXTURE, FILTER) \
	sampler SAMPLER_NAME = sampler_state \
	{ \
		Texture = (TEXTURE); \
		MinFilter = FILTER; \
		MagFilter = FILTER; \
		MipFilter = NONE; \
		AddressU = CLAMP; \
		AddressV = CLAMP; \
	}; \

texture TexMap : TEXTURE;
CREATE_SAMPLER(SampleTexMap, TexMap, POINT)
CREATE_SAMPLER(SampleTexMap_Linear, TexMap, LINEAR)

struct APP2VS
{
	float4 Pos : POSITION;
	float2 TexCoord : TEXCOORD0;
	float4 Color : COLOR;
};

struct VS2PS_REGULAR
{
	float4 HPos : POSITION;
	float2 TexCoord : TEXCOORD0;
	float4 Diffuse : TEXCOORD1;
};

VS2PS_REGULAR VS_Regular(APP2VS Input)
{
	VS2PS_REGULAR Output = (VS2PS_REGULAR)0.0;
	// Output.Output.HPos = mul(float4(Input.Pos.xy, 0.5, 1.0), _WorldView);
	Output.HPos = float4(Input.Pos.xy, 0.5, 1.0);
	Output.TexCoord = Input.TexCoord;
	Output.Diffuse = saturate(Input.Color);
	return Output;
}

float4 PS_Regular(VS2PS_REGULAR Input) : COLOR0
{
	float4 OutputColor = 0.0;
	float4 ColorMap = SRGBToLinearEst(tex2D(SampleTexMap, Input.TexCoord));
	OutputColor = ColorMap * Input.Diffuse;

	LinearToSRGBEst(OutputColor);
	return OutputColor;
}

float4 PS_Regular_Scaled(VS2PS_REGULAR Input) : COLOR0
{
	float4 OutputColor = 0.0;
	float4 ColorMap = SRGBToLinearEst(tex2D(SampleTexMap_Linear, Input.TexCoord));
	OutputColor = ColorMap * Input.Diffuse;

	LinearToSRGBEst(OutputColor);
	return OutputColor;
}

float4 VS_SelectionQuad(float3 Pos : POSITION) : POSITION
{
	return mul(float4(Pos.xy, 0.0, 1.0), _WorldView);
}

float4 PS_SelectionQuad() : COLOR0
{
	return saturate(_DiffuseColor);
}

technique Regular
{
	pass p0
	{
		AlphaTestEnable = FALSE;

		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		VertexShader = compile vs_3_0 VS_Regular();
		PixelShader = compile ps_3_0 PS_Regular();
	}
}

technique RegularScaled
{
	pass p0
	{
		AlphaTestEnable = FALSE;

		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		VertexShader = compile vs_3_0 VS_Regular();
		PixelShader = compile ps_3_0 PS_Regular_Scaled();
	}
}

technique SelectionQuad
{
	pass p0
	{
		AlphaTestEnable = FALSE;

		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		VertexShader = compile vs_3_0 VS_SelectionQuad();
		PixelShader = compile ps_3_0 PS_SelectionQuad();
	}
}

