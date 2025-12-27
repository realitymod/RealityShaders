#line 2 "PortedMenuShader.fx"

/*
	Description: Handles UI elements from Battlefield 2.
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

// [1] Render-state settings from app
bool _AlphaBlend : ALPHABLEND = false;
dword _SrcBlend : SRCBLEND = D3DBLEND_INVSRCALPHA;
dword _DestBlend : DESTBLEND = D3DBLEND_SRCALPHA;
bool _AlphaTest : ALPHATEST = false;
dword _AlphaFunc : ALPHAFUNC = D3DCMP_GREATER;
dword _AlphaRef : ALPHAREF = 0;
dword _ZEnable : ZMODE = D3DZB_TRUE;
dword _ZFunc : ZFUNC = D3DCMP_LESSEQUAL;
bool _ZWriteEnable : ZWRITEENABLE = true;

float4x4 _WorldMatrix : matWORLD;
float4x4 _ViewMatrix : matVIEW;
float4x4 _ProjMatrix : matPROJ;

/*
	[Textures and samplers]
*/

#define CREATE_SAMPLER(SAMPLER_NAME, TEXTURE) \
	sampler SAMPLER_NAME = sampler_state \
	{ \
		Texture = (TEXTURE); \
		MinFilter = LINEAR; \
		MagFilter = LINEAR; \
		MipFilter = LINEAR; \
		AddressU = CLAMP; \
		AddressV = CLAMP; \
	}; \

texture Tex0: TEXLAYER0;
CREATE_SAMPLER(SampleTex0, Tex0)

texture Tex1: TEXLAYER1;
CREATE_SAMPLER(SampleTex1, Tex1)

struct APP2VS
{
	float4 Pos : POSITION;
	float4 Color : COLOR;
	float2 TexCoord0 : TEXCOORD0;
	float2 TexCoord1 : TEXCOORD1;
};

struct VS2PS
{
	float4 HPos : POSITION;
	float4 Color : TEXCOORD0;
	float2 TexCoord0 : TEXCOORD1;
	float2 TexCoord1 : TEXCOORD2;
};

VS2PS VS_Basic(APP2VS Input)
{
	VS2PS Output = (VS2PS)0.0;
	float4x4 WorldViewProj = _WorldMatrix * _ViewMatrix * _ProjMatrix;
	Output.HPos = mul(Input.Pos, WorldViewProj);
	Output.Color = saturate(Input.Color);
 	Output.TexCoord0 = Input.TexCoord0;
 	Output.TexCoord1 = Input.TexCoord1;
	return Output;
}

technique Menu
{
	pass { }
}

technique Menu_States <bool Restore = true;>
{
	pass BeginStates { }
	pass EndStates { }
}

float4 PS_Quad_WTex_NoTex(VS2PS Input) : COLOR0
{
	return Input.Color;
}

float4 PS_Quad_WTex_Tex(VS2PS Input) : COLOR0
{
	return tex2D(SampleTex0, Input.TexCoord0) * Input.Color;
}

float4 PS_Quad_WTex_Tex_Masked(VS2PS Input) : COLOR0
{
	float4 ColorTex = RDirectXTK_SRGBToLinearEst(tex2D(SampleTex0, Input.TexCoord0));
	float AlphaTex = tex2D(SampleTex1, Input.TexCoord1).a;

	float4 OutputColor = ColorTex * Input.Color;
	OutputColor.a *= AlphaTex;

	RDirectXTK_LinearToSRGBEst(OutputColor);
	return OutputColor;
}

// Macro for app render-state settings from [1]
#define APP_ALPHA_DEPTH_SETTINGS \
	AlphaBlendEnable = (_AlphaBlend); \
	SrcBlend = (_SrcBlend); \
	DestBlend = (_DestBlend); \
	AlphaTestEnable = (_AlphaTest); \
	AlphaFunc = (_AlphaFunc); \
	AlphaRef = (_AlphaRef); \
	ZEnable = (_ZEnable); \
	ZFunc = (_ZFunc); \
	ZWriteEnable = (_ZWriteEnable); \

technique QuadWithTexture
<
	int Declaration[] =
	{
		// StreamNo, DataType, Usage, UsageIdx
		0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_POSITION, 0,
		0, D3DDECLTYPE_FLOAT4, D3DDECLUSAGE_COLOR, 0,
		0, D3DDECLTYPE_FLOAT2, D3DDECLUSAGE_TEXCOORD, 0,
		0, D3DDECLTYPE_FLOAT2, D3DDECLUSAGE_TEXCOORD, 1,
		DECLARATION_END	// End macro
	};
>
{
	pass NoTex
	{
		// App alpha/depth settings
		APP_ALPHA_DEPTH_SETTINGS
		VertexShader = compile vs_3_0 VS_Basic();
		PixelShader = compile ps_3_0 PS_Quad_WTex_NoTex();
	}

	pass Tex
	{
		// App alpha/depth settings
		APP_ALPHA_DEPTH_SETTINGS
		VertexShader = compile vs_3_0 VS_Basic();
		PixelShader = compile ps_3_0 PS_Quad_WTex_Tex();
	}

	pass Masked
	{
		// App alpha/depth settings
		APP_ALPHA_DEPTH_SETTINGS
		VertexShader = compile vs_3_0 VS_Basic();
		PixelShader = compile ps_3_0 PS_Quad_WTex_Tex_Masked();
	}
}

float4 PS_Quad_Cache(VS2PS Input) : COLOR0
{
	float4 InputTexture = RDirectXTK_SRGBToLinearEst(tex2D(SampleTex0, Input.TexCoord0));
	float4 OutputColor = (InputTexture + 1.0) * Input.Color;

	RDirectXTK_LinearToSRGBEst(OutputColor);
	return OutputColor;
}

technique QuadCache
<
	int Declaration[] =
	{
		// StreamNo, DataType, Usage, UsageIdx
		0, D3DDECLTYPE_FLOAT4, D3DDECLUSAGE_POSITION, 0,
		0, D3DDECLTYPE_FLOAT4, D3DDECLUSAGE_COLOR, 0,
		0, D3DDECLTYPE_FLOAT2, D3DDECLUSAGE_TEXCOORD, 0,
		0, D3DDECLTYPE_FLOAT2, D3DDECLUSAGE_TEXCOORD, 1,
		DECLARATION_END	// End macro
	};
>
{
	pass p0
	{
		ZEnable = TRUE;
		ZFunc = LESS;
		ZWriteEnable = TRUE;

		AlphaTestEnable = TRUE;
		AlphaFunc = GREATER;
		AlphaRef = 0;

		AlphaBlendEnable = FALSE;

		VertexShader = compile vs_3_0 VS_Basic();
		PixelShader = compile ps_3_0 PS_Quad_Cache();
	}
}
