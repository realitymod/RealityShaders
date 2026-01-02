#line 2 "SkinnedMesh.fx"

/*
    This shader builds shadow maps for skinned mesh objects (dynamic, human-like objects with bones). It performs bone skinning for up to 2 bones and generates shadow data used by RaShaderSM.fx for final rendering.
*/

#include "shaders/shared/RealityDepth.fxh"
#include "shaders/shared/RealityDirectXTK.fxh"
#include "shaders/shared/RealityPixel.fxh"
#if !defined(_HEADERS_)
	#include "shared/RealityDepth.fxh"
	#include "shared/RealityDirectXTK.fxh"
	#include "shared/RealityPixel.fxh"
#endif

// Note: obj space light vectors
float4 _SunLightDirection : SunLightDirection;
float4 _LightDirection : LightDirection;
float _NormalOffsetScale : NormalOffsetScale;

// Offset x/y _HemiMapInfo.z z / _HemiMapInfo.w w
float4 _HemiMapInfo : HemiMapInfo;

float4 _AmbientColor : AmbientColor;
float4 _LightColor : LightColor;
float4 _SkyColor : SkyColor;
float4 _SunColor : SunColor;

float4 _LightPosition : LightPosition;
float _AttenuationSqrInv : AttenuationSqrInv;

float _ShadowAlphaThreshold : SHADOWALPHATHRESHOLD;

float _ConeAngle : ConeAngle;
float4 _WorldEyePos : WorldEyePos;
float4 _ObjectEyePos : ObjectEyePos;

float4x4 _LightViewProj : LIGHTVIEWPROJ;
float4x4 _LightViewProj2 : LIGHTVIEWPROJ2;
float4x4 _LightViewProj3 : LIGHTVIEWPROJ3;
float4 _ViewportMap : VIEWPORTMAP;

dword _StencilRef : STENCILREF = 0;

float4x4 _World : World;
float4x4 _WorldT : WorldT;
float4x4 _WorldView : WorldView;
float4x4 _WorldViewI : WorldViewI; // (WorldViewIT)T = WorldViewI
float4x4 _WorldViewProjection : WorldViewProjection;
float4x3 _BoneArray[26] : BoneArray; // : register(c15) < bool sparseArray = true; int arrayStart = 15; >;

float4x4 _vpLightMat : vpLightMat;
float4x4 _vpLightTrapezMat : vpLightTrapezMat;

float4 _ParaboloidValues : ParaboloidValues;
float4 _ParaboloidZValues : ParaboloidZValues;

/*
	[Textures and Samplers]
*/

#define CREATE_SAMPLER(SAMPLER_NAME, TEXTURE, FILTER) \
	sampler SAMPLER_NAME = sampler_state \
	{ \
		Texture = (TEXTURE); \
		MinFilter = FILTER; \
		MagFilter = FILTER; \
		MipFilter = FILTER; \
	}; \

texture Tex0 : TEXLAYER0;
CREATE_SAMPLER(SampleTex0, Tex0, LINEAR)

texture Tex1 : TEXLAYER1;
CREATE_SAMPLER(SampleTex1, Tex1, LINEAR)

texture Tex2 : TEXLAYER2;
CREATE_SAMPLER(SampleTex2, Tex2, LINEAR)

texture Tex3 : TEXLAYER3;
CREATE_SAMPLER(SampleTex3, Tex3, LINEAR)

texture Tex4 : TEXLAYER4;

struct APP2VS
{
	float4 Pos : POSITION;
	float3 Normal : NORMAL;
	float BlendWeights : BLENDWEIGHT;
	float4 BlendIndices : BLENDINDICES;
	float2 TexCoord0 : TEXCOORD0;
};

/*
	Transformation functions
*/

// Outputs skinned data in object-space

struct SkinnedData
{
	float3 Pos;
	float3 Normal;
};

