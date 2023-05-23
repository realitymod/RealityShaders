#line 2 "RoadCompiled.fx"
#include "shaders/raCommon.fx"

float4x4 mWorldViewProj : WorldViewProjection;
float fTexBlendFactor : TexBlendFactor;
float2 vFadeoutValues : FadeOut;
float4 vLocalEyePos : LocalEye;
float4 vCameraPos : CAMERAPOS;
float vScaleY : SCALEY;
float4 vSunColor : SUNCOLOR;
float4 vGIColor : GICOLOR;

texture detail0 : TEXLAYER3;
texture detail1 : TEXLAYER4;
texture lighting : TEXLAYER2;

sampler sampler0 = sampler_state
{
	Texture = (detail0);
	AddressU = CLAMP;
	AddressV = WRAP;
	MipFilter = FILTER_ROAD_MIP;
	MinFilter = FILTER_ROAD_DIFF_MIN;
	MagFilter = FILTER_ROAD_DIFF_MAG;
#ifdef FILTER_ROAD_DIFF_MAX_ANISOTROPY
	MaxAnisotropy = FILTER_ROAD_DIFF_MAX_ANISOTROPY;
#endif
};
sampler sampler1 = sampler_state
{
	Texture = (detail1);
	AddressU = WRAP;
	AddressV = WRAP;
	MipFilter = FILTER_ROAD_MIP;
	MinFilter = FILTER_ROAD_DIFF_MIN;
	MagFilter = FILTER_ROAD_DIFF_MAG;
#ifdef FILTER_ROAD_DIFF_MAX_ANISOTROPY
	MaxAnisotropy = FILTER_ROAD_DIFF_MAX_ANISOTROPY;
#endif
};
sampler sampler2 = sampler_state
{
	Texture = (lighting);
	AddressU = CLAMP;
	AddressV = CLAMP;
	MinFilter = POINT;
	MagFilter = POINT;
	MipFilter = NONE;
};
struct APP2VS
{
	float4 Pos : POSITION;
	float2 Tex0 : TEXCOORD0;
	float2 Tex1 : TEXCOORD1;
// float4 MorphDelta: POSITION1;
	float Alpha : TEXCOORD2;
};

struct VS2PS
{
    float4 Pos : POSITION;
    float3 Tex0AndZFade : TEXCOORD0;
    float2 Tex1 : TEXCOORD1;
    float4 PosTex : TEXCOORD2;
    float Fog : FOG;
};

VS2PS RoadCompiledVS(APP2VS input)
{
	VS2PS outdata;

	float4 wPos = input.Pos;
	
	float cameraDist = length(vLocalEyePos - input.Pos);
	float interpVal = saturate(cameraDist * vFadeoutValues.x - vFadeoutValues.y);
// wPos.y += 0.01 * (1-interpVal);
	wPos.y += .01;
	
	outdata.Pos = mul(wPos, mWorldViewProj);

	
	outdata.PosTex.xy = outdata.Pos.xy/outdata.Pos.w;
 	outdata.PosTex.xy = (outdata.PosTex.xy + 1) / 2;
 	outdata.PosTex.y = 1-outdata.PosTex.y;
 	outdata.PosTex.xy = outdata.PosTex.xy * outdata.Pos.w;
	outdata.PosTex.zw = outdata.Pos.zw;
	
	outdata.Tex0AndZFade.xy = input.Tex0;
	outdata.Tex1 = input.Tex1;
	
	outdata.Tex0AndZFade.z = 1 - saturate((cameraDist * vFadeoutValues.x) - vFadeoutValues.y);
	outdata.Tex0AndZFade.z *= input.Alpha;
	
	outdata.Fog = calcFog(outdata.Pos.w);
	
	return outdata;
}

float4 RoadCompiledPS(VS2PS indata) : COLOR0
{
// return 0;
// return float4(indata.Tex0AndZFade.z, 0, 0, 1);
	
	float4 t0 = tex2D(sampler0, indata.Tex0AndZFade);
	float4 t1 = tex2D(sampler1, indata.Tex1*0.1);
	float4 accumlights = tex2Dproj(sampler2, indata.PosTex);
	float4 light = ((accumlights.w * vSunColor*2) + accumlights)*2;
	
	float4 final;
	final.rgb = lerp(t1, t0, fTexBlendFactor);
	final.a = t0.a * indata.Tex0AndZFade.z;
	
	final.rgb *= light.xyz;

	return final;
}

