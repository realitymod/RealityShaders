
/*
	Description:
	- Builds shadow map for skinnedmesh (objects that are dynamic, human-like with bones)
	- Does bone skinning for 2 bones
	- Outputs used in RaShaderSM.fx
	Author: Mats Dal
*/

#include "shaders/RealityGraphics.fx"

// Note: obj space light vectors
float4 _SunLightDirection : SunLightDirection;
float4 _LightDirection : LightDirection;
float _NormalOffsetScale : NormalOffsetScale;
// float _HemiMapInfo.z : _HemiMapInfo.z;
// float _HemiMapInfo.w : _HemiMapInfo.w;

// Offset x/y _HemiMapInfo.z z / _HemiMapInfo.w w
float4 _HemiMapInfo : HemiMapInfo;

float4 _SkyColor : SkyColor;
float4 _AmbientColor : AmbientColor;
float4 _SunColor : SunColor;

float4 _LightPosition : LightPosition;
float _AttenuationSqrInv : AttenuationSqrInv;
float4 _LightColor : LightColor;

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

texture Texture_0 : TEXLAYER0;
texture Texture_1 : TEXLAYER1;
texture Texture_2 : TEXLAYER2;
texture Texture_3 : TEXLAYER3;
texture Texture_4 : TEXLAYER4;

sampler Sampler_0 = sampler_state
{
	Texture = (Texture_0);
	MipFilter = LINEAR;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
};

sampler Sampler_1 = sampler_state
{
	Texture = (Texture_1);
	MipFilter = LINEAR;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
};

sampler Sampler_2 = sampler_state
{
	Texture = (Texture_2);
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = LINEAR;
};

sampler Sampler_3 = sampler_state
{
	Texture = (Texture_3);
	MipFilter = LINEAR;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
};

struct APP2VS
{
	float4 Pos : POSITION;
	float3 Normal : NORMAL;
	float BlendWeights : BLENDWEIGHT;
	float4 BlendIndices : BLENDINDICES;
	float2 TexCoord0 : TEXCOORD0;
};

// Object-based lighting

void SkinSoldier_PP(uniform int NumBones, in APP2VS Input, in float3 LightVec, out float3 Pos, out float3 Normal,
					out float3 SkinnedLightVec)
{
	float LastWeight = 0.0;
	Pos = 0.0;
	Normal = 0.0;
	SkinnedLightVec = 0.0;

	// Compensate for lack of UBYTE4 on Geforce3
	int4 IndexVector = D3DCOLORtoUBYTE4(Input.BlendIndices);

	// Cast the vectors to arrays for use in the for loop below
	float BlendWeightsArray[1] = (float[1])Input.BlendWeights;
	int IndexArray[4] = (int[4])IndexVector;

	// Calculate the pos/normal using the "normal" weights
	// and accumulate the weights to calculate the last weight
	for (int BoneIndex = 0; BoneIndex < NumBones - 1; BoneIndex++)
	{
		LastWeight += BlendWeightsArray[BoneIndex];

		Pos += mul(Input.Pos, _BoneArray[IndexArray[BoneIndex]]) * BlendWeightsArray[BoneIndex];
		Normal += mul(Input.Normal, _BoneArray[IndexArray[BoneIndex]]) * BlendWeightsArray[BoneIndex];
		float3x3 mat = transpose((float3x3)_BoneArray[IndexArray[BoneIndex]]);
		SkinnedLightVec += mul(LightVec, mat) * BlendWeightsArray[BoneIndex];
	}
	LastWeight = 1.0 - LastWeight;

	// Now that we have the calculated weight, add in the final influence
	Pos += mul(Input.Pos, _BoneArray[IndexArray[NumBones - 1]]) * LastWeight;
	Normal += mul(Input.Normal, _BoneArray[IndexArray[NumBones - 1]]) * LastWeight;
	float3x3 mat = transpose((float3x3)_BoneArray[IndexArray[NumBones - 1]]);
	SkinnedLightVec += mul(LightVec, mat) * LastWeight;

	// Normalize normals
	Normal = normalize(Normal);
	// SkinnedLightVec = normalize(SkinnedLightVec); // Don't normalize
}

// Tangent-based lighting

