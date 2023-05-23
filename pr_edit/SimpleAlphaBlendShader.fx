float4x4 mWorldViewProj : WorldViewProjection;

texture basetex: TEXLAYER0
<
	 string File = "aniso2.dds";
	 string TextureType = "2D";
>;

struct APP2VS
{
    float4 Pos : POSITION;    
    float2 Tex0 : TEXCOORD0;
};

struct VS2PS
{
    float4 HPos : POSITION;
    float2 Tex0 : TEXCOORD0;
};

sampler diffuseSampler = sampler_state
{
	Texture = <basetex>;
	// Target = Texture2D;
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
    AddressU = Wrap;
    AddressV = Wrap;
};

VS2PS VShader(APP2VS indata, 
	uniform float4x4 wvp)
{
	VS2PS outdata;
 
	outdata.HPos = mul(float4(indata.Pos.xyz, 1.0f), wvp);
	outdata.Tex0 = indata.Tex0;

	return outdata;
}

technique t0_States <bool Restore = true;> {
	pass BeginStates {
		ZEnable = true;
		// MatsD 030903: Due to transparent isn't sorted yet. Write Z values
		ZWriteEnable = true;
		
		CullMode = None;
		AlphaBlendEnable = true;
		SrcBlend = ONE;
		DestBlend = ONE;
		// SrcBlend = SRCALPHA;
		// DestBlend = INVSRCALPHA;
	}
	
	pass EndStates {
	}
}

technique t0
{
	pass p0 
	{
		VertexShader = compile vs_1_1 VShader(mWorldViewProj);

		Sampler[0] = <diffuseSampler>;	

		ColorOp[0] = SelectArg1;
		ColorArg1[0] = Texture;
		ColorArg2[0] = Current;
		AlphaOp[0] = SelectArg1;
		AlphaArg1[0] = Texture;

		ColorOp[1] = Disable;
		AlphaOp[1] = Disable;
	}
}

/*technique marked
{
	pass p0
	{
		CullMode = NONE;
		AlphaBlendEnable = FALSE;
	    Lighting = TRUE;
	
		VertexShader = compile vs_1_1 VShader(mWorldViewProj,MaterialAmbient,MaterialDiffuse,LhtDir);
		PixelShader = compile ps_1_1 PShaderMarked(samplebase);
	}
}*/
