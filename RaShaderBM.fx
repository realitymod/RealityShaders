
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
	// We'd still like fresnel, though
	#define _FRESNELVALUES_ 1
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

float4 GetWorldPos(APP2VS Input)
{
	float4 UnpackedPos = Input.Pos * PosUnpack;
	return float4(mul(UnpackedPos, GetSkinnedWorldMatrix(Input)), 1.0);
}

float3 GetWorldNormal(APP2VS Input)
{
	// Unpack normal
	float3 Normal = normalize(Input.Normal * NormalUnpack.x + NormalUnpack.y);
	return mul(Normal, GetSkinnedWorldMatrix(Input)); // tl: We don't scale/shear objects
}

float2 GetGroundUV(APP2VS Input)
{
	// HemiMapConstants: Offset x/y heightmapsize z / hemilerpbias w
	float4 GroundUV = 0.0;
	GroundUV.xy = ((GetWorldPos(Input) + (HemiMapConstants.z / 2.0) + GetWorldNormal(Input)).xz - HemiMapConstants.xy) / HemiMapConstants.z;
	GroundUV.y = 1.0 - GroundUV.y;
	return GroundUV;
}

float GetGroundLerp(float3 WorldPos, float3 WorldNormal)
{
	// LocalHeight scale, 1 for top and 0 for bottom
	float LocalHeight = (WorldPos.y - GeomBones[0][3][1]) * InvHemiHeightScale;
	float Offset = (LocalHeight * 2.0 - 1.0) + HeightOverTerrain;
	Offset = clamp(Offset, -2.0 * (1.0 - HeightOverTerrain), 0.8); // For TL: seems like taking this like away doesn't change much, take it out?
	return clamp((WorldNormal.y + Offset) * 0.5 + 0.5, 0.0, 0.9);
}

float4 CalcUVRotation(APP2VS Input)
{
	// TODO: (ROD) Gotta rotate the tangent space as well as the uv
	float2 UV = mul(float3(Input.TexUVRotCenter * TexUnpack, 1.0), GetSkinnedUVMatrix(Input)).xy + Input.TexDiffuse * TexUnpack;
	return float4(UV.xy, 0.0, 1.0);
}

// NOTE: This returns un-normalized for point, because point needs to be attenuated.
float3 GetLightVec(APP2VS Input)
{
	#if _POINTLIGHT_
		return (Lights[0].pos - GetWorldPos(Input).xyz);
	#else
		float3 LightVec = -Lights[0].dir;
		#if _HASCOCKPIT_
			//tl: Skin lighting vector to part to create static cockpit lighting
			LightVec = mul(LightVec, GetSkinnedWorldMatrix(Input));
		#endif
		return LightVec;
	#endif
}

struct VS2PS
{
	float4 HPos : POSITION;

	float4 Normals : TEXCOORD0;
	float4 P_Tex0_GroundUV : TEXCOORD1; // .xy = Tex0; .zw = GroundUV;
	float4 P_LightVec_HemiLerp : TEXCOORD2;
	float3 EyeVec : TEXCOORD3;
	float3 VertexPos : TEXCOORD4;

	float4 ShadowTex : TEXCOORD5;
	float4 OccShadowTex : TEXCOORD6;
};

VS2PS Bump_VS(APP2VS Input)
{
	VS2PS Output = (VS2PS)0;

	float4 WorldPos = GetWorldPos(Input);
	float3 WorldNormal = normalize(GetWorldNormal(Input));
	float3 WorldEyeVec = WorldSpaceCamPos.xyz - WorldPos.xyz;

	Output.HPos = mul(WorldPos, ViewProjection); // Output HPOS

	#if _HASNORMALMAP_ // Do tangent space bumped pixel lighting
		float3 UnpackedTangent = Input.Tan * NormalUnpack.x + NormalUnpack.y;
        float3 UnpackedNormal = Input.Normal * NormalUnpack.x + NormalUnpack.y;
        float3x3 TanBasis = GetTangentBasis(UnpackedTangent, UnpackedNormal, GetBinormalFlipping(Input));
        float3x3 World2TanMat = transpose(mul(TanBasis, GetSkinnedWorldMatrix(Input)));

		float3 TanEyeVec = mul(normalize(WorldEyeVec), World2TanMat);
		float3 TanLightVec = mul(GetLightVec(Input), World2TanMat);
		Output.P_LightVec_HemiLerp.xyz = normalize(TanLightVec);
		Output.EyeVec = normalize(TanEyeVec);
	#else // Do world space non-bumped pixel lighting
		Output.P_LightVec_HemiLerp.xyz = GetLightVec(Input);
		Output.EyeVec = WorldEyeVec;
		Output.Normals.xyz = WorldNormal.xyz;
	#endif

	#if _HASUVANIMATION_
		Output.P_Tex0_GroundUV.xy = CalcUVRotation(Input).xy; // pass-through rotate coords
	#else
		Output.P_Tex0_GroundUV.xy = Input.TexDiffuse.xy * TexUnpack; // pass-through texcoord
	#endif

	#if _USEHEMIMAP_
		Output.P_Tex0_GroundUV.zw = GetGroundUV(Input);
		Output.P_LightVec_HemiLerp.w = GetGroundLerp(WorldPos, WorldNormal);
	#endif

	#if _HASSHADOW_
		Output.ShadowTex = GetShadowProjection(WorldPos);
	#endif

	#if _HASSHADOWOCCLUSION_
		Output.OccShadowTex = GetShadowProjection(WorldPos, true);
	#endif

	Output.VertexPos = WorldPos.xyz;

	return Output;
}

