
#include "shaders/RealityGraphics.fxh"
#if !defined(_HEADERS_)
	#include "RealityGraphics.fxh"
#endif

uniform float4x4 _ViewProj : matVIEWPROJ;

uniform bool _AlphaBlend : ALPHABLEND = true;
uniform dword _SrcBlend : SRCBLEND = D3DBLEND_SRCALPHA;
uniform dword _DestBlend : DESTBLEND = D3DBLEND_INVSRCALPHA;

uniform bool _AlphaTest : ALPHATEST = true;
uniform dword _AlphaFunc : ALPHAFUNC = D3DCMP_GREATER;
uniform dword _AlphaRef : ALPHAREF = 0;

uniform dword _ZEnable : ZMODE = D3DZB_TRUE;
uniform bool _ZWriteEnable : ZWRITEENABLE = false;

uniform dword _TexFactor : TEXFACTOR = 0;

uniform texture Tex0: TEXLAYER0;
uniform texture Tex1: TEXLAYER1;

sampler SampleTex0 = sampler_state
{
	Texture = (Tex0);
	AddressU = WRAP;
	AddressV = CLAMP;
	MipFilter = LINEAR;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
};

sampler SampleTex1 = sampler_state
{
	Texture = (Tex1);
	AddressU = WRAP;
	AddressV = CLAMP;
	MipFilter = LINEAR;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
};

struct APP2VS
{
	float4 Pos : POSITION;
	float2 Tex1 : TEXCOORD0;
	float2 Tex2 : TEXCOORD1;
	float4 Color1 : COLOR;
	float4 Color2 : COLOR;
};

struct VS2PS
{
	float4 HPos : POSITION;
	float2 Pos : TEXCOORD0;
	float4 Tex : TEXCOORD1; // .xy = Tex1; .zw = Tex2;
	float4 Color1 : TEXCOORD2;
	float4 Color2 : TEXCOORD3;
};

struct PS2FB
{
	float4 Color : COLOR0;
	#if defined(LOG_DEPTH)
		float Depth : DEPTH;
	#endif
};

VS2PS VS_Quad(APP2VS Input)
{
	VS2PS Output;

	Output.HPos = mul(Input.Pos, _ViewProj);
	Output.Pos = Input.Pos;

	// Output depth
	#if defined(LOG_DEPTH)
		Output.Pos.w = Output.HPos.w + 1.0;
	#endif

	Output.Color1 = Input.Color1;
	Output.Color2 = Input.Color2;
 	Output.Tex = float4(Input.Tex1, Input.Tex2);

	return Output;
}

PS2FB PS_Quad(VS2PS Input)
{
	PS2FB Output = (PS2FB)0;

	float4 Tex0 = tex2D(SampleTex0, Input.Tex.xy);
	float4 Tex1 = tex2D(SampleTex1, Input.Tex.zw);

	Output.Color = lerp(Tex1, Tex0, Input.Color2.a);

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);
	#endif

	return Output;
}

technique QuadWithTexture
<
	int Declaration[] =
	{
		// StreamNo, DataType, Usage, UsageIdx
		0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_POSITION, 0,
		0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 0,
		0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 1,
		0, D3DDECLTYPE_FLOAT2, D3DDECLUSAGE_TEXCOORD, 0,
		0, D3DDECLTYPE_FLOAT2, D3DDECLUSAGE_TEXCOORD, 1,
		DECLARATION_END // End macro
	};
>
{
	pass p0
	{
		// App alpha/depth settings
		AlphaBlendEnable = (_AlphaBlend);
		SrcBlend = (_SrcBlend);
		DestBlend = (_DestBlend);
		AlphaTestEnable = TRUE; // (_AlphaTest);
		AlphaFunc = (_AlphaFunc);
		AlphaRef = (_AlphaRef);
		ZWriteEnable = (_ZWriteEnable);
		CullMode = NONE;

		VertexShader = compile vs_3_0 VS_Quad();
		PixelShader = compile ps_3_0 PS_Quad();
	}
}
