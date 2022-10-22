
/*
	Description: Renders debug linegraph
*/

#include "shaders/RealityGraphics.fx"

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
	float4 Color : COLOR0;
};

VS2PS Debug_Linegraph_VS(APP2VS Input)
{
	VS2PS Output;

	float2 ScreenPos = Input.ScreenPos + _GraphPos;
	ScreenPos.x = ScreenPos.x / (_ViewportSize.x * 0.5) - 1.0;
	ScreenPos.y = -(ScreenPos.y / (_ViewportSize.y * 0.5) - 1.0);

	Output.HPos.xy = ScreenPos;
	Output.HPos.z = 0.001;
	Output.HPos.w = 1.0;
	Output.Color = Input.Color;
	return Output;
}

float4 Debug_Linegraph_PS(VS2PS Input) : COLOR
{
	return Input.Color;
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

		VertexShader = compile vs_3_0 Debug_Linegraph_VS();
		PixelShader = compile ps_3_0 Debug_Linegraph_PS();
	}
}
