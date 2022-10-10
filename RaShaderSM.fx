
/*
	Description: Renders lighting for skinnedmesh (objects that are dynamic, human-like with bones)
*/

#include "shaders/RealityGraphics.fx"
#include "shaders/RaCommon.fx"
#include "shaders/RaShaderSMCommon.fx"

// Debug data
// #define _HASNORMALMAP_ 1
// #define _OBJSPACENORMALMAP_ 1
// #define _HASENVMAP_ 1

// #define _USEHEMIMAP_ 1
// #define _HASSHADOW_ 1
// #define _HASSHADOWOCCLUSION_ 1
// #define _POINTLIGHT_ 1

// Dep.checks, etc

#if _POINTLIGHT_
	#define _HASENVMAP_ 0
	#define _USEHEMIMAP_ 0
	#define _HASSHADOW_ 0
#endif

// Always 2 for now, test with 1!
#define NUMBONES 2

struct APP2VS
{
	float4 Pos : POSITION;
	float3 Normal : NORMAL;
	float BlendWeights : BLENDWEIGHT;
	float4 BlendIndices : BLENDINDICES;
	float2 TexCoord0 : TEXCOORD0;
	float3 Tan : TANGENT;
};

float4x3 GetBoneMatrix(APP2VS Input, uniform int Bone)
{
	// Compensate for lack of UBYTE4 on Geforce3
	int4 IndexVector = D3DCOLORtoUBYTE4(Input.BlendIndices);
	int IndexArray[4] = (int[4])IndexVector;
	return MatBones[IndexArray[Bone]];
}

float GetBinormalFlipping(APP2VS Input)
{
	int4 IndexVector = D3DCOLORtoUBYTE4(Input.BlendIndices);
	int IndexArray[4] = (int[4])IndexVector;
	return 1.0 + IndexArray[2] * -2.0;
}

float3 SkinPos(APP2VS Input, float4 Vec, uniform int NumBones = NUMBONES)
{
	float3 Pos0 = mul(Vec, GetBoneMatrix(Input, 0));
	float3 Pos1 = mul(Vec, GetBoneMatrix(Input, 1));
	float3 SkinnedPos = (NumBones > 1) ? lerp(Pos1, Pos0, Input.BlendWeights) : Pos0;
	return SkinnedPos;
}

float3 SkinVec(APP2VS Input, float3 Vec, uniform int NumBones = NUMBONES)
{
	float3 Vec0 = mul(Vec, GetBoneMatrix(Input, 0));
	float3 Vec1 = mul(Vec, GetBoneMatrix(Input, 1));
	float3 SkinnedVec = (NumBones > 1) ? lerp(Vec1, Vec0, Input.BlendWeights) : Vec0;
	return SkinnedVec;
}

float3 SkinVecToObj(APP2VS Input, float3 Vec, uniform int NumBones = NUMBONES)
{
	float3 Vec0 = mul(Vec, transpose(GetBoneMatrix(Input, 0)));
	float3 Vec1 = mul(Vec, transpose(GetBoneMatrix(Input, 1)));
	float3 SkinnedVec = (NumBones > 1) ? lerp(Vec1, Vec0, Input.BlendWeights) : Vec0;
	return SkinnedVec;
}

float3 SkinVecToTan(APP2VS Input, float3 Vec, uniform int NumBones = NUMBONES)
{
	float3x3 TanBasis = GetTangentBasis(Input.Tan, Input.Normal, GetBinormalFlipping(Input));
	float3 Vec0 = mul(Vec, transpose(mul(TanBasis, GetBoneMatrix(Input, 0))));
	float3 Vec1 = mul(Vec, transpose(mul(TanBasis, GetBoneMatrix(Input, 1))));
	float3 SkinnedVec = (NumBones > 1) ? lerp(Vec1, Vec0, Input.BlendWeights) : Vec0;
	return SkinnedVec;
}

float4 SkinPosition(APP2VS Input)
{
	return float4(SkinPos(Input, Input.Pos), 1.0);
}

float3 SkinNormal(APP2VS Input, uniform int NumBones = NUMBONES)
{
	float3 SkinnedNormal = SkinVec(Input, Input.Normal);
	// Re-normalize skinned Normal
	SkinnedNormal = (NumBones > 1) ? normalize(SkinnedNormal) : SkinnedNormal;
	return SkinnedNormal;
}

