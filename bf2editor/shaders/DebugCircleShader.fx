
/*
	Include header files
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
	Description: Renders circle for debug shaders
*/

float4x4 _WorldViewProj : WorldViewProjection;
bool _ZBuffer : ZBUFFER;

// string Category = "Effects\\Lighting";

struct APP2VS
{
	float4 Pos : POSITION;
	float4 Diffuse : COLOR;
};

struct VS2PS
{
	float4 HPos : POSITION;
	float4 Pos : TEXCOORD0;
	float4 Diffuse : TEXCOORD1;
};

struct PS2FB
{
	float4 Color : COLOR0;
	#if defined(LOG_DEPTH)
		float Depth : DEPTH;
	#endif
};

VS2PS VS_Debug_Circle(APP2VS Input)
{
	VS2PS Output = (VS2PS)0.0;

	Output.HPos = mul(float4(Input.Pos.xyz, 1.0), _WorldViewProj);
	Output.Pos = Output.HPos;

	// Output Depth
	#if defined(LOG_DEPTH)
		Output.Pos.w = Output.HPos.w + 1.0;
	#endif

	Output.Diffuse = float4(Input.Diffuse.rgb, 0.8);

	return Output;
}

PS2FB PS_Debug_Circle(VS2PS Input)
{
	PS2FB Output = (PS2FB)0.0;

	Output.Color = Input.Diffuse;
	TonemapAndLinearToSRGBEst(Output.Color);

	// Output Depth
	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);
	#endif

	return Output;
}

technique t0
<
	int DetailLevel = DLHigh+DLNormal+DLLow+DLAbysmal;
	int Compatibility = CMPR300+CMPNV2X;
	int Declaration[] =
	{
		// StreamNo, DataType, Usage, UsageIdx
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_POSITION, 0 },
		{ 0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 0 },
		DECLARATION_END	// End macro
	};
>
{
	pass p0
	{
		CullMode = NONE;
		DepthBias = -0.00001;
		ShadeMode = FLAT;

		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		ZEnable = FALSE;
		ZFunc = LESSEQUAL;
		ZWriteEnable = TRUE;

		VertexShader = compile vs_3_0 VS_Debug_Circle();
		PixelShader = compile ps_3_0 PS_Debug_Circle();
	}
}

//$ TODO: Temporary fix for enabling z-buffer writing for collision meshes.
technique t0_usezbuffer
<
	int DetailLevel = DLHigh+DLNormal+DLLow+DLAbysmal;
	int Compatibility = CMPR300+CMPNV2X;
	int Declaration[] =
	{
		// StreamNo, DataType, Usage, UsageIdx
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_POSITION, 0 },
		{ 0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 0 },
		DECLARATION_END	// End macro
	};
>
{
	pass p0
	{
		CullMode = NONE;
		AlphaBlendEnable = FALSE;

		ZEnable = TRUE;
		ZFunc = LESSEQUAL;
		ZWriteEnable = TRUE;

		VertexShader = compile vs_3_0 VS_Debug_Circle();
		PixelShader = compile ps_3_0 PS_Debug_Circle();
	}
}
