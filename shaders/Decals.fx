#line 2 "Decals.fx"

/*
	Description: Renders decals such as bullet holes
*/

#include "shaders/RealityGraphics.fxh"
#include "shaders/RaCommon.fxh"

/*
	[Attributes from app]
*/

uniform float4x4 _WorldViewProjection : WorldViewProjection;
uniform float4x3 _InstanceTransformations[10]: InstanceTransformations;
uniform float4x4 _ShadowTransformations[10] : ShadowTransformations;
uniform float4 _ShadowViewPortMaps[10] : ShadowViewPortMaps;

// offset x/y heightmapsize z / hemilerpbias w
// uniform float4 _HemiMapInfo : HemiMapInfo;
// uniform float4 _SkyColor : SkyColor;
uniform float4 _AmbientColor : AmbientColor;
uniform float4 _SunColor : SunColor;
uniform float4 _SunDirection : SunDirection;
uniform float2 _DecalFadeDistanceAndInterval : DecalFadeDistanceAndInterval = float2(100.0, 30.0);

/*
	[Textures and samplers]
*/

#define CREATE_SAMPLER(SAMPLER_NAME, TEXTURE, ADDRESS) \
	sampler SAMPLER_NAME = sampler_state \
	{ \
		Texture = (TEXTURE); \
		MinFilter = LINEAR; \
		MagFilter = LINEAR; \
		MipFilter = LINEAR; \
		AddressU = ADDRESS; \
		AddressV = ADDRESS; \
	};

uniform texture Tex0: TEXLAYER0;
CREATE_SAMPLER(SampleTex0, Tex0, CLAMP)

uniform texture Tex1: HemiMapTexture;

uniform texture DecalShadowMap: ShadowMapTex;
CREATE_SAMPLER(SampleDecalShadowMap, DecalShadowMap, CLAMP)

uniform texture DecalShadowMapOccluder: ShadowMapOccluderTex;
CREATE_SAMPLER(SampleDecalShadowMapOccluder, DecalShadowMapOccluder, CLAMP)

struct APP2VS
{
	float4 Pos : POSITION;
	float4 P_Tex_Index_Alpha : TEXCOORD0; // .xy = Tex; .z = Index; .w = Alpha;
	float4 Normal : NORMAL;
	float4 Color : COLOR;
};

struct VS2PS
{
	float4 HPos : POSITION;
	float4 Pos : TEXCOORD0;
	float3 Normal : TEXCOORD1;

	float2 Tex0 : TEXCOORD2;

	// Shadow attributes
	float4 ShadowTex : TEXCOORD3;
	float4 ViewPortMap : TEXCOORD4;

	float4 Color : TEXCOORD5;
};

struct PS2FB
{
	float4 Color : COLOR;
	#if defined(LOG_DEPTH)
		float Depth : DEPTH;
	#endif
};

VS2PS GetVertexDecals(APP2VS Input, bool UseShadow)
{
	VS2PS Output = (VS2PS)0;

	Output.Tex0 = Input.P_Tex_Index_Alpha.xy;

	float Index = Input.P_Tex_Index_Alpha.z;
	float4x3 WorldMat = _InstanceTransformations[Index];
	float3 WorldPos = mul(Input.Pos, WorldMat);

	Output.HPos = mul(float4(WorldPos, 1.0), _WorldViewProjection);
	Output.Pos = Output.HPos;
	#if defined(LOG_DEPTH)
		Output.Pos.w = Output.HPos.w + 1.0; // Output depth
	#endif

	Output.Normal = normalize(mul(Input.Normal.xyz, (float3x3)WorldMat));

	float Alpha = Input.P_Tex_Index_Alpha.w;
	Output.Color.rgb = saturate(Input.Color);
	Output.Color.a = 1.0 - saturate((Output.HPos.z - _DecalFadeDistanceAndInterval.x) / _DecalFadeDistanceAndInterval.y);
	Output.Color.a = saturate(Alpha * Output.Color.a);

	if (UseShadow)
	{
		Output.ShadowTex = mul(float4(WorldPos, 1.0), _ShadowTransformations[Index]);
		Output.ViewPortMap = _ShadowViewPortMaps[Index];
	}

	return Output;
}

VS2PS Decals_VS(APP2VS Input)
{
	return GetVertexDecals(Input, false);
}

float4 GetPixelDecals(VS2PS Input, bool UseShadow)
{
	float DirShadow = 1.0;

	if(UseShadow)
	{
		float4 Samples;
		float2 Texel = 1.0 / 1024.0;
		Input.ShadowTex.xy = clamp(Input.ShadowTex.xy,  Input.ViewPortMap.xy, Input.ViewPortMap.zw);
		Samples.x = tex2D(SampleDecalShadowMap, Input.ShadowTex.xy);
		Samples.y = tex2D(SampleDecalShadowMap, Input.ShadowTex.xy + float2(Texel.x, 0.0));
		Samples.z = tex2D(SampleDecalShadowMap, Input.ShadowTex.xy + float2(0.0, Texel.y));
		Samples.w = tex2D(SampleDecalShadowMap, Input.ShadowTex.xy + Texel);
		float4 Cmpbits = Samples >= saturate(Input.ShadowTex.z);
		DirShadow = dot(Cmpbits, 0.25);
	}

	float4 DiffuseMap = tex2D(SampleTex0, Input.Tex0);
	float3 Normals = normalize(Input.Normal.xyz);
	float3 Diffuse = LambertLighting(Normals, -_SunDirection.xyz) * _SunColor * DirShadow;

	float3 Lighting = (_AmbientColor.rgb + Diffuse) * Input.Color.rgb;
	float4 OutputColor = DiffuseMap * float4(Lighting, Input.Color.a);

	return OutputColor;
}

PS2FB Decals_PS(VS2PS Input)
{
	PS2FB Output = (PS2FB)0;

	Output.Color = GetPixelDecals(Input, false);

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);
	#endif

	ApplyFog(Output.Color.rgb, GetFogValue(Input.Pos, 0.0));

	return Output;
}

#define GET_RENDERSTATES_DECAL \
	CullMode = CW; \
	ZEnable = TRUE; \
	ZWriteEnable = FALSE; \
	AlphaTestEnable = TRUE; \
	AlphaRef = 0; \
	AlphaFunc = GREATER; \
	AlphaBlendEnable = TRUE; \
	SrcBlend = SRCALPHA; \
	DestBlend = INVSRCALPHA; \

technique Decal
<
	int Declaration[] =
	{
		// StreamNo, DataType, Usage, UsageIdx
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_POSITION, 0 },
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_NORMAL, 0 },
		{ 0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 0 },
		{ 0, D3DDECLTYPE_FLOAT4, D3DDECLUSAGE_TEXCOORD, 0 },
		DECLARATION_END	// End macro
	};
>
{
	pass Pass0
	{
		GET_RENDERSTATES_DECAL
		VertexShader = compile vs_3_0 Decals_VS();
		PixelShader = compile ps_3_0 Decals_PS();
	}

	pass Pass1
	{
		GET_RENDERSTATES_DECAL
		VertexShader = compile vs_3_0 Decals_VS();
		PixelShader = compile ps_3_0 Decals_PS();
	}
}
