//$ TL -- dbg ------------------------ 

struct VSTanOut
{
	float4 HPos : POSITION;
	float4 Diffuse : COLOR;
};


VSTanOut vsShowTanBasis(float4 Pos : POSITION, float4 Col : COLOR)
{
	VSTanOut Out;
	
  	float3 wPos = Pos;// mul(Pos, mOneBoneSkinning[0]);
 	Out.HPos = mul(float4(wPos.xyz, 1.0f), viewProjMatrix);

	Out.Diffuse = Col;
	
	return Out;
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
		AlphaBlendEnable = false;
		ColorOp[0] = SELECTARG1;
		ColorArg1[0] = DIFFUSE;
		AlphaOp[0] = SELECTARG1;
		AlphaArg1[0] = DIFFUSE;

		VertexShader = compile vs_1_1 vsShowTanBasis();		
	}
}