SkinnedData SkinSoldier(in APP2VS Input)
{
	SkinnedData Output = (SkinnedData)0.0;

	// Cast the vectors to arrays for use in the for loop below
	int4 IndexVector = D3DCOLORtoUBYTE4(Input.BlendIndices);
	float BlendWeightsArray[1] = (float[1])Input.BlendWeights;
	int IndexArray[4] = (int[4])IndexVector;

	float4x3 BoneMatrix = (float4x3)0.0;
	BoneMatrix += (_BoneArray[IndexArray[0]] * (BlendWeightsArray[0]));
	BoneMatrix += (_BoneArray[IndexArray[1]] * (1.0 - BlendWeightsArray[0]));

	Output.Pos = mul(Input.Pos, BoneMatrix);

	return Output;
}

/*
	Transforms object-space attributes into world-space
*/

float3 Ra_GetWorldLightDir(float3 ObjectLightVec)
{
	return mul(ObjectLightVec, (float3x3)_World);
}

float3 GetWorldViewVec(float3 WorldPos)
{
	return _WorldEyePos.xyz - WorldPos;
}

struct WorldSpace
{
	float3 Pos;
	float3 Normal;
	float3 LightDir;
	float3 ViewDir;
};

WorldSpace GetWorldSpaceData(float3 WorldPos, float3 TangentNormal)
{
	WorldSpace Output = (WorldSpace)0.0;

	Output.Pos = WorldPos;
	Output.LightDir = normalize(Ra_GetWorldLightDir(-_SunLightDirection.xyz));
	Output.ViewDir = normalize(GetWorldViewVec(WorldPos));

	Output.Normal = normalize(RGraphics_ConvertUNORMtoSNORM_FLT3(TangentNormal));
	Output.Normal = normalize(mul(Output.Normal, (float3x3)_World));

	return Output;
}

struct Lighting
{
	float Wrap;
	float Rim;
};

Lighting GetLighting(WorldSpace WS)
{
	Lighting Output = (Lighting)0.0;

	// Get dot-products
	float DotNL = dot(WS.Normal, WS.LightDir);
	float DotNV = dot(WS.Normal, WS.ViewDir);
	float DotLV = dot(WS.LightDir, WS.ViewDir);
	float IDotNV = 1.0 - DotNV;

	// Calculate lighting
	Output.Wrap = saturate((DotNL + 0.5) / 1.5);
	Output.Rim = pow(IDotNV, 3.0) * saturate(0.75 - saturate(DotLV));

	return Output;
}

/*
	[Shared functions]
*/

float GetHemiLerp(WorldSpace WS)
{
	return (RGraphics_ConvertSNORMtoUNORM_FLT1(WS.Normal.y)) - _HemiMapInfo.w;
}

/*
	Humanskin shader
*/

struct VS2PS_PreSkin
{
	float4 HPos : POSITION;
	float4 WorldPos : TEXCOORD0;
	float2 Tex0 : TEXCOORD1;
};

VS2PS_PreSkin VS_PreSkin(APP2VS Input)
{
	VS2PS_PreSkin Output = (VS2PS_PreSkin)0.0;

	// Object-space data
	SkinnedData Skin = SkinSoldier(Input);

	// World-space data
	float4 WorldPos = mul(Skin.Pos, (float3x4)_World);
	Output.WorldPos = WorldPos;

	Output.HPos.xy = Input.TexCoord0 * float2(2.0, -2.0) - float2(1.0, -1.0);
	Output.HPos.zw = float2(0.0, 1.0);

	// Get texcoord data
	Output.Tex0 = Input.TexCoord0;

	return Output;
}

float4 PS_PreSkin(VS2PS_PreSkin Input) : COLOR0
{
	// Tangent-space data
	float4 TangentNormal = tex2D(SampleTex0, Input.Tex0.xy);

	// World-space data
	WorldSpace WS = GetWorldSpaceData(Input.WorldPos.xyz, TangentNormal.xyz);

	// Get hemi data
	float2 HemiTex = RPixel_GetHemiTex(WS.Pos, WS.Normal, _HemiMapInfo.xyz, true);
	float4 HemiMap = tex2D(SampleTex1, HemiTex);

	// Get diffuse
	Lighting Diffuse = GetLighting(WS);
	float3 Lighting = (Diffuse.Wrap + Diffuse.Rim) * (HemiMap.a * HemiMap.a);

	return float4(Lighting, TangentNormal.a);
}

