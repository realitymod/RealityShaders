#line 2 "SwiffMenu.fx"

/*
	Description: Shaders for main menu
*/

#include "shaders/RaCommon.fxh"

uniform float4x4 WorldView : TRANSFORM;
uniform float4 DiffuseColor : DIFFUSE;
uniform float4 TexGenS : TEXGENS;
uniform float4 TexGenT : TEXGENT;
uniform float Time : TIME;

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

uniform texture TexMap : TEXTURE;
CREATE_SAMPLER(SampleTexMap_Clamp, TexMap, CLAMP)
CREATE_SAMPLER(SampleTexMap_Wrap, TexMap, WRAP)

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

VS2PS_Shape Shape_VS(float3 Position : POSITION, float4 VertexColor : COLOR0)
{
	VS2PS_Shape Output = (VS2PS_Shape)0;
	Output.HPos = float4(Position.xy, 0.0, 1.0); // mul(float4(Position.xy, 0.0, 1.0), WorldView);
	Output.Diffuse = saturate(VertexColor); // saturate(DiffuseColor);
	return Output;
}

VS2PS_Shape Line_VS(float3 Position : POSITION)
{
	VS2PS_Shape Output = (VS2PS_Shape)0;
	// Output.HPos = mul(float4(Position.xy, 0.0, 1.0), WorldView);
	// Output.HPos = float4(Position.xy, 0.0, 1.0);
	Output.HPos = float4(Position.xy, 0.0, 1.0);
	Output.Diffuse = saturate(DiffuseColor);
	return Output;
}

VS2PS_ShapeTexture ShapeTexture_VS(float3 Position : POSITION)
{
	VS2PS_ShapeTexture Output = (VS2PS_ShapeTexture)0;

	Output.HPos = mul(float4(Position.xy, 0.0, 1.0), WorldView);
	Output.Diffuse = saturate(DiffuseColor);
	Output.Selector = saturate(Position.zzzz);

	float4 TexPos = float4(Position.xy, 0.0, 1.0);
	Output.TexCoord.x = mul(TexPos, TexGenS);
	Output.TexCoord.y = mul(TexPos, TexGenT);

	return Output;
}

float4 RegularWrap_PS(VS2PS_ShapeTexture Input) : COLOR
{
	float4 OutputColor = 0.0;
	float4 Tex = tex2D(SampleTexMap_Wrap, Input.TexCoord);
	OutputColor.rgb = lerp(Input.Diffuse, Tex * Input.Diffuse, Input.Selector);
	OutputColor.a = Tex.a * Input.Diffuse.a;
	return OutputColor;
}

float4 RegularClamp_PS(VS2PS_ShapeTexture Input) : COLOR
{
	float4 OutputColor = 0.0;
	float4 Tex = tex2D(SampleTexMap_Clamp, Input.TexCoord);
	OutputColor.rgb = lerp(Input.Diffuse, Tex * Input.Diffuse, Input.Selector);
	OutputColor.a = Tex.a * Input.Diffuse.a;
	return OutputColor;
}

float4 Diffuse_PS(VS2PS_Shape Input) : COLOR
{
	return Input.Diffuse;
}

float4 Line_PS(VS2PS_Shape Input) : COLOR
{
	return Input.Diffuse;
}

technique Shape
{
	pass Pass0
	{
		VertexShader = compile vs_3_0 Shape_VS();
		PixelShader = compile ps_3_0 Diffuse_PS();
	}
}

technique ShapeTextureWrap
{
	pass Pass0
	{
		VertexShader = compile vs_3_0 ShapeTexture_VS();
		PixelShader = compile ps_3_0 RegularWrap_PS();
	}
}

technique ShapeTextureClamp
{
	pass Pass0
	{
		VertexShader = compile vs_3_0 ShapeTexture_VS();
		PixelShader  = compile ps_3_0 RegularClamp_PS();
	}
}

technique Line
{
	pass Pass0
	{
		AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 Line_VS();
		PixelShader = compile ps_3_0 Line_PS();
	}
}
