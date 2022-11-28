
/*
	Description: Renders lighting for undergrowth such as grass
*/

#include "shaders/RealityGraphics.fxh"
#include "shaders/RaCommon.fxh"

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

#define FH2_ALPHAREF 127

#define CREATE_SAMPLER(SAMPLER_NAME, TEXTURE, IS_SRGB) \
	sampler2D SAMPLER_NAME = sampler_state \
	{ \
		Texture = (TEXTURE); \
		MinFilter = LINEAR; \
		MagFilter = LINEAR; \
		MipFilter = LINEAR; \
		AddressU = CLAMP; \
		AddressV = CLAMP; \
		SRGBTexture = IS_SRGB; \
	}; \

uniform texture Tex0 : TEXLAYER0;
CREATE_SAMPLER(SampleColorMap, Tex0, FALSE)

uniform texture Tex1 : TEXLAYER1;
CREATE_SAMPLER(SampleTerrainColorMap, Tex1, FALSE)

uniform texture Tex2 : TEXLAYER2;
CREATE_SAMPLER(SampleTerrainLightMap, Tex2, FALSE)

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

	float4 TexA : TEXCOORD1; // .xy = Tex0; .zw = Tex1;
	float4 ShadowTex : TEXCOORD2;

	float4 Color : COLOR0;
};

struct PS2FB
{
	float4 Color : COLOR;
	float Depth : DEPTH;
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

VS2PS Undergrowth_VS(APP2VS Input, uniform int LightCount, uniform bool ShadowMapEnable)
{
	VS2PS Output = (VS2PS)0;

	float4 Pos = GetUndergrowthPos(Input.Pos, Input.Packed);
	Output.HPos = mul(Pos, _WorldViewProj);
	Output.Pos.xyz = Pos.xyz;
	Output.Pos.w = Output.HPos.w; // Output depth

	Output.TexA.xy = Input.Tex0 / 32767.0;
	Output.TexA.zw = (Pos.xz * _TerrainTexCoordScaleAndOffset.xy) + _TerrainTexCoordScaleAndOffset.zw;
	Output.ShadowTex = (ShadowMapEnable) ? GetShadowProjection(Pos) : 0.0;

	float3 Light = 0.0;
	for (int i = 0; i < LightCount; i++)
	{
		float3 LightVec = Pos.xyz - _PointLightPosAtten[i].xyz;
		float Attenuation = GetLightAttenuation(LightVec, _PointLightPosAtten[i].w);
		Light += (Attenuation * _PointLightColor[i]);
	}

	Output.Color.rgb = saturate(Light);
	Output.Color.a = Input.Packed.w * 0.5;

	return Output;
}

PS2FB Undergrowth_PS(VS2PS Input, uniform bool PointLightEnable, uniform bool ShadowMapEnable)
{
	PS2FB Output;

	float3 LocalPos = Input.Pos.xyz;

	float4 Base = tex2D(SampleColorMap, Input.TexA.xy);
	float4 TerrainColor = tex2D(SampleTerrainColorMap, Input.TexA.zw);
	float3 TerrainLightMap = tex2D(SampleTerrainLightMap, Input.TexA.zw);
	float4 TerrainShadow = (ShadowMapEnable) ? GetShadowFactor(SampleShadowMap, Input.ShadowTex) : 1.0;

	// If thermals assume gray color
	if (FogColor.r < 0.01)
	{
		TerrainColor.rgb = 1.0 / 3.0;
	}

	TerrainColor.rgb = lerp(TerrainColor.rgb, 1.0, Input.Color.a);
	float3 PointColor = (PointLightEnable) ? Input.Color.rgb : 0.0;
	float3 TerrainLight = _GIColor.rgb * TerrainLightMap.z;
	TerrainLight += ((_SunColor.rgb * (TerrainShadow.rgb * TerrainLightMap.y)) + PointColor) * 2.0;

	float4 OutputColor = 0.0;
	OutputColor.rgb = ((Base.rgb * TerrainColor.rgb) * TerrainLight.rgb) * 2.0;
	OutputColor.a = Base.a * (_Transparency_x8.a * 8.0);

	ApplyFog(OutputColor.rgb, GetFogValue(LocalPos, _CameraPos));

	Output.Color = OutputColor;
	Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);