struct VS2PSDx9
{
    float4 Pos : POSITION;
    float3 Tex0AndZFade : TEXCOORD0;
    float2 Tex1 : TEXCOORD1;
};

VS2PSDx9 RoadCompiledVSDx9(APP2VS input)
{
	VS2PSDx9 outdata;
	outdata.Pos = mul(input.Pos, mWorldViewProj);
		
	outdata.Tex0AndZFade.xy = input.Tex0;
	outdata.Tex1 = input.Tex1;
	
	float3 dist = (vLocalEyePos - input.Pos);
	outdata.Tex0AndZFade.z = dot(dist, dist);
	outdata.Tex0AndZFade.z = (outdata.Tex0AndZFade.z - vFadeoutValues.x) * vFadeoutValues.y;
	outdata.Tex0AndZFade.z = 1 - saturate(outdata.Tex0AndZFade.z);
	
	return outdata;
}

float4 RoadCompiledPSDx9(VS2PSDx9 indata) : COLOR0
{
	float4 t0 = tex2D(sampler0, indata.Tex0AndZFade);
	float4 t1 = tex2D(sampler1, indata.Tex1);

	float4 final;
	final.rgb = lerp(t1, t0, fTexBlendFactor);
	final.a = t0.a * indata.Tex0AndZFade.z;
	return final;
}

technique roadcompiledFull
<
	int DetailLevel = DLHigh+DLNormal+DLLow+DLAbysmal;
	int Compatibility = CMPR300+CMPNV2X;
	int Declaration[] = 
	{
		// StreamNo, DataType, Usage, UsageIdx
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_POSITION, 0 },
		{ 0, D3DDECLTYPE_FLOAT2, D3DDECLUSAGE_TEXCOORD, 0 },
		{ 0, D3DDECLTYPE_FLOAT2, D3DDECLUSAGE_TEXCOORD, 1 },
// { 0, D3DDECLTYPE_FLOAT4, D3DDECLUSAGE_POSITION, 1 },
		{ 0, D3DDECLTYPE_FLOAT1, D3DDECLUSAGE_TEXCOORD, 2 },
		DECLARATION_END // End macro
	};
	int TechniqueStates = D3DXFX_DONOTSAVESHADERSTATE;
>
{
	pass NV3x
	{
		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;
// DepthBias = -0.0001f;
// SlopeScaleDepthBias = -0.00001f;
// FillMode = WIREFRAME;
		ZEnable = TRUE;
		ZWriteEnable = FALSE;
		FogEnable = true;
		VertexShader = compile vs_1_1 RoadCompiledVS();
		PixelShader = compile ps_1_4 RoadCompiledPS();
	}

	pass DirectX9
	{
		AlphaBlendEnable = FALSE;
		// AlphaBlendEnable = TRUE;
		// SrcBlend = SRCALPHA;
		// DestBlend = INVSRCALPHA;
		DepthBias = -0.0001f;
		SlopeScaleDepthBias = -0.00001f;
		ZEnable = FALSE;
// FillMode = WIREFRAME;
		VertexShader = compile vs_1_1 RoadCompiledVSDx9();
		PixelShader = compile ps_1_4 RoadCompiledPSDx9();
	}
}

float4 RoadCompiledPS_LightingOnly(VS2PS indata) : COLOR0
{
// float4 t0 = tex2D(sampler0, indata.Tex0AndZFade);
// float4 t2 = tex2D(sampler2, indata.PosTex);

// float4 final;
// final.rgb = t2;
// final.a = t0.a * indata.Tex0AndZFade.z;
// return final;
return 0;
}

technique roadcompiledLightingOnly
<
	int Declaration[] = 
	{
		// StreamNo, DataType, Usage, UsageIdx
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_POSITION, 0 },
		{ 0, D3DDECLTYPE_FLOAT2, D3DDECLUSAGE_TEXCOORD, 0 },
		{ 0, D3DDECLTYPE_FLOAT2, D3DDECLUSAGE_TEXCOORD, 1 },
		{ 0, D3DDECLTYPE_FLOAT4, D3DDECLUSAGE_POSITION, 1 },
		DECLARATION_END // End macro
	};
>
{
	pass p0
	{
		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;
		DepthBias = -0.000025;
		// SlopeScaleDepthBias = -0.5;
		ZEnable = FALSE;
// CullMode = NONE;
// FillMode = WIREFRAME;	
		VertexShader = compile vs_1_1 RoadCompiledVS();
		PixelShader = compile ps_1_4 RoadCompiledPS_LightingOnly();
	}
}
