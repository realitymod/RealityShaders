
/*
	Description: Renders lighting for undergrowth such as grass
*/

uniform float4x4 _WorldViewProj : WorldViewProjection;
uniform float4x4 _WorldView : WorldView;
uniform float4 _PosOffsetAndScale : PosOffsetAndScale;
uniform float2 _SinCos : SinCos;
uniform float4 _TerrainTexCoordScaleAndOffset : TerrainTexCoordScaleAndOffset;
uniform float3 _CameraPos : CameraPos;
uniform float4 _FadeAndHeightScaleOffset : FadeAndHeightScaleOffset;
uniform float4 _SwayOffsets[16] : SwayOffset;
uniform float4 _ShadowTexCoordScaleAndOffset : ShadowTexCoordScaleAndOffset;
uniform float4 _SunColor : SunColor;
uniform float4 _GIColor : GIColor;
uniform float4 _PointLightPosAtten[4] : PointLightPosAtten;
uniform float4 _PointLightColor[4] : PointLightColor;
uniform int _AlphaRefValue : AlphaRef;
uniform float _LightingScale : LightingScale;

uniform float4 _Transparency_x8 : TRANSPARENCY_X8;

#if NVIDIA
	#define _CUSTOMSHADOWSAMPLER_ s3
	#define _CUSTOMSHADOWSAMPLERINDEX_ 3
#endif

#define FH2_ALPHAREF 127

string Category = "Effects\\Lighting";

#include "shaders/RealityGraphics.fx"

#include "shaders/RaCommon.fx"

uniform texture Tex0 : TEXLAYER0;
uniform texture Tex1 : TEXLAYER1;
uniform texture Tex2 : TEXLAYER2;

sampler2D SampleColorMap = sampler_state
{
	Texture = (Tex0);
	MipFilter = LINEAR;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	AddressU = CLAMP;
	AddressV = CLAMP;
};

sampler2D SampleTerrainColorMap = sampler_state
{
	Texture = (Tex1);
	MipFilter = LINEAR;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	AddressU = CLAMP;
	AddressV = CLAMP;
};

sampler2D SampleTerrainLightMap = sampler_state
{
	Texture = (Tex2);
	MipFilter = LINEAR;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	AddressU = CLAMP;
	AddressV = CLAMP;
};

struct APP2VS
{
	float4 Pos : POSITION;
	float2 TexCoord : TEXCOORD0;
	float4 Packed : COLOR;
};

struct APP2VS_Simple
{
	float4 Pos : POSITION;
	float2 TexCoord : TEXCOORD0;
	float4 Packed : COLOR;
	float4 TerrainColorMap : COLOR1;
	float4 TerrainLightMap : COLOR2;
};

struct VS2PS
{
	float4 HPos : POSITION;
	float4 P_Tex0_Tex1 : TEXCOORD0; // .xy = Tex0; .zw = Tex1;
	float4 TexShadow : TEXCOORD1;
	float3 VertexPos : TEXCOORD2; // .x = LightScale; .y = Fog;
	float4 Color : COLOR0;
};

VS2PS Undergrowth_VS(APP2VS Input, uniform int LightCount, uniform bool ShadowMapEnable)
{
	VS2PS Output = (VS2PS)0;

	float4 Pos = float4((Input.Pos.xyz / 32767.0 * _PosOffsetAndScale.w) + _PosOffsetAndScale.xyz, 1.0);
	Pos.xz += _SwayOffsets[Input.Packed.z * 255].xy * Input.Packed.y * 3.0f;

	float ViewDistance = _FadeAndHeightScaleOffset.x;
	float FadeFactor = _FadeAndHeightScaleOffset.y;
	float HeightScale = saturate((ViewDistance - distance(Pos.xyz, _CameraPos.xyz)) * FadeFactor);
	Pos.y = (Input.Pos.y / 32767.0 * _PosOffsetAndScale.w) * HeightScale + _PosOffsetAndScale.y + (Input.Pos.w / 32767.0 * _PosOffsetAndScale.w);

	Output.HPos = mul(Pos, _WorldViewProj);

	Output.P_Tex0_Tex1.xy = Input.TexCoord / 32767.0;
	Output.P_Tex0_Tex1.zw = Pos.xz * _TerrainTexCoordScaleAndOffset.xy + _TerrainTexCoordScaleAndOffset.zw;

	Output.TexShadow = (ShadowMapEnable) ? GetShadowProjection(Pos) : 0.0;

	float4 Light = 0.0;
	for (int i = 0; i < LightCount; i++)
	{
		float3 LightVec = Pos.xyz - _PointLightPosAtten[i].xyz;
		float Attenuation = GetLightAttenuation(LightVec, _PointLightPosAtten[i].w);
		Light += (Attenuation * _PointLightColor[i]);
	}

	Output.Color = saturate(Light);
	Output.Color.a = Input.Packed.w * 0.5;

	Output.VertexPos = Pos.xyz;

	return Output;
}

