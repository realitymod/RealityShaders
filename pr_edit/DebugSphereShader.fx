float4x4 mWorldViewProj : WorldViewProjection;
float4x4 world : World;

string Category = "Effects\\Lighting";

float4 LhtDir = {1.0f, 0.0f, 0.0f, 1.0f};    // light Direction 
float4 lightDiffuse = {1.0f, 1.0f, 1.0f, 1.0f}; // Light Diffuse
float4 MaterialAmbient : MATERIALAMBIENT = {0.5f, 0.5f, 0.5f, 1.0f};
float4 MaterialDiffuse : MATERIALDIFFUSE = {1.0f, 1.0f, 1.0f, 1.0f};

texture basetex: TEXLAYER0
<
	 string File = "aniso2.dds";
	 string TextureType = "2D";
>;

sampler2D samplebase = sampler_state
{
	Texture = <basetex>;
	MipFilter = LINEAR;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
};


struct APP2VS
{
    float4 Pos : POSITION;    
    float3 Normal : NORMAL;
    float2 TexCoord0 : TEXCOORD0;
};

struct VS2PS
{
    float4 Pos : POSITION;
    float4 Diffuse : COLOR;
    float2 Tex0 : TEXCOORD0;
};

struct PS2FB
{
	float4 Col : COLOR;
};

float3 Diffuse(float3 Normal,uniform float4 lhtDir)
{
    float CosTheta;
    
    // N.L Clamped
    CosTheta = max(0.0f, dot(Normal, lhtDir.xyz));
       
    // propogate float result to vector
    return (CosTheta);
}

VS2PS VShader(APP2VS indata, 
	uniform float4x4 wvp, 
	uniform float4 materialAmbient, 
	uniform float4 materialDiffuse,
	uniform float4 lhtDir)
{
	VS2PS outdata;
 
	// float4 Po = float4(indata.Pos.x,indata.Pos.y,indata.Pos.z,1.0);
	// outdata.Pos = mul(wvp, Po);
	// outdata.Pos = mul(float4(indata.Pos.xyz, 1.0f), wvp);
 	float3 Pos;
 	Pos = mul(indata.Pos, world);
	outdata.Pos = mul(float4(Pos.xyz, 1.0f), wvp);
	
	// Lighting. Shade (Ambient + etc.)
    outdata.Diffuse.xyz = materialAmbient.xyz + Diffuse(indata.Normal,lhtDir) * materialDiffuse.xyz;
    outdata.Diffuse.w = 1.0f;
 	 	
 	outdata.Tex0 = indata.TexCoord0;
 	
	return outdata;
}

PS2FB PShader(VS2PS indata,
	uniform sampler2D colorMap)
{
	PS2FB outdata;
	
	float4 base = tex2D(colorMap, indata.Tex0);
	outdata.Col = indata.Diffuse * base;
	
	return outdata;
}

PS2FB PShaderMarked(VS2PS indata,
	uniform sampler2D colorMap)
{
	PS2FB outdata;
	
	float4 base = tex2D(colorMap, indata.Tex0);
	outdata.Col = (indata.Diffuse * base)+float4(1.f,0.f,0.f,0.f);
	
	return outdata;
}


technique t0_States <bool Restore = false;> {
	pass BeginStates 
	{
		CullMode = NONE;
	}
	pass EndStates 
	{
		CullMode = CCW;
	}
}

technique t0
<
	int Declaration[] = 
	{
		// StreamNo, DataType, Usage, UsageIdx
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_POSITION, 0 },
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_NORMAL, 0 },
		{ 0, D3DDECLTYPE_FLOAT2, D3DDECLUSAGE_TEXCOORD, 0 },
		DECLARATION_END // End macro
	};

>
{
	pass p0
	{
		VertexShader = compile vs_1_1 VShader(mWorldViewProj,MaterialAmbient,MaterialDiffuse,LhtDir);
		PixelShader = compile ps_1_1 PShader(samplebase);
	}
}