float4 GetWorldPos(APP2VS Input)
{
	return mul(SkinPosition(Input), World);
}

float3 GetWorldNormal(APP2VS Input)
{
	return mul(SkinNormal(Input), World);
}

float2 GetGroundUV(float3 WorldPos, float3 WorldNormal)
{
	// HemiMapConstants: Offset x/y heightmapsize z / hemilerpbias w
	float2 GroundUVAndLerp = 0.0;
	GroundUVAndLerp.xy = ((WorldPos + (HemiMapConstants.z / 2.0) + WorldNormal).xz - HemiMapConstants.xy) / HemiMapConstants.z;
	GroundUVAndLerp.y = 1.0 - GroundUVAndLerp.y;
	return GroundUVAndLerp;
}

float GetHemiLerp(float3 WorldPos, float3 WorldNormal)
{
	// LocalHeight scale, 1 for top and 0 for bottom
	float LocalHeight = (WorldPos.y - (World[3][1] - 0.5)) * 0.5 /* InvHemiHeightScale */;
	float Offset = (LocalHeight * 2.0 - 1.0) + HeightOverTerrain;
	Offset = clamp(Offset, -2.0 * (1.0 - HeightOverTerrain), 0.8); // For TL: seems like taking this like away doesn't change much, take it out?
	return clamp((WorldNormal.y + Offset) * 0.5 + 0.5, 0.0, 0.9);
}

float3 SkinLightVec(APP2VS Input, float3 LightVec)
{
	#if _OBJSPACENORMALMAP_ || !_HASNORMALMAP_
		return SkinVecToObj(Input, LightVec, 1);
	#else
		return SkinVecToTan(Input, LightVec, 1);
	#endif
}

// NOTE: This returns un-normalized for point, because point needs to be attenuated.
float3 GetLightVec(APP2VS Input)
{
	#if _POINTLIGHT_
		return (Lights[0].pos - SkinPosition(Input).xyz);
	#else
		return -Lights[0].dir;
	#endif
}

struct VS2PS
{
	float4 HPos : POSITION;
	float4 P_Tex0_GroundUV : TEXCOORD0; // .xy = Tex0; .zw = GroundUV;
	float4 P_LightVec_OccShadow : TEXCOORD1; // .xyz = LightVec; .w = OccShadow;
	float4 P_EyeVec_HemiLerp : TEXCOORD2; // .xyz = EyeVec; .w = HemiLerp;
	float3 NormalVec : TEXCOORD3;
	float3 VertexPos : TEXCOORD4;

	#if _HASSHADOW_ || _HASSHADOWOCCLUSION_
		float4 ShadowMat : TEXCOORD5;
	#endif
};

VS2PS Skin_VS(APP2VS Input)
{
	VS2PS Output = (VS2PS)0;

	float4 ObjSpacePosition = SkinPosition(Input);
	float3 ObjSpaceEyeVec = ObjectSpaceCamPos.xyz - ObjSpacePosition.xyz;

	float4 WorldPos = GetWorldPos(Input);
	float3 WorldNormal = normalize(GetWorldNormal(Input));

	Output.HPos = mul(ObjSpacePosition, WorldViewProjection);
	Output.P_Tex0_GroundUV.xy = Input.TexCoord0;

	Output.P_LightVec_OccShadow.xyz = SkinLightVec(Input, GetLightVec(Input));
	Output.P_EyeVec_HemiLerp.xyz = SkinLightVec(Input, ObjSpaceEyeVec);

	#if (_USEHEMIMAP_)
		Output.P_Tex0_GroundUV.zw = GetGroundUV(WorldPos, WorldNormal);
		Output.P_EyeVec_HemiLerp.w = GetHemiLerp(WorldPos, WorldNormal);
	#endif

	#if _HASSHADOWOCCLUSION_
		Output.P_LightVec_OccShadow.w = GetShadowProjection(WorldPos, true).z;
	#endif

	Output.NormalVec = normalize(Input.Normal);

	#if _HASSHADOW_ || _HASSHADOWOCCLUSION_
		Output.ShadowMat = GetShadowProjection(WorldPos);
	#endif

	Output.VertexPos = ObjSpacePosition.xyz;

	return Output;
}

