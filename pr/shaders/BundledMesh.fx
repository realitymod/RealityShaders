
/*
	Include header files
*/

#include "shaders/RealityGraphics.fxh"
#include "shaders/shared/RealityDepth.fxh"
#include "shaders/shared/RealityDirectXTK.fxh"
#include "shaders/shared/RealityVertex.fxh"
#if !defined(INCLUDED_HEADERS)
	#include "RealityGraphics.fxh"
	#include "shared/RealityDepth.fxh"
	#include "shared/RealityDirectXTK.fxh"
	#include "shared/RealityVertex.fxh"
#endif

/*
	Description:
	- Builds shadow and environment maps for bundledmesh (dynamic, nonhuman objects)
	- Outputs used in RaShaderBM.fx
*/

/*
	[Attributes from app]
*/

uniform float4 _AmbientColor : Ambient = { 0.0, 0.0, 0.0, 1.0 };
uniform float4 _DiffuseColor : Diffuse = { 1.0, 1.0, 1.0, 1.0 };
uniform float4 _SpecularColor : Specular = { 0.0, 0.0, 0.0, 1.0 };

uniform float4 _SkyColor : SkyColor;
uniform float4 _AmbientColor2 : AmbientColor;
uniform float4 _SunColor : SunColor;

uniform float _AttenuationSqrInv : AttenuationSqrInv;
uniform float4 _LightColor : LightColor;
uniform float _ConeAngle : ConeAngle;

uniform float4x3 _MatOneBoneSkinning[26]: matONEBONESKINNING; // : register(c15) < bool sparseArray = true; int arrayStart = 15; >;
uniform float4x4 _ViewProjMatrix : WorldViewProjection; // : register(vs_1_1, c0);
uniform float4x4 _ViewInverseMatrix : ViewI; //: register(vs_1_1, c8);
uniform float4x4 _ViewMatrix : ViewMatrix;
uniform float4x4 _ViewITMatrix : ViewITMatrix;
uniform float4 _EyePos : EYEPOS = { 0.0, 0.0, 1.0, 0.25 };

uniform float4 _PosUnpack : POSUNPACK;
uniform float2 _TexProjOffset : TEXPROJOFFSET;

uniform float2 _ZLimitsInv : ZLIMITSINV;

uniform float4x4 _vpLightMat : vpLightMat;
uniform float4x4 _vpLightTrapezMat : vpLightTrapezMat;
uniform float _ShadowAlphaThreshold : SHADOWALPHATHRESHOLD;
uniform float4x4 _LightViewProj : LIGHTVIEWPROJ;

uniform dword _DwordStencilRef : STENCILREF = 0;
uniform bool _AlphaBlendEnable: AlphaBlendEnable;
uniform float _AltitudeFactor : ALTITUDEFACTOR = 0.7;

uniform float4 _ViewportMap : VIEWPORTMAP;
uniform float4x4 _ViewPortMatrix: _ViewPortMatrix;
uniform float4 _ViewportMap2: ViewportMap;

uniform float4 _Attenuation : Attenuation;
uniform float4 _LightPosition : LightPosition;
uniform float4 _LightDirection : LightDirection;

// offset x/y HeightmapSize z / HemiLerpBias w
uniform float4 _HemiMapInfo : HemiMapInfo;
// float _HeightmapSize : HeightmapSize;
// float _HemiLerpBias : HemiLerpBias;

uniform float _NormalOffsetScale : NormalOffsetScale;

uniform float4 _ParaboloidValues : ParaboloidValues;
uniform float4 _ParaboloidZValues : ParaboloidZValues;

uniform float4x3 _UVMatrix[8]: UVMatrix;

/*
	[Textures and Samplers]
*/

#define CREATE_SAMPLER(SAMPLER_NAME, TEXTURE, FILTER, ADDRESS) \
	sampler SAMPLER_NAME = sampler_state \
	{ \
		Texture = (TEXTURE); \
		MinFilter = FILTER; \
		MagFilter = FILTER; \
		MipFilter = FILTER; \
		AddressU = ADDRESS; \
		AddressV = ADDRESS; \
	};

uniform texture Tex0: TEXLAYER0;
CREATE_SAMPLER(SampleTex0, Tex0, LINEAR, CLAMP)
CREATE_SAMPLER(SampleDiffuseMap, Tex0, LINEAR, WRAP)

