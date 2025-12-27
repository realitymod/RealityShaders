#line 2 "RaShaderBM.fx"

/*
	Include header files
*/

#include "shaders/RealityGraphics.fxh"
#include "shaders/shared/RealityDepth.fxh"
#include "shaders/shared/RealityDirectXTK.fxh"
#include "shaders/shared/RealityVertex.fxh"
#include "shaders/shared/RealityPixel.fxh"
#include "shaders/RaCommon.fxh"
#include "shaders/RaDefines.fx"
#include "shaders/RaShaderBM.fxh"
#if !defined(_HEADERS_)
	#include "RealityGraphics.fxh"
	#include "shared/RealityDepth.fxh"
	#include "shared/RealityDirectXTK.fxh"
	#include "shared/RealityVertex.fxh"
	#include "shared/RealityPixel.fxh"
	#include "RaCommon.fxh"
	#include "RaDefines.fx"
	#include "RaShaderBM.fxh"
#endif

/*
	Description: Renders lighting for bundled mesh (dynamic, non-human objects) and calculates world-space lighting.
*/

// Dependencies and sanity checks

// Temp
#if !defined(_HASUVANIMATION_)
	#define _HASUVANIMATION_ 0
#endif
#if !defined(_HASNORMALMAP_)
	#define _HASNORMALMAP_ 0
#endif
#if !defined(_HASGIMAP_)
	#define _HASGIMAP_ 0
#endif
#if !defined(_HASENVMAP_)
	#define _HASENVMAP_ 0
#endif
#if !defined(_USEHEMIMAP_)
	#define _USEHEMIMAP_ 0
#endif
#if !defined(_HASSHADOW_)
	#define _HASSHADOW_ 0
#endif
#if !defined(_HASCOLORMAPGLOSS_)
	#define _HASCOLORMAPGLOSS_ 0
#endif
#if !defined(_HASDOT3ALPHATEST_)
	#define _HASDOT3ALPHATEST_ 0
#endif

// resolve illegal combo GI + ENVMAP
#if _HASGIMAP_ && _HASENVMAP_
	#define _HASENVMAP_ 0
#endif

#if _POINTLIGHT_
	// Disable these code portions for point lights
	#define _HASGIMAP_ 0
	#define _HASENVMAP_ 0
	#define _USEHEMIMAP_ 0
	#define _HASSHADOW_ 0
#endif

#undef _DEBUG_
// #define _DEBUG_
#if defined(_DEBUG_)
	#define _HASUVANIMATION_ 1
	#define _USEHEMIMAP_ 1
	#define _HASSHADOW_ 1
	#define _HASSHADOWOCCLUSION_ 1
	#define _HASNORMALMAP_ 1
	#define _HASGIMAP_ 1
#endif

struct APP2VS
{
	float4 Pos : POSITION;
	float3 Normal : NORMAL;
	float4 BlendIndices : BLENDINDICES;
	float2 TexDiffuse : TEXCOORD0;
	float2 TexUVRotCenter : TEXCOORD1;
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
	#if _HASCOCKPIT_
		float3 SkinLightDir : TEXCOORD7;
	#endif
};

struct Vertex
{
	float4x3 SkinnedWorldMatrix;
	float3x3 SkinnedUVMatrix;
	float BinormalFlipping;
};

Vertex GetVertexData(APP2VS Input)
{
	Vertex Output;

	int4 IndexVector = D3DCOLORtoUBYTE4(Input.BlendIndices);
	Output.SkinnedWorldMatrix = GeomBones[IndexVector[0]];
	Output.SkinnedUVMatrix = (float3x3)UserData.uvMatrix[IndexVector[3]];
	Output.BinormalFlipping = 1.0 + IndexVector[2] * -2.0;

	return Output;
}

float4 GetUVRotation(APP2VS Input, float3x3 SkinnedUVMatrix)
{
	// TODO: (ROD) Gotta rotate the tangent space as well as the uv
	float2 UV = mul(float3(Input.TexUVRotCenter * TexUnpack, 1.0), SkinnedUVMatrix).xy;
	return float4(UV.xy + (Input.TexDiffuse * TexUnpack), 0.0, 1.0);
}

float GetHemiLerp(float3 WorldPos, float3 WorldNormal)
{
	// LocalHeight scale, 1 for top and 0 for bottom
	float LocalHeight = (WorldPos.y - GeomBones[0][3][1]) * InvHemiHeightScale;
	float Offset = (RGraphics_ConvertUNORMtoSNORM_FLT1(LocalHeight)) + HeightOverTerrain;
	Offset = clamp(Offset, (1.0 - HeightOverTerrain) * -2.0, 0.8);
	return clamp(((WorldNormal.y + Offset) * 0.5) + 0.5, 0.0, 0.9);
}

