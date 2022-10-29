
/*
	Description:
	- Builds shadow and environment maps for bundledmesh (dynamic, nonhuman objects)
	- Outputs used in RaShaderBM.fx
*/

#include "shaders/RealityGraphics.fx"

/*
	[Attributes from app]
*/

uniform float4 _AmbientColor : Ambient = { 0.0f, 0.0f, 0.0f, 1.0f };
uniform float4 _DiffuseColor : Diffuse = { 1.0f, 1.0f, 1.0f, 1.0f };
uniform float4 _SpecularColor : Specular = { 0.0f, 0.0f, 0.0f, 1.0f };

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
uniform float4 _EyePos : EYEPOS = { 0.0f, 0.0f, 1.0f, 0.25f };

uniform float4 _PosUnpack : POSUNPACK;
uniform float2 _TexProjOffset : TEXPROJOFFSET;

uniform float2 _ZLimitsInv : ZLIMITSINV;

uniform float4x4 _vpLightMat : vpLightMat;
uniform float4x4 _vpLightTrapezMat : vpLightTrapezMat;
uniform float _ShadowAlphaThreshold : SHADOWALPHATHRESHOLD;
uniform float4x4 _LightViewProj : LIGHTVIEWPROJ;

uniform dword _DwordStencilRef : STENCILREF = 0;
uniform bool _AlphaBlendEnable: AlphaBlendEnable;
uniform float _AltitudeFactor : ALTITUDEFACTOR = 0.7f;

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

uniform texture Tex0: TEXLAYER0;
uniform texture Tex1: TEXLAYER1;
uniform texture Tex2: TEXLAYER2;
uniform texture Tex3: TEXLAYER3;
uniform texture Tex4: TEXLAYER4;

#define CREATE_SAMPLER(NAME, TEXTURE, ADDRESS, FILTER) \
	sampler NAME = sampler_state \
	{ \
		Texture = (TEXTURE); \
		AddressU = ADDRESS; \
		AddressV = ADDRESS; \
		MinFilter = FILTER; \
		MagFilter = FILTER; \
		MipFilter = FILTER; \
	};

CREATE_SAMPLER(SampleTex0, Tex0, CLAMP, LINEAR)
CREATE_SAMPLER(SampleTex1, Tex1, CLAMP, LINEAR)
CREATE_SAMPLER(SampleTex2, Tex2, CLAMP, LINEAR)
CREATE_SAMPLER(SampleCubeTex3, Tex3, WRAP, LINEAR)

CREATE_SAMPLER(SampleDiffuseMap, Tex0, WRAP, LINEAR)
CREATE_SAMPLER(SampleNormalMap, Tex1, WRAP, LINEAR)

CREATE_SAMPLER(SampleColorLUT, Tex2, CLAMP, LINEAR)

sampler SampleDummy = sampler_state
{
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	AddressU = CLAMP;
	AddressV = CLAMP;
};