float4 Skin_PS(VS2PS Input) : COLOR
{
	#if _HASSHADOW_
		float ShadowDir = GetShadowFactor(ShadowMapSampler, Input.ShadowMat);
	#else
		float ShadowDir = 1.0;
	#endif

	#if _HASSHADOWOCCLUSION_
		float4 ShadowOccMat = Input.ShadowMat;
		ShadowOccMat.z = Input.P_LightVec_OccShadow.w;
		float OccShadowDir = GetShadowFactor(ShadowOccluderMapSampler, ShadowOccMat);
		ShadowDir *= OccShadowDir;
	#endif

	#if _USEHEMIMAP_
		// GoundColor.a has an occlusion factor that we can use for static shadowing
		float4 GroundColor = tex2D(HemiMapSampler, Input.P_Tex0_GroundUV.zw);
		float3 HemiColor = lerp(GroundColor, HemiMapSkyColor, Input.P_EyeVec_HemiLerp.w);
	#else
		// "old" -- expose a per-level "static hemi" value (ambient mod)
		const float3 HemiColor = 0.425;
		float4 GroundColor = 1.0;
	#endif

	#if _HASNORMALMAP_
		float4 NormalVec = tex2D(NormalMapSampler, Input.P_Tex0_GroundUV.xy);
		NormalVec.xyz = normalize(NormalVec.xyz * 2.0 - 1.0);
	#else
		float4 NormalVec = float4(normalize(Input.NormalVec), 0.15);
	#endif

	float Gloss = NormalVec.a;
	float3 LightVec = normalize(Input.P_LightVec_OccShadow.xyz);
	float3 EyeVec = normalize(Input.P_EyeVec_HemiLerp.xyz);
	float3 HalfVec = normalize(LightVec + EyeVec);

	float4 DiffuseTex = tex2D(DiffuseMapSampler, Input.P_Tex0_GroundUV.xy);
	float3 DiffuseColor = GetDiffuseValue(NormalVec.xyz, LightVec) * Lights[0].color;
	float3 SpecularColor = GetSpecularValue(NormalVec.xyz, HalfVec, SpecularPower) * Lights[0].color * Gloss;

	#if _POINTLIGHT_
		float Attenuation = GetRadialAttenuation(Input.P_EyeVec_HemiLerp.xyz, Lights[0].attenuation);
	#else
		const float Attenuation = 1.0;
	#endif

	DiffuseColor = DiffuseColor * ShadowDir;
	SpecularColor = (SpecularColor * Attenuation) * ShadowDir;

	#if !_POINTLIGHT_
		DiffuseColor.rgb += HemiColor;
	#endif

	float4 OutColor = 0.0;
	OutColor.rgb = (DiffuseTex.rgb * DiffuseColor.rgb) + SpecularColor;
	OutColor.a = DiffuseTex.a * Transparency.a;

	if (FogColor.r < 0.01)
	{
		#if _HASENVMAP_
			// If EnvMap enabled, then should be hot on thermals
			OutColor.rgb = float3(lerp(0.6, 0.3, DiffuseTex.b), 1.0, 0.0); // M //0.61,0.25
		#else
			// Else cold
			OutColor.rgb = float3(lerp(0.43, 0.17, DiffuseTex.b), 1.0, 0.0);
		#endif
	}

	#if !_POINTLIGHT_
		OutColor.rgb = ApplyFog(OutColor.rgb, GetFogValue(Input.VertexPos.xyz, ObjectSpaceCamPos.xyz));
	#endif

	return OutColor;
}

technique VariableTechnique
{
	pass
	{
		AlphaTestEnable = (AlphaTest);
		AlphaRef = (AlphaTestRef);
		#if _POINTLIGHT_
			AlphaBlendEnable = TRUE;
			SrcBlend = ONE;
			DestBlend = ONE;
		#else
			AlphaBlendEnable = FALSE;
		#endif

		VertexShader = compile vs_3_0 Skin_VS();
		PixelShader = compile ps_3_0 Skin_PS();
	}
}
