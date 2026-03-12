#line 2 "RaShaderSM.fx"

/*
	This shader renders lighting for skinned mesh (dynamic, human-like objects with bones). It supports bone-based animation with 2-bone skinning, normal mapping, environment mapping, and shadow mapping. The shader calculates world-space lighting and handles complex material properties for character rendering.
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
	float4 WorldPos : TEXCOORD0;
	float3 Tex0AndOccShadowTex : TEXCOORD1; // .xy = Tex0; .z = OccShadowTex
	#if _HASNORMALMAP_
		float3 WorldToTexture0 : TEXCOORD2;
		float3 WorldToTexture1 : TEXCOORD3;
		float3 WorldToTexture2 : TEXCOORD4;
	#else
		float3 WorldNormal : TEXCOORD2;
	#endif
	#if _USEHEMIMAP_ && (!_USEPERPIXELHEMIMAP_ || !_HASNORMALMAP_)
		float3 HemiTexAndLerp : TEXCOORD5;
	#endif
	#if _HASSHADOW_ || _HASSHADOWOCCLUSION_
		float4 ShadowTex: TEXCOORD6;
	#endif
};

struct Vertex
{
	int BoneCount;
	float4x3 BoneMatrix[2];
	float BoneWeight[2];
	float4x3 BlendedBoneMatrix;
	float BinormalFlipping;
};

Vertex GetVertexData(APP2VS Input)
{
	Vertex Output;

	Output.BoneCount = 2;

	// We are on Shader Model 3.0 - no more workarounds.
	int4 IndexVector = D3DCOLORtoUBYTE4(Input.BlendIndices);

	// Compute Bone 1
	Output.BoneMatrix[0] = MatBones[IndexVector[0]];
	Output.BoneWeight[0] = Input.BlendWeights;

	// Compute Bone 2
	Output.BoneMatrix[1] = MatBones[IndexVector[1]];
	Output.BoneWeight[1] = 1.0 - Input.BlendWeights;

	Output.BlendedBoneMatrix = (Output.BoneMatrix[0] * Output.BoneWeight[0]);
	Output.BlendedBoneMatrix += (Output.BoneMatrix[1] * Output.BoneWeight[1]);

	// Compute Binormal flipping
	Output.BinormalFlipping = 1.0 + IndexVector[2] * -2.0;

	return Output;
}

float4 GetSkinnedPos(Vertex Input, float4 Pos)
{
	float3 SkinnedPos = mul(Pos, Input.BlendedBoneMatrix);
	return float4(SkinnedPos, 1.0);
}

float3 GetSkinnedNormal(Vertex Input, float3 Normal)
{
	return normalize(mul(Normal, (float3x3)Input.BlendedBoneMatrix));
}

float3 GetSkinnedWorldNormal(Vertex Input, float3 Normal)
{
	return mul(GetSkinnedNormal(Input, Normal), (float3x3)World);
}

float GetHemiLerp(float3 WorldPos, float3 WorldNormal)
{
	// LocalHeight scale, 1 for top and 0 for bottom
	float LocalHeight = (WorldPos.y - (World[3][1] - 0.5)) * 0.5;
	float Offset = RGraphics_ConvertUNORMtoSNORM_FLT1(LocalHeight) + HeightOverTerrain;
	Offset = clamp(Offset, (1.0 - HeightOverTerrain) * -2.0, 0.8);
	return clamp(((WorldNormal.y + Offset) * 0.5) + 0.5, 0.0, 0.9);
}

VS2PS VS_SkinnedMesh(APP2VS Input)
{
	VS2PS Output = (VS2PS)0.0;

	// Get vertex data
	Vertex Vtx = GetVertexData(Input);

	// Get skinned object-space position
	float4 SkinnedObjectPos = GetSkinnedPos(Vtx, Input.Pos);

	// Output HPos data
	Output.HPos = mul(SkinnedObjectPos, WorldViewProjection);

	// World-space data
	float4 SkinnedWorldPos = mul(SkinnedObjectPos, World);
	float3 SkinnedWorldNormal = GetSkinnedWorldNormal(Vtx, Input.Normal);
	#if _HASNORMALMAP_
		#if _OBJSPACENORMALMAP_
			// [object-space] -> [skinned object space]
			float3x3 ObjectToTexture = (float3x3)Vtx.BlendedBoneMatrix;
		#else
			// [tangent-space] -> [object-space] -> [skinned object space]
			float3x3 ObjectTBN = RVertex_GetTangentBasis(Input.Tan, Input.Normal, Vtx.BinormalFlipping, true);
			float3x3 ObjectToTexture = mul(ObjectTBN, (float3x3)Vtx.BlendedBoneMatrix);
		#endif

		// [skinned object space] -> [transposed skinned world-space]
		float3x3 WorldToTexture = mul(ObjectToTexture, (float3x3)World);
		Output.WorldToTexture0 = WorldToTexture[0];
		Output.WorldToTexture1 = WorldToTexture[1];
		Output.WorldToTexture2 = WorldToTexture[2];
	#else
		Output.WorldNormal = SkinnedWorldNormal;
	#endif
	Output.WorldPos = SkinnedWorldPos;

	// Output Depth
	#if PR_LOG_DEPTH
		Output.WorldPos.w = Output.HPos.w + 1.0;
	#endif

	// Texture-space data
	Output.Tex0AndOccShadowTex.xy = Input.TexCoord0;

	// Packing shadows into other data
	#if _HASSHADOW_ || _HASSHADOWOCCLUSION_
		Output.ShadowTex = Ra_GetMeshShadowProjection(SkinnedWorldPos);
		#if _HASSHADOWOCCLUSION_
			float OccShadowTex = Ra_GetMeshShadowProjection(SkinnedWorldPos, true).z;
			Output.Tex0AndOccShadowTex.z = OccShadowTex;
		#endif
	#endif

	// Process per-vertex hemi data
	#if _USEHEMIMAP_ && (!_USEPERPIXELHEMIMAP_ || !_HASNORMALMAP_)
		Output.HemiTexAndLerp.xy = RPixel_GetHemiTex(SkinnedWorldPos, SkinnedWorldNormal, HemiMapConstants, true);
		Output.HemiTexAndLerp.z = GetHemiLerp(SkinnedWorldPos, SkinnedWorldNormal);
	#endif

	return Output;
}

struct LightColors
{
	float4 Diffuse;
	float4 Specular;
};

LightColors GetLightColors()
{
	LightColors Output = (LightColors)0.0;

	Output.Diffuse = Lights[0].color;
	#if _POINTLIGHT_
		Output.Specular = Lights[0].color;
	#else
		Output.Specular = Lights[0].specularColor;
	#endif

	return Output;
}

RGraphics_PS2FB PS_SkinnedMesh(VS2PS Input)
{
	RGraphics_PS2FB Output = (RGraphics_PS2FB)0.0;

	// Lighting data
	LightColors LC = GetLightColors();
	float3 WorldPos = Input.WorldPos.xyz;
	float3 WorldViewDir = normalize(WorldSpaceCamPos.xyz - WorldPos);

	#if _POINTLIGHT_
		float3 WorldLightPos = Ra_GetWorldLightPos(Lights[0].pos);
		float3 WorldLightDir = normalize(WorldLightPos - WorldPos);
		float Attenuation = RPixel_GetLightAttenuation(WorldLightPos - WorldPos, Lights[0].attenuation);
	#else
		float3 WorldLightDir = normalize(Ra_GetWorldLightDir(-Lights[0].dir));
		float Attenuation = 1.0;
	#endif

	// Texture-space data
	float4 ColorMap = RDirectXTK_SRGBToLinearEst(tex2D(SampleDiffuseMap, Input.Tex0AndOccShadowTex.xy));
	#if _HASNORMALMAP_
		float3x3 WorldToTexture =
		{
			normalize(Input.WorldToTexture0),
			normalize(Input.WorldToTexture1),
			normalize(Input.WorldToTexture2)
		};

		// NormalMap.a stores the glossmap
		float4 NormalMap = tex2D(SampleNormalMap, Input.Tex0AndOccShadowTex.xy);
		NormalMap.xyz = RGraphics_ConvertUNORMtoSNORM_FLT3(NormalMap.xyz);
		float3 WorldNormal = normalize(mul(NormalMap.xyz, WorldToTexture));
	#else
		float4 NormalMap = float4(0.0, 0.0, 1.0, 0.0);
		float3 WorldNormal = normalize(Input.WorldNormal);
	#endif
	float3 HemiNormal = WorldNormal;

	// Calculate shadow factors
	float Shadow = 1.0;
	float ShadowOcc = 1.0;

	#if _HASSHADOW_ || _HASSHADOWOCCLUSION_
		float4 ShadowTex = Input.ShadowTex;

		#if _HASSHADOW_
			Shadow = RDepth_GetShadowFactor(SampleShadowMap, ShadowTex);
		#endif

		#if _HASSHADOWOCCLUSION_
			ShadowTex.z = Input.Tex0AndOccShadowTex.z;
			ShadowOcc = RDepth_GetShadowFactor(SampleShadowOccluderMap, ShadowTex);
		#endif
	#endif

	// Calculate Hemi
	float HemiLight = 1.0;
	float3 AmbientRGB = 0.0;

	#if !_POINTLIGHT_
		#if _USEHEMIMAP_ && (!_USEPERPIXELHEMIMAP_ || !_HASNORMALMAP_)
			float4 HemiMap = RDirectXTK_SRGBToLinearEst(tex2D(SampleHemiMap, Input.HemiTexAndLerp.xy));
			AmbientRGB = lerp(HemiMap.rgb, HemiMapSkyColor.rgb, Input.HemiTexAndLerp.z);
		#elif _USEPERPIXELHEMIMAP_ && !_NOTHING_
			// GoundColor.a has an occlusion factor that we can use for static shadowing
			float2 HemiTex = RPixel_GetHemiTex(WorldPos, HemiNormal, HemiMapConstants, true);
			float4 HemiMap = RDirectXTK_SRGBToLinearEst(tex2D(SampleHemiMap, HemiTex));
			float HemiLerp = GetHemiLerp(WorldPos, WorldNormal);
			AmbientRGB = lerp(HemiMap.rgb, HemiMapSkyColor.rgb, HemiLerp);
			// HemiLight = HemiMap.a;
		#else
			AmbientRGB = HemiMapSkyColor.rgb;
		#endif
	#endif

	// Initialize output color
	float4 OutputColor = 1.0;

	// Calculate lighting
	RDirectXTK_ColorPair Light = RDirectXTK_ComputeLights(WorldNormal.xyz, WorldLightDir, WorldViewDir, SpecularPower);
	float TotalLights = Attenuation * (HemiLight * Shadow * ShadowOcc);
	float3 DiffuseRGB = (Light.Diffuse * LC.Diffuse.rgb) * TotalLights;
	float3 SpecularRGB = ((Light.Specular * NormalMap.a) * LC.Specular.rgb) * TotalLights;
	OutputColor.rgb = RDirectXTK_CompositeLights(ColorMap.rgb, AmbientRGB, DiffuseRGB, SpecularRGB);
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
		Output.Depth = RDepth_ApplyLogarithmicDepth(Input.WorldPos.w);
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
