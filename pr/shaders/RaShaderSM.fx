#include "shaders/RealityGraphics.fxh"
#include "shaders/RaCommon.fxh"
#include "shaders/RaShaderSMCommon.fxh"

/*
	Description:
	- Renders lighting for skinnedmesh (objects that are dynamic, human-like with bones)
	- Skinning function currently for 2 bones
	- Calculates world-space lighting
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

	float3 WorldTangent : TEXCOORD1;
	float3 WorldBinormal : TEXCOORD2;
	float3 WorldNormal : TEXCOORD3;

	float2 Tex0 : TEXCOORD4;
	float4 ShadowTex : TEXCOORD5;
	float4 OccShadowTex : TEXCOORD6;
};

struct PS2FB
{
	float4 Color : COLOR;
	#if defined(LOG_DEPTH)
		float Depth : DEPTH;
	#endif
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

VS2PS SkinnedMesh_VS(APP2VS Input)
{
	VS2PS Output = (VS2PS)0;

	// Get skinned object-space data
	float4 ObjectPosition = Input.Pos;
	float4x3 SkinnedObjMat = GetSkinnedObjectMatrix(Input);
	float4 SkinnedObjPos = float4(mul(ObjectPosition, SkinnedObjMat), 1.0);

	// Output HPos data
	Output.HPos = mul(SkinnedObjPos, WorldViewProjection);

	// Get world-space data
	float4 WorldPos = mul(SkinnedObjPos, World);
	float3x3 WorldMat = mul(GetBoneMatrix(Input, 0), (float3x3)World);
	#if _OBJSPACENORMALMAP_ // [object-space] -> [skinned object-space] -> [skinned world-space]
		Output.WorldTangent = WorldMat[0];
		Output.WorldBinormal = WorldMat[1];
		Output.WorldNormal = WorldMat[2];
	#else // [tangent-space] -> [object-space] -> [skinned object-space] -> [skinned world-space]
		float3x3 ObjectTBN = GetTangentBasis(Input.Tan, Input.Normal, GetBinormalFlipping(Input));
		float3x3 WorldTBN = mul(ObjectTBN, WorldMat);
		Output.WorldTangent = WorldTBN[0];
		Output.WorldBinormal = WorldTBN[1];
		Output.WorldNormal = WorldTBN[2];
	#endif
	Output.Pos.xyz = WorldPos;
	#if defined(LOG_DEPTH)
		Output.Pos.w = Output.HPos.w + 1.0; // Output depth
	#endif

	Output.Tex0 = Input.TexCoord0;

	#if _HASSHADOW_
		Output.ShadowTex = GetShadowProjection(WorldPos);
	#endif

	#if _HASSHADOWOCCLUSION_
		Output.OccShadowTex = GetShadowProjection(WorldPos, true);
	#endif

	return Output;
}

// NOTE: This returns un-normalized for point, because point needs to be attenuated.
float3 GetWorldLightVec(float3 WorldPos)
{
	#if _POINTLIGHT_
		return GetWorldLightPos(Lights[0].pos.xyz) - WorldPos;
	#else
		return GetWorldLightDir(-Lights[0].dir.xyz);
	#endif
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
	float Offset = ((LocalHeight * 2.0) - 1.0) + HeightOverTerrain;
	Offset = clamp(Offset, (1.0 - HeightOverTerrain) * -2.0, 0.8);
	return saturate(((WorldNormal.y + Offset) * 0.5) + 0.5);
}

PS2FB SkinnedMesh_PS(VS2PS Input)
{
	PS2FB Output = (PS2FB)0;

	// Get world-space properties
	float3 WorldPos = Input.Pos.xyz;
	float3 WorldLightVec = GetWorldLightVec(WorldPos);
	float3 WorldNLightVec = normalize(WorldLightVec);
	float3 WorldViewVec = normalize(WorldSpaceCamPos.xyz - WorldPos.xyz);
	float3x3 WorldTBN =
	{
		normalize(Input.WorldTangent),
		normalize(Input.WorldBinormal),
		normalize(Input.WorldNormal)
	};

	// (.a) stores the glossmap
	#if _HASNORMALMAP_
		float4 WorldNormal = tex2D(SampleNormalMap, Input.Tex0);
		WorldNormal.xyz = normalize((WorldNormal.xyz * 2.0) - 1.0);
		WorldNormal.xyz = normalize(mul(WorldNormal.xyz, WorldTBN));
	#else
		float4 WorldNormal = float4(WorldTBN[2], 0.0);
	#endif

	float4 ColorMap = tex2D(SampleDiffuseMap, Input.Tex0);

	#if _HASSHADOW_
		float ShadowDir = GetShadowFactor(SampleShadowMap, Input.ShadowTex);
	#else
		float ShadowDir = 1.0;
	#endif

	#if _HASSHADOWOCCLUSION_
		float OccShadowDir = GetShadowFactor(SampleShadowOccluderMap, Input.OccShadowTex);
	#else
		float OccShadowDir = 1.0;
	#endif

	#if _POINTLIGHT_
		float3 Ambient = 0.0;
	#else
		#if _USEHEMIMAP_
			// GoundColor.a has an occlusion factor that we can use for static shadowing
			float2 GroundUV = GetGroundUV(WorldPos, WorldNormal);
			float4 GroundColor = tex2D(SampleHemiMap, GroundUV);
			float HemiLerp = GetHemiLerp(WorldPos, WorldNormal);
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

	float Gloss = WorldNormal.a;
	ColorPair Light = ComputeLights(WorldNormal, WorldNLightVec, WorldViewVec, SpecularPower);
	Light.Diffuse = (Light.Diffuse * Lights[0].color);
	Light.Specular = ((Light.Specular * Gloss) * Lights[0].color);

	float3 LightFactors = Attenuation * (ShadowDir * OccShadowDir);
	Light.Diffuse *= LightFactors;
	Light.Specular *= LightFactors;

	// Only add specular to bundledmesh with a glossmap (.a channel in NormalMap or ColorMap)
	// Prevents non-detailed bundledmesh from looking shiny
	#if !_HASNORMALMAP_
		Light.Specular = 0.0;
	#endif

	float4 OutputColor = 1.0;
	OutputColor.rgb = (ColorMap.rgb * (Ambient + Light.Diffuse)) + Light.Specular;
	OutputColor.a = ColorMap.a * Transparency.a;

	// Thermals
	if (IsTisActive())
	{
		#if _HASENVMAP_ // If EnvMap enabled, then should be hot on thermals
			OutputColor.rgb = float3(lerp(0.60, 0.30, ColorMap.b), 1.0, 0.0); // M // 0.61, 0.25
		#else // Else cold
			OutputColor.rgb = float3(lerp(0.43, 0.17, ColorMap.b), 1.0, 0.0);
		#endif
	}

	Output.Color = OutputColor;

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);
	#endif

	#if !_POINTLIGHT_
		ApplyFog(Output.Color.rgb, GetFogValue(WorldPos, WorldSpaceCamPos));
	#endif

	return Output;
}

technique VariableTechnique
{
	pass Pass0
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
