#line 2 "RaShaderSM.fx"

/*
	Include header files
*/

#include "shaders/RealityGraphics.fxh"
#include "shaders/shared/RealityDepth.fxh"
#include "shaders/shared/RealityDirectXTK.fxh"
#include "shaders/shared/RealityVertex.fxh"
#include "shaders/shared/RealityPixel.fxh"
#include "shaders/RaCommon.fxh"
#include "shaders/RaShaderSM.fxh"
#if !defined(_HEADERS_)
	#include "RealityGraphics.fxh"
	#include "shared/RealityDepth.fxh"
	#include "shared/RealityDirectXTK.fxh"
	#include "shared/RealityVertex.fxh"
	#include "shared/RealityPixel.fxh"
	#include "RaCommon.fxh"
	#include "RaShaderSM.fxh"
#endif

/*
	Description:
	- Renders lighting for skinnedmesh (objects that are dynamic, human-like with bones)
	- Skinning function currently for 2 bones
	- Calculates direction lighting dependant on the space of the normalmap
*/

// Dep.checks, etc

#if _POINTLIGHT_
	#define _HASENVMAP_ 0
	#define _USEHEMIMAP_ 0
	#define _HASSHADOW_ 0
#endif

#undef _DEBUG_
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

struct VS2PS
{
	float4 HPos : POSITION;
	float4 Pos : TEXCOORD0;
	float2 Tex0 : TEXCOORD1;
	#if _HASNORMALMAP_
		float3 WorldTangent : TEXCOORD2;
		float3 WorldBinormal : TEXCOORD3;
	#endif
	float3 WorldNormal : TEXCOORD4;
	#if _HASSHADOW_
		float4 ShadowTex : TEXCOORD5;
	#endif
	#if _HASSHADOWOCCLUSION_
		float4 ShadowOccTex : TEXCOORD6;
	#endif
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
	return 1.0 + D3DCOLORtoUBYTE4(Input.BlendIndices)[2] * -2.0;
}

float4x3 GetBlendedBoneMatrix(APP2VS Input)
{
	float4x3 Mat0 = GetBoneMatrix(Input, 0);
	float4x3 Mat1 = GetBoneMatrix(Input, 1);
	return lerp(Mat1, Mat0, Input.BlendWeights); 
}

float GetHemiLerp(float3 WorldPos, float3 WorldNormal)
{
	// LocalHeight scale, 1 for top and 0 for bottom
	float LocalHeight = (WorldPos.y - (World[3][1] - 0.5)) * 0.5;
	float Offset = (RGraphics_ConvertUNORMtoSNORM_FLT1(LocalHeight)) + HeightOverTerrain;
	Offset = clamp(Offset, (1.0 - HeightOverTerrain) * -2.0, 0.8);
	return clamp(((WorldNormal.y + Offset) * 0.5) + 0.5, 0.0, 0.9);
}

VS2PS VS_SkinnedMesh(APP2VS Input)
{
	VS2PS Output = (VS2PS)0.0;

	// Get skinned object-space data
	float4x3 BoneMatrix = GetBlendedBoneMatrix(Input);
	float4 ObjectPos = float4(mul(Input.Pos, BoneMatrix), 1.0);
	float3x3 ObjectTBN = RVertex_GetTangentBasis(Input.Tan, Input.Normal, GetBinormalFlipping(Input));

	// Output HPos data
	Output.HPos = mul(ObjectPos, WorldViewProjection);
	// World-space data
	float4 WorldPos = mul(float4(Input.Pos.xyz, 1.0), World);
	float4 SkinWorldPos = mul(ObjectPos, World);
	float3x3 WorldMat = mul((float3x3)BoneMatrix, (float3x3)World);
	float3x3 WorldTBN = mul(ObjectTBN, WorldMat);
	#if _HASNORMALMAP_
		#if _OBJSPACENORMALMAP_
			// [object-space] -> [skinned object-space] -> [skinned world-space]
			Output.WorldTangent = WorldMat[0];
			Output.WorldBinormal = WorldMat[1];
			Output.WorldNormal = WorldMat[2];
		#else
			// [tangent-space] -> [object-space] -> [skinned object-space] -> [skinned world-space]
			Output.WorldTangent = WorldTBN[0];
			Output.WorldBinormal = WorldTBN[1];
			Output.WorldNormal = WorldTBN[2];
		#endif
	#else
		Output.WorldNormal = WorldTBN[2];
	#endif
	Output.Pos = SkinWorldPos;

	// Output Depth
	#if PR_LOG_DEPTH
		Output.Pos.w = Output.HPos.w + 1.0;
	#endif

	// Texture-space data
	Output.Tex0 = Input.TexCoord0;
	#if _HASSHADOW_
		Output.ShadowTex = Ra_GetMeshShadowProjection(SkinWorldPos);
	#endif
	#if _HASSHADOWOCCLUSION_
		Output.ShadowOccTex = Ra_GetMeshShadowProjection(SkinWorldPos, true);
	#endif

	return Output;
}

float3 GetSpecularColor()
{
	#if _POINTLIGHT_
		return Lights[0].color.rgb;
	#else
		return Lights[0].specularColor.rgb;
	#endif
}

