#line 2 "TreeBillboard.fx"

float4x4 mViewProj : matVIEWPROJ;


bool bAlphaBlend : ALPHABLEND = true;
dword dwSrcBlend : SRCBLEND = D3DBLEND_SRCALPHA;
dword dwDestBlend : DESTBLEND = D3DBLEND_INVSRCALPHA;

bool bAlphaTest : ALPHATEST = true;
dword dwAlphaFunc : ALPHAFUNC = D3DCMP_GREATER;
dword dwAlphaRef : ALPHAREF = 0;

dword dwZEnable : ZMODE = D3DZB_TRUE;
bool bZWriteEnable : ZWRITEENABLE = false;

dword dwTexFactor : TEXFACTOR = 0;

texture texture0: TEXLAYER0;
texture texture1: TEXLAYER1;


struct APP2VS
{
    float4 Pos : POSITION;
    float4 Col : COLOR;
    float4 Col2 : COLOR;
    float2 Tex : TEXCOORD0;
    float2 Tex2 : TEXCOORD1;
};

struct VS2PS
{
    float4 Pos : POSITION;
    float4 Col : COLOR0;
    float4 Col2 : COLOR1;
    float2 Tex : TEXCOORD0;
    float2 Tex2 : TEXCOORD1;
};

VS2PS vsFFP(APP2VS indata)
{
	VS2PS outdata;
	
	outdata.Pos = mul(indata.Pos, mViewProj);
	outdata.Col = indata.Col;
	outdata.Col2 = indata.Col2;	
 	outdata.Tex = indata.Tex;
 	outdata.Tex2 = indata.Tex2;
 	
	return outdata;
}


technique QuadWithTexture
<
	int Declaration[] = 
	{
		// StreamNo, DataType, Usage, UsageIdx
		0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_POSITION, 0,
		0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 0,
		0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 1,
		0, D3DDECLTYPE_FLOAT2, D3DDECLUSAGE_TEXCOORD, 0,
		0, D3DDECLTYPE_FLOAT2, D3DDECLUSAGE_TEXCOORD, 1,
		DECLARATION_END // End macro
	};
>
{
	pass p0
	{
		// App alpha/depth settings
		AlphaBlendEnable = (bAlphaBlend);
		SrcBlend = (dwSrcBlend);
		DestBlend = (dwDestBlend);
		AlphaTestEnable = true;//(bAlphaTest);
		AlphaFunc = (dwAlphaFunc);
		AlphaRef = (dwAlphaRef);
		ZWriteEnable = (bZWriteEnable);
		// TextureFactor = (dwTexFactor);
		CullMode = NONE;
		
		Texture[0] = (texture0);
		AddressU[0] = WRAP;
		AddressV[0] = CLAMP;
		MipFilter[0] = LINEAR;
		MinFilter[0] = LINEAR;
		MagFilter[0] = LINEAR;

		Texture[1] = (texture1);
		AddressU[1] = WRAP;
		AddressV[1] = CLAMP;
		MipFilter[1] = LINEAR;
		MinFilter[1] = LINEAR;
		MagFilter[1] = LINEAR;

		VertexShader = compile vs_1_1 vsFFP();
		PixelShader = asm 
		{
			ps.1.1

			tex t0
			tex t1

			// mov r0, t0
			lrp r1, v1.a, t0, t1
			mov r0, r1
			// mul_x2 r0, r1, v0
			// mul r0.a, r1.a, v0.a
		};
	}
}

