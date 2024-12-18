#line 2 "SwiffMenu.fx"

/*
	Description: Shaders for main menu
*/
#include "shaders/RealityGraphics.fxh"
#include "shaders/shared/RealityDirectXTK.fxh"
#if !defined(_HEADERS_)
	#include "RealityGraphics.fxh"
	#include "shared/RealityDirectXTK.fxh"
#endif

float4x4 WorldView : TRANSFORM;
float4 DiffuseColor : DIFFUSE;
float4 TexGenS : TEXGENS;
float4 TexGenT : TEXGENT;
float Time : TIME;

#define CREATE_SAMPLER(SAMPLER_NAME, TEXTURE, ADDRESS) \
	sampler SAMPLER_NAME = sampler_state \
	{ \
		Texture = (TEXTURE); \
		MinFilter = LINEAR; \
		MagFilter = LINEAR; \
		MipFilter = NONE; \
		AddressU = ADDRESS; \
		AddressV = ADDRESS; \
	}; \

texture TexMap : TEXTURE;
CREATE_SAMPLER(SampleTexMap_Clamp, TexMap, CLAMP)
CREATE_SAMPLER(SampleTexMap_Wrap, TexMap, WRAP)

struct APP2VS_Shape
{
	float3 Pos : POSITION;
	float4 Color : COLOR0;
};

struct VS2PS_Shape
{
	float4 HPos : POSITION;
	float4 Diffuse : TEXCOORD0;
};

struct VS2PS_ShapeTexture
{
	float4 HPos : POSITION;
	float2 TexCoord : TEXCOORD0;
	float4 Diffuse : TEXCOORD1;
	float4 Selector : TEXCOORD2;
};

VS2PS_Shape VS_Shape(APP2VS_Shape Input)
{
	VS2PS_Shape Output = (VS2PS_Shape)0.0;
	Output.HPos = float4(Input.Pos.xy, 0.0, 1.0);
	Output.Diffuse = saturate(Input.Color);
	return Output;
}

VS2PS_Shape VS_Line(float3 Position : POSITION)
{
	VS2PS_Shape Output = (VS2PS_Shape)0.0;
	Output.HPos = float4(Position.xy, 0.0, 1.0);
	Output.Diffuse = saturate(DiffuseColor);
	return Output;
}

VS2PS_ShapeTexture VS_ShapeTexture(float3 Position : POSITION)
{
	VS2PS_ShapeTexture Output = (VS2PS_ShapeTexture)0.0;

	Output.HPos = mul(float4(Position.xy, 0.0, 1.0), WorldView);
	Output.Diffuse = saturate(DiffuseColor);
	Output.Selector = saturate(Position.zzzz);

	float4 TexPos = float4(Position.xy, 0.0, 1.0);
	Output.TexCoord.x = mul(TexPos, TexGenS);
	Output.TexCoord.y = mul(TexPos, TexGenT);

	return Output;
}

float4 PS_RegularWrap(VS2PS_ShapeTexture Input) : COLOR0
{
	float4 OutputColor = 0.0;
	float4 Tex = SRGBToLinearEst(tex2D(SampleTexMap_Wrap, Input.TexCoord));

	OutputColor.rgb = lerp(Input.Diffuse, Tex * Input.Diffuse, Input.Selector);
	OutputColor.a = Tex.a * Input.Diffuse.a;

	LinearToSRGBEst(OutputColor);
	return OutputColor;
}

float4 PS_RegularClamp(VS2PS_ShapeTexture Input) : COLOR0
{
	float4 OutputColor = 0.0;
	float4 Tex = SRGBToLinearEst(tex2D(SampleTexMap_Clamp, Input.TexCoord));

	OutputColor.rgb = lerp(Input.Diffuse, Tex * Input.Diffuse, Input.Selector);
	OutputColor.a = Tex.a * Input.Diffuse.a;

	LinearToSRGBEst(OutputColor);
	return OutputColor;
}

float4 PS_Diffuse(VS2PS_Shape Input) : COLOR0
{
	return Input.Diffuse;
}

float4 PS_Line(VS2PS_Shape Input) : COLOR0
{
	return Input.Diffuse;
}

technique Shape
{
	pass p0
	{
		VertexShader = compile vs_3_0 VS_Shape();
		PixelShader = compile ps_3_0 PS_Diffuse();
	}
}

technique ShapeTextureWrap
{
	pass p0
	{
		VertexShader = compile vs_3_0 VS_ShapeTexture();
		PixelShader = compile ps_3_0 PS_RegularWrap();
	}
}

technique ShapeTextureClamp
{
	pass p0
	{
		VertexShader = compile vs_3_0 VS_ShapeTexture();
		PixelShader  = compile ps_3_0 PS_RegularClamp();
	}
}

technique Line
{
	pass p0
	{
		AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_Line();
		PixelShader = compile ps_3_0 PS_Line();
	}
}