float4 Undergrowth_PS
(
	VS2PS Input,
	uniform bool PointLightEnable,
	uniform bool ShadowMapEnable
) : COLOR
{
	float4 Base = tex2D(SampleColorMap, Input.P_Tex0_Tex1.xy);
	float4 TerrainColor = tex2D(SampleTerrainColorMap, Input.P_Tex0_Tex1.zw);

	// If thermals assume gray color
	if (FogColor.r < 0.01)
	{
		TerrainColor.rgb = 1.0 / 3.0;
	}

	TerrainColor.rgb = lerp(TerrainColor.rgb, 1.0, Input.Color.a);
	float3 TerrainLightMap = tex2D(SampleTerrainLightMap, Input.P_Tex0_Tex1.zw);
	float4 TerrainShadow = (ShadowMapEnable) ? GetShadowFactor(SampleShadowMap, Input.TexShadow) : 1.0;

	float3 PointColor = (PointLightEnable) ? Input.Color.rgb * 0.125 : 0.0;
	float3 TerrainLight = (TerrainLightMap.y * _SunColor.rgb * TerrainShadow.rgb + PointColor) * 2.0 + (TerrainLightMap.z * _GIColor.rgb);

	float4 OutputColor = 0.0;
	OutputColor.rgb = Base.rgb * TerrainColor.rgb * TerrainLight.rgb * 2.0;
	OutputColor.a = Base.a * _Transparency_x8.a * 8.0;

	ApplyFog(OutputColor.rgb, GetFogValue(Input.VertexPos.xyz, _CameraPos.xyz));

	return OutputColor;
}

// { StreamNo, DataType, Usage, UsageIdx }
// DECLARATION_END => End macro
#define VERTEX_DECLARATION_UNDERGROWTH \
	int Declaration[] = \
	{ \
		{ 0, D3DDECLTYPE_SHORT4, D3DDECLUSAGE_POSITION, 0 }, \
		{ 0, D3DDECLTYPE_SHORT2, D3DDECLUSAGE_TEXCOORD, 0 }, \
		{ 0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 0 }, \
		DECLARATION_END \
	}; \

#define RENDERSTATES_UNDERGROWTH \
	CullMode = CW; \
	AlphaTestEnable = TRUE; \
	AlphaRef = FH2_ALPHAREF; \
	AlphaFunc = GREATER; \
	ZFunc = LESS; \

technique t0_l0
<
	VERTEX_DECLARATION_UNDERGROWTH
>
{
	pass Normal
	{
		RENDERSTATES_UNDERGROWTH
		VertexShader = compile vs_3_0 Undergrowth_VS(0, false);
		PixelShader = compile ps_3_0 Undergrowth_PS(false, false);
	}
}

technique t0_l1
<
	VERTEX_DECLARATION_UNDERGROWTH
>
{
	pass Normal
	{
		RENDERSTATES_UNDERGROWTH
		VertexShader = compile vs_3_0 Undergrowth_VS(1, false);
		PixelShader = compile ps_3_0 Undergrowth_PS(true, false);
	}
}

technique t0_l2
<
	VERTEX_DECLARATION_UNDERGROWTH