struct VS2PS_ShadowedPreSkin
{
	float4 HPos : POSITION;
	float4 WorldPos : TEXCOORD0;
	float2 Tex0 : TEXCOORD1;
	float4 ShadowTex : TEXCOORD2;
};

VS2PS_ShadowedPreSkin VS_ShadowedPreSkin(APP2VS Input)
{
	VS2PS_ShadowedPreSkin Output = (VS2PS_ShadowedPreSkin)0.0;

	// Object-space data
	SkinnedData Skin = SkinSoldier(Input);

	// World-space data
	float4 WorldPos = mul(Skin.Pos, (float3x4)_World);
	Output.WorldPos.xyz = WorldPos.xyz;

	// Get homogeneous-space data
	Output.HPos.xy = Input.TexCoord0 * float2(2.0, -2.0) - float2(1.0, -1.0);
	Output.HPos.zw = float2(0.0, 1.0);

	// Get texcoord data
	Output.Tex0 = Input.TexCoord0;
	Output.ShadowTex = mul(float4(Skin.Pos, 1.0), _LightViewProj);

	return Output;
}

float4 PS_ShadowedPreSkin(VS2PS_ShadowedPreSkin Input) : COLOR0
{
	// Tangent-space data
	float4 TangentNormal = tex2D(SampleTex0, Input.Tex0.xy);

	// World-space data
	WorldSpace WS = GetWorldSpaceData(Input.WorldPos.xyz, TangentNormal.xyz);

	float2 Texel = float2(1.0 / 1024.0, 1.0 / 1024.0);
	float4 Samples;
	// Input.ShadowTex.xy = clamp(Input.ShadowTex.xy, _ViewportMap.xy, _ViewportMap.zw);
	Samples.x = tex2D(SampleTex2, Input.ShadowTex.xy);
	Samples.y = tex2D(SampleTex2, Input.ShadowTex.xy + float2(Texel.x, 0.0));
	Samples.z = tex2D(SampleTex2, Input.ShadowTex.xy + float2(0.0, Texel.y));
	Samples.w = tex2D(SampleTex2, Input.ShadowTex.xy + Texel);
	float4 StaticSamples;
	StaticSamples.x = tex2D(SampleTex1, Input.ShadowTex.xy + float2(-Texel.x, -Texel.y * 2.0)).b;
	StaticSamples.y = tex2D(SampleTex1, Input.ShadowTex.xy + float2(Texel.x, -Texel.y * 2.0)).b;
	StaticSamples.z = tex2D(SampleTex1, Input.ShadowTex.xy + float2(-Texel.x, Texel.y * 2.0)).b;
	StaticSamples.w = tex2D(SampleTex1, Input.ShadowTex.xy + float2(Texel.x, Texel.y * 2.0)).b;
	StaticSamples.x = dot(StaticSamples.xyzw, 0.25);

	float4 CMPBits = Samples > saturate(Input.ShadowTex.z);
	float AvgShadowValue = dot(CMPBits, 0.25);
	float TotalShadow = AvgShadowValue.x * StaticSamples.x;

	Lighting Diffuse = GetLighting(WS);

	float4 OutputColor = 0.0;
	OutputColor.r = (Diffuse.Rim + Diffuse.Wrap);
	OutputColor.g = TotalShadow;
	OutputColor.b = saturate(TotalShadow + 0.35);
	OutputColor.a = TangentNormal.a;

	return OutputColor;
}

struct VS2PS_ApplySkin
{
	float4 HPos : POSITION;
	float4 WorldPos : TEXCOORD0;
	float2 Tex0 : TEXCOORD1;
};