struct APP2VStangent
{
	float4 Pos : POSITION;
	float3 Normal : NORMAL;
	float BlendWeights : BLENDWEIGHT;
	float4 BlendIndices : BLENDINDICES;
	float2 TexCoord0 : TEXCOORD0;
	float3 Tan : TANGENT;
};

struct VS2PS_PP
{
	float4 HPos : POSITION;
	float2 Tex0 : TEXCOORD0;
	float3 GroundUVAndLerp : TEXCOORD1;
	float3 SkinnedLightVec : TEXCOORD2;
	float3 HalfVec : TEXCOORD3;
};

//----------------
// Humanskin
//----------------

struct VS2PS_Skinpre
{
	float4 HPos : POSITION;
	float2 Tex0 : TEXCOORD0;
	float3 SkinnedLightVec : TEXCOORD1;
	float3 ObjEyeVec : TEXCOORD2;
	float3 GroundUVAndLerp : TEXCOORD3;
};

VS2PS_Skinpre Skin_Pre_VS(APP2VS Input, uniform int NumBones)
{
	VS2PS_Skinpre Output;
	float3 Pos, Normal;

	SkinSoldier_PP(NumBones, Input, -_SunLightDirection.xyz, Pos, Normal, Output.SkinnedLightVec);

	Output.ObjEyeVec = normalize(_ObjectEyePos.xyz - Pos);

	Output.HPos.xy = Input.TexCoord0 * float2(2.0, -2.0) - float2(1.0, -1.0);
	Output.HPos.zw = float2(0.0, 1.0);

	// Hemi lookup values
	float4 WorldPos = mul(Pos, _World);
	Output.GroundUVAndLerp.xy = ((WorldPos.xyz + (_HemiMapInfo.z / 2.0) + Normal * 1.0).xz - _HemiMapInfo.xy) / _HemiMapInfo.z;
	Output.GroundUVAndLerp.y = 1.0 - Output.GroundUVAndLerp.y;
	Output.GroundUVAndLerp.z = (Normal.y * 0.5) + 0.5;
	Output.GroundUVAndLerp.z -= _HemiMapInfo.w;

	Output.Tex0 = Input.TexCoord0;
	Output.SkinnedLightVec = normalize(Output.SkinnedLightVec);

	return Output;
}

float4 Skin_Pre_PS(VS2PS_Skinpre Input) : COLOR
{
	float4 ExpNormal = tex2D(Sampler_0, Input.Tex0);
	float4 GroundColor = tex2D(Sampler_1, Input.GroundUVAndLerp.xy);

	ExpNormal.rgb = (ExpNormal * 2.0) - 1.0;
	float WrapDiff = dot(ExpNormal.xyz, Input.SkinnedLightVec) + 0.5;
	WrapDiff = saturate(WrapDiff / 1.5);

	float RimDiff = 1.0 - dot(ExpNormal.xyz, Input.ObjEyeVec);
	RimDiff = pow(RimDiff, 3.0);

	RimDiff *= saturate(0.75 - saturate(dot(Input.ObjEyeVec, Input.SkinnedLightVec)));
	// RimDiff *= saturate(0.1-saturate(dot(Input.ObjEyeVec, normalize(Input.SkinnedLightVec))));

	return float4((WrapDiff.rrr + RimDiff) * GroundColor.a * GroundColor.a, ExpNormal.a);
}

struct VS2PS_Skinpreshadowed
{
	float4 HPos : POSITION;
	float4 Tex0AndHZW : TEXCOORD0;
	float3 SkinnedLightVec : TEXCOORD1;
	float4 ShadowTex : TEXCOORD2;
	float3 ObjEyeVec : TEXCOORD3;
};

VS2PS_Skinpreshadowed Skin_Preshadowed_VS(APP2VS Input, uniform int NumBones)
{
	VS2PS_Skinpreshadowed Output;
	float3 Pos, Normal;

	// don't need as much code for this case.. will rewrite later
	SkinSoldier_PP(NumBones, Input, -_SunLightDirection.xyz, Pos, Normal, Output.SkinnedLightVec);

	Output.ObjEyeVec = normalize(_ObjectEyePos.xyz - Pos);

	Output.ShadowTex = mul(float4(Pos, 1), _LightViewProj);
	Output.ShadowTex.z -= 0.007;

	Output.HPos.xy = Input.TexCoord0 * float2(2.0, -2.0) - float2(1.0, -1.0);
	Output.HPos.zw = float2(0.0, 1.0);
	Output.Tex0AndHZW = Input.TexCoord0.xyyy;

	return Output;
}

