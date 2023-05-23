float4x4 mWorldViewProj : WorldViewProjection;
bool zbuffer : ZBUFFER;

// string Category = "Effects\\Lighting";

struct APP2VS
{
    float4 Pos : POSITION;    
    float4 Diffuse : COLOR;
};

struct VS2PS
{
    float4 Pos : POSITION;
    float4 Diffuse : COLOR;
};

struct PS2FB
{
	float4 Col : COLOR;
};


VS2PS VShader(APP2VS indata, 
	uniform float4x4 wvp)
{
	VS2PS outdata;
 

	outdata.Pos = mul(float4(indata.Pos.xyz, 1.0f), wvp);

	
    	outdata.Diffuse.xyz = indata.Diffuse.xyz;
    	outdata.Diffuse.w = 0.8f;// indata.Diffuse.w;
 	 	
 	return outdata;
}

PS2FB PShader(VS2PS indata)
{
	PS2FB outdata;
	outdata.Col = indata.Diffuse;
	
	return outdata;
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
		DECLARATION_END // End macro
	};
>
{
	pass p0
	{
		/*CullMode = NONE;
		AlphaBlendEnable = TRUE;
		// FillMode = WIREFRAME;
		// ColorWriteEnable = 0;
 		ZWriteEnable = 0;
 		ZEnable = TRUE;*/

		CullMode = NONE;
		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;
		// FillMode = WIREFRAME;
		// ColorWriteEnable = 0;
		DepthBias=-0.00001;
		ZWriteEnable = 1;
		// float zbuffe = TRUE;
		ZEnable = FALSE;// TRUE;
		ShadeMode = FLAT;
		ZFunc = LESSEQUAL;
	
		VertexShader = compile vs_1_1 VShader(mWorldViewProj);
		PixelShader = compile ps_1_1 PShader();
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
		DECLARATION_END // End macro
	};
>
{
	pass p0
	{
		CullMode = NONE;
		AlphaBlendEnable = FALSE;
 		ZWriteEnable = 1;
 		ZEnable = TRUE;
			
		VertexShader = compile vs_1_1 VShader(mWorldViewProj);
		PixelShader = compile ps_1_1 PShader();
	}
}