VS2PS_ApplySkin VS_ApplySkin(APP2VS Input)
{
	VS2PS_ApplySkin Output = (VS2PS_ApplySkin)0.0;

	// Object-space data
	SkinnedData Skin = SkinSoldier(Input);

	// World-space data
	float4 WorldPos = mul(Skin.Pos, (float3x4)_World);
	Output.WorldPos.xyz = WorldPos.xyz;

	// Transform position into view and then projection space
	Output.HPos = mul(float4(Skin.Pos, 1.0), _WorldViewProjection);
	// Texcoord data
	Output.Tex0 = Input.TexCoord0;

	return Output;
}

float4 PS_ApplySkin(VS2PS_ApplySkin Input) : COLOR0
{
	// Tangent-space data
	float4 TangentNormal = tex2D(SampleTex1, Input.Tex0);
	float4 DiffuseMap = tex2D(SampleTex2, Input.Tex0);
	float4 DiffuseLight = tex2D(SampleTex3, Input.Tex0);

	// World-space data
	WorldSpace WS = GetWorldSpaceData(Input.WorldPos.xyz, TangentNormal.xyz);

	// Hemi-mapping
	float HemiLerp = GetHemiLerp(WS);
	float2 HemiTex = RPixel_GetHemiTex(WS.Pos, WS.Normal, _HemiMapInfo.xyz, true);
	float4 HemiMap = tex2D(SampleTex0, HemiTex);
	float4 HemiColor = lerp(HemiMap, _SkyColor, HemiLerp);

	// Get lighting data
	// NOTE: Glossmap is in the Diffuse alpha channel.
	float4 Ambient = _AmbientColor * HemiColor;
	float4 Diffuse = (DiffuseLight.r * DiffuseLight.b) * _SunColor;
	float ShadowIntensity = pow(saturate(DiffuseLight.g), 2.0);

	// Composite diffuse lighting
	RDirectXTK_ColorPair Light = RDirectXTK_ComputeLights(WS.Normal.xyz, WS.LightDir, WS.ViewDir);
	Light.Specular *= DiffuseMap.a * ShadowIntensity;
	float3 Lighting = saturate((DiffuseMap * (Ambient + Diffuse)) + Light.Specular);

	return float4(Lighting, DiffuseMap.a);
}

#define GET_RENDERSTATES_SKIN(CULLMODE) \
	CullMode = CULLMODE; \
	AlphaBlendEnable = FALSE; \
	StencilEnable = FALSE; \
	ZEnable = FALSE; \
	ZWriteEnable = FALSE; \
	ZFunc = PR_ZFUNC_WITHEQUAL; \

technique humanskin
{
	pass Pre
	{
		GET_RENDERSTATES_SKIN(NONE)
		VertexShader = compile vs_3_0 VS_PreSkin();
		PixelShader = compile ps_3_0 PS_PreSkin();
	}

	pass PreShadowed
	{
		GET_RENDERSTATES_SKIN(NONE)
		VertexShader = compile vs_3_0 VS_ShadowedPreSkin();
		PixelShader = compile ps_3_0 PS_ShadowedPreSkin();
	}

	pass Apply
	{
		GET_RENDERSTATES_SKIN(CCW)
		VertexShader = compile vs_3_0 VS_ApplySkin();
		PixelShader = compile ps_3_0 PS_ApplySkin();
	}
}

/*
	Shadowmap shaders
*/

struct VS2PS_ShadowMap
{
	float4 HPos : POSITION;
	float4 Tex0 : TEXCOORD0; // .xy = Tex0; .zw = ShadowMapDepth;
};