float4 Skin_Preshadowed_PS(VS2PS_Skinpreshadowed Input) : COLOR
{
	float4 ExpNormal = tex2D(Sampler_0, Input.Tex0AndHZW.xy);
	ExpNormal.rgb = (ExpNormal * 2.0) - 1.0;

	float WrapDiff = dot(ExpNormal.xyz, Input.SkinnedLightVec) + 0.5;
	WrapDiff = saturate(WrapDiff / 1.5);

	float RimDiff = 1.0 - dot(ExpNormal.xyz, Input.ObjEyeVec);
	RimDiff = pow(RimDiff, 3.0);
	RimDiff *= saturate(0.75 - saturate(dot(Input.ObjEyeVec, Input.SkinnedLightVec)));

	float2 Texel = float2(1.0 / 1024.0, 1.0 / 1024.0);
	float4 Samples;
	// Input.ShadowTex.xy = clamp(Input.ShadowTex.xy, _ViewportMap.xy, _ViewportMap.zw);
	Samples.x = tex2D(Sampler_2, Input.ShadowTex.xy);
	Samples.y = tex2D(Sampler_2, Input.ShadowTex.xy + float2(Texel.x, 0));
	Samples.z = tex2D(Sampler_2, Input.ShadowTex.xy + float2(0, Texel.y));
	Samples.w = tex2D(Sampler_2, Input.ShadowTex.xy + Texel);

	float4 StaticSamples;
	StaticSamples.x = tex2D(Sampler_1, Input.ShadowTex.xy + float2(-Texel.x, -Texel.y * 2.0)).b;
	StaticSamples.y = tex2D(Sampler_1, Input.ShadowTex.xy + float2(Texel.x, -Texel.y * 2.0)).b;
	StaticSamples.z = tex2D(Sampler_1, Input.ShadowTex.xy + float2(-Texel.x, Texel.y * 2.0)).b;
	StaticSamples.w = tex2D(Sampler_1, Input.ShadowTex.xy + float2(Texel.x, Texel.y * 2.0)).b;
	StaticSamples.x = dot(StaticSamples.xyzw, 0.25);

	float4 CMPBits = Samples > saturate(Input.ShadowTex.z);
	float AvgShadowValue = dot(CMPBits, 0.25);

	float TotalShadow = AvgShadowValue.x * StaticSamples.x;
	float TotalDiff = WrapDiff + RimDiff;
	return float4(TotalDiff, TotalShadow, saturate(TotalShadow + 0.35), ExpNormal.a);
}

VS2PS_PP Skin_Apply_VS(APP2VS Input, uniform int NumBones)
{
	VS2PS_PP Output;

	float3 Pos, Normal;

	SkinSoldier_PP(NumBones, Input, -_SunLightDirection.xyz, Pos, Normal, Output.SkinnedLightVec);

	// Transform position into view and then projection space
	Output.HPos = mul(float4(Pos.xyz, 1.0f), _WorldViewProjection);

	// Hemi lookup values
	float4 WorldPos = mul(Pos, _World);
	Output.GroundUVAndLerp.xy =
		((WorldPos.xyz + (_HemiMapInfo.z / 2.0) + Normal * 1.0).xz - _HemiMapInfo.xy) / _HemiMapInfo.z;
	Output.GroundUVAndLerp.y = 1.0 - Output.GroundUVAndLerp.y;
	Output.GroundUVAndLerp.z = (Normal.y * 0.5) + 0.5;
	Output.GroundUVAndLerp.z -= _HemiMapInfo.w;

	Output.Tex0 = Input.TexCoord0;
	Output.HalfVec = normalize(normalize(_ObjectEyePos.xyz - Pos) + Output.SkinnedLightVec);
	Output.SkinnedLightVec = normalize(Output.SkinnedLightVec);

	return Output;
}

