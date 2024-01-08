
#include "Shaders/StaticMesh_Data.fxh"
#if !defined(INCLUDED_HEADERS)
	#include "StaticMesh_Data.fxh"
#endif

struct APP2VS_ShowTangentBasis
{
	float4 Pos : POSITION;
	float4 Color : COLOR;
};

struct VS2PS_ShowTangentBasis
{
	float4 HPos : POSITION;
	float4 Diffuse : COLOR;
};

VS2PS_ShowTangentBasis VS_ShowTangentBasis(APP2VS_ShowTangentBasis Input)
{
	VS2PS_ShowTangentBasis Output;

	float3 WorldPos = Input.Pos; // mul(Pos, _OneBoneSkinning[0]);

	Output.HPos = mul(float4(WorldPos.xyz, 1.0f), _ViewProjMatrix);
	Output.Diffuse = Input.Color;

	return Output;
}

float4 PS_ShowTangentBasis(VS2PS_ShowTangentBasis Input) : COLOR0
{
	return Input.Diffuse;
}

technique showTangentBasis
<
	int Declaration[] =
	{
		// StreamNo, DataType, Usage, UsageIdx
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_POSITION, 0 },
		{ 0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 0 },
		DECLARATION_END // End macro
	};
>
{
	pass p0
	{
		ZEnable = TRUE;
		ZWriteEnable = FALSE;
		AlphaBlendEnable = FALSE;

		VertexShader = compile vs_3_0 VS_ShowTangentBasis();
		PixelShader = compile ps_3_0 PS_ShowTangentBasis();
	}
}