	return Output;
}

// { StreamNo, DataType, Usage, UsageIdx }
// DECLARATION_END => End macro
#define CREATE_VERTEX_DECLARATION_UNDERGROWTH \
	int Declaration[] = \
	{ \
		{ 0, D3DDECLTYPE_SHORT4, D3DDECLUSAGE_POSITION, 0 }, \
		{ 0, D3DDECLTYPE_SHORT2, D3DDECLUSAGE_TEXCOORD, 0 }, \
		{ 0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 0 }, \
		DECLARATION_END \
	}; \

#define GET_RENDERSTATES_UNDERGROWTH \
	CullMode = CW; \
	AlphaTestEnable = TRUE; \
	AlphaRef = FH2_ALPHAREF; \
	AlphaFunc = GREATER; \
	ZFunc = LESS; \
	SRGBWriteEnable = FALSE; \

technique t0_l0
<
	CREATE_VERTEX_DECLARATION_UNDERGROWTH
>
{
	pass Normal
	{
		GET_RENDERSTATES_UNDERGROWTH
		VertexShader = compile vs_3_0 Undergrowth_VS(0, false);
		PixelShader = compile ps_3_0 Undergrowth_PS(false, false);
	}
}

technique t0_l1
<
	CREATE_VERTEX_DECLARATION_UNDERGROWTH
>
{
	pass Normal
	{
		GET_RENDERSTATES_UNDERGROWTH
		VertexShader = compile vs_3_0 Undergrowth_VS(1, false);
		PixelShader = compile ps_3_0 Undergrowth_PS(true, false);
	}
}

technique t0_l2
<
	CREATE_VERTEX_DECLARATION_UNDERGROWTH
>
{
	pass Normal
	{
		GET_RENDERSTATES_UNDERGROWTH
		VertexShader = compile vs_3_0 Undergrowth_VS(2, false);
		PixelShader = compile ps_3_0 Undergrowth_PS(true, false);
	}
}

technique t0_l3
<
	CREATE_VERTEX_DECLARATION_UNDERGROWTH
>
{
	pass Normal
	{
		GET_RENDERSTATES_UNDERGROWTH
		VertexShader = compile vs_3_0 Undergrowth_VS(3, false);
		PixelShader = compile ps_3_0 Undergrowth_PS(true, false);
	}
}

technique t0_l4
<
	CREATE_VERTEX_DECLARATION_UNDERGROWTH
>
{
	pass Normal
	{
		GET_RENDERSTATES_UNDERGROWTH
		VertexShader = compile vs_3_0 Undergrowth_VS(4, false);
		PixelShader = compile ps_3_0 Undergrowth_PS(true, false);
	}
}

technique t0_l0_ds
<
	CREATE_VERTEX_DECLARATION_UNDERGROWTH
>
{
	pass Normal
	{
		GET_RENDERSTATES_UNDERGROWTH
		VertexShader = compile vs_3_0 Undergrowth_VS(0, true);
		PixelShader = compile ps_3_0 Undergrowth_PS(false, true);
	}
}

technique t0_l1_ds
<
	CREATE_VERTEX_DECLARATION_UNDERGROWTH
>
{
	pass Normal
	{
		GET_RENDERSTATES_UNDERGROWTH
		VertexShader = compile vs_3_0 Undergrowth_VS(1, true);
		PixelShader = compile ps_3_0 Undergrowth_PS(false, true);
	}
}

technique t0_l2_ds
<
	CREATE_VERTEX_DECLARATION_UNDERGROWTH
