#line 2 "TerrainUGShader.fx"
#include "shaders/datatypes.fx"


float4x4 mViewProj: matVIEWPROJ;
float4x4 mLightVP : LIGHTVIEWPROJ;
float4 vScaleTransXZ : SCALETRANSXZ;
float4 vScaleTransY : SCALETRANSY;
float4 vShadowTexCoordScaleAndOffset : SHADOWTEXCOORDSCALEANDOFFSET;
float4 vViewportMap : VIEWPORTMAP;

texture texture2 : TEXLAYER2;

sampler sampler2Point = sampler_state { Texture = (texture2); MinFilter = POINT; MagFilter = POINT; };

struct APP2VS_BM_Dx9
{
    float4 Pos0 : POSITION0;
    float4 Pos1 : POSITION1;
    float4 MorphDelta : POSITION2;
    float2 TexCoord0 : TEXCOORD0;
    float3 Normal : NORMAL;
};

struct VS2PS_DynamicShadowmap
{
    float4 Pos : POSITION;
    float4 ShadowTex : TEXCOORD1;
};


float4 psDynamicShadowmap(VS2PS_DynamicShadowmap indata) : COLOR
{
	float2 texel = float2(1.0/1024.0, 1.0/1024.0);
	float4 samples;
	indata.ShadowTex.xy = clamp(indata.ShadowTex.xy, vViewportMap.xy, vViewportMap.zw);
	samples.x = tex2D(sampler2Point, indata.ShadowTex);
	samples.y = tex2D(sampler2Point, indata.ShadowTex + float2(texel.x, 0));
	samples.z = tex2D(sampler2Point, indata.ShadowTex + float2(0, texel.y));
	samples.w = tex2D(sampler2Point, indata.ShadowTex + texel);

	float4 cmpbits = samples >= saturate(indata.ShadowTex.z);
	float avgShadowValue = dot(cmpbits, float4(0.25, 0.25, 0.25, 0.25));

	return 1-saturate(4-indata.ShadowTex.z)+avgShadowValue.x;
}

VS2PS_DynamicShadowmap vsDynamicShadowmap(APP2VS_BM_Dx9 indata)
{
	VS2PS_DynamicShadowmap outdata;
	
	float4 wPos;
	wPos.xz = (indata.Pos0.xy * vScaleTransXZ.xy) + vScaleTransXZ.zw;
	wPos.yw = (indata.Pos1.xw * vScaleTransY.xy) + vScaleTransY.zw;

 	outdata.Pos = mul(wPos, mViewProj);

	outdata.ShadowTex = mul(wPos, mLightVP);
	outdata.ShadowTex.z -= 0.007;

	return outdata;
}

technique Dx9Style_BM
{
	pass DynamicShadowmap // p0
	{
		CullMode = CW;
		// ColorWriteEnable = RED|BLUE|GREEN|ALPHA;
		
		ZEnable = FALSE;
		ZWriteEnable = FALSE;
		ZFunc = LESSEQUAL;
		
 		AlphaBlendEnable = TRUE;
 		SrcBlend = DESTCOLOR;
 		DestBlend = ZERO;
 		
		VertexShader = compile vs_1_1 vsDynamicShadowmap();
		PixelShader = compile PS2_EXT psDynamicShadowmap();
	}
}