/*
	SHADOW BUFFER DATA

	texture ShadowMap: ShadowMapTex;
	texture ShadowMapOccluder : ShadowMapOccluderTex;

	CREATE_SAMPLER(SampleShadowMap, ShadowMap, CLAMP, LINEAR)
	CREATE_SAMPLER(SampleShadowMapOccluder, ShadowMapOccluder, CLAMP, LINEAR)
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
	float3 Tangent : TEXCOORD2;
	float3 BiNormal : TEXCOORD3;
	float3 Normal : TEXCOORD4;
};

VS2PS_Specular Lighting_VS(APP2VS Input)
{
	VS2PS_Specular Output = (VS2PS_Specular)0;

	// Compensate for lack of UBYTE4 on Geforce3
	int4 IndexVector = D3DCOLORtoUBYTE4(Input.BlendIndices);
	int IndexArray[4] = (int[4])IndexVector;

	float4x3 SkinWorldMat = _MatOneBoneSkinning[IndexArray[0]];
	float3 WorldPos = mul(Input.Pos, SkinWorldMat);

	Output.HPos = mul(float4(WorldPos.xyz, 1.0f), _ViewProjMatrix);
	Output.Tex = Input.TexCoord;

	// Calculate WorldTangent directly... inverse is the transpose for affine rotations
	float3x3 TBN = GetTangentBasis(Input.Tan, Input.Normal, 1.0);
	float3x3 WorldI = transpose(mul(TBN, (float3x3)SkinWorldMat));

	Output.WorldPos = WorldPos;
	Output.Tangent = WorldI[0];
	Output.BiNormal = WorldI[1];
	Output.Normal = WorldI[2];

	return Output;
}

float4 Lighting_PS(VS2PS_Specular Input) : COLOR
{
	// Get world-space properties
	float3 WorldPos = Input.WorldPos;
	float3 Tangent = normalize(Input.Tangent);
	float3 BiNormal = normalize(Input.BiNormal);
	float3 Normal = normalize(Input.Normal);
	float3x3 WorldI = float3x3(Tangent, BiNormal, Normal);

	// Get world-space positions
	float3 MatsLightDir = float3(0.5, 0.5, 0.0);
	float3 WorldEyeVec = _ViewInverseMatrix[3].xyz - WorldPos;

	// Transform vectors from world space to tangent space
	float3 TanLightVec = normalize(mul(MatsLightDir, WorldI));
	float3 TanEyeVec = normalize(mul(WorldEyeVec, WorldI));
	float3 TanHalfVec = normalize(TanLightVec + TanEyeVec);

	float4 NormalMap = tex2D(SampleNormalMap, Input.Tex);
	float4 DiffuseMap = tex2D(SampleDiffuseMap, Input.Tex); // What should we do with .a channel now?

	float Gloss = NormalMap.a;
	float4 Ambient = float4(0.4, 0.4, 0.4, 1.0);
	float4 CosAngle = GetLambert(NormalMap.xyz, TanLightVec);
	float4 Specular = GetSpecular(NormalMap.xyz, TanHalfVec) * Gloss;

	float4 Lighting = Ambient + (CosAngle + (Specular * CosAngle));
	return saturate(DiffuseMap * Lighting);
}

technique Full
{
	pass p0
	{
		VertexShader = compile vs_3_0 Lighting_VS();
		PixelShader = compile ps_3_0 Lighting_PS();
	}
}

/*
	Diffuse map shaders
*/

struct VS2PS_Diffuse
{
	float4 HPos : POSITION;
	float2 TexCoord : TEXCOORD0;
	float3 Normal : TEXCOORD1;
	float4 WorldI[3] : TEXCOORD2;
};

VS2PS_Diffuse Diffuse_VS(APP2VS Input)
{
	VS2PS_Diffuse Output = (VS2PS_Diffuse)0;

	// Compensate for lack of UBYTE4 on Geforce3
	int4 IndexVector = D3DCOLORtoUBYTE4(Input.BlendIndices);
	int IndexArray[4] = (int[4])IndexVector;

	float4x3 SkinWorldMat = _MatOneBoneSkinning[IndexArray[0]];
	float3 WorldPos = mul(Input.Pos, SkinWorldMat);
	Output.HPos = mul(float4(WorldPos, 1.0), _ViewProjMatrix);

	// Pass-through texcoords
	Output.TexCoord = Input.TexCoord;

	Output.Normal = normalize(Input.Normal);

	// Need to calculate the WorldI based on each matBone skinning world matrix
	// Inverse is simplified to M-1 = Rt * T,
	// Where Rt is the transpose of the rotaional part and T is the translation
	float3x3 Rtranspose = transpose(SkinWorldMat);
	float3 Translation = mul(SkinWorldMat[3], Rtranspose);
	Output.WorldI[0] = float4(Rtranspose[0].xyz, Translation.x);
	Output.WorldI[1] = float4(Rtranspose[1].xyz, Translation.y);
	Output.WorldI[2] = float4(Rtranspose[2].xyz, Translation.z);

	return Output;
}