>
{
	pass Normal
	{
		GET_RENDERSTATES_UNDERGROWTH
		VertexShader = compile vs_3_0 Undergrowth_VS(2, true);
		PixelShader = compile ps_3_0 Undergrowth_PS(false, true);
	}
}

technique t0_l3_ds
<
	CREATE_VERTEX_DECLARATION_UNDERGROWTH
>
{
	pass Normal
	{
		GET_RENDERSTATES_UNDERGROWTH
		VertexShader = compile vs_3_0 Undergrowth_VS(3, true);
		PixelShader = compile ps_3_0 Undergrowth_PS(false, true);
	}
}

technique t0_l4_ds
<
	CREATE_VERTEX_DECLARATION_UNDERGROWTH
>
{
	pass Normal
	{
		GET_RENDERSTATES_UNDERGROWTH
		VertexShader = compile vs_3_0 Undergrowth_VS(4, true);
		PixelShader = compile ps_3_0 Undergrowth_PS(false, true);
	}
}

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

	float2 Tex0 : TEXCOORD1;
	float4 ShadowTex : TEXCOORD2;

	float4 Color : TEXCOORD3;
	float4 TerrainLightMap : TEXCOORD4;
	float4 TerrainColorMap : TEXCOORD5;
};

VS2PS_Simple Undergrowth_Simple_VS(APP2VS_Simple Input, uniform int LightCount, uniform bool ShadowMapEnable)
{
	VS2PS_Simple Output = (VS2PS_Simple)0;

	float4 Pos = GetUndergrowthPos(Input.Pos, Input.Packed);
	Output.HPos = mul(Pos, _WorldViewProj);
	Output.Pos.xyz = Pos.xyz;
	Output.Pos.w = Output.HPos.w; // Output depth

	Output.Tex0 = Input.Tex0 / 32767.0;
	Output.ShadowTex = (ShadowMapEnable) ? GetShadowProjection(Pos) : 0.0;

	float3 Light = 0.0;
	for (int i = 0; i < LightCount; i++)
	{
		float3 LightVec = Pos.xyz - _PointLightPosAtten[i].xyz;
		float Attenuation = GetLightAttenuation(LightVec, _PointLightPosAtten[i].w);
		Light += (Attenuation * _PointLightColor[i]);
	}

	Output.Color.rgb = saturate(Light);
	Output.Color.a = Input.Packed.w * 0.5;
	Output.TerrainColorMap = saturate(Input.TerrainColorMap);
	Output.TerrainLightMap = saturate(Input.TerrainLightMap);

	return Output;
}

PS2FB Undergrowth_Simple_PS(VS2PS_Simple Input, uniform bool PointLightEnable, uniform bool ShadowMapEnable)
{
	PS2FB Output;

	float3 LocalPos = Input.Pos.xyz;

	float4 Base = tex2D(SampleColorMap, Input.Tex0.xy);
	float4 TerrainColor = Input.TerrainColorMap;
	float3 TerrainLightMap = Input.TerrainLightMap;
	float4 TerrainShadow = (ShadowMapEnable) ? GetShadowFactor(SampleShadowMap, Input.ShadowTex) : 1.0;

	// If thermals assume gray color
	if (FogColor.r < 0.01)
	{
		TerrainColor.rgb = 1.0 / 3.0;
	}

	TerrainColor.rgb = lerp(TerrainColor.rgb, 1.0, Input.Color.a);
	float3 PointColor = (PointLightEnable) ? Input.Color.rgb : 0.0;
	float3 TerrainLight = _GIColor.rgb * TerrainLightMap.z;
	TerrainLight += ((_SunColor.rgb * (TerrainShadow.rgb * TerrainLightMap.y)) + PointColor) * 2.0;

	float4 OutputColor = 0.0;
	OutputColor.rgb = ((Base.rgb * TerrainColor.rgb) * TerrainLight.rgb) * 2.0;
	OutputColor.a = Base.a * (_Transparency_x8.a * 8.0);

	ApplyFog(OutputColor.rgb, GetFogValue(LocalPos, _CameraPos));

	Output.Color = OutputColor;
	Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);

	return Output;
}

