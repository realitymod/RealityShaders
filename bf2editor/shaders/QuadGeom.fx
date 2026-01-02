#line 2 "QuadGeom.fx"

/*
    Renders a simple textured quad.
*/

texture Tex0: TEXLAYER0;

sampler SampleTex0 = sampler_state
{
	Texture = (Tex0);
	MipFilter = POINT;
	MinFilter = POINT;
	MagFilter = POINT;
	AddressU = CLAMP;
	AddressV = CLAMP;
};

struct APP2VS
{
	float2 Pos : POSITION;
};

struct VS2PS
{
	float4 Pos : POSITION;
	float2 Tex0 : TEXCOORD0;
};

VS2PS VS_Quad(APP2VS Input)
{
	VS2PS Output = (VS2PS)0;

	Output.Pos = float4(Input.Pos.xy, 0.0, 1.0);
 	Output.Tex0.x = 0.5 * (Input.Pos.x + 1.0);
 	Output.Tex0.y = 1.0 - (0.5 * (Input.Pos.y + 1.0));

	return Output;
}

float4 PS_Quad(VS2PS Input) : COLOR0
{
	return tex2D(SampleTex0, Input.Tex0);
}

technique TexturedQuad
<
	int Declaration[] =
	{
		// StreamNo, DataType, Usage, UsageIdx
		0, D3DDECLTYPE_FLOAT2, D3DDECLUSAGE_POSITION, 0,
		DECLARATION_END // End macro
	};
>
{
	pass p0
	{
		// App alpha/depth settings
		CullMode = NONE;
		ZEnable = TRUE;
		ZFunc = ALWAYS;
		ZWriteEnable = TRUE;

		// SET UP STENCIL TO ONLY WRITE WHERE STENCIL IS SET TO ZERO
		StencilEnable = TRUE; // FALSE;
		StencilFunc = EQUAL; // ALWAYS;
		StencilPass = ZERO; // ZERO;
		StencilRef = 0; // 0;

		VertexShader = compile vs_3_0 VS_Quad();
		PixelShader = compile ps_3_0 PS_Quad();
	}
}