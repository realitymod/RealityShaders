
#include "Shaders/StaticMesh_Data.fxh"
#if !defined(INCLUDED_HEADERS)
	#include "StaticMesh_Data.fxh"
#endif

uniform float4 _PosUnpack : POSUNPACK;
uniform float _TexUnpack : TEXUNPACK;

struct APP2VS_LightMapGen
{
	float4 Pos : POSITION;
	float2 DiffuseTex : TEXCOORD0;
};

struct APP2VS_LightMapGen2
{
	float4 Pos : POSITION;
	float3 Normal : NORMAL;
	float2 DiffuseTex : TEXCOORD0;
};

struct VS2PS_LightMapGen
{
	float4 HPos : POSITION;
	float2 DiffuseTex : TEXCOORD0;
};

VS2PS_LightMapGen VS_LightMapBase(APP2VS_LightMapGen Input)
{
	VS2PS_LightMapGen Output = (VS2PS_LightMapGen)0.0;

	// Compensate for lack of UBYTE4 on Geforce3
	// int4 IndexVector = D3DCOLORtoUBYTE4(Input.BlendIndices);
	// int IndexArray[4] = (int[4])IndexVector;

	float4 Pos = Input.Pos * _PosUnpack; // mul(Input.Pos, _OneBoneSkinning[IndexArray[0]]);
	Output.HPos = mul(float4(Pos.xyz, 1.0f), _ViewProjMatrix);

	// Pass-through texcoords
	Output.DiffuseTex = Input.DiffuseTex * _TexUnpack;

	return Output;
}

VS2PS_LightMapGen VS_LightMapBase2(APP2VS_LightMapGen2 Input)
{
	VS2PS_LightMapGen Output = (VS2PS_LightMapGen)0.0;

	// Compensate for lack of UBYTE4 on Geforce3
	// int4 IndexVector = D3DCOLORtoUBYTE4(Input.BlendIndices);
	// int IndexArray[4] = (int[4])IndexVector;

	float4 Pos = Input.Pos * _PosUnpack; // mul(Input.Pos, _OneBoneSkinning[IndexArray[0]]);
	Output.HPos = mul(float4(Pos.xyz, 1.0f), _ViewProjMatrix);

	// Pass-through texcoords
	Output.DiffuseTex = Input.DiffuseTex * _TexUnpack;

	return Output;
}

float4 PS_LightMapGenTest(VS2PS_LightMapGen indata) : COLOR0
{
	float4 Color = tex2D(SamplerWrap0, indata.DiffuseTex);
	Color.rgb = 0.0;
	return Color;
}

float4 PS_LightMapGen(VS2PS_LightMapGen Input) : COLOR0
{
	// Output pure black color for lightmap generation
	return float4(0.0, 0.0, 0.0, 1.0);
}

technique lightmapGenerationAlphaTest
{
	pass p0
	{
		AlphaTestEnable = <_AlphaTest>;
		AlphaRef = 50;
		AlphaFunc = GREATER;

		ZEnable = TRUE;
		ZWriteEnable = TRUE;
		AlphaBlendEnable = FALSE;
		CullMode = NONE;

		VertexShader = compile vs_3_0 VS_LightMapBase();
		PixelShader = compile ps_3_0 PS_LightMapGenTest();
	}

	pass p1
	{
		AlphaTestEnable = <_AlphaTest>;
		AlphaRef = 50;
		AlphaFunc = GREATER;

		ZEnable = TRUE;
		ZWriteEnable = TRUE;
		AlphaBlendEnable = FALSE;
		CullMode = NONE;

		VertexShader = compile vs_3_0 VS_LightMapBase2();
		PixelShader = compile ps_3_0 PS_LightMapGenTest();
	}
}

technique lightmapGeneration
{
	pass p0
	{
		ZEnable = TRUE;
		ZWriteEnable = TRUE;
		AlphaBlendEnable = FALSE;
		AlphaTestEnable = FALSE;
		AlphaRef = 0;
		AlphaFunc = GREATER;
		CullMode = NONE;

		VertexShader = compile vs_3_0 VS_LightMapBase();
		PixelShader = compile ps_3_0 PS_LightMapGen();
	}
}
