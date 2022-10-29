
/*
	Description: Renders lightning
*/

#include "shaders/RealityGraphics.fx"

/*
	[Attributes from app]
*/

uniform float4x4 _WorldViewProj : WORLDVIEWPROJ;
uniform float4 _LightningColor: LIGHTNINGCOLOR = { 1.0, 1.0, 1.0, 1.0 };

/*
	[Textures and samplers]
*/

uniform texture Tex0 : TEXTURE;
sampler SampleLightning = sampler_state
{
	Texture = (Tex0);
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = LINEAR;
	AddressU = CLAMP;
	AddressV = CLAMP;
};

struct APP2VS
{
	float3 Pos: POSITION;
	float2 TexCoords: TEXCOORD0;
	float4 Color : COLOR;
};

struct VS2PS
{
	float4 HPos: POSITION;
	float2 TexCoords: TEXCOORD0;
	float4 Color : COLOR0;
};

VS2PS Lightning_VS(APP2VS Input)
{
	VS2PS Output;
	Output.HPos = mul(float4(Input.Pos, 1.0), _WorldViewProj);
	Output.TexCoords = Input.TexCoords;
	Output.Color = saturate(Input.Color);
	return Output;
}

float4 Lightning_PS(VS2PS Input) : COLOR
{
	float4 Color = tex2D(SampleLightning, Input.TexCoords);
	return float4(Color.rgb * _LightningColor.rgb, Color.a * _LightningColor.a * Input.Color.a);
}

technique Lightning
{
	pass p0
	{
		ZEnable = TRUE;
		ZFunc = LESSEQUAL;
		ZWriteEnable = TRUE;
		AlphaBlendEnable = TRUE;
		SrcBlend = SrcAlpha;
		DestBlend = One;
		CullMode = NONE;
		
		VertexShader = compile vs_3_0 Lightning_VS();
		PixelShader = compile ps_3_0 Lightning_PS();
	}
}