// { StreamNo, DataType, Usage, UsageIdx }
// DECLARATION_END => End macro
#define CREATE_VERTEX_DECLARATION_UNDERGROWTH_SIMPLE \
	int Declaration[] = \
	{ \
		{ 0, D3DDECLTYPE_SHORT4, D3DDECLUSAGE_POSITION, 0 }, \
		{ 0, D3DDECLTYPE_SHORT2, D3DDECLUSAGE_TEXCOORD, 0 }, \
		{ 0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 0 }, \
		{ 0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 1 }, \
		{ 0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 2 }, \
		DECLARATION_END \
	}; \

#define GET_RENDERSTATES_UNDERGROWTH_SIMPLE \
	CullMode = CW; \
	AlphaTestEnable = TRUE; \
	AlphaRef = FH2_ALPHAREF; \
	AlphaFunc = GREATER; \
	ZFunc = LESS; \
	SRGBWriteEnable = FALSE; \

technique t0_l0_simple
<
	CREATE_VERTEX_DECLARATION_UNDERGROWTH_SIMPLE
>
{
	pass Normal
	{
		GET_RENDERSTATES_UNDERGROWTH_SIMPLE
		VertexShader = compile vs_3_0 Undergrowth_Simple_VS(0, false);
		PixelShader = compile ps_3_0 Undergrowth_Simple_PS(false, false);
	}
}

technique t0_l1_simple
<
	CREATE_VERTEX_DECLARATION_UNDERGROWTH_SIMPLE
>
{
	pass Normal
	{
		GET_RENDERSTATES_UNDERGROWTH_SIMPLE
		VertexShader = compile vs_3_0 Undergrowth_Simple_VS(1, false);
		PixelShader = compile ps_3_0 Undergrowth_Simple_PS(true, false);
	}
}

technique t0_l2_simple
<
	CREATE_VERTEX_DECLARATION_UNDERGROWTH_SIMPLE
>
{
	pass Normal
	{
		GET_RENDERSTATES_UNDERGROWTH_SIMPLE
		VertexShader = compile vs_3_0 Undergrowth_Simple_VS(2, false);
		PixelShader = compile ps_3_0 Undergrowth_Simple_PS(true, false);
	}
}

technique t0_l3_simple
<
	CREATE_VERTEX_DECLARATION_UNDERGROWTH_SIMPLE
>
{
	pass Normal
	{
		GET_RENDERSTATES_UNDERGROWTH_SIMPLE
		VertexShader = compile vs_3_0 Undergrowth_Simple_VS(3, false);
		PixelShader = compile ps_3_0 Undergrowth_Simple_PS(true, false);
	}
}

technique t0_l4_simple
<
	CREATE_VERTEX_DECLARATION_UNDERGROWTH_SIMPLE
>
{
	pass Normal
	{
		GET_RENDERSTATES_UNDERGROWTH_SIMPLE
		VertexShader = compile vs_3_0 Undergrowth_Simple_VS(4, false);
		PixelShader = compile ps_3_0 Undergrowth_Simple_PS(true, false);
	}
}

technique t0_l0_ds_simple
<
	CREATE_VERTEX_DECLARATION_UNDERGROWTH_SIMPLE
>
{
	pass Normal
	{
		GET_RENDERSTATES_UNDERGROWTH_SIMPLE
		VertexShader = compile vs_3_0 Undergrowth_Simple_VS(0, true);
		PixelShader = compile ps_3_0 Undergrowth_Simple_PS(false, true);
	}
}

technique t0_l1_ds_simple
<
	CREATE_VERTEX_DECLARATION_UNDERGROWTH_SIMPLE
>
{
	pass Normal
	{
		GET_RENDERSTATES_UNDERGROWTH_SIMPLE
		VertexShader = compile vs_3_0 Undergrowth_Simple_VS(1, true);
		PixelShader = compile ps_3_0 Undergrowth_Simple_PS(true, true);
	}
}