uniform texture Tex1: TEXLAYER1;
CREATE_SAMPLER(SampleTex1, Tex1, LINEAR, CLAMP)
CREATE_SAMPLER(SampleNormalMap, Tex1, LINEAR, WRAP)

uniform texture Tex2: TEXLAYER2;
CREATE_SAMPLER(SampleTex2, Tex2, LINEAR, CLAMP)
CREATE_SAMPLER(SampleColorLUT, Tex2, LINEAR, CLAMP)

uniform texture Tex3: TEXLAYER3;
CREATE_SAMPLER(SampleCubeTex3, Tex3, LINEAR, WRAP)

uniform texture Tex4: TEXLAYER4;

/*
	SHADOW BUFFER DATA

	uniform texture ShadowMap: ShadowMapTex;
	uniform texture ShadowMapOccluder : ShadowMapOccluderTex;

	CREATE_SAMPLER(SampleShadowMap, ShadowMap, LINEAR, CLAMP,  FALSE)
	CREATE_SAMPLER(SampleShadowMapOccluder, ShadowMapOccluder, LINEAR, CLAMP,  FALSE)
*/

struct APP2VS
{
	float4 Pos : POSITION;
	float3 Normal : NORMAL;
	float4 BlendIndices : BLENDINDICES;
	float2 TexCoord : TEXCOORD0;
	float3 Tan : TANGENT;
	float3 Binorm : BINORMAL;
};

/*
	Blinn-specular-bumpmap shaders
*/

struct VS2PS_Specular
{
	float4 HPos : POSITION;
	float2 Tex : TEXCOORD0;
	float3 WorldPos : TEXCOORD1;
	float3 WorldTangent : TEXCOORD2;
	float3 WorldBinormal : TEXCOORD3;
	float3 WorldNormal : TEXCOORD4;
};

VS2PS_Specular VS_Lighting(APP2VS Input)
{
	VS2PS_Specular Output = (VS2PS_Specular)0;

	// Compensate for lack of UBYTE4 on Geforce3
	int4 IndexVector = D3DCOLORtoUBYTE4(Input.BlendIndices);
	int IndexArray[4] = (int[4])IndexVector;

	// Object-space data
	float3x3 ObjectTBN = GetTangentBasis(Input.Tan, Input.Normal, 1.0);

	// World-space data
	float4x3 SkinWorldMat = _MatOneBoneSkinning[IndexArray[0]];
	float3 WorldPos = mul(Input.Pos, SkinWorldMat);
	float3x3 WorldTBN = mul(ObjectTBN, (float3x3)SkinWorldMat);

	Output.WorldPos = WorldPos;
	Output.WorldTangent = WorldTBN[0];
	Output.WorldBinormal = WorldTBN[1];
	Output.WorldNormal = WorldTBN[2];

	Output.HPos = mul(float4(WorldPos.xyz, 1.0), _ViewProjMatrix);
	Output.Tex = Input.TexCoord;

	return Output;
}

float4 PS_Lighting(VS2PS_Specular Input) : COLOR0
{
	const float4 Ambient = float4(0.4, 0.4, 0.4, 1.0);

	// Texture data
	// What should we do with DiffuseMap.a now?
	float4 TangentNormal = tex2D(SampleNormalMap, Input.Tex);
	float4 DiffuseMap = tex2D(SampleDiffuseMap, Input.Tex);
	float Gloss = TangentNormal.a;

	// World-space data
	float3 WorldPos = Input.WorldPos;
	float3x3 WorldTBN =
	{
		normalize(Input.WorldTangent),
		normalize(Input.WorldBinormal),
		normalize(Input.WorldNormal)
	};

	// World-space positions
	float3 MatsLightDir = float3(0.5, 0.5, 0.0);
	float3 WorldEyeVec = _ViewInverseMatrix[3].xyz - WorldPos;

	// Transform vectors from world space to tangent space
	float3 WorldLightDir = normalize(MatsLightDir);
	float3 WorldViewDir = normalize(WorldEyeVec);
	float3 WorldNormal = normalize((TangentNormal * 2.0) - 1.0);
	WorldNormal = normalize(mul(WorldNormal, WorldTBN));

	// Get lighting data
	ColorPair Light = ComputeLights(WorldNormal, WorldLightDir, WorldViewDir);
	float3 Diffuse = DiffuseMap * (Ambient + Light.Diffuse);
	float3 Specular = Light.Specular * Gloss;
	float3 Lighting = saturate(Diffuse + Specular);

	return float4(Lighting, DiffuseMap.a);
}

