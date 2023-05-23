
// 
// -- Detail textured techniques
//

struct APP2VS_DT_Dx9
{
    float4 Pos0 : POSITION0;
    float2 TexCoord0 : TEXCOORD0;
    float4 Pos1 : POSITION1;
    float4 MorphDelta : POSITION2;
    // float3 Tan : TANGENT;
  // float3 Bin : BINORMAL;
// float3 Normal : NORMAL;
};


struct VS2PS_DT_Dx9
{
    float4 Pos : POSITION;
    float4 Tex0And1 : TEXCOORD0;
    float4 PosTex : TEXCOORD1;
    float4 ColorAndFadeLerp : COLOR;
};

float4 psDx9_DT(VS2PS_DT_Dx9 indata) : COLOR
{
	float4 component = tex2D(sampler0Clamp, indata.Tex0And1.xy);
	float4 detailmap = tex2D(sampler1Wrap, indata.Tex0And1.zw);

	float chartcontrib = dot(vComponentsel, component);
	float4 detailcontrib = chartcontrib * detailmap;
return 1;
	return lerp(detailcontrib, chartcontrib, indata.ColorAndFadeLerp.w);
// return lerp(1.5 * detailcontrib,
	// detailcontrib,
		// indata.ColorAndFadeLerp.w);
}

VS2PS_DT_Dx9 vsDx9_DT(APP2VS_DT_Dx9 indata)
{
	VS2PS_DT_Dx9 outdata;
	
	float4 wPos;
	wPos.xz = (indata.Pos0.xy * vScaleTransXZ.xy) + vScaleTransXZ.zw;
	wPos.yw = (indata.Pos1.xw * vScaleTransY.xy) + vScaleTransY.zw;

	float cameraDist = length(wPos.xyz - vCamerapos);
float interpVal = cameraDist * vNearFarMorphLimits.x - vNearFarMorphLimits.y;
	interpVal = saturate(interpVal);
	
	wPos.y -= indata.MorphDelta.x * vScaleTransY.x * interpVal;

 	outdata.Pos = mul(wPos, mViewProj);

 	outdata.PosTex.xy = outdata.Pos.xy/outdata.Pos.w;
 	outdata.PosTex.xy = (outdata.PosTex.xy + 1) / 2;
 	outdata.PosTex.y = 1-outdata.PosTex.y;
// outdata.PosTex.xy = outdata.PosTex.xy * outdata.Pos.w;
 	outdata.PosTex.zw = outdata.Pos.zw;
 	
 	outdata.Tex0And1.xy = indata.TexCoord0;
 	outdata.Tex0And1.zw = indata.TexCoord0 * 32;
 	
	outdata.ColorAndFadeLerp.w = (-50 + length(wPos - vCamerapos)) / 140;
outdata.ColorAndFadeLerp.rgb = float3(1,0,1);

	return outdata;
}



struct VS2PS_DT2_Dx9
{
    float4 Pos : POSITION;
    float4 Tex0AndPos : TEXCOORD0;
};

float4 psDx9_DT2(VS2PS_DT2_Dx9 indata) : COLOR
{
	float4 colormap = tex2D(sampler0Clamp, indata.Tex0AndPos.xy);
	float4 lightaccum = tex2D(sampler1Clamp, indata.Tex0AndPos.zw);
return 1;
	return lightaccum * colormap;
}


VS2PS_DT2_Dx9 vsDx9_DT2(APP2VS_DT_Dx9 indata)
{
	VS2PS_DT2_Dx9 outdata;
	
	float4 wPos;
	wPos.xz = (indata.Pos0.xy * vScaleTransXZ.xy) + vScaleTransXZ.zw;
	wPos.yw = (indata.Pos1.xw * vScaleTransY.xy) + vScaleTransY.zw;

	float cameraDist = length(wPos.xyz - vCamerapos);
float interpVal = cameraDist * vNearFarMorphLimits.x - vNearFarMorphLimits.y;
	interpVal = saturate(interpVal);
	wPos.y -= indata.MorphDelta.x * vScaleTransY.x * interpVal;

 	outdata.Pos = mul(wPos, mViewProj);
	
// outdata.PosTex.xy = outdata.Pos.xy/outdata.Pos.w;
// outdata.PosTex.xy = (outdata.PosTex.xy + 1) / 2;
// outdata.PosTex.y = 1-outdata.PosTex.y;
//// outdata.PosTex.xy = outdata.PosTex.xy * outdata.Pos.w;
// outdata.PosTex.zw = outdata.Pos.zw;

 	outdata.Tex0AndPos.zw = outdata.Pos.xy/outdata.Pos.w;
 	outdata.Tex0AndPos.zw = (outdata.Tex0AndPos.zw + 1) / 2;
 	outdata.Tex0AndPos.w = 1-outdata.Tex0AndPos.w;

 	outdata.Tex0AndPos.xy = indata.TexCoord0;
 	
	return outdata;
}

technique Dx9Style_DT_States <bool Restore = true;> {
	pass BeginStates {
		CullMode = CW;
	}
	
	pass EndStates {
	}
}

technique Dx9Style_DT
{
	pass p0detailpass
	{
		AlphaBlendEnable = TRUE;
		SrcBlend = ONE;
		DestBlend = ONE;

		ZWriteEnable = FALSE;
		ZFunc = EQUAL;

		VertexShader = compile vs_1_1 vsDx9_DT();
		PixelShader = compile PS2_EXT psDx9_DT();
	}
	
	pass p1basicpass
	{
		AlphaBlendEnable = FALSE;

		VertexShader = compile vs_1_1 vsDx9_DT2();
		PixelShader = compile PS2_EXT psDx9_DT2();
	}
	
	pass p2basicpass2
	{
		AlphaBlendEnable = TRUE;
		SrcBlend = DESTCOLOR;
		DestBlend = ZERO;

		VertexShader = compile vs_1_1 vsDx9_DT2();
		PixelShader = compile PS2_EXT psDx9_DT2();
	}
}