>
{
	pass Normal
	{
		RENDERSTATES_UNDERGROWTH
		VertexShader = compile vs_3_0 Undergrowth_VS(2, false);
		PixelShader = compile ps_3_0 Undergrowth_PS(true, false);
	}
}

technique t0_l3
<
	VERTEX_DECLARATION_UNDERGROWTH
>
{
	pass Normal
	{
		RENDERSTATES_UNDERGROWTH
		VertexShader = compile vs_3_0 Undergrowth_VS(3, false);
		PixelShader = compile ps_3_0 Undergrowth_PS(true, false);
	}
}

technique t0_l4
<
	VERTEX_DECLARATION_UNDERGROWTH
>
{
	pass Normal
	{
		RENDERSTATES_UNDERGROWTH
		VertexShader = compile vs_3_0 Undergrowth_VS(4, false);
		PixelShader = compile ps_3_0 Undergrowth_PS(true, false);
	}
}

technique t0_l0_ds
<
	VERTEX_DECLARATION_UNDERGROWTH
>
{
	pass Normal
	{
		RENDERSTATES_UNDERGROWTH
		VertexShader = compile vs_3_0 Undergrowth_VS(0, true);
		PixelShader = compile ps_3_0 Undergrowth_PS(false, true);
	}
}

technique t0_l1_ds
<
	VERTEX_DECLARATION_UNDERGROWTH
>
{
	pass Normal
	{
		RENDERSTATES_UNDERGROWTH
		VertexShader = compile vs_3_0 Undergrowth_VS(1, true);
		PixelShader = compile ps_3_0 Undergrowth_PS(false, true);
	}
}

technique t0_l2_ds
<
	VERTEX_DECLARATION_UNDERGROWTH
>
{
	pass Normal
	{
		RENDERSTATES_UNDERGROWTH
		VertexShader = compile vs_3_0 Undergrowth_VS(2, true);
		PixelShader = compile ps_3_0 Undergrowth_PS(false, true);
	}
}

technique t0_l3_ds
<
	VERTEX_DECLARATION_UNDERGROWTH
>
{
	pass Normal
	{
		RENDERSTATES_UNDERGROWTH
		VertexShader = compile vs_3_0 Undergrowth_VS(3, true);
		PixelShader = compile ps_3_0 Undergrowth_PS(false, true);
	}
}

technique t0_l4_ds
<
	VERTEX_DECLARATION_UNDERGROWTH
>
{
	pass Normal
	{
		RENDERSTATES_UNDERGROWTH
		VertexShader = compile vs_3_0 Undergrowth_VS(4, true);
		PixelShader = compile ps_3_0 Undergrowth_PS(false, true);
	}
}




/*
	Undergrowth simple shaders
*/

struct VS2PS_Simple
{
	float4 HPos : POSITION;
	float2 Tex0 : TEXCOORD0;
	float4 TexShadow : TEXCOORD1;
	float3 SunLight : TEXCOORD2;
	float3 VertexPos : TEXCOORD3;
	float4 P_Light_Scale : COLOR0; // .rgb = Light; .a = Scale;
	float4 P_TerrainColor : COLOR1;
};