VS2PS VS_BundledMesh(APP2VS Input)
{
	VS2PS Output = (VS2PS)0.0;

	// Get Bone information
	Vertex Vtx = GetVertexData(Input);

	// Unpack object-space position
	float4 ObjectPos = Input.Pos * PosUnpack;
	// Unpack object-space tangent and normal
	float3 ObjectTangent = Input.Tan * NormalUnpack.x + NormalUnpack.y;
	float3 ObjectNormal = Input.Normal * NormalUnpack.x + NormalUnpack.y;
	// Create object-space TBN
	float3x3 ObjectTBN = RVertex_GetTangentBasis(ObjectTangent, ObjectNormal, Vtx.BinormalFlipping);

	// Get world-space data
	float4 WorldPos = float4(mul(ObjectPos, Vtx.SkinnedWorldMatrix), 1.0);
	float3x3 WorldTBN = mul(ObjectTBN, (float3x3)Vtx.SkinnedWorldMatrix);

	// Output HPos
	Output.HPos = mul(WorldPos, ViewProjection);
	// Output world-space data
	Output.Pos.xyz = WorldPos.xyz;

	// Output Depth
	#if PR_LOG_DEPTH
		Output.Pos.w = Output.HPos.w + 1.0;
	#endif

	#if _HASNORMALMAP_
		Output.WorldTangent = WorldTBN[0];
		Output.WorldBinormal = WorldTBN[1];
		Output.WorldNormal = WorldTBN[2];
	#else
		Output.WorldNormal = WorldTBN[2];
	#endif

	// Texture-space data
	#if _HASUVANIMATION_
		// Pass-through rotate coords
		Output.Tex0 = GetUVRotation(Input, Vtx.SkinnedUVMatrix);
	#else
		// Pass-through texcoord
		Output.Tex0 = Input.TexDiffuse * TexUnpack;
	#endif
	#if _HASSHADOW_
		Output.ShadowTex = Ra_GetMeshShadowProjection(WorldPos);
	#endif
	#if _HASSHADOWOCCLUSION_
		Output.ShadowOccTex = Ra_GetMeshShadowProjection(WorldPos, true);
	#endif

	// Special data
	#if _HASCOCKPIT_
		Output.SkinLightDir = mul(-Lights[0].dir.xyz, Vtx.SkinnedWorldMatrix);
	#endif

	return Output;
}

// NOTE: This returns un-normalized for point, because point needs to be attenuated.
float3 GetWorldLightVec(VS2PS Input, float3 WorldPos)
{
	#if _POINTLIGHT_
		return Lights[0].pos - WorldPos;
	#else
		#if _HASCOCKPIT_
			// Use skinned lighting vector to part to create static cockpit lighting
			float3 LightVec = Input.SkinLightDir;
		#else
			float3 LightVec = -Lights[0].dir;
		#endif
		return LightVec;
	#endif
}