float4 Skin_Apply_PS(VS2PS_PP Input) : COLOR
{
	float4 GroundColor = tex2D(Sampler_0, Input.GroundUVAndLerp.xy);
	float4 HemiColor = lerp(GroundColor, _SkyColor, Input.GroundUVAndLerp.z);
	float4 ExpNormal = tex2D(Sampler_1, Input.Tex0);
	ExpNormal.rgb = (ExpNormal * 2.0) - 1.0;
	float4 Diffuse = tex2D(Sampler_2, Input.Tex0);
	float4 DiffuseLight = tex2D(Sampler_3, Input.Tex0);

	// Glossmap is in the Diffuse alpha channel.
	float Specular = pow(dot(ExpNormal.rgb, Input.HalfVec), 32.0) * Diffuse.a;

	float4 TotalColor = saturate(_AmbientColor * HemiColor + DiffuseLight.r * DiffuseLight.b * _SunColor);
	TotalColor *= Diffuse;

	// What to do what the shadow???
	float ShadowIntensity = saturate(DiffuseLight.g);
	TotalColor.rgb += Specular * ShadowIntensity * ShadowIntensity;
	return TotalColor;
}

technique humanskin
{
	pass pre
	{
		CullMode = NONE;
		AlphaBlendEnable = FALSE;
		ZEnable = FALSE;
		ZWriteEnable = FALSE;
		ZFunc = LESSEQUAL;

		StencilEnable = FALSE;

		VertexShader = compile vs_3_0 Skin_Pre_VS(2);
		PixelShader = compile ps_3_0 Skin_Pre_PS();
	}

	pass preshadowed
	{
		CullMode = NONE;
		AlphaBlendEnable = FALSE;
		ZEnable = FALSE;
		ZWriteEnable = FALSE;
		ZFunc = LESSEQUAL;

		StencilEnable = FALSE;

		VertexShader = compile vs_3_0 Skin_Preshadowed_VS(2);
		PixelShader = compile ps_3_0 Skin_Preshadowed_PS();
	}

	pass apply
	{
		CullMode = CCW;
		AlphaBlendEnable = FALSE;
		ZEnable = TRUE;
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;

		VertexShader = compile vs_3_0 Skin_Apply_VS(2);
		PixelShader = compile ps_3_0 Skin_Apply_PS();
	}
}

struct VS2PS_ShadowMap
{
	float4 HPos : POSITION;
	float2 PosZW : TEXCOORD0;
};

VS2PS_ShadowMap ShadowMap_VS(APP2VS Input)
{
	VS2PS_ShadowMap Output;

	// Compensate for lack of UBYTE4 on Geforce3
	int4 IndexVector = D3DCOLORtoUBYTE4(Input.BlendIndices);

	// Cast the vectors to arrays for use in the for loop below
	float BlendWeightsArray[1] = (float[1])Input.BlendWeights;
	int IndexArray[4] = (int[4])IndexVector;

	float3 Pos = mul(Input.Pos, _BoneArray[IndexArray[0]]) * BlendWeightsArray[0];
	Pos += mul(Input.Pos, _BoneArray[IndexArray[1]]) * (1.0 - BlendWeightsArray[0]);

	Output.HPos = mul(float4(Pos.xyz, 1.0), _vpLightTrapezMat);
	float2 LightZW = mul(float4(Pos.xyz, 1.0), _vpLightMat).zw;
	Output.HPos.z = (LightZW.x * Output.HPos.w) / LightZW.y; // (zL*wT)/wL == zL/wL post homo
	Output.PosZW = Output.HPos.zw;

	return Output;

	// Shadow
	Output.HPos = mul(float4(Pos.xyz, 1.0), _vpLightMat);
	Output.PosZW = Output.HPos.zw;

	return Output;
}

float4 ShadowMap_PS(VS2PS_ShadowMap Input) : COLOR
{
	#if NVIDIA
		return 0.0;
	#else
		return Input.PosZW.x / Input.PosZW.y;
	#endif
}

struct VS2PS_ShadowMapAlpha
{
	float4 HPos : POSITION;
	float4 Tex0PosZW : TEXCOORD0;
};

