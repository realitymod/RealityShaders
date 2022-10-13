
/*
	Description: Renders lighting for bundledmesh (objects that are dynamic, nonhuman)
*/

#include "shaders/RealityGraphics.fx"
#include "shaders/RaCommon.fx"
#include "shaders/RaDefines.fx"
#include "shaders/RaShaderBMCommon.fx"

// Dependencies and sanity checks

// Tmp
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

#if _HASENVMAP_
	#define _FRESNELVALUES_ 1
#else
	#define _FRESNELVALUES_ 0
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

/*
	#if defined(_DEBUG_)
		#define _HASUVANIMATION_ 1
		#define _USEHEMIMAP_ 1
		#define _HASSHADOW_ 1
		#define _HASSHADOWOCCLUSION_ 1
		#define _HASNORMALMAP_ 1
		#define _FRESNELVALUES_ 1
		#define _HASGIMAP_ 1
	#endif
*/

struct APP2VS
{
   	float4 Pos : POSITION;
	float3 Normal : NORMAL;
	float4 BlendIndices : BLENDINDICES;
	float2 TexDiffuse : TEXCOORD0;
	float2 TexUVRotCenter : TEXCOORD1;
	float3 Tan : TANGENT;
};

float4x3 GetSkinnedWorldMatrix(APP2VS Input)
{
	int4 IndexVector = D3DCOLORtoUBYTE4(Input.BlendIndices);
	int IndexArray[4] = (int[4])IndexVector;
	return GeomBones[IndexArray[0]];
}

