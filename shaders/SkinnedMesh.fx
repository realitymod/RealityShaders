
/*
	Description:
	- Builds shadow map for skinnedmesh (objects that are dynamic, human-like with bones)
	- Does bone skinning for 2 bones
	- Outputs used in RaShaderSM.fx
	Author: Mats Dal
*/

#include "shaders/RealityGraphics.fxh"

// Note: obj space light vectors
uniform float4 _SunLightDirection : SunLightDirection;
uniform float4 _LightDirection : LightDirection;
uniform float _NormalOffsetScale : NormalOffsetScale;

// Offset x/y _HemiMapInfo.z z / _HemiMapInfo.w w
uniform float4 _HemiMapInfo : HemiMapInfo;

uniform float4 _AmbientColor : AmbientColor;
uniform float4 _LightColor : LightColor;
uniform float4 _SkyColor : SkyColor;
uniform float4 _SunColor : SunColor;

uniform float4 _LightPosition : LightPosition;
uniform float _AttenuationSqrInv : AttenuationSqrInv;

uniform float _ShadowAlphaThreshold : SHADOWALPHATHRESHOLD;

uniform float _ConeAngle : ConeAngle;
uniform float4 _WorldEyePos : WorldEyePos;
uniform float4 _ObjectEyePos : ObjectEyePos;

uniform float4x4 _LightViewProj : LIGHTVIEWPROJ;
uniform float4x4 _LightViewProj2 : LIGHTVIEWPROJ2;
uniform float4x4 _LightViewProj3 : LIGHTVIEWPROJ3;
uniform float4 _ViewportMap : VIEWPORTMAP;

uniform dword _StencilRef : STENCILREF = 0;

uniform float4x4 _World : World;
uniform float4x4 _WorldT : WorldT;
uniform float4x4 _WorldView : WorldView;
uniform float4x4 _WorldViewI : WorldViewI; // (WorldViewIT)T = WorldViewI
uniform float4x4 _WorldViewProjection : WorldViewProjection;
uniform float4x3 _BoneArray[26] : BoneArray; // : register(c15) < bool sparseArray = true; int arrayStart = 15; >;

uniform float4x4 _vpLightMat : vpLightMat;
uniform float4x4 _vpLightTrapezMat : vpLightTrapezMat;

uniform float4 _ParaboloidValues : ParaboloidValues;
uniform float4 _ParaboloidZValues : ParaboloidZValues;

/*
	[Textures and Samplers]
*/

#define CREATE_SAMPLER(SAMPLER_NAME, TEXTURE, FILTER, IS_SRGB) \
	sampler SAMPLER_NAME = sampler_state \
	{ \
		Texture = (TEXTURE); \
		MinFilter = FILTER; \
		MagFilter = FILTER; \
		MipFilter = FILTER; \
		SRGBTexture = IS_SRGB; \
	}; \

uniform texture Tex0 : TEXLAYER0;
CREATE_SAMPLER(SampleTex0, Tex0, LINEAR, FALSE)

uniform texture Tex1 : TEXLAYER1;
CREATE_SAMPLER(SampleTex1, Tex1, LINEAR, FALSE)

uniform texture Tex2 : TEXLAYER2;
CREATE_SAMPLER(SampleTex2, Tex2, LINEAR, FALSE)

uniform texture Tex3 : TEXLAYER3;
CREATE_SAMPLER(SampleTex3, Tex3, LINEAR, FALSE)

uniform texture Tex4 : TEXLAYER4;

struct APP2VS
{
	float4 Pos : POSITION;
	float3 Normal : NORMAL;
	float BlendWeights : BLENDWEIGHT;
	float4 BlendIndices : BLENDINDICES;
	float2 TexCoord0 : TEXCOORD0;
};

/*
	Object-based skinning
*/

struct SkinnedData
{
	float3 Pos;
	float3 Normal;
	float3 LightVec;
};