technique Full
{
	pass p0
	{
		VertexShader = compile vs_3_0 VS_Lighting();
		PixelShader = compile ps_3_0 PS_Lighting();
	}
}

/*
	Diffuse map shaders
*/

struct VS2PS_Diffuse
{
	float4 HPos : POSITION;
	float2 Tex0 : TEXCOORD0;
	float3 WorldNormal : TEXCOORD1;
};

VS2PS_Diffuse VS_Diffuse(APP2VS Input)
{
	VS2PS_Diffuse Output = (VS2PS_Diffuse)0;

	// Compensate for lack of UBYTE4 on Geforce3
	int4 IndexVector = D3DCOLORtoUBYTE4(Input.BlendIndices);
	int IndexArray[4] = (int[4])IndexVector;

	// World-space data
	float4x3 SkinWorldMat = _MatOneBoneSkinning[IndexArray[0]];
	float3 WorldPos = mul(Input.Pos, SkinWorldMat);
	float3 WorldNormal = mul(Input.Normal, (float3x3)SkinWorldMat);
	Output.WorldNormal = normalize(WorldNormal);

	Output.HPos = mul(float4(WorldPos, 1.0), _ViewProjMatrix);

	// Get texcoord data
	Output.Tex0 = Input.TexCoord;

	return Output;
}

float4 PS_Diffuse(VS2PS_Diffuse Input) : COLOR0
{
	// Constants
	const float4 Ambient = 0.8;
	const float3 MatsLightDir = float3(0.2, 0.8, -0.2);

	// World-space data
	float3 WorldNormal = normalize(Input.WorldNormal);
	float3 WorldLightDir = normalize(-MatsLightDir);

	// Get lighting data
	float4 DiffuseMap = tex2D(SampleDiffuseMap, Input.Tex0);
	float3 DotNL = GetDot(WorldNormal, WorldLightDir) + Ambient;
	float4 Lighting = DiffuseMap * float4(DotNL, 1.0);

	return Lighting;
}

technique t1
{
	pass p0
	{
		ZEnable = TRUE;
		ZWriteEnable = TRUE;

		AlphaBlendEnable = FALSE;
		AlphaTestEnable = TRUE;
		AlphaRef = 0;
		AlphaFunc = GREATER;

		VertexShader = compile vs_3_0 VS_Diffuse();
		PixelShader = compile ps_3_0 PS_Diffuse();
	}
}

/*
	Alpha environment map shaders
*/

struct VS2PS_Alpha
{
	float4 HPos : POSITION;
	float2 Tex0 : TEXCOORD0;
	float4 ProjTex : TEXCOORD1;
};

VS2PS_Alpha VS_Alpha(APP2VS Input)
{
	VS2PS_Alpha Output;

	// Compensate for lack of UBYTE4 on Geforce3
	int4 IndexVector = D3DCOLORtoUBYTE4(Input.BlendIndices);
	int IndexArray[4] = (int[4])IndexVector;

	// World-space data
	float4x3 SkinWorldMat = _MatOneBoneSkinning[IndexArray[0]];
	float3 WorldPos = mul(Input.Pos, SkinWorldMat);
	Output.HPos = mul(float4(WorldPos, 1.0), _ViewProjMatrix);

	// Get texcoord data
	Output.Tex0 = Input.TexCoord.xy;
	Output.ProjTex.xy = ((Output.HPos.xy / Output.HPos.w) * 0.5) + 0.5;
	Output.ProjTex.y = 1.0 - Output.ProjTex.y;
	Output.ProjTex.xy = (Output.ProjTex.xy + _TexProjOffset) * Output.HPos.w;
	Output.ProjTex.zw = Output.HPos.zw;

	return Output;
}

float4 PS_Alpha(VS2PS_Alpha Input) : COLOR0
{
	// Texture data
	float4 DiffuseMap = tex2D(SampleTex0, Input.Tex0);
	float4 ProjLight = tex2Dproj(SampleTex1, Input.ProjTex);

	// Composite lighting
	float4 Lighting = 0.0;
	Lighting.rgb = (DiffuseMap.rgb * ProjLight.rgb) + ProjLight.a;

	return Lighting;
}

/*
	Alpha environment map shaders
*/

struct VS2PS_EnvMap_Alpha
{
	float4 HPos : POSITION;
	float2 Tex : TEXCOORD0;
	float4 ProjTex : TEXCOORD1;
	float3 WorldPos : TEXCOORD2;
	float3 WorldTangent : TEXCOORD3;
	float3 WorldBiNormal : TEXCOORD4;
	float3 WorldNormal : TEXCOORD5;
};

