
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
uniform float2 _DecalFadeDistanceAndInterval : DecalFadeDistanceAndInterval = float2(100.0f, 30.0f);

/*
	[Textures and samplers]
*/

#define CREATE_SAMPLER(SAMPLER_NAME, TEXTURE, ADDRESS, IS_SRGB) \
	sampler SAMPLER_NAME = sampler_state \
	{ \
		Texture = (TEXTURE); \
		MinFilter = LINEAR; \
		MagFilter = LINEAR; \
		MipFilter = LINEAR; \
		AddressU = ADDRESS; \
		AddressV = ADDRESS; \
		SRGBTexture = IS_SRGB; \
	};

uniform texture Tex0: TEXLAYER0;
uniform texture Tex1: HemiMapTexture;
// uniform texture ShadowMap: ShadowMapTex;
// uniform texture ShadowMapOccluder: ShadowMapOccluderTex;

CREATE_SAMPLER(SampleTex0, Tex0, CLAMP, FALSE)
// CREATE_SAMPLER(SampleShadowMap, ShadowMap, CLAMP, FALSE)
// CREATE_SAMPLER(SampleShadowMapOccluder, ShadowMapOccluder, CLAMP, FALSE)

struct APP2VS
{
	float4 Pos : POSITION;
	float4 P_Tex_Index_Alpha : TEXCOORD0; // .xy = Tex; .z = Index; .w = Alpha;
	float4 Normal : NORMAL;
	float4 Color : COLOR;
};

/*
	Regular decals shader
*/

struct VS2PS_Decals
{
	float4 HPos : POSITION;
	float2 Tex0 : TEXCOORD0;
	float3 ViewPos : TEXCOORD1;
	float3 WorldNormal : TEXCOORD2;
	float4 Color : TEXCOORD3;
};

VS2PS_Decals Decals_VS(APP2VS Input)
{
	VS2PS_Decals Output = (VS2PS_Decals)0;

	Output.Tex0 = Input.P_Tex_Index_Alpha.xy;

	float Index = Input.P_Tex_Index_Alpha.z;
	float4x3 WorldMat = _InstanceTransformations[Index];
	float3 WorldPos = mul(Input.Pos, WorldMat);

	Output.HPos = mul(float4(WorldPos, 1.0f), _WorldViewProjection);
	Output.ViewPos = Output.HPos.xyz;
	Output.WorldNormal = normalize(mul(Input.Normal.xyz, (float3x3)WorldMat));

	float Alpha = Input.P_Tex_Index_Alpha.w;
	Output.Color.rgb = saturate(Input.Color.rgb);
	Output.Color.a = 1.0f - saturate((Output.HPos.z - _DecalFadeDistanceAndInterval.x) / _DecalFadeDistanceAndInterval.y);
	Output.Color.a = saturate(Alpha * Output.Color.a);

	return Output;
}

float4 Decals_PS(VS2PS_Decals Input) : COLOR
{
	float4 DiffuseMap = tex2D(SampleTex0, Input.Tex0);
	float3 Normals = normalize(Input.WorldNormal.xyz);
	float3 Diffuse = LambertLighting(Normals, -_SunDirection.xyz) * _SunColor;

	float3 Lighting = (_AmbientColor.rgb + Diffuse) * Input.Color.rgb;
	float4 OutputColor = DiffuseMap * float4(Lighting, Input.Color.a);
	ApplyFog(OutputColor.rgb, GetFogValue(Input.ViewPos, 0.0));
	return OutputColor;
}

/*
	Shadowed decals shader
*/

struct VS2PS_ShadowedDecals
{
	float4 HPos : POSITION;
	float2 Tex0 : TEXCOORD0;
	float3 ViewPos : TEXCOORD1;
	float3 WorldNormal : TEXCOORD2;
	float4 Color : TEXCOORD3;

	// Shadow attributes
	float4 ShadowTex : TEXCOORD4;
	float4 ViewPortMap : TEXCOORD5;
};

VS2PS_ShadowedDecals ShadowedDecals_VS(APP2VS Input)
{
	VS2PS_ShadowedDecals Output = (VS2PS_ShadowedDecals)0;

	Output.Tex0 = Input.P_Tex_Index_Alpha.xy;

	float Index = Input.P_Tex_Index_Alpha.z;
	float4x3 WorldMat = _InstanceTransformations[Index];
	float3 WorldPos = mul(Input.Pos, WorldMat);

	Output.HPos = mul(float4(WorldPos, 1.0f), _WorldViewProjection);
	Output.ViewPos = Output.HPos.xyz;
	Output.WorldNormal = normalize(mul(Input.Normal.xyz, (float3x3)WorldMat));

	float Alpha = Input.P_Tex_Index_Alpha.w;
	Output.Color.rgb = saturate(Input.Color);
	Output.Color.a = 1.0f - saturate((Output.HPos.z - _DecalFadeDistanceAndInterval.x) / _DecalFadeDistanceAndInterval.y);
	Output.Color.a = saturate(Alpha * Output.Color.a);

	Output.ShadowTex = mul(float4(WorldPos, 1.0), _ShadowTransformations[Index]);
	Output.ViewPortMap = _ShadowViewPortMaps[Index];

	return Output;
}

float4 ShadowedDecals_PS(VS2PS_ShadowedDecals Input) : COLOR
{
	/*
		float4 Samples;
		float2 Texel = float2(1.0 / 1024.0, 1.0 / 1024.0);
		Input.ShadowTex.xy = clamp(Input.ShadowTex.xy,  Input.ViewPortMap.xy, Input.ViewPortMap.zw);
		Samples.x = tex2D(SampleShadowMap, Input.ShadowTex.xy);
		Samples.y = tex2D(SampleShadowMap, Input.ShadowTex.xy + float2(Texel.x, 0.0));
		Samples.z = tex2D(SampleShadowMap, Input.ShadowTex.xy + float2(0.0, Texel.y));
		Samples.w = tex2D(SampleShadowMap, Input.ShadowTex.xy + Texel);
		float4 Cmpbits = Samples >= saturate(Input.ShadowTex.z);
		float DirShadow = dot(Cmpbits, 0.25);
	*/

	float DirShadow = 1.0;
	float4 DiffuseMap = tex2D(SampleTex0, Input.Tex0);
	float3 Normals = normalize(Input.WorldNormal.xyz);
	float3 Diffuse = LambertLighting(Normals, -_SunDirection.xyz) * _SunColor * DirShadow;

	float3 Lighting = (_AmbientColor.rgb + Diffuse) * Input.Color.rgb;
	float4 OutputColor = DiffuseMap * float4(Lighting, Input.Color.a);
	ApplyFog(OutputColor.rgb, GetFogValue(Input.ViewPos, 0.0));
	return OutputColor;
}

#define DECAL_RENDERSTATES \
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
	pass p0
	{
		DECAL_RENDERSTATES
 		VertexShader = compile vs_3_0 Decals_VS();
		PixelShader = compile ps_3_0 Decals_PS();
	}

	pass p1
	{
		DECAL_RENDERSTATES
 		VertexShader = compile vs_3_0 Decals_VS();
		PixelShader = compile ps_3_0 Decals_PS();
	}
}
