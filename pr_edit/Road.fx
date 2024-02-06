#include "shaders/RealityGraphics.fxh"
#include "shaders/shared/RealityDirectXTK.fxh"
#include "shaders/RaCommon.fxh"
#if !defined(_HEADERS_)
	#include "RealityGraphics.fxh"
	#include "shared/RealityDirectXTK.fxh"
	#include "RaCommon.fxh"
#endif

uniform float4x4 _WorldViewProj : WorldViewProjection;
uniform float4 _ViewPos : ViewPos;
uniform float4 _DiffuseColor : DiffuseColor;
uniform float _BlendFactor : BlendFactor;
uniform float _Material : Material;

uniform float4 _RoadFogColor : FogColor;

uniform texture DetailTex0 : TEXLAYER0;
uniform texture DetailTex1 : TEXLAYER1;

sampler SampleDetailTex0 = sampler_state
{
	Texture = (DetailTex0);
	AddressU = CLAMP;
	AddressV = WRAP;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = LINEAR;
};

sampler SampleDetailTex1 = sampler_state
{
	Texture = (DetailTex1);
	AddressU = WRAP;
	AddressV = WRAP;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = LINEAR;
};

struct PS2FB
{
	float4 Color : COLOR0;
	#if defined(LOG_DEPTH)
		float Depth : DEPTH;
	#endif
};

struct APP2VS
{
	float4 Pos : POSITION;
	float2 Tex0 : TEXCOORD0;
	float2 Tex1 : TEXCOORD1;
	float Alpha : TEXCOORD2;
};

struct VS2PS
{
	float4 HPos : POSITION;
	float4 Pos : TEXCOORD0;
	float4 Tex0 : TEXCOORD1; // .xy = Tex0; .zw = Tex1;
	float Alpha : TEXCOORD2;
};

void VS_RoadEditable(in APP2VS Input, out VS2PS Output)
{
	Output = (VS2PS)0.0;

	Input.Pos.y +=  0.01;
	Output.HPos = mul(Input.Pos, _WorldViewProj);

	Output.Pos = Output.HPos;

	// Output depth
	#if defined(LOG_DEPTH)
		Output.Pos.w = Output.HPos.w + 1.0;
	#endif

	Output.Tex0 = float4(Input.Tex0, Input.Tex1);
	Output.Alpha = Input.Alpha;
}

void PS_RoadEditable(in VS2PS Input, out PS2FB Output)
{
	float4 ColorMap0 = SRGBToLinearEst(tex2D(SampleDetailTex0, Input.Tex0.xy));
	float4 ColorMap1 = SRGBToLinearEst(tex2D(SampleDetailTex1, Input.Tex0.zw));

	float4 OutputColor = 0.0;
	OutputColor.rgb = lerp(ColorMap1.rgb, ColorMap0.rgb, saturate(_BlendFactor));
	OutputColor.a = ColorMap0.a * Input.Alpha;

	Output.Color = OutputColor;
	Output.Color = lerp(_RoadFogColor, Output.Color, GetFogValue(Input.Pos, 0.0));
	TonemapAndLinearToSRGBEst(Output.Color);

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);
	#endif
}

struct APP2VS_DrawMaterial
{
	float4 Pos : POSITION;
	float2 Tex0 : TEXCOORD0;
	float2 Tex1 : TEXCOORD1;
};

struct VS2PS_DrawMaterial
{
	float4 HPos : POSITION;
	float4 Pos : TEXCOORD0;
};

void VS_RoadEditable_DrawMaterial(in APP2VS_DrawMaterial Input, out VS2PS_DrawMaterial Output)
{
	Output = (VS2PS_DrawMaterial)0;

	Output.HPos = mul(Input.Pos, _WorldViewProj);
	Output.Pos = Output.HPos;

	// Output depth
	#if defined(LOG_DEPTH)
		Output.Pos.w = Output.HPos.w + 1.0;
	#endif
}

void PS_RoadEditable_DrawMaterial(in VS2PS_DrawMaterial Input, out PS2FB Output)
{
	Output.Color = float4((float3)_Material, 1.0);
	Output.Color = lerp(_RoadFogColor, Output.Color, GetFogValue(Input.Pos, 0.0));

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);
	#endif
}

technique roadeditable
<
	int DetailLevel = DLHigh+DLNormal+DLLow+DLAbysmal;
	int Compatibility = CMPR300+CMPNV2X;
	int Declaration[] =
	{
		// StreamNo, DataType, Usage, UsageIdx
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_POSITION, 0 },
		// { 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_NORMAL, 0 },
		{ 0, D3DDECLTYPE_FLOAT2, D3DDECLUSAGE_TEXCOORD, 0 },
		{ 0, D3DDECLTYPE_FLOAT2, D3DDECLUSAGE_TEXCOORD, 1 },
		{ 0, D3DDECLTYPE_FLOAT1, D3DDECLUSAGE_TEXCOORD, 2 },
		DECLARATION_END // End macro
	};
>
{
	pass p0
	{
		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;
		FogEnable = FALSE;
		ZEnable = TRUE;
		ZWriteEnable = FALSE;
		FogEnable = TRUE;

		VertexShader = compile vs_3_0 VS_RoadEditable();
		PixelShader = compile ps_3_0 PS_RoadEditable();
	}

	pass p1 // draw material
	{
		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;
		DepthBias = -0.0001f;
		SlopeScaleDepthBias = -0.00001f;
		ZEnable = TRUE;
		ZWriteEnable = FALSE;

		VertexShader = compile vs_3_0 VS_RoadEditable_DrawMaterial();
		PixelShader = compile ps_3_0 PS_RoadEditable_DrawMaterial();
	}
}
