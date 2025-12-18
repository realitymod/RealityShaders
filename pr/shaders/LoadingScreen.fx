#line 2 "LoadingScreen.fx"

/*
	Description: Renders loading screen at startup
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

float4x4 _WorldViewProj : TRANSFORM;

/*
	[Textures and samplers]
*/

texture TexMap : TEXTURE;

sampler SampleTexMap = sampler_state
{
	Texture = (TexMap);
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = LINEAR;
	AddressU = WRAP;
	AddressV = WRAP;
};

struct APP2VS
{
	float3 Pos : POSITION;
	float2 Tex : TEXCOORD0;
	float4 Color : COLOR0;
};

struct VS2PS
{
	float4 HPos : POSITION;
	float2 Tex : TEXCOORD0;
	float4 Color : TEXCOORD1;
};

VS2PS VS_Screen(APP2VS Input)
{
	VS2PS Output = (VS2PS)0.0;
	Output.HPos = float4(Input.Pos.xy, 0.0, 1.0);
	Output.Tex = Input.Tex;
	Output.Color = saturate(Input.Color);
	return Output;
}

float4 PS_Screen(VS2PS Input) : COLOR0
{
	float4 InputTexture0 = SRGBToLinearEst(tex2D(SampleTexMap, Input.Tex));

	float4 OutputColor = 0.0;
	OutputColor.rgb = InputTexture0.rgb * Input.Color.rgb;
	OutputColor.a = Input.Color.a;

	LinearToSRGBEst(OutputColor);
	return OutputColor;
}

technique Screen
{
	pass p0
	{
		CullMode = NONE;
		StencilEnable = FALSE;
		AlphaTestEnable = FALSE;
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_3_0 VS_Screen();
		PixelShader = compile ps_3_0 PS_Screen();
	}
}