RGraphics_PS2FB PS_SkinnedMesh(VS2PS Input)
{
	RGraphics_PS2FB Output = (RGraphics_PS2FB)0.0;

	// Texture-space data
	float4 ColorMap = RDirectXTK_SRGBToLinearEst(tex2D(SampleDiffuseMap, Input.Tex0));
	#if _HASNORMALMAP_
		float3x3 WorldTBN =
		{
			normalize(Input.WorldTangent),
			normalize(Input.WorldBinormal),
			normalize(Input.WorldNormal)
		};

		// NormalMap.a stores the glossmap
		float4 NormalMap = tex2D(SampleNormalMap, Input.Tex0);
		NormalMap.xyz = normalize(RGraphics_ConvertUNORMtoSNORM_FLT3(NormalMap.xyz));
		float3 WorldNormal = mul(NormalMap.xyz, WorldTBN);
	#else
		float4 NormalMap = float4(0.0, 0.0, 1.0, 0.0);
		float3 WorldNormal = normalize(Input.WorldNormal);
	#endif

	// Lighting data
	float3 WorldPos = Input.Pos.xyz;
	float3 WorldLightDir = normalize(mul(-Lights[0].dir.xyz, (float3x3)World));
	float3 WorldViewDir = normalize(WorldSpaceCamPos.xyz - WorldPos);

	#if _HASSHADOW_
		float Shadow = RDepth_GetShadowFactor(SampleShadowMap, Input.ShadowTex);
	#else
		float Shadow = 1.0;
	#endif
	#if _HASSHADOWOCCLUSION_
		float ShadowOcc = RDepth_GetShadowFactor(SampleShadowOccluderMap, Input.ShadowOccTex);
	#else
		float ShadowOcc = 1.0;
	#endif

	float HemiLight = 1.0;
	#if _POINTLIGHT_
		float Ambient = 0.0;
	#else
		#if _USEHEMIMAP_
			// GoundColor.a has an occlusion factor that we can use for static shadowing
			float2 HemiTex = RPixel_GetHemiTex(WorldPos, 0.0, HemiMapConstants, true);
			float4 HemiMap = RDirectXTK_SRGBToLinearEst(tex2D(SampleHemiMap, HemiTex));
			float HemiLerp = GetHemiLerp(WorldPos, WorldNormal);
			float3 Ambient = lerp(HemiMap, HemiMapSkyColor, HemiLerp);
			// HemiLight = HemiMap.a;
		#else
			float Ambient = Lights[0].color.a;
		#endif
	#endif

	#if _POINTLIGHT_
		float3 WorldLightVec = Ra_GetWorldLightPos(Lights[0].pos.xyz) - WorldPos;
		float Attenuation = RPixel_GetLightAttenuation(WorldLightVec, Lights[0].attenuation);
	#else
		float Attenuation = 1.0;
	#endif

	float4 OutputColor = 1.0;

	// Calculate lighting
	RDirectXTK_ColorPair Light = RDirectXTK_ComputeLights(WorldNormal.xyz, WorldLightDir, WorldViewDir, SpecularPower);
	float TotalLights = Attenuation * (HemiLight * Shadow * ShadowOcc);
	float3 DiffuseRGB = (Light.Diffuse * Lights[0].color.rgb) * TotalLights;
	float3 SpecularRGB = ((Light.Specular * NormalMap.a) * GetSpecularColor()) * TotalLights;
	OutputColor.rgb = RDirectXTK_CompositeLights(ColorMap.rgb, Ambient, DiffuseRGB, SpecularRGB);
	OutputColor.a = ColorMap.a * Transparency.a;

	// Thermals
	if (Ra_IsTisActive())
	{
		#if _HASENVMAP_ // If EnvMap enabled, then should be hot on thermals
			OutputColor.rgb = float3(lerp(0.60, 0.30, ColorMap.b), 1.0, 0.0); // M // 0.61, 0.25
		#else // Else cold
			OutputColor.rgb = float3(lerp(0.43, 0.17, ColorMap.b), 1.0, 0.0);
		#endif
	}

	Output.Color = OutputColor;
	#if !_POINTLIGHT_
		Ra_ApplyFog(Output.Color.rgb, Ra_GetFogValue(WorldPos, WorldSpaceCamPos.xyz));
	#endif
	RDirectXTK_TonemapAndLinearToSRGBEst(Output.Color);

	#if PR_LOG_DEPTH
		Output.Depth = RDepth_ApplyLogarithmicDepth(Input.Pos.w);
	#endif

	return Output;
}

technique VariableTechnique
{
	pass p0
	{
		ZEnable = TRUE;
		ZFunc = PR_ZFUNC_WITHEQUAL;

		AlphaTestEnable = (AlphaTest);
		AlphaRef = (AlphaTestRef);

		#if _POINTLIGHT_
			AlphaBlendEnable = TRUE;
			SrcBlend = ONE;
			DestBlend = ONE;
		#else
			AlphaBlendEnable = FALSE;
		#endif

		VertexShader = compile vs_3_0 VS_SkinnedMesh();
		PixelShader = compile ps_3_0 PS_SkinnedMesh();
	}
}