VS2PS_EnvMap_Alpha VS_EnvMap_Alpha(APP2VS Input)
{
	VS2PS_EnvMap_Alpha Output = (VS2PS_EnvMap_Alpha)0;

	// Compensate for lack of UBYTE4 on Geforce3
	int4 IndexVector = D3DCOLORtoUBYTE4(Input.BlendIndices);
	int IndexArray[4] = (int[4])IndexVector;

	// Object-space data
	float3x3 ObjectTBN = GetTangentBasis(Input.Tan, Input.Normal, 1.0);

	// World-space data
	float4x3 SkinWorldMat = _MatOneBoneSkinning[IndexArray[0]];
	float3 WorldPos = mul(Input.Pos, SkinWorldMat);
	float3x3 WorldTBN = mul(ObjectTBN, (float3x3)SkinWorldMat);
	Output.WorldPos = WorldPos;
	Output.WorldTangent = WorldTBN[0];
	Output.WorldBiNormal = WorldTBN[1];
	Output.WorldNormal = WorldTBN[2];

	// Get homogeneous-space data
	Output.HPos = mul(float4(WorldPos, 1.0), _ViewProjMatrix);

	// Get texcoord data
	Output.Tex = Input.TexCoord;
	Output.ProjTex.xy = ((Output.HPos.xy / Output.HPos.w) * 0.5) + 0.5;
	Output.ProjTex.y = 1.0 - Output.ProjTex.y;
	Output.ProjTex.xy = (Output.ProjTex.xy + _TexProjOffset) * Output.HPos.w;
	Output.ProjTex.zw = Output.HPos.zw;

	return Output;
}

float4 PS_EnvMap_Alpha(VS2PS_EnvMap_Alpha Input) : COLOR0
{
	// Tangent-space data
	float4 DiffuseMap = tex2D(SampleTex0, Input.Tex);
	float4 AccumLight = tex2Dproj(SampleTex1, Input.ProjTex);
	float4 TangentNormal = tex2D(SampleTex2, Input.Tex);

	// Get world-space data
	float Reflection = _EyePos.w;
	float3 WorldPos = Input.WorldPos;
	float3 WorldViewDir = normalize(WorldPos.xyz - _EyePos.xyz);
	float3x3 WorldTBN =
	{
		normalize(Input.WorldTangent),
		normalize(Input.WorldBiNormal),
		normalize(Input.WorldNormal)
	};

	float3 WorldNormal = normalize((TangentNormal * 2.0) - 1.0);
	WorldNormal = normalize(mul(WorldNormal, WorldTBN));

	// Get reflection data
	float3 EnvMapTex = reflect(WorldViewDir, WorldNormal);
	float3 EnvMap = texCUBE(SampleCubeTex3, EnvMapTex) * (Reflection * TangentNormal.a);
	float3 Lighting = ((DiffuseMap.rgb * AccumLight.rgb) + EnvMap) + AccumLight.a;

	return float4(Lighting, DiffuseMap.a);
}

#define GET_RENDERSTATES_ALPHA \
	ZEnable = TRUE; \
	ZWriteEnable = FALSE; \
	CullMode = NONE; \
	AlphaBlendEnable = TRUE; \
	SrcBlend = SRCALPHA; \
	DestBlend = INVSRCALPHA; \
	AlphaTestEnable = TRUE; \
	AlphaRef = 0; \
	AlphaFunc = GREATER; \

technique Alpha
{
	pass p0
	{
		GET_RENDERSTATES_ALPHA
		VertexShader = compile vs_3_0 VS_Alpha();
		PixelShader = compile ps_3_0 PS_Alpha();
	}

	pass p1_EnvMap
	{
		GET_RENDERSTATES_ALPHA
		VertexShader = compile vs_3_0 VS_EnvMap_Alpha();
		PixelShader = compile ps_3_0 PS_EnvMap_Alpha();
	}
}

/*
	Shadow map shaders
*/

struct VS2PS_ShadowMap
{
	float4 HPos : POSITION;
	float4 DepthPos : TEXCOORD0;
};