// Skin solders by blending between two bones
SkinnedData SkinSoldier(in APP2VS Input, in float3 LightVec)
{
	SkinnedData Output = (SkinnedData)0;

	// Cast the vectors to arrays for use in the for loop below
	int4 IndexVector = D3DCOLORtoUBYTE4(Input.BlendIndices);
	float BlendWeightsArray[1] = (float[1])Input.BlendWeights;
	int IndexArray[4] = (int[4])IndexVector;

	float4x3 BoneMatrix = (float4x3)0;
	BoneMatrix += (_BoneArray[IndexArray[0]] * (BlendWeightsArray[0]));
	BoneMatrix += (_BoneArray[IndexArray[1]] * (1.0 - BlendWeightsArray[0]));

	Output.Pos = mul(Input.Pos, BoneMatrix);
	Output.Normal = normalize(mul(Input.Normal, (float3x3)BoneMatrix));
	Output.LightVec = mul((float3x3)BoneMatrix, LightVec);

	return Output;
}

/*
	Humanskin shader
*/

struct VS2PS_PreSkin
{
	float4 HPos : POSITION;
	float4 P_Tex0_GroundUV : TEXCOORD0; // .xy = Tex0; .zw = GroundUV
	float4 P_ViewVec_Lerp : TEXCOORD1; // .xyz = ViewVec; .w = HemiLerp;
	float3 LightVec : TEXCOORD2;
};

VS2PS_PreSkin PreSkin_VS(APP2VS Input)
{
	VS2PS_PreSkin Output = (VS2PS_PreSkin)0;
	SkinnedData Skin = SkinSoldier(Input, -_SunLightDirection.xyz);

	Output.HPos.xy = Input.TexCoord0 * float2(2.0, -2.0) - float2(1.0, -1.0);
	Output.HPos.zw = float2(0.0, 1.0);

	Output.P_Tex0_GroundUV.xy = Input.TexCoord0;

	// Hemi lookup values
	float4 WorldPos = mul(Skin.Pos, (float3x4)_World);
	Output.P_Tex0_GroundUV.zw = ((WorldPos.xyz + (_HemiMapInfo.z / 2.0) + Skin.Normal).xz - _HemiMapInfo.xy) / _HemiMapInfo.z;
	Output.P_Tex0_GroundUV.w = 1.0 - Output.P_Tex0_GroundUV.w;

	Output.P_ViewVec_Lerp.xyz = normalize(_ObjectEyePos.xyz - Skin.Pos);
	Output.P_ViewVec_Lerp.w = ((Skin.Normal.y * 0.5) + 0.5) - _HemiMapInfo.w;

	Output.LightVec = normalize(Skin.LightVec);

	return Output;
}

float4 PreSkin_PS(VS2PS_PreSkin Input) : COLOR
{
	float HemiLerp = Input.P_ViewVec_Lerp.w;
	float3 ViewVec = normalize(Input.P_ViewVec_Lerp.xyz);
	float3 LightVec = normalize(Input.LightVec);

	float4 GroundColor = tex2D(SampleTex1, Input.P_Tex0_GroundUV.zw);
	float4 NormalMap = tex2D(SampleTex0, Input.P_Tex0_GroundUV.xy);
	NormalMap.rgb = normalize((NormalMap * 2.0) - 1.0);

	float WrapDiffuse = dot(NormalMap.xyz, Input.LightVec) + 0.5;
	WrapDiffuse = saturate(WrapDiffuse / 1.5);

	float RimDiffuse = pow(1.0 - dot(NormalMap.xyz, ViewVec), 3.0);
	RimDiffuse = saturate(0.75 - saturate(dot(LightVec, ViewVec)));

	return float4((WrapDiffuse.rrr + RimDiffuse) * (GroundColor.a * GroundColor.a), NormalMap.a);
}

struct VS2PS_ShadowedPreSkin
{
	float4 HPos : POSITION;
	float2 Tex0 : TEXCOORD0;
	float3 LightVec : TEXCOORD1;
	float3 ViewVec : TEXCOORD2;
	float4 ShadowTex : TEXCOORD3;
};

VS2PS_ShadowedPreSkin ShadowedPreSkin_VS(APP2VS Input)
{
	VS2PS_ShadowedPreSkin Output = (VS2PS_ShadowedPreSkin)0;
	SkinnedData Skin = SkinSoldier(Input, -_SunLightDirection.xyz);

	Output.HPos.xy = Input.TexCoord0 * float2(2.0, -2.0) - float2(1.0, -1.0);
	Output.HPos.zw = float2(0.0, 1.0);

	Output.Tex0 = Input.TexCoord0;

	Output.LightVec = normalize(Skin.LightVec);
	Output.ViewVec = normalize(_ObjectEyePos.xyz - Skin.Pos);

	Output.ShadowTex = mul(float4(Skin.Pos, 1.0), _LightViewProj);

	return Output;
}