VS2PS_ShadowMapAlpha ShadowMapAlpha_VS(APP2VS Input)
{
	VS2PS_ShadowMapAlpha Output;

	// Compensate for lack of UBYTE4 on Geforce3
	int4 IndexVector = D3DCOLORtoUBYTE4(Input.BlendIndices);

	// Cast the vectors to arrays for use in the for loop below
	float BlendWeightsArray[1] = (float[1])Input.BlendWeights;
	int IndexArray[4] = (int[4])IndexVector;

	float3 Pos = mul(Input.Pos, _BoneArray[IndexArray[0]]) * BlendWeightsArray[0];
	Pos += mul(Input.Pos, _BoneArray[IndexArray[1]]) * (1.0 - BlendWeightsArray[0]);

	Output.HPos = mul(float4(Pos.xyz, 1.0), _vpLightTrapezMat);
	float2 LightZW = mul(float4(Pos.xyz, 1.0), _vpLightMat).zw;
	Output.HPos.z = (LightZW.x * Output.HPos.w) / LightZW.y; // (zL*wT)/wL == zL/wL post homo
	Output.Tex0PosZW.xy = Input.TexCoord0;
	Output.Tex0PosZW.zw = Output.HPos.zw;

	return Output;
}

float4 ShadowMapAlpha_PS(VS2PS_ShadowMapAlpha Input) : COLOR
{
	float Alpha = tex2D(Sampler_0, Input.Tex0PosZW.xy).a - _ShadowAlphaThreshold;
	#if NVIDIA
		return Alpha;
	#else
		clip(Alpha);
		return Input.Tex0PosZW.z / Input.Tex0PosZW.w;
	#endif
}

technique DrawShadowMap
{
	pass directionalspot
	{
		#if NVIDIA
			ColorWriteEnable = 0; // 0x0000000F;
		#endif

		AlphaBlendEnable = FALSE;
		ZEnable = TRUE;
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;
		CullMode = CW;

		ScissorTestEnable = TRUE;

		VertexShader = compile vs_3_0 ShadowMap_VS();
		PixelShader = compile ps_3_0 ShadowMap_PS();

		CullMode = None;
	}

	pass directionalspotalpha
	{
		#if NVIDIA
			ColorWriteEnable = 0; // 0x0000000F;
			AlphaTestEnable = TRUE;
			AlphaRef = 0;
		#endif

		AlphaBlendEnable = FALSE;
		ZEnable = TRUE;
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;

		ScissorTestEnable = TRUE;

		VertexShader = compile vs_3_0 ShadowMapAlpha_VS();
		PixelShader = compile ps_3_0 ShadowMapAlpha_PS();

		CullMode = CCW;
		CullMode = None;
	}

	pass point_
	{
		#if NVIDIA
			ColorWriteEnable = 0; // 0x0000000F;
		#endif

		AlphaBlendEnable = FALSE;
		ZEnable = TRUE;
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;

		ScissorTestEnable = TRUE;

		VertexShader = compile vs_3_0 ShadowMap_VS();
		PixelShader = compile ps_3_0 ShadowMap_PS();

		CullMode = None;
	}
}

// We actually don't need to have 2 techniques here
// but it is kept for back-compatibility with original BF2
technique DrawShadowMapNV
{
	pass directionalspot
	{
		#if NVIDIA
			ColorWriteEnable = 0; // 0x0000000F;
		#endif

		AlphaBlendEnable = FALSE;
		ZEnable = TRUE;
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;
		CullMode = CW;

		ScissorTestEnable = TRUE;

		VertexShader = compile vs_3_0 ShadowMap_VS();
		PixelShader = compile ps_3_0 ShadowMap_PS();

		CullMode = None;
	}

	pass directionalspotalpha
	{
		#if NVIDIA
			ColorWriteEnable = 0; // 0x0000000F;
			AlphaTestEnable = TRUE;
			AlphaRef = 0;
		#endif

		AlphaBlendEnable = FALSE;
		ZEnable = TRUE;
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;

		ScissorTestEnable = TRUE;

		VertexShader = compile vs_3_0 ShadowMapAlpha_VS();
		PixelShader = compile ps_3_0 ShadowMapAlpha_PS();

		CullMode = CCW;
		CullMode = None;
	}

	pass point_
	{
		#if NVIDIA
			ColorWriteEnable = 0; // 0x0000000F;
		#endif

		AlphaBlendEnable = FALSE;
		ZEnable = TRUE;
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;

		ScissorTestEnable = TRUE;

		VertexShader = compile vs_3_0 ShadowMap_VS();
		PixelShader = compile ps_3_0 ShadowMap_PS();

		CullMode = None;
	}
}