RGraphics_PS2FB PS_BundledMesh(VS2PS Input)
{
	RGraphics_PS2FB Output = (RGraphics_PS2FB)0.0;

	/*
		World-space data
	*/

	float3 WorldPos = Input.Pos;
	float3 WorldLightVec = GetWorldLightVec(Input, WorldPos);
	float3 WorldLightDir = normalize(WorldLightVec);
	float3 WorldViewDir = normalize(WorldSpaceCamPos.xyz - WorldPos);
	#if _HASNORMALMAP_
		// Transform from tangent-space to world-space
		float3x3 WorldTBN =
		{
			normalize(Input.WorldTangent),
			normalize(Input.WorldBinormal),
			normalize(Input.WorldNormal)
		};
		float4 NormalMap = tex2D(SampleNormalMap, Input.Tex0);
		float3 WorldNormal = normalize(RGraphics_ConvertUNORMtoSNORM_FLT3(NormalMap.xyz));
		WorldNormal = normalize(mul(WorldNormal, WorldTBN));
	#else
		float3 WorldNormal = normalize(Input.WorldNormal);
	#endif

	/*
		Texture data
	*/

	// Get color texture data
	// We copy ColorMap to ColorTex to preserve original alpha data
	float4 ColorMap = RDirectXTK_SRGBToLinearEst(tex2D(SampleDiffuseMap, Input.Tex0));
	float4 ColorTex = ColorMap;

	// Get shadow texture data
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

	/*
		Calculate diffuse + specular lighting
	*/

	// Prevents non-detailed bundledmesh from looking shiny
	#if _HASCOLORMAPGLOSS_
		float Gloss = ColorTex.a;
	#elif !_HASSTATICGLOSS_ && _HASNORMALMAP_
		float Gloss = NormalMap.a;
	#else
		float Gloss = 0.0;
	#endif

	#if _HASENVMAP_
		float3 Reflection = -reflect(WorldViewDir, WorldNormal);
		float3 EnvMapColor = RDirectXTK_SRGBToLinearEst(texCUBE(SampleCubeMap, Reflection)).rgb;
		ColorMap.rgb = lerp(ColorMap.rgb, EnvMapColor, Gloss / 4.0);
	#endif

	float HemiLight = 1.0;
	#if _POINTLIGHT_
		float3 Ambient = 0.0;
	#else
		#if _USEHEMIMAP_
			// GoundColor.a has an occlusion factor that we can use for static shadowing
			float2 HemiTex = RPixel_GetHemiTex(WorldPos, 0.0, HemiMapConstants.rgb, true);
			float4 HemiMap = RDirectXTK_SRGBToLinearEst(tex2D(SampleHemiMap, HemiTex));
			float HemiLerp = GetHemiLerp(WorldPos, WorldNormal);
			float3 Ambient = lerp(HemiMap.rgb, HemiMapSkyColor.rgb, HemiLerp);
			// HemiLight = lerp(HemiMap.a, 1.0, saturate(HeightOverTerrain - 1.0));
		#else
			float3 Ambient = Lights[0].color.a;
		#endif
	#endif

	#if _HASGIMAP_
		float4 GI = RDirectXTK_SRGBToLinearEst(tex2D(SampleGIMap, Input.Tex0));
		float4 GI_TIS = GI; // M
		GI = (GI_TIS.a < 0.01) ? 1.0 : GI;
	#else
		float4 GI = 1.0;
	#endif

	#if _POINTLIGHT_
		float Attenuation = RPixel_GetLightAttenuation(WorldLightVec, Lights[0].attenuation);
	#else
		float Attenuation = 1.0;
	#endif

	RDirectXTK_ColorPair Light = RDirectXTK_ComputeLights(WorldNormal, WorldLightDir, WorldViewDir, SpecularPower);
	float TotalLights = Attenuation * (HemiLight * Shadow * ShadowOcc);
	float3 DiffuseRGB = (Light.Diffuse * Lights[0].color.rgb) * TotalLights;
	float3 SpecularRGB = ((Light.Specular * Gloss) * Lights[0].specularColor.rgb) * TotalLights;

	#if _HASSTATICGLOSS_
		SpecularRGB = clamp(SpecularRGB, 0.0, StaticGloss.rgb);
	#endif

	// There is no Gloss map, so alpha means transparency
	#if _POINTLIGHT_ && !_HASCOLORMAPGLOSS_
		DiffuseRGB *= ColorTex.a;
	#endif

	float4 OutputColor = 1.0;
	OutputColor.rgb = RDirectXTK_CompositeLights(ColorMap.rgb, Ambient, DiffuseRGB, SpecularRGB) * GI.rgb;

	/*
		Calculate fogging and other occluders
	*/

	#if _POINTLIGHT_
		OutputColor.rgb *= Ra_GetFogValue(WorldPos, WorldSpaceCamPos.xyz) * Attenuation;
	#endif

	// Thermals
	if (Ra_IsTisActive())
	{
		#if _HASGIMAP_
			float Cold = lerp(0.43, 0.17, ColorTex.b);
			float Hot = 0.7;
			float Temp = lerp(Cold, Hot, GI_TIS.g);
			Temp = (GI_TIS.a < 0.01) ? Temp : Cold;
			OutputColor.rgb = float3(Temp, 1.0, 0.0);
		#else
			OutputColor.rgb = float3(lerp(0.64, 0.3, ColorTex.b), 1.0, 0.0); // M // 0.61, 0.25
		#endif
	}

	/*
		Calculate alpha transparency
	*/

	#if _HASENVMAP_
		float FresnelFactor = RDirectXTK_ComputeFresnelFactor(WorldNormal, WorldViewDir, 1.0);
		ColorMap.a = lerp(ColorMap.a, 1.0, FresnelFactor);
	#endif

	// Unaltered alpha should be 1.0 for debug reasons
	Output.Color.a = 1.0;

	#if _HASDOT3ALPHATEST_
		Output.Color.a = dot(ColorTex.rgb, 1.0);
	#else
		#if _HASCOLORMAPGLOSS_
			Output.Color.a = 1.0;
		#else
			Output.Color.a = ColorMap.a;
		#endif
	#endif

	#if _POINTLIGHT_
		Output.Color.a *= Attenuation;
	#endif

	Output.Color.rgb = OutputColor.rgb;
	Output.Color.a *= Transparency.a;
	#if !_POINTLIGHT_
		Ra_ApplyFog(Output.Color.rgb, Ra_GetFogValue(WorldPos, WorldSpaceCamPos.xyz));
	#endif
	RDirectXTK_TonemapAndLinearToSRGBEst(Output.Color);

	#if PR_LOG_DEPTH
		Output.Depth = RDepth_ApplyLogarithmicDepth(Input.Pos.w);
	#endif

	return Output;
}

technique Variable
{
	pass p0
	{
		#if defined(ENABLE_WIREFRAME)
			FillMode = WireFrame;
		#endif

		ZEnable = TRUE;
		ZFunc = PR_ZFUNC_WITHEQUAL;

		AlphaTestEnable = (AlphaTest);
		AlphaRef = (AlphaTestRef);

		#if _POINTLIGHT_
			AlphaBlendEnable = TRUE;
			SrcBlend = SRCALPHA;
			DestBlend = ONE;
		#else
			AlphaBlendEnable = (AlphaBlendEnable);
			SrcBlend = SRCALPHA;
			DestBlend = INVSRCALPHA;
			ZWriteEnable = (DepthWrite);
		#endif

		VertexShader = compile vs_3_0 VS_BundledMesh();
		PixelShader = compile ps_3_0 PS_BundledMesh();
	}
}
