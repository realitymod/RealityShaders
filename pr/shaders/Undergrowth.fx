
/*
	Include header files
*/

#include "shaders/RealityGraphics.fxh"
#include "shaders/shared/RealityDepth.fxh"
#include "shaders/shared/RealityDirectXTK.fxh"
#include "shaders/shared/RealityPixel.fxh"
#include "shaders/RaCommon.fxh"
#if !defined(_HEADERS_)
	#include "RealityGraphics.fxh"
	#include "shared/RealityDepth.fxh"
	#include "shared/RealityDirectXTK.fxh"
	#include "shared/RealityPixel.fxh"
	#include "RaCommon.fxh"
#endif

/*
	Description: Renders lighting for undergrowth such as grass
*/

string Category = "Effects\\Lighting";

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

#define CREATE_SAMPLER(SAMPLER_NAME, TEXTURE) \
	sampler2D SAMPLER_NAME = sampler_state \
	{ \
		Texture = (TEXTURE); \
		MinFilter = LINEAR; \
		MagFilter = LINEAR; \
		MipFilter = LINEAR; \
		AddressU = CLAMP; \
		AddressV = CLAMP; \
	}; \

uniform texture Tex0 : TEXLAYER0;
CREATE_SAMPLER(SampleColorMap, Tex0)

uniform texture Tex1 : TEXLAYER1;
CREATE_SAMPLER(SampleTerrainColorMap, Tex1)

uniform texture Tex2 : TEXLAYER2;
CREATE_SAMPLER(SampleTerrainLightMap, Tex2)

struct APP2VS
{
	float4 Pos : POSITION;
	float2 Tex0 : TEXCOORD0;
	float4 Packed : COLOR;
};

struct VS2PS
{
	float4 HPos : POSITION;
	float4 Pos : TEXCOORD0;
	float4 Tex0 : TEXCOORD1; // .xy = Tex0; .zw = Tex1;
	float4 ShadowTex : TEXCOORD2;
	float Scale : TEXCOORD3;
};

struct PS2FB
{
	float4 Color : COLOR0;
	#if defined(LOG_DEPTH)
		float Depth : DEPTH;
	#endif
};

float4 GetUndergrowthPos(float4 InputPos, float4 InputPacked)
{
	float3 PosOffset = _PosOffsetAndScale.xyz;
	float PosScale = _PosOffsetAndScale.w;

	float4 UnpackedPos = (InputPos / 32767.0) * PosScale;
	float4 Pos = float4(UnpackedPos.xyz, 1.0);
	Pos.xz += _SwayOffsets[InputPacked.z * 255].xy * InputPacked.y * 3.0;
	Pos.xyz += PosOffset.xyz;

	float ViewDistance = _FadeAndHeightScaleOffset.x;
	float FadeFactor = _FadeAndHeightScaleOffset.y;
	float HeightScale = saturate((ViewDistance - distance(Pos.xyz, _CameraPos.xyz)) * FadeFactor);
	Pos.y = ((UnpackedPos.y * HeightScale) + PosOffset.y) + UnpackedPos.w;

	return Pos;
}

VS2PS VS_Undergrowth(APP2VS Input, uniform bool ShadowMapEnable)
{
	VS2PS Output = (VS2PS)0.0;

	float4 Pos = GetUndergrowthPos(Input.Pos, Input.Packed);
	Output.HPos = mul(Pos, _WorldViewProj);
	Output.Pos = Pos;

	// Output Depth
	#if defined(LOG_DEPTH)
		Output.Pos.w = Output.HPos.w + 1.0;
	#endif

	Output.Tex0.xy = Input.Tex0 / 32767.0;
	Output.Tex0.zw = (Pos.xz * _TerrainTexCoordScaleAndOffset.xy) + _TerrainTexCoordScaleAndOffset.zw;
	Output.ShadowTex = (ShadowMapEnable) ? GetShadowProjection(Pos) : 0.0;

	Output.Scale = Input.Packed.w * 0.5;

	return Output;
}

