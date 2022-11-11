
/*
	Description: Renders circle for debug shaders
*/

#include "shaders/RealityGraphics.fxh"

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
	float4 Diffuse : COLOR;
};

VS2PS Debug_Circle_VS(APP2VS Input)
{
	VS2PS Output;
	Output.HPos = mul(float4(Input.Pos.xyz, 1.0f), _WorldViewProj);
	Output.Diffuse.xyz = Input.Diffuse.xyz;
	Output.Diffuse.w = 0.8f;
	return Output;
}

float4 Debug_Circle_PS(VS2PS Input) : COLOR
{
	return Input.Diffuse;
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
	pass Pass0
	{
		CullMode = NONE;
		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;
		DepthBias = -0.00001;
		ZWriteEnable = 1;
		ZEnable = FALSE;
		ShadeMode = FLAT;
		ZFunc = LESSEQUAL;

		VertexShader = compile vs_3_0 Debug_Circle_VS();
		PixelShader = compile ps_3_0 Debug_Circle_PS();
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
	pass Pass0
	{
		CullMode = NONE;
		AlphaBlendEnable = FALSE;
		ZWriteEnable = 1;
		ZEnable = TRUE;

		VertexShader = compile vs_3_0 Debug_Circle_VS();
		PixelShader = compile ps_3_0 Debug_Circle_PS();
	}
}