VS2PS_ShadowMap VS_ShadowMap(APP2VS Input)
{
	VS2PS_ShadowMap Output = (VS2PS_ShadowMap)0;

	// Compensate for lack of UBYTE4 on Geforce3
	int4 IndexVector = D3DCOLORtoUBYTE4(Input.BlendIndices);
	int IndexArray[4] = (int[4])IndexVector;

	float4 UnpackPos = float4(Input.Pos.xyz * _PosUnpack.xyz, 1.0);
	float4x3 SkinWorldMat = _MatOneBoneSkinning[IndexArray[0]];
	float4 WorldPos = float4(mul(UnpackPos, SkinWorldMat), 1.0);

	Output.HPos = GetMeshShadowProjection(WorldPos, _vpLightTrapezMat, _vpLightMat);
	Output.DepthPos = Output.HPos; // Output shadow depth

	return Output;
}

float4 PS_ShadowMap(VS2PS_ShadowMap Input) : COLOR0
{
	#if NVIDIA
		return 0.0;
	#else
		return Input.DepthPos.z / Input.DepthPos.w;
	#endif
}

struct VS2PS_ShadowMap_Alpha
{
	float4 HPos : POSITION;
	float4 DepthPos : TEXCOORD0;
	float2 Tex0 : TEXCOORD1;
};

VS2PS_ShadowMap_Alpha VS_ShadowMap_Alpha(APP2VS Input)
{
	VS2PS_ShadowMap_Alpha Output;

	// Compensate for lack of UBYTE4 on Geforce3
	int4 IndexVector = D3DCOLORtoUBYTE4(Input.BlendIndices);
	int IndexArray[4] = (int[4])IndexVector;

	// World-space data
	float4 UnpackPos = Input.Pos * _PosUnpack;
	float4x3 SkinWorldMat = _MatOneBoneSkinning[IndexArray[0]];
	float4 WorldPos = float4(mul(UnpackPos, SkinWorldMat), 1.0);

	// Light-space data
	Output.HPos = GetMeshShadowProjection(WorldPos, _vpLightTrapezMat, _vpLightMat);

	// Texcoord data
	Output.DepthPos = Output.HPos; // Output shadow depth
	Output.Tex0 = Input.TexCoord;

	return Output;
}

float4 PS_ShadowMap_Alpha(VS2PS_ShadowMap_Alpha Input) : COLOR0
{
	float Alpha = tex2D(SampleTex0, Input.Tex0).a - _ShadowAlphaThreshold;
	#if NVIDIA
		return Alpha;
	#else
		clip(Alpha);
		return Input.DepthPos.z / Input.DepthPos.w;
	#endif
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
			AlphaTestEnable = TRUE;
			AlphaRef = 0;
			ColorWriteEnable = 0; // 0x0000000F;
		#endif

		GET_RENDERSTATES_SHADOWMAP
		VertexShader = compile vs_3_0 VS_ShadowMap_Alpha();
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

	pass PointAlpha
	{
		#if NVIDIA
			ColorWriteEnable = 0; // 0x0000000F;
			AlphaTestEnable = TRUE;
			AlphaRef = 0;
		#endif

		GET_RENDERSTATES_SHADOWMAP
		VertexShader = compile vs_3_0 VS_ShadowMap_Alpha();
		PixelShader = compile ps_3_0 PS_ShadowMap_Alpha();
	}
}

// We actually don't need to have 2 techniques here
// but it is kept for back-compatibility with original BF2
technique DrawShadowMapNV
{
	pass DirectionalSpot
	{
		#if NVIDIA
			ColorWriteEnable = 0;//0x0000000F;
		#endif

		GET_RENDERSTATES_SHADOWMAP
		VertexShader = compile vs_3_0 VS_ShadowMap();
		PixelShader = compile ps_3_0 PS_ShadowMap();
	}

	pass DirectionalSpotAlpha
	{
		#if NVIDIA
			ColorWriteEnable = 0;//0x0000000F;
			AlphaTestEnable = TRUE;
			AlphaRef = 0;
		#endif

		GET_RENDERSTATES_SHADOWMAP
		VertexShader = compile vs_3_0 VS_ShadowMap_Alpha();
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

	pass PointAlpha
	{
		#if NVIDIA
			ColorWriteEnable = 0; // 0x0000000F;
			AlphaTestEnable = TRUE;
			AlphaRef = 0;
		#endif

		GET_RENDERSTATES_SHADOWMAP
		VertexShader = compile vs_3_0 VS_ShadowMap_Alpha();
		PixelShader = compile ps_3_0 PS_ShadowMap_Alpha();
	}
}