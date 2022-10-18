
/*
	Description:
	- Renders lighting for skinnedmesh (objects that are dynamic, human-like with bones)
	- Skinning function currently for 2 bones
	- Calculates tangent-space lighting (object-space lighting for obj normalmap)
*/

#include "shaders/RealityGraphics.fx"
#include "shaders/RaCommon.fx"
#include "shaders/RaShaderSMCommon.fx"

// Dep.checks, etc

#if _POINTLIGHT_
	#define _HASENVMAP_ 0
	#define _USEHEMIMAP_ 0
	#define _HASSHADOW_ 0
#endif

// #define _DEBUG_
#if defined(_DEBUG_)
	#define _HASNORMALMAP_ 1
	#define _OBJSPACENORMALMAP_ 1
	#define _HASENVMAP_ 1
	#define _USEHEMIMAP_ 1
	#define _HASSHADOW_ 1
	#define _HASSHADOWOCCLUSION_ 1
	#define _POINTLIGHT_ 1
#endif

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

float3 SkinPosition(APP2VS Input)
{
	float3 Vec0 = mul(Input.Pos, GetBoneMatrix(Input, 0));
	float3 Vec1 = mul(Input.Pos, GetBoneMatrix(Input, 1));
	return lerp(Vec1, Vec0, Input.BlendWeights);
}

float3 SkinNormal(APP2VS Input)
{
	float3 Vec0 = mul(Input.Normal, GetBoneMatrix(Input, 0));
	float3 Vec1 = mul(Input.Normal, GetBoneMatrix(Input, 1));
	return lerp(Vec1, Vec0, Input.BlendWeights);
}

float3 SkinVecToObj(APP2VS Input, float3 Vec)
{
	float3 Vec0 = mul(Vec, transpose(GetBoneMatrix(Input, 0)));
	float3 Vec1 = mul(Vec, transpose(GetBoneMatrix(Input, 1)));
	return lerp(Vec1, Vec0, Input.BlendWeights);
}

float3 SkinVecToTan(APP2VS Input, float3 Vec)
{
	float3x3 TanBasis = GetTangentBasis(Input.Tan, Input.Normal, GetBinormalFlipping(Input));
	float3 Vec0 = mul(Vec, transpose(mul(TanBasis, GetBoneMatrix(Input, 0))));
	float3 Vec1 = mul(Vec, transpose(mul(TanBasis, GetBoneMatrix(Input, 1))));
	return lerp(Vec1, Vec0, Input.BlendWeights);
}

float2 GetGroundUV(float3 WorldPos, float3 WorldNormal)
{
	// HemiMapConstants: Offset x/y heightmapsize z / hemilerpbias w
	float2 GroundUV = 0.0;
	GroundUV.xy = ((WorldPos + (HemiMapConstants.z / 2.0) + WorldNormal).xz - HemiMapConstants.xy) / HemiMapConstants.z;
	GroundUV.y = 1.0 - GroundUV.y;
	return GroundUV;
}

float GetHemiLerp(float3 WorldPos, float3 WorldNormal)
{
	// LocalHeight scale, 1 for top and 0 for bottom
	float LocalHeight = (WorldPos.y - (World[3][1] - 0.5)) * 0.5;
	float Offset = (LocalHeight * 2.0 - 1.0) + HeightOverTerrain;
	Offset = clamp(Offset, (1.0 - HeightOverTerrain) * -2.0, 0.8);
	return clamp((WorldNormal.y + Offset) * 0.5 + 0.5, 0.0, 0.9);
}

// NOTE: This returns un-normalized for point, because point needs to be attenuated.
float3 GetLightVec(APP2VS Input)
{
	#if _POINTLIGHT_
		return Lights[0].pos - SkinPosition(Input);
	#else
		return -Lights[0].dir;
	#endif
}

struct VS2PS
{
	float4 HPos : POSITION;

	float3 VertexPos : TEXCOORD0;
	float4 P_Tex0_GroundUV : TEXCOORD1; // .xy = Tex0; .zw = GroundUV;
	float4 P_LightVec_OccShadow : TEXCOORD2; // .xyz = LightVec; .w = OccShadow;
	float4 P_EyeVec_HemiLerp : TEXCOORD3; // .xyz = ViewVec; .w = HemiLerp;

	#if _HASSHADOW_ || _HASSHADOWOCCLUSION_
		float4 ShadowMat : TEXCOORD4;
	#endif
};