VS2PS_Simple Undergrowth_Simple_VS(APP2VS_Simple Input, uniform int LightCount, uniform bool ShadowMapEnable)
{
	VS2PS_Simple Output = (VS2PS_Simple)0;

	float4 Pos = float4((Input.Pos.xyz / 32767.0 * _PosOffsetAndScale.w) + _PosOffsetAndScale.xyz, 1.0);
	Pos.xz += _SwayOffsets[Input.Packed.z * 255].xy * Input.Packed.y * 3.0f;

	float ViewDistance = _FadeAndHeightScaleOffset.x;
	float FadeFactor = _FadeAndHeightScaleOffset.y;
	float HeightScale = saturate((ViewDistance - distance(Pos.xyz, _CameraPos)) * FadeFactor);
	Pos.y = (Input.Pos.y / 32767.0 * _PosOffsetAndScale.w) * HeightScale + _PosOffsetAndScale.y + (Input.Pos.w / 32767.0 * _PosOffsetAndScale.w);

	Output.HPos = mul(Pos, _WorldViewProj);

	Output.Tex0 = Input.TexCoord / 32767.0;

	if (ShadowMapEnable)
	{
		Output.TexShadow = GetShadowProjection(Pos);
	}

	float3 Light = Input.TerrainLightMap.z * _GIColor;
	for (int i = 0; i < LightCount; i++)
	{
		float3 LightVec = Pos.xyz - _PointLightPosAtten[i].xyz;
		float Attenuation = GetLightAttenuation(LightVec, _PointLightPosAtten[i].w);
		Light += (Attenuation * _PointLightColor[i]);
	}

	if (ShadowMapEnable)
	{
		Output.P_Light_Scale.rgb = Light;
		Output.P_Light_Scale.w = Input.Packed.w;
		Output.SunLight = Input.TerrainLightMap.y * _SunColor * 2.0;
		Output.P_TerrainColor.rgb = lerp(Input.TerrainColorMap, 1.0, Input.Packed.w);
	}
	else
	{
		Light += Input.TerrainLightMap.y * _SunColor * 2.0;
		Output.P_TerrainColor.rgb = lerp(Input.TerrainColorMap, 1.0, Input.Packed.w);
		Output.P_TerrainColor.rgb *= Light;
	}

	Output.P_Light_Scale = saturate(Output.P_Light_Scale);
	Output.P_TerrainColor.rgb = saturate(Output.P_TerrainColor.rgb);
	Output.VertexPos = Pos.xyz;

	return Output;
}

float4 Undergrowth_Simple_PS
(
	VS2PS_Simple Input,
	uniform bool PointLightEnable,
	uniform bool ShadowMapEnable
) : COLOR
{
	float4 Base = tex2D(SampleColorMap, Input.Tex0);
	float3 LightColor = 0.0;

	if (ShadowMapEnable)
	{
		float4 TerrainShadow = GetShadowFactor(SampleShadowMap, Input.TexShadow);
		float3 Light = (Input.SunLight * TerrainShadow.xyz) + Input.P_Light_Scale.rgb;
		LightColor = Base.rgb * Input.P_TerrainColor.rgb * Light * 2.0;
	}
	else
	{
		LightColor = Base.rgb * Input.P_TerrainColor.rgb * 2.0;
	}

	float4 OutputColor = float4(LightColor, Base.a * _Transparency_x8.a * 8.0);

	// Thermals
	if (FogColor.r < 0.01)
	{
		OutputColor.rgb = float3(lerp(0.43, 0.17, LightColor.b), 1.0, 0.0);
	}

	ApplyFog(OutputColor.rgb, GetFogValue(Input.VertexPos.xyz, _CameraPos.xyz));

	return OutputColor;
}

// { StreamNo, DataType, Usage, UsageIdx }
// DECLARATION_END => End macro
#define VERTEX_DECLARATION_UNDERGROWTH_SIMPLE \
	int Declaration[] = \
	{ \
		{ 0, D3DDECLTYPE_SHORT4, D3DDECLUSAGE_POSITION, 0 }, \
		{ 0, D3DDECLTYPE_SHORT2, D3DDECLUSAGE_TEXCOORD, 0 }, \
		{ 0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 0 }, \
		{ 0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 1 }, \
		{ 0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 2 }, \
		DECLARATION_END \
	}; \

#define RENDERSTATES_UNDERGROWTH_SIMPLE \
	CullMode = CW; \
	AlphaTestEnable = TRUE; \
	AlphaRef = FH2_ALPHAREF; \
	AlphaFunc = GREATER; \
	ZFunc = LESS; \

technique t0_l0_simple
<
	VERTEX_DECLARATION_UNDERGROWTH_SIMPLE
>
{
	pass Normal
	{
		RENDERSTATES_UNDERGROWTH_SIMPLE
		VertexShader = compile vs_3_0 Undergrowth_Simple_VS(0, false);
		PixelShader = compile ps_3_0 Undergrowth_Simple_PS(false, false);
	}
}