VS2PS_ShadowMap VS_ShadowMap(APP2VS Input)
{
	VS2PS_ShadowMap Output = (VS2PS_ShadowMap)0.0;

	// Cast the vectors to arrays for use in the for loop below
	int4 IndexVector = D3DCOLORtoUBYTE4(Input.BlendIndices);
	float BlendWeightsArray[1] = (float[1])Input.BlendWeights;
	int IndexArray[4] = (int[4])IndexVector;

	float4x3 BoneMat = (float4x3)0.0;
	BoneMat += (_BoneArray[IndexArray[0]] * (BlendWeightsArray[0]));
	BoneMat += (_BoneArray[IndexArray[1]] * (1.0 - BlendWeightsArray[0]));
	float4 BonePos = float4(mul(Input.Pos, BoneMat), 1.0);

	// Output shadow coordinates & depth
	Output.HPos = RDepth_GetMeshShadowProjection(BonePos, _vpLightTrapezMat, _vpLightMat, Output.Tex0.zw);

	// Texcoord data
	Output.Tex0.xy = Input.TexCoord0;

	return Output;
}

float4 PS_ShadowMap(VS2PS_ShadowMap Input) : COLOR0
{
	return Input.Tex0.z / Input.Tex0.w;
}

float4 PS_ShadowMap_Alpha(VS2PS_ShadowMap Input) : COLOR0
{
	float Alpha = tex2D(SampleTex0, Input.Tex0.xy).a - _ShadowAlphaThreshold;
	clip(Alpha);
	return Input.Tex0.z / Input.Tex0.w;
}

#define GET_RENDERSTATES_SHADOWMAP \
	CullMode = CW; \
	ZEnable = TRUE; \
	ZFunc = LESSEQUAL; \
	ZWriteEnable = TRUE; \
	ScissorTestEnable = TRUE; \
	AlphaBlendEnable = FALSE; \

technique DrawShadowMap
{
	pass DirectionalSpot
	{
		#if NVIDIA
			ColorWriteEnable = 0; // 0x0000000F;
		#endif

		GET_RENDERSTATES_SHADOWMAP
		VertexShader = compile vs_3_0 VS_ShadowMap();
		PixelShader = compile ps_3_0 PS_ShadowMap();
	}

	pass DirectionalSpotAlpha
	{
		#if NVIDIA
			ColorWriteEnable = 0; // 0x0000000F;
			AlphaTestEnable = TRUE;
			AlphaRef = 0;
		#endif

		GET_RENDERSTATES_SHADOWMAP
		VertexShader = compile vs_3_0 VS_ShadowMap();
		PixelShader = compile ps_3_0 PS_ShadowMap_Alpha();

	}

	pass Point_
	{
		#if NVIDIA
			ColorWriteEnable = 0; // 0x0000000F;
		#endif

		GET_RENDERSTATES_SHADOWMAP
		VertexShader = compile vs_3_0 VS_ShadowMap();
		PixelShader = compile ps_3_0 PS_ShadowMap();
	}
}

// We actually don't need to have 2 techniques here
// but it is kept for back-compatibility with original BF2
technique DrawShadowMapNV
{
	pass DirectionalSpot
	{
		#if NVIDIA
			ColorWriteEnable = 0; // 0x0000000F;
		#endif

		GET_RENDERSTATES_SHADOWMAP
		VertexShader = compile vs_3_0 VS_ShadowMap();
		PixelShader = compile ps_3_0 PS_ShadowMap();
	}

	pass DirectionalSpotAlpha
	{
		#if NVIDIA
			ColorWriteEnable = 0; // 0x0000000F;
			AlphaTestEnable = TRUE;
			AlphaRef = 0;
		#endif

		GET_RENDERSTATES_SHADOWMAP
		VertexShader = compile vs_3_0 VS_ShadowMap();
		PixelShader = compile ps_3_0 PS_ShadowMap_Alpha();

	}

	pass Point_
	{
		#if NVIDIA
			ColorWriteEnable = 0; // 0x0000000F;
		#endif

		GET_RENDERSTATES_SHADOWMAP
		VertexShader = compile vs_3_0 VS_ShadowMap();
		PixelShader = compile ps_3_0 PS_ShadowMap();
	}
}
