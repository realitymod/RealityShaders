#line 2 "PortedMenuShader.fx"

float4x4 mWorld : matWORLD;
float4x4 mView : matVIEW;
float4x4 mProj : matPROJ;

bool bAlphaBlend : ALPHABLEND = false;
dword dwSrcBlend : SRCBLEND = D3DBLEND_INVSRCALPHA;
dword dwDestBlend : DESTBLEND = D3DBLEND_SRCALPHA;

bool bAlphaTest : ALPHATEST = false;
dword dwAlphaFunc : ALPHAFUNC = D3DCMP_GREATER;
dword dwAlphaRef : ALPHAREF = 0;

dword dwZEnable : ZMODE = D3DZB_TRUE;
dword dwZFunc : ZFUNC = D3DCMP_LESSEQUAL;
bool bZWriteEnable : ZWRITEENABLE = true;

texture texture0: TEXLAYER0;
texture texture1: TEXLAYER1;

sampler sampler0Clamp = sampler_state { Texture = (texture0); AddressU = CLAMP; AddressV = CLAMP; MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = LINEAR; };
sampler sampler1Clamp = sampler_state { Texture = (texture1); AddressU = CLAMP; AddressV = CLAMP; MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = LINEAR; };
sampler sampler1Wrap = sampler_state { Texture = (texture1); AddressU = WRAP; AddressV = WRAP; MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = LINEAR; };

struct APP2VS
{
    float4 Pos : POSITION;
    float4 Col : COLOR;
    float2 Tex : TEXCOORD0;
    float2 Tex2 : TEXCOORD1;
};

struct VS2PS
{
    float4 Pos : POSITION;
    float4 Col : COLOR;
    float2 Tex : TEXCOORD0;
    float2 Tex2 : TEXCOORD1;
};

VS2PS vsFFP(APP2VS indata)
{
	VS2PS outdata;
	
	float4x4 mWVP = mWorld * mView * mProj;
	outdata.Pos = mul(indata.Pos, mWVP);
	outdata.Col = indata.Col;
 	outdata.Tex = indata.Tex;
 	outdata.Tex2 = indata.Tex2;
 	
	return outdata;
}

float4 psQuadWTexNoTex(VS2PS indata) : COLOR
{
	return indata.Col;	
}

float4 psQuadWTexOneTex(VS2PS indata) : COLOR
{
	return indata.Col * tex2D(sampler0Clamp, indata.Tex);
}

float4 psQuadWTexOneTexMasked(VS2PS indata) : COLOR
{
	float4 outcol = indata.Col * tex2D(sampler0Clamp, indata.Tex);
// outcol *= tex2D(sampler1Clamp, indata.Tex2);
	outcol.a *= tex2D(sampler1Clamp, indata.Tex2).a;
	return outcol;
}

technique Menu{pass{}}
technique Menu_States <bool Restore = true;> {
	pass BeginStates {
	}
	
	pass EndStates {
	}
}

technique QuadWithTexture
<
	int Declaration[] = 
	{
		// StreamNo, DataType, Usage, UsageIdx
		0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_POSITION, 0,
		0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 0,
		0, D3DDECLTYPE_FLOAT2, D3DDECLUSAGE_TEXCOORD, 0,
		0, D3DDECLTYPE_FLOAT2, D3DDECLUSAGE_TEXCOORD, 1,
		DECLARATION_END // End macro
	};
>
{
	pass notex
	{
		// App alpha/depth settings
		AlphaBlendEnable = (bAlphaBlend);
		SrcBlend = (dwSrcBlend);
		DestBlend = (dwDestBlend);
		AlphaTestEnable = (bAlphaTest);
		AlphaFunc = (dwAlphaFunc);
		AlphaRef = (dwAlphaRef);
		ZEnable = (dwZEnable);
		ZFunc = (dwZFunc);
		ZWriteEnable = (bZWriteEnable);
		
		VertexShader = compile vs_1_1 vsFFP();
		PixelShader = compile ps_1_1 psQuadWTexNoTex();
	}
	
	pass tex
	{
		// App alpha/depth settings
		AlphaBlendEnable = (bAlphaBlend);
		SrcBlend = (dwSrcBlend);
		DestBlend = (dwDestBlend);
		AlphaTestEnable = (bAlphaTest);
		AlphaFunc = (dwAlphaFunc);
		AlphaRef = (dwAlphaRef);
		ZEnable = (dwZEnable);
		ZFunc = (dwZFunc);
		ZWriteEnable = (bZWriteEnable);
		
		VertexShader = compile vs_1_1 vsFFP();
		PixelShader = compile ps_1_1 psQuadWTexOneTex();
	}
	
	pass masked
	{
		// App alpha/depth settings
		AlphaBlendEnable = (bAlphaBlend);
		SrcBlend = (dwSrcBlend);
		DestBlend = (dwDestBlend);
		AlphaTestEnable = (bAlphaTest);
		AlphaFunc = (dwAlphaFunc);
		AlphaRef = (dwAlphaRef);
		ZEnable = (dwZEnable);
		ZFunc = (dwZFunc);
		ZWriteEnable = (bZWriteEnable);
		
		VertexShader = compile vs_1_1 vsFFP();
		PixelShader = compile ps_1_4 psQuadWTexOneTexMasked();
	}
}

technique QuadCache
<
	int Declaration[] = 
	{
		// StreamNo, DataType, Usage, UsageIdx
		0, D3DDECLTYPE_FLOAT4, D3DDECLUSAGE_POSITION, 0,
		0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 0,
		0, D3DDECLTYPE_FLOAT2, D3DDECLUSAGE_TEXCOORD, 0,
		0, D3DDECLTYPE_FLOAT2, D3DDECLUSAGE_TEXCOORD, 1,
		DECLARATION_END // End macro
	};
>
{
	pass p0
	{
		AlphaBlendEnable = FALSE;
		AlphaTestEnable = TRUE;
		AlphaFunc = GREATER;
		AlphaRef = 0;
		ZEnable = TRUE;
		ZFunc = LESS;
		ZWriteEnable = TRUE;
		TextureFactor = 0xFFFFFFFF;
		
		// App pixel settings
		ColorOp[0] = ADD;
		ColorArg1[0] = TEXTURE;
		ColorArg2[0] = TFACTOR;
		ColorOp[1] = MODULATE;
		ColorArg1[1] = CURRENT;
		ColorArg2[1] = DIFFUSE;
		ColorOp[2] = DISABLE;
		AlphaOp[0] = ADD;
		AlphaArg1[0] = TEXTURE;
		AlphaArg2[0] = TFACTOR;
		AlphaOp[1] = MODULATE;
		AlphaArg1[1] = CURRENT;
		AlphaArg2[1] = DIFFUSE;
		AlphaOp[2] = DISABLE;

		Texture[0] = (texture0);
		AddressU[0] = CLAMP;
		AddressV[0] = CLAMP;
		MipFilter[0] = LINEAR;
		MinFilter[0] = LINEAR;
		MagFilter[0] = LINEAR;

		VertexShader = compile vs_1_1 vsFFP();
		PixelShader = NULL;
	}
}
