
//
//$ TL -- dbg ------------------------ 
//

struct VSTanOut
{
	float4 HPos : POSITION;
	float4 Diffuse : COLOR;
};


VSTanOut vsShowTanBasis(float4 Pos : POSITION, float4 Col : COLOR)
{
	VSTanOut Out;

	Pos.y += 0.15;	
 	Out.HPos = mul(Pos, mViewProj);
	Out.Diffuse = Col;
	
	return Out;
}

float4 psShowTanBasis(float4 Col : COLOR) : COLOR
{
	return Col;
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
		ZEnable = true;
		ZWriteEnable = false;

		VertexShader = compile vs_1_1 vsShowTanBasis();		
		PixelShader = compile ps_1_1 psShowTanBasis();		
	}
}

dword dwStencilZFail : STENCILZFAIL = 1;
dword dwStencilPass : STENCILPASS = 1;

technique RPDirectX9DepthComplexity
{
	pass zFill
	{
		CullMode = NONE;
	
		ColorWriteEnable = 0;
		
		ZEnable = TRUE;
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;

		StencilEnable = TRUE;
		StencilFunc = ALWAYS;
		StencilFail = KEEP;
		StencilZFail = (dwStencilZFail);
		StencilPass = (dwStencilPass);
		
		VertexShader = compile vs_1_1 vsDx9_zFill();
		PixelShader = asm {
			ps.1.1
			def c0, 0, 0, 0, 0
			mov r0, c0
		};
	}
	pass detailDiffuse
	{
		ColorWriteEnable = 0;

		ZEnable = TRUE;
		ZWriteEnable = FALSE;
		ZFunc = EQUAL;
		
		StencilEnable = TRUE;
		StencilFunc = ALWAYS;
		StencilFail = KEEP;
		StencilZFail = (dwStencilZFail);
		StencilPass = (dwStencilPass);

		AlphaBlendEnable = TRUE;
		SrcBlend = ONE;
		DestBlend = ONE;

		VertexShader = compile vs_1_1 vsDx9_detailDiffuse();
		PixelShader = compile PS2_EXT psDx9_detailDiffuse();
	}
	pass detailLightmap
	{
		ColorWriteEnable = 0;

		ZEnable = TRUE;
		ZWriteEnable = FALSE;
		ZFunc = EQUAL;

		StencilEnable = TRUE;
		StencilFunc = ALWAYS;
		StencilFail = KEEP;
		StencilZFail = (dwStencilZFail);
		StencilPass = (dwStencilPass);
		
		AlphaBlendEnable = FALSE;

		VertexShader = compile vs_1_1 vsDx9_detailLightmap();
		PixelShader = compile PS2_EXT psDx9_detailLightmap();
	}
	pass fullMRT
	{	
		ColorWriteEnable = 0;

		ZEnable = TRUE;
		ZWriteEnable = FALSE;
		ZFunc = EQUAL;
		
		StencilEnable = TRUE;
		StencilFunc = ALWAYS;
		StencilFail = KEEP;
		StencilZFail = (dwStencilZFail);
		StencilPass = (dwStencilPass);

		AlphaBlendEnable = FALSE;

		VertexShader = compile vs_1_1 vsDx9_fullMRT();
		PixelShader = compile PS2_EXT psDx9_fullMRT();
	}
}