technique t0_l1_simple
<
	VERTEX_DECLARATION_UNDERGROWTH_SIMPLE
>
{
	pass Normal
	{
		RENDERSTATES_UNDERGROWTH_SIMPLE
		VertexShader = compile vs_3_0 Undergrowth_Simple_VS(1, false);
		PixelShader = compile ps_3_0 Undergrowth_Simple_PS(true, false);
	}
}

technique t0_l2_simple
<
	VERTEX_DECLARATION_UNDERGROWTH_SIMPLE
>
{
	pass Normal
	{
		RENDERSTATES_UNDERGROWTH_SIMPLE
		VertexShader = compile vs_3_0 Undergrowth_Simple_VS(2, false);
		PixelShader = compile ps_3_0 Undergrowth_Simple_PS(true, false);
	}
}

technique t0_l3_simple
<
	VERTEX_DECLARATION_UNDERGROWTH_SIMPLE
>
{
	pass Normal
	{
		RENDERSTATES_UNDERGROWTH_SIMPLE
		VertexShader = compile vs_3_0 Undergrowth_Simple_VS(3, false);
		PixelShader = compile ps_3_0 Undergrowth_Simple_PS(true, false);
	}
}

technique t0_l4_simple
<
	VERTEX_DECLARATION_UNDERGROWTH_SIMPLE
>
{
	pass Normal
	{
		RENDERSTATES_UNDERGROWTH_SIMPLE
		VertexShader = compile vs_3_0 Undergrowth_Simple_VS(4, false);
		PixelShader = compile ps_3_0 Undergrowth_Simple_PS(true, false);
	}
}

technique t0_l0_ds_simple
<
	VERTEX_DECLARATION_UNDERGROWTH_SIMPLE
>
{
	pass Normal
	{
		RENDERSTATES_UNDERGROWTH_SIMPLE
		VertexShader = compile vs_3_0 Undergrowth_Simple_VS(0, true);
		PixelShader = compile ps_3_0 Undergrowth_Simple_PS(false, true);
	}
}

technique t0_l1_ds_simple
<
	VERTEX_DECLARATION_UNDERGROWTH_SIMPLE
>
{
	pass Normal
	{
		RENDERSTATES_UNDERGROWTH_SIMPLE
		VertexShader = compile vs_3_0 Undergrowth_Simple_VS(1, true);
		PixelShader = compile ps_3_0 Undergrowth_Simple_PS(true, true);
	}
}

technique t0_l2_ds_simple
<
	VERTEX_DECLARATION_UNDERGROWTH_SIMPLE
>
{
	pass Normal
	{
		RENDERSTATES_UNDERGROWTH_SIMPLE
		VertexShader = compile vs_3_0 Undergrowth_Simple_VS(2, true);
		PixelShader = compile ps_3_0 Undergrowth_Simple_PS(true, true);
	}
}

technique t0_l3_ds_simple
<
	VERTEX_DECLARATION_UNDERGROWTH_SIMPLE
>
{
	pass Normal
	{
		RENDERSTATES_UNDERGROWTH_SIMPLE
		VertexShader = compile vs_3_0 Undergrowth_Simple_VS(3, true);
		PixelShader = compile ps_3_0 Undergrowth_Simple_PS(true, true);
	}
}

technique t0_l4_ds_simple
<
	VERTEX_DECLARATION_UNDERGROWTH_SIMPLE
>
{
	pass Normal
	{
		RENDERSTATES_UNDERGROWTH_SIMPLE
		VertexShader = compile vs_3_0 Undergrowth_Simple_VS(4, true);
		PixelShader = compile ps_3_0 Undergrowth_Simple_PS(true, true);
	}
}




/*
	Undergrowth ZOnly shaders
*/

struct VS2PS_ZOnly
{
	float4 HPos : POSITION;
	float2 Tex0 : TEXCOORD0;
};

