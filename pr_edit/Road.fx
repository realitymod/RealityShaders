#line 2 "Road.fx"
#include "shaders/raCommon.fx"

float4x4 mWorldViewProj : WorldViewProjection;
float4 vView : ViewPos;
float4 vDiffuse : DiffuseColor;
float fBlendFactor : BlendFactor;
float fMaterial : Material;

float4 fogColor : FogColor;

texture detail0: TEXLAYER0;
texture detail1: TEXLAYER1;
// texture lightmap: LightMap;

sampler sampler0 = sampler_state
{
	Texture = (detail0);
	AddressU = CLAMP;
	AddressV = WRAP;
	MinFilter = ANISOTROPIC;
	MagFilter = LINEAR;
	MipFilter = LINEAR;
	MaxAnisotropy = 8;
};
sampler sampler1 = sampler_state
{
	Texture = (detail1);
	AddressU = WRAP;
	AddressV = WRAP;
	MinFilter = ANISOTROPIC;
	MagFilter = LINEAR;
	MipFilter = LINEAR;
	MaxAnisotropy = 8;
};
// sampler sampler2 = sampler_state
//{
// Texture = (lightmap);
// AddressU = CLAMP;
// AddressV = CLAMP;
// MinFilter = POINT;
// MagFilter = POINT;
// MipFilter = NONE;
//};

struct VS2PS
{
    float4 Pos : POSITION;
    float2 Tex0 : TEXCOORD0;
    float2 Tex1 : TEXCOORD1;
    float2 Tex2 : TEXCOORD2;
    float2 Alpha : TEXCOORD3;
    float Fog : FOG;
};

VS2PS RoadEditableVS(float4 Pos : POSITION, float2 Tex0 : TEXCOORD0, float2 Tex1 : TEXCOORD1, float Alpha : TEXCOORD2)
{
	VS2PS outdata;
	Pos.y +=  0.01;
	outdata.Pos = mul(Pos, mWorldViewProj);
	outdata.Tex0 = Tex0;
	outdata.Tex1 = Tex1;
	outdata.Tex2 = Tex1+Tex0;
	outdata.Alpha = Alpha;

 	outdata.Fog = saturate(calcFog(outdata.Pos.w));
	
	return outdata;
}

float4 RoadEditablePS(VS2PS indata) : COLOR0
{
	float4 tex0 = tex2D(sampler0, indata.Tex0);
	float4 tex1 = tex2D(sampler1, indata.Tex1);

	float4 outcolor;
	outcolor.rgb = lerp(tex1.rgb, tex0.rgb, saturate(fBlendFactor));
	outcolor.a = tex0.a;

	outcolor.a *= indata.Alpha;
	
	return outcolor;
}



struct VS2PS_dm
{
    float4 Pos : POSITION;
// float2 Tex0 : TEXCOORD0;
};

VS2PS_dm RoadEditableVS_dm(float4 Pos : POSITION, float2 Tex0 : TEXCOORD0, float2 Tex1 : TEXCOORD1)
{
	VS2PS_dm outdata;
	outdata.Pos = mul(Pos, mWorldViewProj);
// outdata.Tex0 = Tex0;
	
	return outdata;
}

float4 RoadEditablePS_dm(VS2PS_dm indata) : COLOR0
{
	float4 col;
	col.rgb = fMaterial;
	col.a = 1;
	return col;
}



technique roadeditable
<
	int DetailLevel = DLHigh+DLNormal+DLLow+DLAbysmal;
	int Compatibility = CMPR300+CMPNV2X;
	int Declaration[] = 
	{
		// StreamNo, DataType, Usage, UsageIdx
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_POSITION, 0 },
// { 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_NORMAL, 0 },
		{ 0, D3DDECLTYPE_FLOAT2, D3DDECLUSAGE_TEXCOORD, 0 },
		{ 0, D3DDECLTYPE_FLOAT2, D3DDECLUSAGE_TEXCOORD, 1 },
		{ 0, D3DDECLTYPE_FLOAT1, D3DDECLUSAGE_TEXCOORD, 2 },
		DECLARATION_END // End macro
	};
>
{
	pass p0
	{
		// CullMode = CCW;
		// CullMode = NONE;
		AlphaBlendEnable = true;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;
		FogEnable = FALSE;
		// ZEnable = FALSE;
		// FillMode = WIREFRAME;
// DepthBias = -0.0001f;
// SlopeScaleDepthBias = -0.00001f;
		// ColorWriteEnable = 0;
		ZEnable = TRUE;
		ZWriteEnable = FALSE;
		FogEnable = true;		


		VertexShader = compile vs_1_1 RoadEditableVS();
		PixelShader = compile ps_1_4 RoadEditablePS();
	}

	pass p1 // draw material
	{
		// CullMode = CCW;
		// CullMode = NONE;
		AlphaBlendEnable = true;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;
		// ZEnable = FALSE;
		// FillMode = WIREFRAME;
		DepthBias = -0.0001f;
		SlopeScaleDepthBias = -0.00001f;
		// ColorWriteEnable = 0;
		ZEnable = TRUE;
		ZWriteEnable = FALSE;

		VertexShader = compile vs_1_1 RoadEditableVS_dm();
		PixelShader = compile ps_1_4 RoadEditablePS_dm();
	}

	
}



technique projectroad
<
	int Declaration[] = 
	{
		// StreamNo, DataType, Usage, UsageIdx
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_POSITION, 0 },
		DECLARATION_END // End macro
	};
>
{
	pass p0
	{
		CullMode = NONE;
		// ShadeMode = FLAT;
// DitherEnable = FALSE;
		// FillMode = WIREFRAME;
		ZEnable = FALSE;
		AlphaBlendEnable = false;
		FogEnable = false;
				
		VertexShader = asm
		{
			vs.1.1
			
			dcl_position0 v0
			
			add r0.xyz, v0.xzw, -c[0].xyz
			mul r0.xyz, r0.xyz, c[1].xyw // z = 0, w = 1
			add oPos.x, r0.x, -c[1].w
			add oPos.y, r0.y, -c[1].w
			mov oPos.z, r0.z
			mov oPos.w, c[1].w // z = 0, w = 1
			add r1, v0.y, -c[2].x
			mul oD0, r1, c[2].y
			mov oD0.a, c[1].z // z = 0
		};
				
		PixelShader = asm
		{
			ps.1.1
			mov r0, v0
		};
	}
}