float4 ShadowedPreSkin_PS(VS2PS_ShadowedPreSkin Input) : COLOR
{
	float3 ViewVec = normalize(Input.ViewVec);
	float3 LightVec = normalize(Input.LightVec);

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

	float4 NormalMap = tex2D(SampleTex0, Input.Tex0);
	NormalMap.rgb = normalize((NormalMap * 2.0) - 1.0);

	float WrapDiffuse = dot(NormalMap.xyz, LightVec) + 0.5;
	WrapDiffuse = saturate(WrapDiffuse / 1.5);

	float RimDiffuse = 1.0 - dot(NormalMap.xyz, ViewVec);
	RimDiffuse = pow(RimDiffuse, 3.0) * saturate(0.75 - saturate(dot(ViewVec, LightVec)));

	float4 OutputColor = 0.0;
	OutputColor.r = WrapDiffuse + RimDiffuse;
	OutputColor.g = TotalShadow;
	OutputColor.b = saturate(TotalShadow + 0.35);
	OutputColor.a = NormalMap.a;

	return OutputColor;
}

struct VS2PS_ApplySkin
{
	float4 HPos : POSITION;
	float4 P_Tex0_GroundUV : TEXCOORD0; // .xy = Tex0; .zw = GroundUV
	float4 P_LightVec_Lerp : TEXCOORD1; // .xyz = ViewVec; .w = HemiLerp;
	float3 ViewVec : TEXCOORD2;
};

VS2PS_ApplySkin ApplySkin_VS(APP2VS Input)
{
	VS2PS_ApplySkin Output = (VS2PS_ApplySkin)0;
	SkinnedData Skin = SkinSoldier(Input, -_SunLightDirection.xyz);

	// Transform position into view and then projection space
	Output.HPos = mul(float4(Skin.Pos, 1.0), _WorldViewProjection);

	Output.P_Tex0_GroundUV.xy = Input.TexCoord0;

	// Hemi lookup values
	float4 WorldPos = mul(Skin.Pos, _World);
	Output.P_Tex0_GroundUV.zw = ((WorldPos.xyz + (_HemiMapInfo.z / 2.0) + Skin.Normal).xz - _HemiMapInfo.xy) / _HemiMapInfo.z;
	Output.P_Tex0_GroundUV.w = 1.0 - Output.P_Tex0_GroundUV.w;

	Output.P_LightVec_Lerp.xyz = Skin.LightVec;
	Output.P_LightVec_Lerp.w = ((Skin.Normal.y * 0.5) + 0.5) - _HemiMapInfo.w;

	Output.ViewVec = _ObjectEyePos.xyz - Skin.Pos;

	return Output;
}

float4 ApplySkin_PS(VS2PS_ApplySkin Input) : COLOR
{
	float3 LightVec = normalize(Input.P_LightVec_Lerp.xyz);
	float3 ViewVec = normalize(Input.ViewVec);
	float HemiLerp = Input.P_LightVec_Lerp.w;

	float4 GroundColor = tex2D(SampleTex0, Input.P_Tex0_GroundUV.zw);
	float4 HemiColor = lerp(GroundColor, _SkyColor, HemiLerp);

	float4 NormalMap = tex2D(SampleTex1, Input.P_Tex0_GroundUV.xy);
	NormalMap.xyz = normalize((NormalMap * 2.0) - 1.0);
	float4 DiffuseMap = tex2D(SampleTex2, Input.P_Tex0_GroundUV.xy);
	float4 DiffuseLight = tex2D(SampleTex3, Input.P_Tex0_GroundUV.xy);

	// Glossmap is in the Diffuse alpha channel.
	float4 Ambient = _AmbientColor * HemiColor;
	float4 Diffuse = (DiffuseLight.r * DiffuseLight.b) * _SunColor;
	float ShadowIntensity = saturate(DiffuseLight.g);
	ColorPair Light = ComputeLights(NormalMap.xyz, LightVec, ViewVec);
	Light.Specular = Light.Specular * DiffuseMap.a * pow(ShadowIntensity, 2.0);

	DiffuseMap.rgb = saturate((DiffuseMap * (Ambient + Diffuse)) + Light.Specular);
	return DiffuseMap;
}