float4 Diffuse_PS(VS2PS_Diffuse Input) : COLOR
{
	float4x4 WorldI;
	WorldI[0] = Input.WorldI[0];
	WorldI[1] = Input.WorldI[1];
	WorldI[2] = Input.WorldI[2];
	WorldI[3] = float4(0.0, 0.0, 0.0, 1.0);

	float3 Normal = normalize(Input.Normal);

	// Transform Light pos to Object space
	float3 MatsLightDir = float3(0.2, 0.8, -0.2);
	float3 ObjSpaceLightDir = mul(-MatsLightDir, WorldI);
	float3 LightVec = normalize(ObjSpaceLightDir);

	float4 DiffuseMap = tex2D(SampleDiffuseMap, Input.TexCoord);
	float4 Diffuse = saturate(GetLambert(Normal, LightVec) + 0.8);
	Diffuse.a = 1.0;

	return DiffuseMap * Diffuse;
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

		VertexShader = compile vs_3_0 Diffuse_VS();
		PixelShader = compile ps_3_0 Diffuse_PS();
	}
}

/*
	Alpha environment map shaders
*/

struct VS2PS_Alpha
{
	float4 HPos : POSITION;
	float4 ProjTex : TEXCOORD0;
	float2 DiffuseTex : TEXCOORD1;
};

VS2PS_Alpha Alpha_VS(APP2VS Input)
{
	VS2PS_Alpha Output;

	// Compensate for lack of UBYTE4 on Geforce3
	int4 IndexVector = D3DCOLORtoUBYTE4(Input.BlendIndices);
	int IndexArray[4] = (int[4])IndexVector;

	float4x3 SkinWorldMat = _MatOneBoneSkinning[IndexArray[0]];
	float3 WorldPos = mul(Input.Pos, SkinWorldMat);
	Output.HPos = mul(float4(WorldPos, 1.0), _ViewProjMatrix);

	Output.ProjTex.xy = (Output.HPos.xy / Output.HPos.w) * 0.5 + 0.5;
	Output.ProjTex.y = 1.0 - Output.ProjTex.y;
	Output.ProjTex.xy = (Output.ProjTex.xy + _TexProjOffset) * Output.HPos.w;
	Output.ProjTex.zw = Output.HPos.zw;

	// Pass-through texcoords
	Output.DiffuseTex = Input.TexCoord.xy;

	return Output;
}

float4 Alpha_PS(VS2PS_Alpha Input) : COLOR
{
	float4 DiffuseMap = tex2D(SampleTex0, Input.DiffuseTex);
	float4 ProjLight = tex2Dproj(SampleTex1, Input.ProjTex);
	float4 OutputColor = 0.0;
	OutputColor.rgb = (DiffuseMap.rgb * ProjLight.rgb) + ProjLight.a;
	return OutputColor;
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
	float3 TanToCubeSpace[3] : TEXCOORD3;
};

VS2PS_EnvMap_Alpha EnvMap_Alpha_VS(APP2VS Input)
{
	VS2PS_EnvMap_Alpha Output = (VS2PS_EnvMap_Alpha)0;

	// Compensate for lack of UBYTE4 on Geforce3
	int4 IndexVector = D3DCOLORtoUBYTE4(Input.BlendIndices);
	int IndexArray[4] = (int[4])IndexVector;

	float4x3 SkinWorldMat = _MatOneBoneSkinning[IndexArray[0]];
	float3 WorldPos = mul(Input.Pos, SkinWorldMat);
	Output.HPos = mul(float4(WorldPos, 1.0), _ViewProjMatrix);

	Output.ProjTex.xy = (Output.HPos.xy / Output.HPos.w) * 0.5 + 0.5;
	Output.ProjTex.y = 1.0 - Output.ProjTex.y;
	Output.ProjTex.xy = (Output.ProjTex.xy + _TexProjOffset) * Output.HPos.w;
	Output.ProjTex.zw = Output.HPos.zw;

	// Pass-through texcoords
	Output.Tex = Input.TexCoord;

	// Need to calculate the TanToCubeState based on each matBone skinning world matrix
	float3x3 TanToObjectBasis = GetTangentBasis(Input.Tan,  Input.Normal, 1.0);
	Output.TanToCubeSpace[0] = mul(_MatOneBoneSkinning[IndexArray[0]][0].xyz, TanToObjectBasis);
	Output.TanToCubeSpace[1] = mul(_MatOneBoneSkinning[IndexArray[0]][1].xyz, TanToObjectBasis);
	Output.TanToCubeSpace[2] = mul(_MatOneBoneSkinning[IndexArray[0]][2].xyz, TanToObjectBasis);

	return Output;
}