PS2FB PS_Undergrowth(VS2PS Input, uniform bool PointLightEnable, uniform int LightCount, uniform bool ShadowMapEnable)
{
	PS2FB Output = (PS2FB)0.0;

	float3 LocalPos = Input.Pos.xyz;
	float3 TerrainSunColor = _SunColor * 2.0;

	float4 Base = SRGBToLinearEst(tex2D(SampleColorMap, Input.Tex0.xy));
	float4 TerrainColor = SRGBToLinearEst(tex2D(SampleTerrainColorMap, Input.Tex0.zw));
	float4 TerrainLightMap = SRGBToLinearEst(tex2D(SampleTerrainLightMap, Input.Tex0.zw));
	float TerrainShadow = (ShadowMapEnable) ? GetShadowFactor(SampleShadowMap, Input.ShadowTex) : 1.0;

	// If thermals assume gray color
	if (IsTisActive())
	{
		TerrainColor = 1.0 / 3.0;
	}

	float3 Lights = 0.0;
	for (int i = 0; i < LightCount; i++)
	{
		float3 LightVec = LocalPos - _PointLightPosAtten[i].xyz;
		float Attenuation = GetLightAttenuation(LightVec, _PointLightPosAtten[i].w);
		Lights += (Attenuation * _PointLightColor[i]);
	}
	Lights = saturate(Lights);

	TerrainColor = lerp(TerrainColor, 1.0, Input.Scale) * 2.0;
	float3 TerrainLight = _GIColor.rgb * TerrainLightMap.z;
	TerrainLight += (TerrainSunColor * (TerrainShadow * TerrainLightMap.y));
	TerrainLight += Lights;

	float4 OutputColor = 0.0;
	OutputColor.rgb = (Base.rgb * TerrainColor.rgb) * TerrainLight;
	OutputColor.a = (Base.a * 2.0) * (_Transparency_x8.a * 8.0);

	Output.Color = OutputColor;
	ApplyFog(Output.Color.rgb, GetFogValue(LocalPos, _CameraPos));
	TonemapAndLinearToSRGBEst(Output.Color);

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);
	#endif

	return Output;
}

// { StreamNo, DataType, Usage, UsageIdx }
// DECLARATION_END => End macro
#define CREATE_TECHNIQUE_UG(TECHNIQUE_NAME, VERTEX_SHADER, PIXEL_SHADER) \
	technique TECHNIQUE_NAME \
	< \
		int Declaration[] = \
		{ \
			{ 0, D3DDECLTYPE_SHORT4, D3DDECLUSAGE_POSITION, 0 }, \
			{ 0, D3DDECLTYPE_SHORT2, D3DDECLUSAGE_TEXCOORD, 0 }, \
			{ 0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 0 }, \
			DECLARATION_END \
		}; \
	> \
	{ \
		pass Normal \
		{ \
			CullMode = CW; \
			AlphaTestEnable = TRUE; \
			AlphaRef = PR_ALPHA_REF; \
			AlphaFunc = GREATER; \
			ZFunc = LESS; \
			VertexShader = compile vs_3_0 VERTEX_SHADER; \
			PixelShader = compile ps_3_0 PIXEL_SHADER; \
		} \
	}

CREATE_TECHNIQUE_UG(t0_l0, VS_Undergrowth(false), PS_Undergrowth(false, 0, false))
CREATE_TECHNIQUE_UG(t0_l1, VS_Undergrowth(false), PS_Undergrowth(true, 1, false))
CREATE_TECHNIQUE_UG(t0_l2, VS_Undergrowth(false), PS_Undergrowth(true, 2, false))
CREATE_TECHNIQUE_UG(t0_l3, VS_Undergrowth(false), PS_Undergrowth(true, 3, false))
CREATE_TECHNIQUE_UG(t0_l4, VS_Undergrowth(false), PS_Undergrowth(true, 4, false))
CREATE_TECHNIQUE_UG(t0_l0_ds, VS_Undergrowth(true), PS_Undergrowth(false, 0, true))
CREATE_TECHNIQUE_UG(t0_l1_ds, VS_Undergrowth(true), PS_Undergrowth(false, 1, true))
CREATE_TECHNIQUE_UG(t0_l2_ds, VS_Undergrowth(true), PS_Undergrowth(false, 2, true))
CREATE_TECHNIQUE_UG(t0_l3_ds, VS_Undergrowth(true), PS_Undergrowth(false, 3, true))
CREATE_TECHNIQUE_UG(t0_l4_ds, VS_Undergrowth(true), PS_Undergrowth(false, 4, true))

/*
	Undergrowth simple shaders
*/

struct APP2VS_Simple
{
	float4 Pos : POSITION;
	float2 Tex0 : TEXCOORD0;
	float4 Packed : COLOR;
	float4 TerrainColorMap : COLOR1;
	float4 TerrainLightMap : COLOR2;
};

