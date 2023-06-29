#include "shaders/RealityGraphics.fxh"

/*
	Description: Renders lightning
*/

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
	#if defined(LOG_DEPTH)
		float Depth : DEPTH;
	#endif
};

VS2PS VS_Lightning(APP2VS Input)
{
	VS2PS Output = (VS2PS)0;

	Output.HPos = mul(float4(Input.Pos, 1.0), _WorldViewProj);

	Output.Tex0.xy = Input.TexCoords;
	#if defined(LOG_DEPTH)
		Output.Tex0.z = Output.HPos.w + 1.0; // Output depth
	#endif

	Output.Color = saturate(Input.Color);

	return Output;
}

PS2FB PS_Lightning(VS2PS Input)
{
	PS2FB Output = (PS2FB)0;

	float4 ColorTex = tex2D(SampleLightning, Input.Tex0.xy);

	Output.Color = ColorTex * _LightningColor;
	Output.Color.a *= Input.Color.a;

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Tex0.z);
	#endif

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


		VertexShader = compile vs_3_0 VS_Lightning();
		PixelShader = compile ps_3_0 PS_Lightning();
	}
}