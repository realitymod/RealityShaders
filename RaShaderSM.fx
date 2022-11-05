
/*
	Description:
	- Renders lighting for skinnedmesh (objects that are dynamic, human-like with bones)
	- Skinning function currently for 2 bones
	- Calculates world-space lighting
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

float4x3 GetSkinnedObjectMatrix(APP2VS Input)
{
	float4x3 BoneMatrix = (float4x3)0;
	BoneMatrix += (GetBoneMatrix(Input, 0) * (Input.BlendWeights));
	BoneMatrix += (GetBoneMatrix(Input, 1) * (1.0 - Input.BlendWeights));
	return BoneMatrix;
}

float GetBinormalFlipping(APP2VS Input)
{
	int4 IndexVector = D3DCOLORtoUBYTE4(Input.BlendIndices);
	int IndexArray[4] = (int[4])IndexVector;
	return 1.0 + IndexArray[2] * -2.0;
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

struct VS2PS
{
	float4 HPos : POSITION;

	float3 WorldPos : TEXCOORD0;
	float4 P_Tex0_GroundUV : TEXCOORD1; // .xy = Tex0; .zw = GroundUV;
	float3 Tangent : TEXCOORD2;
	float3 BiNormal : TEXCOORD3;
	float3 Normal : TEXCOORD4;
	float4 ShadowTex : TEXCOORD5;
	float4 OccShadowTex : TEXCOORD6;
};

VS2PS SkinnedMesh_VS(APP2VS Input)
{
	VS2PS Output = (VS2PS)0;

	// Get object-space properties
	float4 ObjectPosition = Input.Pos;
	float3x3 ObjectTBN = GetTangentBasis(Input.Tan, Input.Normal, GetBinormalFlipping(Input));

	// Get skinned object-space properties
	float4x3 SkinnedObjectMatrix = GetSkinnedObjectMatrix(Input);
	float4 SkinnedObjectPosition = float4(mul(ObjectPosition, SkinnedObjectMatrix), 1.0);
	float3x3 SkinnedObjectTBN = mul(ObjectTBN, (float3x3)SkinnedObjectMatrix);

	// Get world-space properties
	float4x3 SkinnedWorldMatrix = mul(SkinnedObjectMatrix, World);
	float3x3 SkinnedWorldTBN = mul(SkinnedObjectTBN, (float3x3)World);
	float4 WorldPos = mul(SkinnedObjectPosition, World);
	float3 WorldNormal = normalize(mul(SkinnedObjectTBN[2], World));

	#if _OBJSPACENORMALMAP_ // (Object Space) -> (Skinned Object Space) -> (Skinned World Space)
		Output.Tangent = SkinnedWorldMatrix[0].xyz;
		Output.BiNormal = SkinnedWorldMatrix[1].xyz;
		Output.Normal = SkinnedWorldMatrix[2].xyz;
	#else // (Tangent Space) -> (Object Space) -> (Skinned Object Space) -> (Skinned World Space)
		Output.Tangent = SkinnedWorldTBN[0].xyz;
		Output.BiNormal = SkinnedWorldTBN[1].xyz;
		Output.Normal = SkinnedWorldTBN[2].xyz;
	#endif
	
	// Output HPos
	Output.HPos = mul(SkinnedObjectPosition, WorldViewProjection);

	Output.WorldPos.xyz = WorldPos.xyz;
	Output.P_Tex0_GroundUV.xy = Input.TexCoord0;

	#if _USEHEMIMAP_
		Output.P_Tex0_GroundUV.zw = GetGroundUV(WorldPos.xyz, WorldNormal);
	#endif

	#if _HASSHADOW_
		Output.ShadowTex = GetShadowProjection(WorldPos);
	#endif

	#if _HASSHADOWOCCLUSION_
		Output.OccShadowTex = GetShadowProjection(WorldPos, true);
	#endif

	return Output;
}

// NOTE: This returns un-normalized for point, because point needs to be attenuated.
float3 GetLightVec(float3 WorldPos)
{
	#if _POINTLIGHT_
		return mul(float4(Lights[0].pos, 1.0), World) - WorldPos;
	#else
		return mul(-Lights[0].dir, (float3x3)World);
	#endif
}

float4 SkinnedMesh_PS(VS2PS Input) : COLOR
{
	// Get world-space properties
	float3 WorldPos = Input.WorldPos;
	float3x3 WorldTBN;
	WorldTBN[0] = normalize(Input.Tangent);
	WorldTBN[1] = normalize(Input.BiNormal);
	WorldTBN[2] = normalize(Input.Normal);

	// mul(mat, vec) ==	mul(vec, transpose(mat))
	float3 WorldLightVec = GetLightVec(WorldPos.xyz);
	float3 LightVec = normalize(WorldLightVec);
	float3 ViewVec = normalize(WorldSpaceCamPos.xyz - WorldPos.xyz);
	float3 HalfVec = normalize(LightVec + ViewVec);

	// (.a) stores the glossmap
	#if _HASNORMALMAP_
		float4 NormalVec = tex2D(SampleNormalMap, Input.P_Tex0_GroundUV.xy);
		NormalVec.xyz = normalize(NormalVec.xyz * 2.0 - 1.0);
		NormalVec.xyz = normalize(mul(NormalVec.xyz, WorldTBN));
	#else
		float4 NormalVec = float4(WorldTBN[2], 0.0);
	#endif

	float4 ColorMap = tex2D(SampleDiffuseMap, Input.P_Tex0_GroundUV.xy);

	#if _HASSHADOW_
		float ShadowDir = GetShadowFactor(SampleShadowMap, Input.ShadowTex);
	#else
		float ShadowDir = 1.0;
	#endif

	#if _HASSHADOWOCCLUSION_
		float OccShadowDir = GetShadowFactor(ShadowOccluderMapSampler, Input.OccShadowTex);
	#else
		float OccShadowDir = 1.0;
	#endif

	#if _POINTLIGHT_
		float3 Ambient = 0.0;
	#else
		#if _USEHEMIMAP_
			// GoundColor.a has an occlusion factor that we can use for static shadowing
			float HemiLerp = GetHemiLerp(WorldPos.xyz, NormalVec.xyz);
			float4 GroundColor = tex2D(SampleHemiMap, Input.P_Tex0_GroundUV.zw);
			float3 Ambient = lerp(GroundColor, HemiMapSkyColor, HemiLerp);
		#else
			float3 Ambient = Lights[0].color.w;
		#endif
	#endif

	#if _POINTLIGHT_
		float Attenuation = GetLightAttenuation(WorldLightVec, Lights[0].attenuation);
	#else
		const float Attenuation = 1.0;
	#endif

	float Gloss = NormalVec.a;
	float CosAngle = GetLambert(NormalVec.xyz, LightVec);
	float3 Diffuse = CosAngle * Lights[0].color;
	float3 Specular = GetSpecular(NormalVec.xyz, HalfVec, SpecularPower) * Gloss * Lights[0].color;
	float3 LightFactors = Attenuation * (ShadowDir * OccShadowDir);

	// Only add specular to bundledmesh with a glossmap (.a channel in NormalMap or ColorMap)
	// Prevents non-detailed bundledmesh from looking shiny
	#if _HASNORMALMAP_
		float3 Lighting = (Diffuse + (Specular * CosAngle)) * LightFactors;
	#else
		float3 Lighting = (Diffuse) * LightFactors;
	#endif

	float4 OutColor = 1.0;
	OutColor.rgb = ColorMap.rgb * (Ambient + Lighting);

	// Thermals
	if (FogColor.r < 0.01)
	{
		#if _HASENVMAP_ // If EnvMap enabled, then should be hot on thermals
			OutColor.rgb = float3(lerp(0.60, 0.30, ColorMap.b), 1.0, 0.0); // M // 0.61, 0.25
		#else // Else cold
			OutColor.rgb = float3(lerp(0.43, 0.17, ColorMap.b), 1.0, 0.0);
		#endif
	}

	#if !_POINTLIGHT_
		ApplyFog(OutColor.rgb, GetFogValue(WorldPos, WorldSpaceCamPos));
	#endif

	OutColor.a = ColorMap.a * Transparency.a;

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
