#line 2 "Lightning.fx"

/*
    Renders lightning effects and electrical discharges.
*/

#include "shaders/RealityGraphics.fxh"
#include "shaders/shared/RealityDepth.fxh"
#include "shaders/shared/RealityDirectXTK.fxh"
#if !defined(_HEADERS_)
	#include "RealityGraphics.fxh"
	#include "shared/RealityDepth.fxh"
	#include "shared/RealityDirectXTK.fxh"
#endif

/*
	[Attributes from app]
*/

float4x4 _WorldViewProj : WORLDVIEWPROJ;
float4 _LightningColor: LIGHTNINGCOLOR = { 1.0, 1.0, 1.0, 1.0 };

/*
	[Textures and samplers]
*/

texture Tex0 : TEXTURE;
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

VS2PS VS_Lightning(APP2VS Input)
{
	VS2PS Output = (VS2PS)0.0;

	Output.HPos = mul(float4(Input.Pos, 1.0), _WorldViewProj);
	Output.Tex0.xy = Input.TexCoords;

	// Output Depth
	#if PR_LOG_DEPTH
		Output.Tex0.z = Output.HPos.w + 1.0;
	#endif

	Output.Color = saturate(Input.Color);

	return Output;
}

RGraphics_PS2FB PS_Lightning(VS2PS Input)
{
	RGraphics_PS2FB Output = (RGraphics_PS2FB)0.0;

	float4 ColorTex = RDirectXTK_SRGBToLinearEst(tex2D(SampleLightning, Input.Tex0.xy));

	Output.Color = ColorTex * _LightningColor;
	Output.Color.a *= Input.Color.a;
	RDirectXTK_TonemapAndLinearToSRGBEst(Output.Color);

	#if PR_LOG_DEPTH
		Output.Depth = RDepth_ApplyLogarithmicDepth(Input.Tex0.z);
	#endif

	return Output;
}

technique Lightning
{
	pass p0
	{
		CullMode = NONE;

		ZEnable = TRUE;
		ZFunc = PR_ZFUNC_WITHEQUAL;
		ZWriteEnable = TRUE;

		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = ONE;

		VertexShader = compile vs_3_0 VS_Lightning();
		PixelShader = compile ps_3_0 PS_Lightning();
	}
}
