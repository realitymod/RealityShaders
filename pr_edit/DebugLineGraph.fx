
float2 graphPos : GRAPHSIZE;
float2 viewportSize : VIEWPORTSIZE;

struct APP2VS
{
    float2 scrPos : POSITION;
    float4 col : COLOR;
};


struct VS2PS
{
    float4 hPos : POSITION;
    float4 col : COLOR;
};

VS2PS vs(APP2VS indata)
{
	VS2PS outdata;

	float2 scrPos = indata.scrPos + graphPos;
	scrPos.x = scrPos.x/(viewportSize.x/2)-1;
	scrPos.y = -(scrPos.y/(viewportSize.y/2)-1);

	outdata.hPos.xy = scrPos;
	outdata.hPos.z = 0.001;
	outdata.hPos.w = 1;
	outdata.col = indata.col;
	return outdata;
}

float4 ps(VS2PS indata) : COLOR
{
	return indata.col;
}

technique Graph <
	int Declaration[] = 
	{
		// StreamNo, DataType, Usage, UsageIdx
		0, D3DDECLTYPE_FLOAT2, D3DDECLUSAGE_POSITION, 0,
		0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 0,
		DECLARATION_END // End macro
	};
>
{
	pass p0
	{
		ZEnable = FALSE;

		VertexShader = compile vs_1_1 vs();
		PixelShader = compile ps_1_1 ps();
	}
}
