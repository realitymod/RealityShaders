
/*
	Description: Renders lightning
*/

#include "shaders/RealityGraphics.fxh"

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
	float3 Tex0 : TEXCOORD0;
	float4 Color : TEXCOORD1;
};

struct PS2FB
{
	float4 Color : COLOR;
	float Depth : DEPTH;
};

VS2PS Lightning_VS(APP2VS Input)
{
	VS2PS Output;

	Output.HPos = mul(float4(Input.Pos, 1.0), _WorldViewProj);

	Output.Tex0.xy = Input.TexCoords;
	Output.Tex0.z = Output.HPos.w + 1.0; // Output depth

	Output.Color = saturate(Input.Color);

	return Output;
}

PS2FB Lightning_PS(VS2PS Input)
{
	PS2FB Output;

	float4 ColorTex = tex2D(SampleLightning, Input.Tex0.xy);

	Output.Color = ColorTex * _LightningColor;
	Output.Color.a *= Input.Color.a;
	Output.Depth = ApplyLogarithmicDepth(Input.Tex0.z);

	return Output;
}

technique Lightning
{
	pass Pass0
	{
		CullMode = NONE;

		ZEnable = TRUE;
		ZFunc = LESSEQUAL;
		ZWriteEnable = TRUE;

		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = ONE;


		VertexShader = compile vs_3_0 Lightning_VS();
		PixelShader = compile ps_3_0 Lightning_PS();
	}
}