VS2PS_ZOnly Undergrowth_ZOnly_Simple_VS(APP2VS_Simple Input)
{
	VS2PS_ZOnly Output = (VS2PS_ZOnly)0;

	float4 Pos = float4((Input.Pos.xyz / 32767.0 * _PosOffsetAndScale.w) + _PosOffsetAndScale.xyz, 1.0);
	Pos.xz += _SwayOffsets[Input.Packed.z * 255].xy * Input.Packed.y * 3.0f;

	float ViewDistance = _FadeAndHeightScaleOffset.x;
	float FadeFactor = _FadeAndHeightScaleOffset.y;
	float HeightScale = saturate((ViewDistance - distance(Pos.xyz, _CameraPos)) * FadeFactor);
	Pos.y = (Input.Pos.y / 32767.0 * _PosOffsetAndScale.w) * HeightScale + _PosOffsetAndScale.y + (Input.Pos.w / 32767.0 * _PosOffsetAndScale.w);

	Output.HPos = mul(Pos, _WorldViewProj);

 	Output.Tex0 = Input.TexCoord / 32767.0;

	return Output;
}

VS2PS_ZOnly Undergrowth_ZOnly_VS(APP2VS Input)
{
	VS2PS_ZOnly Output = (VS2PS_ZOnly)0;

	float4 Pos = float4((Input.Pos.xyz / 32767.0 * _PosOffsetAndScale.w), 1.0);
	Pos.xz += _SwayOffsets[Input.Packed.z * 255].xy * Input.Packed.y * 3.0f;
	Pos.xyz += _PosOffsetAndScale.xyz;

	float ViewDistance = _FadeAndHeightScaleOffset.x;
	float FadeFactor = _FadeAndHeightScaleOffset.y;
	float HeightScale = saturate((ViewDistance - distance(Pos.xyz, _CameraPos.xyz)) * FadeFactor);
	Pos.y = (Input.Pos.y / 32767.0 * _PosOffsetAndScale.w) * HeightScale + _PosOffsetAndScale.y + (Input.Pos.w / 32767.0 * _PosOffsetAndScale.w);

	Output.HPos = mul(Pos, _WorldViewProj);

	Output.Tex0 = Input.TexCoord / 32767.0;

	return Output;
}

float4 Undergrowth_ZOnly_PS(VS2PS_ZOnly Input) : COLOR
{
	float4 OutputColor = tex2D(SampleColorMap, Input.Tex0);
	OutputColor.a *= _Transparency_x8.a * 8.0;
	return OutputColor;
}

// { StreamNo, DataType, Usage, UsageIdx }
// DECLARATION_END => End macro
#define VERTEX_DECLARATION_UNDERGROWTH_ZONLY \
	int Declaration[] = \
	{ \
		{ 0, D3DDECLTYPE_SHORT4, D3DDECLUSAGE_POSITION, 0 }, \
		{ 0, D3DDECLTYPE_SHORT2, D3DDECLUSAGE_TEXCOORD, 0 }, \
		{ 0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 0 }, \
		DECLARATION_END \
	}; \

#define RENDERSTATES_UNDERGROWTH_ZONLY \
	CullMode = CW; \
	AlphaTestEnable = TRUE; \
	AlphaRef = FH2_ALPHAREF; \
	AlphaFunc = GREATER; \
	ColorWriteEnable = 0; \
	ZFunc = LESS; \

technique ZOnly
<
	VERTEX_DECLARATION_UNDERGROWTH_ZONLY
>
{
	pass Normal
	{
		RENDERSTATES_UNDERGROWTH_ZONLY
		VertexShader = compile vs_3_0 Undergrowth_ZOnly_VS();
		PixelShader = compile ps_3_0 Undergrowth_ZOnly_PS();
	}
}

technique ZOnly_Simple
<
	VERTEX_DECLARATION_UNDERGROWTH_ZONLY
>
{
	pass Normal
	{
		RENDERSTATES_UNDERGROWTH_ZONLY
		VertexShader = compile vs_3_0 Undergrowth_ZOnly_Simple_VS();
		PixelShader = compile ps_3_0 Undergrowth_ZOnly_PS();
	}
}