float4 EnvMap_Alpha_PS(VS2PS_EnvMap_Alpha Input) : COLOR
{
	float3x3 TanToCubeSpace;
	TanToCubeSpace[0] = normalize(Input.TanToCubeSpace[0]);
	TanToCubeSpace[1] = normalize(Input.TanToCubeSpace[1]);
	TanToCubeSpace[2] = normalize(Input.TanToCubeSpace[2]);

	float3 WorldPos = Input.WorldPos;
	float3 WorldViewVec = normalize(WorldPos.xyz - _EyePos.xyz);
	float Reflection = _EyePos.w;

	float4 AccumLight = tex2Dproj(SampleTex1, Input.ProjTex);
	float4 DiffuseMap = tex2D(SampleTex0, Input.Tex);
	float4 NormalMap = tex2D(SampleTex2, Input.Tex);

	float3 NormalVec = normalize((NormalMap.xyz * 2.0) - 1.0);
	float3 WorldNormal = normalize(mul(TanToCubeSpace, NormalVec));

	float3 Lookup = reflect(WorldViewVec, WorldNormal);
	float3 EnvMapColor = texCUBE(SampleCubeTex3, Lookup) * NormalMap.a * Reflection;
	return float4((DiffuseMap.rgb * AccumLight.rgb) + EnvMapColor + AccumLight.a, DiffuseMap.a);
}