struct VS2PS_Simple
{
	float4 HPos : POSITION;
	float4 Pos : TEXCOORD0;
	float3 Tex0 : TEXCOORD1; // .xy = Tex0; .z = Scale;
	float4 ShadowTex : TEXCOORD2;
	float4 TerrainLightMap : TEXCOORD3;
	float4 TerrainColorMap : TEXCOORD4;
};

VS2PS_Simple VS_Undergrowth_Simple(APP2VS_Simple Input, uniform bool ShadowMapEnable)
{
	VS2PS_Simple Output = (VS2PS_Simple)0.0;

	float4 Pos = GetUndergrowthPos(Input.Pos, Input.Packed);
	Output.HPos = mul(Pos, _WorldViewProj);
	Output.Pos = Pos;

	// Output Depth
	#if defined(LOG_DEPTH)
		Output.Pos.w = Output.HPos.w + 1.0;
	#endif

	Output.Tex0.xy = Input.Tex0 / 32767.0;
	Output.Tex0.z = Input.Packed.w * 0.5;
	Output.ShadowTex = (ShadowMapEnable) ? GetShadowProjection(Pos) : 0.0;

	Output.TerrainColorMap = saturate(Input.TerrainColorMap);
	Output.TerrainLightMap = saturate(Input.TerrainLightMap);

	return Output;
}

PS2FB PS_Undergrowth_Simple(VS2PS_Simple Input, uniform bool PointLightEnable, uniform int LightCount, uniform bool ShadowMapEnable)
{
	PS2FB Output = (PS2FB)0.0;

	float3 LocalPos = Input.Pos.xyz;
	float3 TerrainColor = Input.TerrainColorMap;
	float3 TerrainLightMap = Input.TerrainLightMap;
	float3 TerrainSunColor = _SunColor * 2.0;

	float4 Base = SRGBToLinearEst(tex2D(SampleColorMap, Input.Tex0.xy));
	float TerrainShadow = (ShadowMapEnable) ? GetShadowFactor(SampleShadowMap, Input.ShadowTex) : 1.0;

	// If thermals assume gray color
	if (IsTisActive())
	{
		TerrainColor = 1.0 / 3.0;
	}

	float3 Lights = 0.0;
	for (int i = 0; i < LightCount; i++)
	{
		float3 LightVec = LocalPos - _PointLightPosAtten[i].xyz;
		float Attenuation = GetLightAttenuation(LightVec, _PointLightPosAtten[i].w);
		Lights += (Attenuation * _PointLightColor[i]);
	}
	Lights = saturate(Lights);

	TerrainColor = lerp(TerrainColor, 1.0, Input.Tex0.z) * 2.0;
	float3 TerrainLight = _GIColor.rgb * TerrainLightMap.z;
	TerrainLight += (TerrainSunColor * (TerrainShadow * TerrainLightMap.y));
	TerrainLight += Lights;

	float4 OutputColor = 0.0;
	OutputColor.rgb = (Base.rgb * TerrainColor) * TerrainLight;
	OutputColor.a = (Base.a * 2.0) * (_Transparency_x8.a * 8.0);

	Output.Color = OutputColor;
	ApplyFog(Output.Color.rgb, GetFogValue(LocalPos, _CameraPos));
	TonemapAndLinearToSRGBEst(Output.Color);

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);
	#endif

	return Output;
}

// { StreamNo, DataType, Usage, UsageIdx }
// DECLARATION_END => End macro
#define CREATE_TECHNIQUE_UG_SIMPLE(TECHNIQUE_NAME, VERTEX_SHADER, PIXEL_SHADER) \
	technique TECHNIQUE_NAME \
	< \
		int Declaration[] = \
		{ \
			{ 0, D3DDECLTYPE_SHORT4, D3DDECLUSAGE_POSITION, 0 }, \
			{ 0, D3DDECLTYPE_SHORT2, D3DDECLUSAGE_TEXCOORD, 0 }, \
			{ 0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 0 }, \
			{ 0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 1 }, \
			{ 0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 2 }, \
			DECLARATION_END \
		}; \
	> \
	{ \
		pass Normal \
		{ \
			CullMode = CW; \
			AlphaTestEnable = TRUE; \
			AlphaRef = PR_ALPHA_REF; \
			AlphaFunc = GREATER; \
			ZFunc = LESS; \
			VertexShader = compile vs_3_0 VERTEX_SHADER; \
			PixelShader = compile ps_3_0 PIXEL_SHADER; \
		} \
	}

