#include "shaders/RealityGraphics.fxh"
#include "shaders/shared/RealityDirectXTK.fxh"
#include "shaders/RaCommon.fxh"
#if !defined(_HEADERS_)
	#include "RealityGraphics.fxh"
	#include "shared/RealityDirectXTK.fxh"
	#include "RaCommon.fxh"
#endif

float4x4 _WorldViewProj : WorldViewProjection;
float4 _ViewPos : ViewPos;
float4 _DiffuseColor : DiffuseColor;
float _BlendFactor : BlendFactor;
float _Material : Material;

float4 _RoadFogColor : FogColor;

texture DetailTex0 : TEXLAYER0;
texture DetailTex1 : TEXLAYER1;

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

struct APP2VS_RoadEditable
{
	float4 Pos : POSITION;
	float2 Tex0 : TEXCOORD0;
	float2 Tex1 : TEXCOORD1;
	float Alpha : TEXCOORD2;
};

struct VS2PS_RoadEditable
{
	float4 HPos : POSITION;
	float4 Pos : TEXCOORD0;
	float4 Tex0 : TEXCOORD1; // .xy = Tex0; .zw = Tex1;
	float Alpha : TEXCOORD2;
};

VS2PS_RoadEditable VS_RoadEditable(APP2VS_RoadEditable Input)
{
	VS2PS_RoadEditable Output = (VS2PS_RoadEditable)0.0;

	Input.Pos.y +=  0.01;
	Output.HPos = mul(Input.Pos, _WorldViewProj);

	Output.Pos = Output.HPos;

	// Output depth
	#if defined(LOG_DEPTH)
		Output.Pos.w = Output.HPos.w + 1.0;
	#endif

	Output.Tex0 = float4(Input.Tex0, Input.Tex1);
	Output.Alpha = Input.Alpha;

	return Output;
}

PS2FB PS_RoadEditable(VS2PS_RoadEditable Input)
{
	PS2FB Output = (PS2FB)0.0;

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

	return Output;
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

VS2PS_DrawMaterial VS_RoadEditable_DrawMaterial(APP2VS_DrawMaterial Input)
{
	VS2PS_DrawMaterial Output = (VS2PS_DrawMaterial)0;

	Output.HPos = mul(Input.Pos, _WorldViewProj);
	Output.Pos = Output.HPos;

	// Output depth
	#if defined(LOG_DEPTH)
		Output.Pos.w = Output.HPos.w + 1.0;
	#endif

	return Output;
}

PS2FB PS_RoadEditable_DrawMaterial(VS2PS_DrawMaterial Input)
{
	PS2FB Output = (PS2FB)0.0;

	Output.Color = float4((float3)_Material, 1.0);
	Output.Color = lerp(_RoadFogColor, Output.Color, GetFogValue(Input.Pos, 0.0));

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);
	#endif

	return Output;
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

// [R-DEV]papadanku: [R-DEV]ason please test this

// Declare variables to registers because DICE didn't do so in their ASM.
float4 Constant0 : register(c0); // c[0]
float4 Constant1 : register(c1); // c[1]
float4 Constant2 : register(c2); // c[2]

struct APP2PS_ProjectRoad
{
	float4 Pos : POSITION0;
};

struct VS2PS_ProjectRoad
{
	float4 HPos : POSITION;
	float4 Color : TEXCOORD0;
};

VS2PS_ProjectRoad VS_ProjectRoad(APP2PS_ProjectRoad Input)
{
	VS2PS_ProjectRoad Output = (VS2PS_ProjectRoad)0.0;

	// add r0.xyz, v0.xzw, -c[0].xyz
	// mul r0.xyz, r0.xyz, c[1].xyw // z = 0, w = 1
	float3 ProjPos = Input.Pos.xzw - Constant0.xyz;
	ProjPos *= Constant1.xyw; // z = 0, w = 1

	// add oPos.x, r0.x, -c[1].w
	// add oPos.y, r0.y, -c[1].w
	// mov oPos.z, r0.z
	// mov oPos.w, c[1].w // z = 0, w = 1
	Output.HPos.x = ProjPos.x - Constant1.w;
	Output.HPos.y = ProjPos.y - Constant1.w;
	Output.HPos.z = ProjPos.z;
	Output.HPos.w = Constant1.w; // z = 0, w = 1

	// add r1, v0.y, -c[2].x
	// mul oD0, r1, c[2].y
	// mov oD0.a, c[1].z // z = 0
	float4 Color = Input.Pos.y - Constant2.x;
	Output.Color = Color * Constant2.y;
	Output.Color.a = Constant1.z; // z = 0
	Output.Color = saturate(Output.Color);

	return Output;
}

float4 PS_ProjectRoad(VS2PS_ProjectRoad Input)
{
	// mov r0, v0
	return Input.Color;
}

technique projectroad
<
	int Declaration[] =
	{
		// StreamNo, DataType, Usage, UsageIdx
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_POSITION, 0 },
		DECLARATION_END // End macro
	};
>
{
	pass p0
	{
		CullMode = NONE;
		// ShadeMode = FLAT;
		// DitherEnable = FALSE;
		// FillMode = WIREFRAME;
		ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		FogEnable = FALSE;

		VertexShader = compile vs_3_0 VS_ProjectRoad();
		PixelShader = compile ps_3_0 PS_ProjectRoad();
	}
}
