#line 2 "SwiffMenu.fx"

/*
	Description: Shaders for main menu
*/

#include "shaders/RaCommon.fx"

uniform float4x4 WorldView : TRANSFORM;
uniform float4 DiffuseColor : DIFFUSE;
uniform float4 TexGenS : TEXGENS;
uniform float4 TexGenT : TEXGENT;
uniform texture TexMap : TEXTURE;
uniform float Time : TIME;

sampler Sampler_Clamp = sampler_state
{
	Texture = (TexMap);
	AddressU = CLAMP;
	AddressV = CLAMP;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = NONE;
};

sampler Sampler_Wrap = sampler_state
{
	Texture = (TexMap);
	AddressU = WRAP;
	AddressV = WRAP;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = NONE;
};

struct VS2PS_Shape
{
	float4 HPos : POSITION;
	float4 Diffuse : COLOR0;
};

struct VS2PS_Shape_Texture
{
	float4 HPos : POSITION;
	float2 TexCoord : TEXCOORD0;
	float4 Diffuse : COLOR0;
	float4 Selector : COLOR1;
};

VS2PS_Shape Shape_VS(float3 Position : POSITION, float4 VertexColor : COLOR0)
{
	VS2PS_Shape Output = (VS2PS_Shape)0;
	// Output.HPos = mul(float4(Position.xy, 0.0f, 1.0), WorldView);
	Output.HPos = float4(Position.xy, 0.0f, 1.0);
	// Output.Diffuse = saturate(DiffuseColor);
	Output.Diffuse = saturate(VertexColor);
	return Output;
}

VS2PS_Shape Line_VS(float3 Position : POSITION)
{
	VS2PS_Shape Output = (VS2PS_Shape)0;
	// Output.HPos = mul(float4(Position.xy, 0.0f, 1.0), WorldView);
	// Output.HPos = float4(Position.xy, 0.0f, 1.0);
	Output.HPos = float4(Position.xy, 0.0f, 1.0);
	Output.Diffuse = saturate(DiffuseColor);
	return Output;
}

VS2PS_Shape_Texture Shape_Texture_VS(float3 Position : POSITION)
{
	VS2PS_Shape_Texture Output = (VS2PS_Shape_Texture)0;

	Output.HPos = mul(float4(Position.xy, 0.0f, 1.0), WorldView);
	Output.Diffuse = saturate(DiffuseColor);
	Output.Selector = saturate(Position.zzzz);

	float4 TexPos = float4(Position.xy, 0.0, 1.0);
	Output.TexCoord.x = mul(TexPos, TexGenS);
	Output.TexCoord.y = mul(TexPos, TexGenT);

	return Output;
}

float4 Regular_Wrap_PS(VS2PS_Shape_Texture Input) : COLOR
{
	float4 Color = 0.0;
	float4 Tex = tex2D(Sampler_Wrap, Input.TexCoord);
	// return Tex.aaaa;
	Color.rgb = Tex * Input.Diffuse * Input.Selector + Input.Diffuse * (1.0 - Input.Selector);
	Color.a = Tex.a * Input.Diffuse.a;
	return Color;
}

float4 PSRegularClamp(VS2PS_Shape_Texture Input) : COLOR
{
	float4 Color = 0.0;
	float4 Tex = tex2D(Sampler_Clamp, Input.TexCoord);
	// return Tex.aaaa + 1.0;
	Color.rgb = Tex * Input.Diffuse * Input.Selector + Input.Diffuse * (1.0 - Input.Selector);
	Color.a = Tex.a * Input.Diffuse.a;
	return Color;
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
	pass P0
	{
		VertexShader = compile vs_3_0 Shape_VS();
		PixelShader = compile ps_3_0 Diffuse_PS();
	}
}

technique ShapeTextureWrap
{
	pass P0
	{
		VertexShader = compile vs_3_0 Shape_Texture_VS();
		PixelShader = compile ps_3_0 Regular_Wrap_PS();
	}
}

technique ShapeTextureClamp
{
	pass P0
	{
		VertexShader = compile vs_3_0 Shape_Texture_VS();
		PixelShader  = compile ps_3_0 PSRegularClamp();
	}
}

technique Line
{
	pass P0
	{
		VertexShader = compile vs_3_0 Line_VS();
		PixelShader = compile ps_3_0 Line_PS();
		AlphaTestEnable = FALSE;
	}
}