#define ALPHA_RENDERSTATES \
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
		ALPHA_RENDERSTATES
		VertexShader = compile vs_3_0 Alpha_VS();
		PixelShader = compile ps_3_0 Alpha_PS();
	}

	pass p1EnvMap
	{
		ALPHA_RENDERSTATES
		VertexShader = compile vs_3_0 EnvMap_Alpha_VS();
		PixelShader = compile ps_3_0 EnvMap_Alpha_PS();
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

VS2PS_ShadowMap ShadowMap_VS(APP2VS Input)
{
	VS2PS_ShadowMap Output = (VS2PS_ShadowMap)0;

	// Compensate for lack of UBYTE4 on Geforce3
	int4 IndexVector = D3DCOLORtoUBYTE4(Input.BlendIndices);
	int IndexArray[4] = (int[4])IndexVector;

	float4 UnpackPos = float4(Input.Pos.xyz * _PosUnpack.xyz, 1.0);
	float4x3 SkinWorldMat = _MatOneBoneSkinning[IndexArray[0]];
	float4 WorldPos = float4(mul(UnpackPos, SkinWorldMat), 1.0);

	Output.HPos = GetMeshShadowProjection(WorldPos, _vpLightTrapezMat, _vpLightMat);
	Output.DepthPos = Output.HPos;

	return Output;
}

float4 ShadowMap_PS(VS2PS_ShadowMap Input) : COLOR
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

VS2PS_ShadowMap_Alpha ShadowMap_Alpha_VS(APP2VS Input)
{
	VS2PS_ShadowMap_Alpha Output;

	// Compensate for lack of UBYTE4 on Geforce3
	int4 IndexVector = D3DCOLORtoUBYTE4(Input.BlendIndices);
	int IndexArray[4] = (int[4])IndexVector;

	float4 UnpackPos = Input.Pos * _PosUnpack;
	float4x3 SkinWorldMat = _MatOneBoneSkinning[IndexArray[0]];
	float4 WorldPos = float4(mul(UnpackPos, SkinWorldMat), 1.0);

	Output.HPos = GetMeshShadowProjection(WorldPos, _vpLightTrapezMat, _vpLightMat);
	Output.DepthPos = Output.HPos;
	Output.Tex0 = Input.TexCoord;

	return Output;
}

float4 ShadowMap_Alpha_PS(VS2PS_ShadowMap_Alpha Input) : COLOR
{
	float Alpha = tex2D(SampleTex0, Input.Tex0).a - _ShadowAlphaThreshold;
	#if NVIDIA
		return Alpha;
	#else
		clip(Alpha);
		return Input.DepthPos.z / Input.DepthPos.w;
	#endif
}

#define SHADOWMAP_RENDERSTATES \
	CullMode = CW; \
	ZEnable = TRUE; \
	ZFunc = LESSEQUAL; \
	ZWriteEnable = TRUE; \
	AlphaBlendEnable = FALSE; \
	ScissorTestEnable = TRUE; \

technique DrawShadowMap
{
	pass directionalspot
	{
		#if NVIDIA
			ColorWriteEnable = 0; // 0x0000000F;
		#endif

		SHADOWMAP_RENDERSTATES
		VertexShader = compile vs_3_0 ShadowMap_VS();
		PixelShader = compile ps_3_0 ShadowMap_PS();
	}

	pass directionalspotalpha
	{
		#if NVIDIA
			AlphaTestEnable = TRUE;
			AlphaRef = 0;
			ColorWriteEnable = 0; // 0x0000000F;
		#endif

		SHADOWMAP_RENDERSTATES
		VertexShader = compile vs_3_0 ShadowMap_Alpha_VS();
		PixelShader = compile ps_3_0 ShadowMap_Alpha_PS();
	}

	pass point_
	{
		#if NVIDIA
			ColorWriteEnable = 0; // 0x0000000F;
		#endif

		SHADOWMAP_RENDERSTATES
		VertexShader = compile vs_3_0 ShadowMap_VS();
		PixelShader = compile ps_3_0 ShadowMap_PS();
	}

	pass pointalpha
	{
		#if NVIDIA
			ColorWriteEnable = 0; // 0x0000000F;
			AlphaTestEnable = TRUE;
			AlphaRef = 0;
		#endif

		SHADOWMAP_RENDERSTATES
		VertexShader = compile vs_3_0 ShadowMap_Alpha_VS();
		PixelShader = compile ps_3_0 ShadowMap_Alpha_PS();
	}
}

// We actually don't need to have 2 techniques here
// but it is kept for back-compatibility with original BF2
technique DrawShadowMapNV
{
	pass directionalspot
	{
		#if NVIDIA
			ColorWriteEnable = 0;//0x0000000F;
		#endif

		SHADOWMAP_RENDERSTATES
		VertexShader = compile vs_3_0 ShadowMap_VS();
		PixelShader = compile ps_3_0 ShadowMap_PS();
	}

	pass directionalspotalpha
	{
		#if NVIDIA
			ColorWriteEnable = 0;//0x0000000F;
			AlphaTestEnable = TRUE;
			AlphaRef = 0;
		#endif

		SHADOWMAP_RENDERSTATES
		VertexShader = compile vs_3_0 ShadowMap_Alpha_VS();
		PixelShader = compile ps_3_0 ShadowMap_Alpha_PS();
	}

	pass point_
	{
		#if NVIDIA
			ColorWriteEnable = 0; // 0x0000000F;
		#endif

		SHADOWMAP_RENDERSTATES
		VertexShader = compile vs_3_0 ShadowMap_VS();
		PixelShader = compile ps_3_0 ShadowMap_PS();
	}

	pass pointalpha
	{
		#if NVIDIA
			ColorWriteEnable = 0; // 0x0000000F;
			AlphaTestEnable = TRUE;
			AlphaRef = 0;
		#endif

		SHADOWMAP_RENDERSTATES
		VertexShader = compile vs_3_0 ShadowMap_Alpha_VS();
		PixelShader = compile ps_3_0 ShadowMap_Alpha_PS();
	}
}