CREATE_TECHNIQUE_UG_SIMPLE(t0_l0_simple, VS_Undergrowth_Simple(false), PS_Undergrowth_Simple(false, 0, false))
CREATE_TECHNIQUE_UG_SIMPLE(t0_l1_simple, VS_Undergrowth_Simple(false), PS_Undergrowth_Simple(true, 1, false))
CREATE_TECHNIQUE_UG_SIMPLE(t0_l2_simple, VS_Undergrowth_Simple(false), PS_Undergrowth_Simple(true, 2, false))
CREATE_TECHNIQUE_UG_SIMPLE(t0_l3_simple, VS_Undergrowth_Simple(false), PS_Undergrowth_Simple(true, 3, false))
CREATE_TECHNIQUE_UG_SIMPLE(t0_l4_simple, VS_Undergrowth_Simple(false), PS_Undergrowth_Simple(true, 4, false))
CREATE_TECHNIQUE_UG_SIMPLE(t0_l0_ds_simple, VS_Undergrowth_Simple(true), PS_Undergrowth_Simple(false, 0, true))
CREATE_TECHNIQUE_UG_SIMPLE(t0_l1_ds_simple, VS_Undergrowth_Simple(true), PS_Undergrowth_Simple(true, 1, true))
CREATE_TECHNIQUE_UG_SIMPLE(t0_l2_ds_simple, VS_Undergrowth_Simple(true), PS_Undergrowth_Simple(true, 2, true))
CREATE_TECHNIQUE_UG_SIMPLE(t0_l3_ds_simple, VS_Undergrowth_Simple(true), PS_Undergrowth_Simple(true, 3, true))
CREATE_TECHNIQUE_UG_SIMPLE(t0_l4_ds_simple, VS_Undergrowth_Simple(true), PS_Undergrowth_Simple(true, 4, true))

/*
	Undergrowth ZOnly shaders
*/

struct VS2PS_ZOnly
{
	float4 HPos : POSITION;
	float3 Tex0 : TEXCOORD0;
};

VS2PS_ZOnly VS_Undergrowth_ZOnly(APP2VS Input)
{
	VS2PS_ZOnly Output = (VS2PS_ZOnly)0.0;

	float4 Pos = GetUndergrowthPos(Input.Pos, Input.Packed);
	Output.HPos = mul(Pos, _WorldViewProj);
	Output.Tex0.xy = Input.Tex0 / 32767.0;

	// Output Depth
	#if defined(LOG_DEPTH)
		Output.Tex0.z = Output.HPos.w + 1.0;
	#endif

	return Output;
}

PS2FB PS_Undergrowth_ZOnly(VS2PS_ZOnly Input)
{
	PS2FB Output = (PS2FB)0.0;

	float4 OutputColor = tex2D(SampleColorMap, Input.Tex0.xy);
	OutputColor.a *= (_Transparency_x8.a * 8.0);

	Output.Color = OutputColor;

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Tex0.z);
	#endif

	return Output;
}

// { StreamNo, DataType, Usage, UsageIdx }
// DECLARATION_END => End macro
#define CREATE_TECHNIQUE_UG_ZONLY(TECHNIQUE_NAME, VERTEX_SHADER, PIXEL_SHADER) \
	technique TECHNIQUE_NAME \
	< \
		int Declaration[] = \
		{ \
			{ 0, D3DDECLTYPE_SHORT4, D3DDECLUSAGE_POSITION, 0 }, \
			{ 0, D3DDECLTYPE_SHORT2, D3DDECLUSAGE_TEXCOORD, 0 }, \
			{ 0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 0 }, \
			DECLARATION_END \
		}; \
	> \
	{ \
		pass Normal \
		{ \
			CullMode = CW; \
			AlphaTestEnable = TRUE; \
			AlphaRef = PR_ALPHA_REF; \
			AlphaFunc = GREATER; \
			ZFunc = LESS; \
			ColorWriteEnable = 0; \
			VertexShader = compile vs_3_0 VERTEX_SHADER; \
			PixelShader = compile ps_3_0 PIXEL_SHADER; \
		} \
	}

CREATE_TECHNIQUE_UG_ZONLY(ZOnly, VS_Undergrowth_ZOnly(), PS_Undergrowth_ZOnly())
CREATE_TECHNIQUE_UG_ZONLY(ZOnly_Simple, VS_Undergrowth_ZOnly(), PS_Undergrowth_ZOnly())