#define GET_RENDERSTATES_SKIN(CULLMODE) \
	CullMode = CULLMODE; \
	AlphaBlendEnable = FALSE; \
	StencilEnable = FALSE; \
	ZEnable = FALSE; \
	ZWriteEnable = FALSE; \
	ZFunc = LESSEQUAL; \

technique humanskin
{
	pass Pre
	{
		GET_RENDERSTATES_SKIN(NONE)
		VertexShader = compile vs_3_0 PreSkin_VS();
		PixelShader = compile ps_3_0 PreSkin_PS();
	}

	pass PreShadowed
	{
		GET_RENDERSTATES_SKIN(NONE)
		VertexShader = compile vs_3_0 ShadowedPreSkin_VS();
		PixelShader = compile ps_3_0 ShadowedPreSkin_PS();
	}

	pass Apply
	{
		GET_RENDERSTATES_SKIN(CCW)
		VertexShader = compile vs_3_0 ApplySkin_VS();
		PixelShader = compile ps_3_0 ApplySkin_PS();
	}
}

/*
	Shadowmap shaders
*/

struct VS2PS_ShadowMap
{
	float4 HPos : POSITION;
	float4 DepthPos : TEXCOORD0;
	float2 Tex0 : TEXCOORD1;
};

VS2PS_ShadowMap ShadowMap_VS(APP2VS Input)
{
	VS2PS_ShadowMap Output;

	// Cast the vectors to arrays for use in the for loop below
	int4 IndexVector = D3DCOLORtoUBYTE4(Input.BlendIndices);
	float BlendWeightsArray[1] = (float[1])Input.BlendWeights;
	int IndexArray[4] = (int[4])IndexVector;

	float4x3 BoneMat = (float4x3)0.0;
	BoneMat += (_BoneArray[IndexArray[0]] * (BlendWeightsArray[0]));
	BoneMat += (_BoneArray[IndexArray[1]] * (1.0 - BlendWeightsArray[0]));
	float4 BonePos = float4(mul(Input.Pos, BoneMat), 1.0);

	Output.HPos = GetMeshShadowProjection(BonePos, _vpLightTrapezMat, _vpLightMat);
	Output.DepthPos = Output.HPos; // Output depth
	Output.Tex0 = Input.TexCoord0;

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

float4 ShadowMap_Alpha_PS(VS2PS_ShadowMap Input) : COLOR
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
		VertexShader = compile vs_3_0 ShadowMap_VS();
		PixelShader = compile ps_3_0 ShadowMap_PS();
	}

	pass DirectionalSpotAlpha
	{
		#if NVIDIA
			ColorWriteEnable = 0; // 0x0000000F;
			AlphaTestEnable = TRUE;
			AlphaRef = 0;
		#endif

		GET_RENDERSTATES_SHADOWMAP
		VertexShader = compile vs_3_0 ShadowMap_VS();
		PixelShader = compile ps_3_0 ShadowMap_Alpha_PS();

	}

	pass Point_
	{
		#if NVIDIA
			ColorWriteEnable = 0; // 0x0000000F;
		#endif

		GET_RENDERSTATES_SHADOWMAP
		VertexShader = compile vs_3_0 ShadowMap_VS();
		PixelShader = compile ps_3_0 ShadowMap_PS();
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
		VertexShader = compile vs_3_0 ShadowMap_VS();
		PixelShader = compile ps_3_0 ShadowMap_PS();
	}

	pass DirectionalSpotAlpha
	{
		#if NVIDIA
			ColorWriteEnable = 0; // 0x0000000F;
			AlphaTestEnable = TRUE;
			AlphaRef = 0;
		#endif

		GET_RENDERSTATES_SHADOWMAP
		VertexShader = compile vs_3_0 ShadowMap_VS();
		PixelShader = compile ps_3_0 ShadowMap_Alpha_PS();

	}

	pass Point_
	{
		#if NVIDIA
			ColorWriteEnable = 0; // 0x0000000F;
		#endif

		GET_RENDERSTATES_SHADOWMAP
		VertexShader = compile vs_3_0 ShadowMap_VS();
		PixelShader = compile ps_3_0 ShadowMap_PS();
	}
}
