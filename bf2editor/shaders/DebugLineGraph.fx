
/*
	Description: Renders debug linegraph
*/
#include "shaders/RealityGraphics.fxh"
#include "shaders/shared/RealityDirectXTK.fxh"
#if !defined(_HEADERS_)
	#include "RealityGraphics.fxh"
	#include "shared/RealityDirectXTK.fxh"
#endif

float2 _GraphPos : GRAPHSIZE;
float2 _ViewportSize : VIEWPORTSIZE;

struct APP2VS
{
	float2 ScreenPos : POSITION;
	float4 Color : COLOR;
};

struct VS2PS
{
	float4 HPos : POSITION;
	float4 Color : TEXCOORD0;
};

VS2PS VS_Debug_Linegraph(APP2VS Input)
{
	VS2PS Output = (VS2PS)0.0;

	float2 ScreenPos = Input.ScreenPos + _GraphPos;
	ScreenPos = ScreenPos / (_ViewportSize * 0.5) - 1.0;

	Output.HPos = (ScreenPos.x, -ScreenPos.y, 0.001, 1.0);

	Output.Color = Input.Color;

	return Output;
}

float4 PS_Debug_Linegraph(VS2PS Input) : COLOR0
{
	float4 OutputColor = Input.Color;

	LinearToSRGBEst(OutputColor);
	return OutputColor;
}

technique Graph <
	int Declaration[] =
	{
		// StreamNo, DataType, Usage, UsageIdx
		0, D3DDECLTYPE_FLOAT2, D3DDECLUSAGE_POSITION, 0,
		0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 0,
		DECLARATION_END	// End macro
	};
>
{
	pass p0
	{
		ZEnable = FALSE;

		VertexShader = compile vs_3_0 VS_Debug_Linegraph();
		PixelShader = compile ps_3_0 PS_Debug_Linegraph();
	}
}