float3x3 GetSkinnedUVMatrix(APP2VS Input)
{
	int4 IndexVector = D3DCOLORtoUBYTE4(Input.BlendIndices);
	int IndexArray[4] = (int[4])IndexVector;
	return (float3x3)UserData.uvMatrix[IndexArray[3]];
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

float4 GetUVRotation(APP2VS Input)
{
	// TODO: (ROD) Gotta rotate the tangent space as well as the uv
	float2 UV = mul(float3(Input.TexUVRotCenter * TexUnpack, 1.0), GetSkinnedUVMatrix(Input)).xy;
	return float4(UV.xy + (Input.TexDiffuse * TexUnpack), 0.0, 1.0);
}

struct VS2PS
{
	float4 HPos : POSITION;

	float4 P_VertexPos_Flip : TEXCOORD0; // .xyz = WorldPos; .w = BiNormalFlipping
	float3 WorldNormal : TEXCOORD1;
	float3 WorldTangent : TEXCOORD2;

	float4 P_Tex0_GroundUV : TEXCOORD3; // .xy = Tex0; .zw = GroundUV;
	float4 ShadowTex : TEXCOORD4;
	float4 OccShadowTex : TEXCOORD5;
};

VS2PS BundledMesh_VS(APP2VS Input)
{
	VS2PS Output = (VS2PS)0;

	float4 UnpackedPos = Input.Pos * PosUnpack;
	float3 UnpackedNormal = Input.Normal * NormalUnpack.x + NormalUnpack.y;
	float3 UnpackedTangent = Input.Tan * NormalUnpack.x + NormalUnpack.y;

	float4x3 SkinnedWorldMatrix = GetSkinnedWorldMatrix(Input);
	float4 WorldPos = float4(mul(UnpackedPos, SkinnedWorldMatrix), 1.0);
	float3 WorldNormal = mul(UnpackedNormal, SkinnedWorldMatrix);
	float3 WorldTangent = mul(UnpackedTangent, SkinnedWorldMatrix);

	Output.HPos = mul(WorldPos, ViewProjection); // Output HPos

	Output.P_VertexPos_Flip = float4(WorldPos.xyz, GetBinormalFlipping(Input));
	Output.WorldNormal = WorldNormal;
	Output.WorldTangent = WorldTangent;

	#if _HASUVANIMATION_
		Output.P_Tex0_GroundUV.xy = GetUVRotation(Input).xy; // pass-through rotate coords
	#else
		Output.P_Tex0_GroundUV.xy = Input.TexDiffuse.xy * TexUnpack; // pass-through texcoord
	#endif

	#if _USEHEMIMAP_
		Output.P_Tex0_GroundUV.zw = GetGroundUV(WorldPos, WorldNormal);
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
		return Lights[0].pos - WorldPos;
	#else
		return -Lights[0].dir;
	#endif
}

float GetHemiLerp(float3 WorldPos, float3 WorldNormal)
{
	// LocalHeight scale, 1 for top and 0 for bottom
	float LocalHeight = (WorldPos.y - GeomBones[0][3][1]) * InvHemiHeightScale;
	float Offset = (LocalHeight * 2.0 - 1.0) + HeightOverTerrain;
	Offset = clamp(Offset, (1.0 - HeightOverTerrain) * -2.0, 0.8);
	return clamp((WorldNormal.y + Offset) * 0.5 + 0.5, 0.0, 0.9);
}

float4 BundledMesh_PS(VS2PS Input) : COLOR
{
	float3 WorldPos = Input.P_VertexPos_Flip.xyz;
	float3 WorldNormal = Input.WorldNormal;
	float3 WorldTangent = Input.WorldTangent;
	float BiNormalFlip = Input.P_VertexPos_Flip.w;
	float3x3 TBN = GetTangentBasis(WorldTangent, WorldNormal, BiNormalFlip);

	float3 LightVec = normalize(GetLightVec(WorldPos));
	float3 EyeVec = normalize(WorldSpaceCamPos - WorldPos);
	float3 HalfVec = normalize(LightVec + EyeVec);

	float4 ColorMap = tex2D(DiffuseMapSampler, Input.P_Tex0_GroundUV.xy);
	float4 DiffuseTex = ColorMap;

	#if _HASNORMALMAP_
		// Transform from tangent-space to world-space
		float4 TangentNormal = tex2D(NormalMapSampler, Input.P_Tex0_GroundUV.xy);
		float3 NormalVec = normalize(TangentNormal.xyz * 2.0 - 1.0);
		NormalVec = normalize(mul(NormalVec, TBN));
	#else
		float3 NormalVec = normalize(WorldNormal);
	#endif

	#if _HASSHADOW_
		float ShadowDir = GetShadowFactor(ShadowMapSampler, Input.ShadowTex);
	#else
		float ShadowDir = 1.0f;
	#endif

	#if _HASSHADOWOCCLUSION_
		float ShadowOccDir = GetShadowFactor(ShadowOccluderMapSampler, Input.OccShadowTex);
	#else
		float ShadowOccDir = 1.0f;
	#endif

	#if _USEHEMIMAP_
		// GoundColor.a has an occlusion factor that we can use for static shadowing
		float4 GroundColor = tex2D(HemiMapSampler, Input.P_Tex0_GroundUV.zw);
		float HemiLerp = GetHemiLerp(WorldPos, NormalVec);
		float3 Ambient = lerp(GroundColor, HemiMapSkyColor, HemiLerp);
	#else
		float3 Ambient = Lights[0].color.w;
	#endif

	#if _HASCOLORMAPGLOSS_
		float Gloss = ColorMap.a;
	#elif !_HASSTATICGLOSS_ && _HASNORMALMAP_
		float Gloss = TangentNormal.a;
	#else
		float Gloss = StaticGloss;
	#endif

	#if _FRESNELVALUES_
		#if _HASENVMAP_
			float3 Reflection = -reflect(EyeVec, NormalVec);
			float3 EnvMapColor = texCUBE(CubeMapSampler, Reflection);
			DiffuseTex.rgb = lerp(DiffuseTex, EnvMapColor, Gloss / 4.0);
		#endif
		float RefractionIndexRatio = 0.15;
		float F0 = pow(1.0 - RefractionIndexRatio, 2.0) / pow(1.0 + RefractionIndexRatio, 4.0);
		float FresnelValue = pow(F0 + (1.0 - F0) * (1.0 - dot(NormalVec, EyeVec)), 2.0);
		DiffuseTex.a = lerp(DiffuseTex.a, 1.0, FresnelValue);
	#endif

	float3 Diffuse = GetDiffuseValue(NormalVec, LightVec);
	float3 Specular = GetSpecularValue(NormalVec, HalfVec) * (Gloss * 4.0);

	#if _POINTLIGHT_
		#if !_HASCOLORMAPGLOSS_
			// there is no Gloss map so alpha means transparency
			Diffuse *= ColorMap.a;
		#endif
		float Attenuation = GetRadialAttenuation(Lights[0].pos - WorldPos, Lights[0].attenuation);
	#else
		const float Attenuation = 1.0;
	#endif

	#if _HASGIMAP_
		float4 GI = tex2D(GIMapSampler, Input.P_Tex0_GroundUV.xy);
		float4 GI_TIS = GI; // M
		GI = (GI_TIS.a < 0.01) ? 1.0 : GI;
	#else
		const float4 GI = 1.0;
	#endif

	float4 OutputColor = 1.0;

	// Calculate diffuse + specular lighting
	// Only add specular to bundledmesh with a glossmap (.a channel in NormalMap or ColorMap)
	// Prevents non-detailed bundledmesh from looking shiny
	float3 LightFactors = Attenuation * (ShadowDir * ShadowOccDir);
	#if _HASCOLORMAPGLOSS_ || _HASNORMALMAP_
		float3 Lighting = ((Diffuse + Specular) * Lights[0].color) * LightFactors;
		OutputColor.rgb = DiffuseTex.rgb * ((Ambient + Lighting) * GI.rgb);
	#else
		float3 Lighting = (Diffuse * Lights[0].color) * LightFactors;
		OutputColor.rgb = DiffuseTex.rgb * ((Ambient + Lighting) * GI.rgb);
	#endif

	#if _POINTLIGHT_
		OutputColor.rgb *= GetFogValue(WorldPos, WorldSpaceCamPos);
	#endif

	#if _HASDOT3ALPHATEST_
		OutputColor.a = dot(ColorMap.rgb, 1.0);
	#else
		#if _HASCOLORMAPGLOSS_
			OutputColor.a = 1.0f;
		#else
			OutputColor.a = DiffuseTex.a;
		#endif
	#endif

	#if _HASGIMAP_
		if (FogColor.r < 0.01)
		{
			if (GI_TIS.a < 0.01)
			{
				if (GI_TIS.g < 0.01)
				{
					OutputColor.rgb = float3(lerp(0.43, 0.17, ColorMap.b), 1.0, 0.0);
				}
				else
				{
					OutputColor.rgb = float3(GI_TIS.g, 1.0, 0.0);
				}
			}
			else
			{
				// Normal Wrecks also cold
				OutputColor.rgb = float3(lerp(0.43, 0.17, ColorMap.b), 1.0, 0.0);
			}
		}
	#else
		if (FogColor.r < 0.01)
		{
			OutputColor.rgb = float3(lerp(0.64, 0.3, ColorMap.b), 1.0, 0.0); // M // 0.61, 0.25
		}
	#endif

	#if !_POINTLIGHT_
		OutputColor.rgb = ApplyFog(OutputColor.rgb, GetFogValue(WorldPos, WorldSpaceCamPos));
	#endif

	OutputColor.a *= Transparency.a;

	return OutputColor;
}

technique Variable
{
	pass p0
	{
		#if defined(ENABLE_WIREFRAME)
			FillMode = WireFrame;
		#endif

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

		VertexShader = compile vs_3_0 BundledMesh_VS();
		PixelShader = compile ps_3_0 BundledMesh_PS();
	}
}