float4 Bump_PS(VS2PS Input) : COLOR
{
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
		float3 HemiColor = lerp(GroundColor, HemiMapSkyColor, Input.P_LightVec_HemiLerp.w);
	#else
		//tl: by setting this to 0, hlsl will remove it from the compiled code (in an addition).
		//    for non-hemi'ed materials, a static ambient will be added to sun color in vertex shader
		float HemiColor = Lights[0].color.w;
	#endif

	float3 NormalVec = 0.0;

	#if _HASNORMALMAP_
		float4 TangentNormal = tex2D(NormalMapSampler, Input.P_Tex0_GroundUV.xy);
		TangentNormal.xyz = normalize(TangentNormal.xyz * 2.0 - 1.0);
		NormalVec = TangentNormal.xyz;
	#else
		NormalVec = normalize(Input.Normals.xyz);
	#endif

	float3 LightVec = normalize(Input.P_LightVec_HemiLerp.xyz);
	float3 EyeVec = normalize(Input.EyeVec);
	float3 HalfVec = normalize(LightVec + EyeVec);

	float4 DiffuseMap = tex2D(DiffuseMapSampler, Input.P_Tex0_GroundUV.xy);

	#if _HASCOLORMAPGLOSS_
		float Gloss = DiffuseMap.a;
	#elif !_HASSTATICGLOSS_ && _HASNORMALMAP_
		float Gloss = TangentNormal.a;
	#else
		float Gloss = StaticGloss;
	#endif

	float3 Diffuse = GetDiffuseValue(NormalVec, LightVec) * Lights[0].color;
	float3 Specular = GetSpecularValue(NormalVec, HalfVec) * Lights[0].color * Gloss;

	Diffuse *= ShadowDir * ShadowOccDir;
	Specular *= ShadowDir * ShadowOccDir;

	float4 OutputColor = 1.0;

	#if _POINTLIGHT_
		#if !_HASCOLORMAPGLOSS_
			// there is no Gloss map so alpha means transparency
			OutputColor.rgb = Diffuse * DiffuseMap.a;
		#else
			OutputColor.rgb = Diffuse;
		#endif
	#else
		OutputColor.rgb = Diffuse + HemiColor;
	#endif

	float4 DiffuseColor = DiffuseMap;

	#if _FRESNELVALUES_
		#if _HASENVMAP_
			float3 Reflection = -reflect(EyeVec.xyz, NormalVec.xyz);
			float3 EnvMapColor = texCUBE(CubeMapSampler, Reflection);
			DiffuseColor.rgb = lerp(DiffuseColor, EnvMapColor, Gloss / 4.0);
		#endif

		float FresnelValue = GetSchlickApproximation(NormalVec.xyz, EyeVec.xyz, 0.15);
		DiffuseColor.a = lerp(DiffuseColor.a, 1.0, FresnelValue);
	#endif

	#if _HASGIMAP_
		float4 GI = tex2D(GIMapSampler, Input.P_Tex0_GroundUV.xy);
		float4 GI_TIS = GI; // M
		GI = (GI_TIS.a < 0.01) ? 1.0 : GI;
	#else
		const float4 GI = 1.0;
	#endif

	// Only add specular to bundledmesh with a glossmap (.a channel in NormalMap or DiffuseMap)
	// Prevents non-detailed bundledmesh from looking shiny
	OutputColor.rgb *= DiffuseColor.rgb * GI.rgb;
	#if _HASCOLORMAPGLOSS_ || _HASNORMALMAP_
		OutputColor.rgb += Specular * GI.rgb;
	#endif

	#if _HASDOT3ALPHATEST_
		OutputColor.a = dot(DiffuseMap.rgb, 1.0);
	#else
		#if _HASCOLORMAPGLOSS_
			OutputColor.a = 1.0f;
		#else
			OutputColor.a = DiffuseColor.a;
		#endif
	#endif

	#if _POINTLIGHT_
		OutputColor *= GetRadialAttenuation(Input.P_LightVec_HemiLerp.xyz, Lights[0].attenuation);
		OutputColor.a *= GetFogValue(Input.VertexPos.xyz, WorldSpaceCamPos.xyz);
	#endif

	OutputColor.a *= Transparency.a;

	#if _HASGIMAP_
		if (FogColor.r < 0.01)
		{
			if (GI_TIS.a < 0.01)
			{
				if (GI_TIS.g < 0.01)
				{
					OutputColor.rgb = float3(lerp(0.43, 0.17, DiffuseMap.b), 1.0, 0.0);
				}
				else
				{
					OutputColor.rgb = float3(GI_TIS.g, 1.0, 0.0);
				}
			}
			else
			{
				// Normal Wrecks also cold
				OutputColor.rgb = float3(lerp(0.43, 0.17, DiffuseMap.b), 1.0, 0.0);
			}
		}
	#else
		if (FogColor.r < 0.01)
		{
			OutputColor.rgb = float3(lerp(0.64, 0.3, DiffuseMap.b), 1.0, 0.0); // M // 0.61, 0.25
		}
	#endif

	#if !_POINTLIGHT_
		OutputColor.rgb = ApplyFog(OutputColor.rgb, GetFogValue(Input.VertexPos.xyz, WorldSpaceCamPos.xyz));
	#endif

	return OutputColor;
}

technique Variable
{
	pass p0
	{
		VertexShader = compile vs_3_0 Bump_VS();
		PixelShader = compile ps_3_0 Bump_PS();

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
	}
}