VS2PS SkinnedMesh_VS(APP2VS Input)
{
	VS2PS Output = (VS2PS)0;

	// Get object-space properties
	float4 ObjectPosition = float4(SkinPosition(Input), 1.0);
	float3 ObjectNormal = normalize(SkinNormal(Input));
	float3 ObjectLightVec = GetLightVec(Input);
	float3 ObjectEyeVec = ObjectSpaceCamPos.xyz - ObjectPosition.xyz;

	// Get world-space properties
	float4 WorldPos = mul(ObjectPosition, World);
	float3 WorldNormal = normalize(mul(ObjectNormal, World));

	// Output HPos
	Output.HPos = mul(ObjectPosition, WorldViewProjection);

	Output.VertexPos = ObjectPosition.xyz;

	#if _OBJSPACENORMALMAP_ // Do object-space bumped lighting
		Output.P_LightVec_OccShadow.xyz = SkinVecToObj(Input, ObjectLightVec);
		Output.P_EyeVec_HemiLerp.xyz = SkinVecToObj(Input, ObjectEyeVec);
	#else // Do tangent-space lighting
		Output.P_LightVec_OccShadow.xyz = SkinVecToTan(Input, ObjectLightVec);
		Output.P_EyeVec_HemiLerp.xyz = SkinVecToTan(Input, ObjectEyeVec);
	#endif

	Output.P_Tex0_GroundUV.xy = Input.TexCoord0;

	#if _USEHEMIMAP_
		Output.P_Tex0_GroundUV.zw = GetGroundUV(WorldPos, WorldNormal);
		Output.P_EyeVec_HemiLerp.w = GetHemiLerp(WorldPos, WorldNormal);
	#endif

	#if _HASSHADOWOCCLUSION_
		Output.P_LightVec_OccShadow.w = GetShadowProjection(WorldPos, true).z;
	#endif

	#if _HASSHADOW_ || _HASSHADOWOCCLUSION_
		Output.ShadowMat = GetShadowProjection(WorldPos);
	#endif

	return Output;
}

float4 SkinnedMesh_PS(VS2PS Input) : COLOR
{
	float3 LightVec = normalize(Input.P_LightVec_OccShadow.xyz);
	float3 ViewVec = normalize(Input.P_EyeVec_HemiLerp.xyz);
	float3 HalfVec = normalize(LightVec + ViewVec);
	float4 DiffuseTex = tex2D(DiffuseMapSampler, Input.P_Tex0_GroundUV.xy);

	#if _HASNORMALMAP_
		float4 NormalVec = tex2D(NormalMapSampler, Input.P_Tex0_GroundUV.xy);
		NormalVec.xyz = normalize(NormalVec.xyz * 2.0 - 1.0);
	#else
		float4 NormalVec = float4(0.0, 0.0, 1.0, 0.1);
	#endif

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
		float HemiLerp = Input.P_EyeVec_HemiLerp.w;
		float4 GroundColor = tex2D(HemiMapSampler, Input.P_Tex0_GroundUV.zw);
		float3 Ambient = lerp(GroundColor, HemiMapSkyColor, HemiLerp);
	#else
		float3 Ambient = Lights[0].color.w;
	#endif

	#if _POINTLIGHT_
		float Attenuation = GetLightAttenuation(Input.P_LightVec_OccShadow.xyz, Lights[0].attenuation);
	#else
		const float Attenuation = 1.0;
	#endif

	float Gloss = NormalVec.a;
	float Diffuse = GetDiffuse(NormalVec.xyz, LightVec);
	float Specular = GetSpecular(Diffuse, NormalVec.xyz, HalfVec) * Gloss;

	float3 LightFactors = Attenuation * ShadowDir;
	float3 Lighting = ((Diffuse + Specular) * Lights[0].color) * LightFactors;

	float4 OutColor = 1.0;
	OutColor.rgb = DiffuseTex.rgb * (Ambient + Lighting);
	OutColor.a = DiffuseTex.a * Transparency.a;

	if (FogColor.r < 0.01)
	{
		#if _HASENVMAP_
			// If EnvMap enabled, then should be hot on thermals
			OutColor.rgb = float3(lerp(0.6, 0.3, DiffuseTex.b), 1.0, 0.0); // M // 0.61, 0.25
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

		VertexShader = compile vs_3_0 SkinnedMesh_VS();
		PixelShader = compile ps_3_0 SkinnedMesh_PS();
	}
}