technique marked
<
	int DetailLevel = DLHigh+DLNormal+DLLow+DLAbysmal;
	int Compatibility = CMPR300+CMPNV2X;
	int Declaration[] = 
	{
		// StreamNo, DataType, Usage, UsageIdx
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_POSITION, 0 },
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_NORMAL, 0 },
		{ 0, D3DDECLTYPE_FLOAT2, D3DDECLUSAGE_TEXCOORD, 0 },
		DECLARATION_END // End macro
	};
>
{
	pass p0
	{
		CullMode = NONE;
		AlphaBlendEnable = FALSE;
	
		VertexShader = compile vs_1_1 VShader(mWorldViewProj,MaterialAmbient,MaterialDiffuse,LhtDir);
		PixelShader = compile ps_1_1 PShaderMarked(samplebase);
	}
}

VS2PS vsLightSource(APP2VS indata, 
	uniform float4x4 wvp, 
	uniform float4 materialDiffuse)
{
	VS2PS outdata;
 
 	float4 Pos;
 	Pos.xyz = mul(indata.Pos, world);
 	Pos.w = 1;
	outdata.Pos = mul(Pos, wvp);
	
	// Lighting. Shade (Ambient + etc.)
	outdata.Diffuse.rgb = materialDiffuse.xyz;
	outdata.Diffuse.a = materialDiffuse.w;
 	 	
	outdata.Tex0 = 0;

	return outdata;
}

float4 psLightSource(VS2PS indata) : COLOR
{
	return indata.Diffuse;
}

technique lightsource
<
	int Declaration[] = 
	{
		// StreamNo, DataType, Usage, UsageIdx
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_POSITION, 0 },
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_NORMAL, 0 },
		DECLARATION_END // End macro
	};
>
{
	pass p0
	{
		CullMode = NONE;
		ColorWriteEnable = 0;
		AlphaBlendEnable = FALSE;

		ZFunc = LESSEQUAL;
		ZWriteEnable = TRUE;

		VertexShader = compile vs_1_1 vsLightSource(mWorldViewProj, MaterialDiffuse);
		PixelShader = compile ps_1_1 psLightSource();
	}
	pass p1
	{
		ColorWriteEnable = Red|Blue|Green|Alpha;
		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;
		
		ZFunc = EQUAL;
		ZWriteEnable = FALSE;
	
		VertexShader = compile vs_1_1 vsLightSource(mWorldViewProj, MaterialDiffuse);
		PixelShader = compile ps_1_1 psLightSource();
	}
}

technique editor
<
	int Declaration[] = 
	{
		// StreamNo, DataType, Usage, UsageIdx
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_POSITION, 0 },
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_NORMAL, 0 },
		DECLARATION_END // End macro
	};
>
{
	pass p0
	{
		CullMode = NONE;
		ColorWriteEnable = 0;
		AlphaBlendEnable = FALSE;

		ZFunc = LESSEQUAL;
		ZWriteEnable = TRUE;

		VertexShader = compile vs_1_1 vsLightSource(mWorldViewProj, MaterialDiffuse);
		PixelShader = compile ps_1_1 psLightSource();
	}
	pass p1
	{
		ColorWriteEnable = Red|Blue|Green|Alpha;
		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;
		
		ZFunc = EQUAL;
		ZWriteEnable = FALSE;
		
		VertexShader = compile vs_1_1 vsLightSource(mWorldViewProj, MaterialDiffuse);
		PixelShader = compile ps_1_1 psLightSource();
	}
}

technique EditorDebug
{
	pass p0
	{
		CullMode = NONE;
		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;
		ZWriteEnable = 1;
		ZEnable = TRUE;
		ShadeMode = FLAT;
		ZFunc = LESSEQUAL;
		FillMode = SOLID;
		
		VertexShader = compile vs_1_1 vsLightSource(mWorldViewProj, MaterialDiffuse);
		PixelShader = compile ps_1_1 psLightSource();
	}
}