technique t0_l2_ds_simple
<
	CREATE_VERTEX_DECLARATION_UNDERGROWTH_SIMPLE
>
{
	pass Normal
	{
		GET_RENDERSTATES_UNDERGROWTH_SIMPLE
		VertexShader = compile vs_3_0 Undergrowth_Simple_VS(2, true);
		PixelShader = compile ps_3_0 Undergrowth_Simple_PS(true, true);
	}
}

technique t0_l3_ds_simple
<
	CREATE_VERTEX_DECLARATION_UNDERGROWTH_SIMPLE
>
{
	pass Normal
	{
		GET_RENDERSTATES_UNDERGROWTH_SIMPLE
		VertexShader = compile vs_3_0 Undergrowth_Simple_VS(3, true);
		PixelShader = compile ps_3_0 Undergrowth_Simple_PS(true, true);
	}
}

technique t0_l4_ds_simple
<
	CREATE_VERTEX_DECLARATION_UNDERGROWTH_SIMPLE
>
{
	pass Normal
	{
		GET_RENDERSTATES_UNDERGROWTH_SIMPLE
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
	float3 Tex0 : TEXCOORD0;
};

VS2PS_ZOnly Undergrowth_ZOnly_VS(APP2VS Input)
{
	VS2PS_ZOnly Output = (VS2PS_ZOnly)0;

	float4 Pos = GetUndergrowthPos(Input.Pos, Input.Packed);
	Output.HPos = mul(Pos, _WorldViewProj);
	Output.Tex0.xy = Input.Tex0 / 32767.0;
	Output.Tex0.z = Output.HPos.w; // Output depth

	return Output;
}

PS2FB Undergrowth_ZOnly_PS(VS2PS_ZOnly Input)
{
	PS2FB Output;

	float4 OutputColor = tex2D(SampleColorMap, Input.Tex0.xy);
	OutputColor.a *= (_Transparency_x8.a * 8.0);

	Output.Color = OutputColor;
	Output.Depth = ApplyLogarithmicDepth(Input.Tex0.z);

	return Output;
}

// { StreamNo, DataType, Usage, UsageIdx }
// DECLARATION_END => End macro
#define CREATE_VERTEX_DECLARATION_UNDERGROWTH_ZONLY \
	int Declaration[] = \
	{ \
		{ 0, D3DDECLTYPE_SHORT4, D3DDECLUSAGE_POSITION, 0 }, \
		{ 0, D3DDECLTYPE_SHORT2, D3DDECLUSAGE_TEXCOORD, 0 }, \
		{ 0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 0 }, \
		DECLARATION_END \
	}; \

#define GET_RENDERSTATES_UNDERGROWTH_ZONLY \
	CullMode = CW; \
	AlphaTestEnable = TRUE; \
	AlphaRef = FH2_ALPHAREF; \
	AlphaFunc = GREATER; \
	ColorWriteEnable = 0; \
	ZFunc = LESS; \
	SRGBWriteEnable = FALSE; \

technique ZOnly
<
	CREATE_VERTEX_DECLARATION_UNDERGROWTH_ZONLY
>
{
	pass Normal
	{
		GET_RENDERSTATES_UNDERGROWTH_ZONLY
		VertexShader = compile vs_3_0 Undergrowth_ZOnly_VS();
		PixelShader = compile ps_3_0 Undergrowth_ZOnly_PS();
	}
}

technique ZOnly_Simple
<
	CREATE_VERTEX_DECLARATION_UNDERGROWTH_ZONLY
>
{
	pass Normal
	{
		GET_RENDERSTATES_UNDERGROWTH_ZONLY
		VertexShader = compile vs_3_0 Undergrowth_ZOnly_VS();
		PixelShader = compile ps_3_0 Undergrowth_ZOnly_PS();
	}
}
