
#include "shaders/RealityGraphics.fx"
#include "shaders/RaCommon.fx"
#include "shaders/RaShaderSTMCommon.fx"

#define skyNormal float3(0.78,0.52,0.65)

// tl: Alias packed data indices to regular indices:
#if defined(TexBasePackedInd)
	#define TexBaseInd TexBasePackedInd
#endif

#if defined(TexDetailPackedInd)
	#define TexDetailInd TexDetailPackedInd
#endif

#if defined(TexDirtPackedInd)
	#define TexDirtInd TexDirtPackedInd
#endif

#if defined(TexCrackPackedInd)
	#define TexCrackInd TexCrackPackedInd
#endif

#if defined(TexLightMapPackedInd)
	#define TexLightMapInd TexLightMapPackedInd
#endif

#if (_NBASE_ || _NDETAIL_ || _NCRACK_ || _PARALLAXDETAIL_)
	#define USE_DETAIL
#else
	#define _CRACK_ 0 // We do not allow Crack if we run on the non detailed path.
#endif

// common vars
Light Lights[NUM_LIGHTS];

struct APP2VS
{
	float4 Pos : POSITION;
	float3 Normal : NORMAL;
	float3 Tan : TANGENT;
	float4 TexSets[NUM_TEXSETS] : TEXCOORD0;
};

float GetBinormalFlipping(APP2VS Input)
{
	return 1.0 + Input.Pos.w * -2.0;
}

/*
	Common vertex shader methods
*/

// P_(x)_(y) == Packed interpolator with (x) and (y)

struct VS2PS
{
	float4 HPos : POSITION;

	float4 P_Normals_Fog : TEXCOORD0; // .xyz = Normals; .w = Fog
	float3 EyeVec : TEXCOORD1;
	float3 LightVec : TEXCOORD2;

	float4 P_Base_Detail : TEXCOORD3; // .xy = TexBase; .zw = TexDetail;
	float4 P_Dirt_Crack : TEXCOORD4; // .xy = TexDirt; .zw = TexCrack;

	float4 LightMapTex : TEXCOORD5;
	float4 ShadowTex : TEXCOORD6;
};

VS2PS StaticMesh_VS(APP2VS Input)
{
	VS2PS Output = (VS2PS)0;

	// Output position early
	float4 UnpackedPos = float4(Input.Pos.xyz, 1.0) * PosUnpack;
	Output.HPos = mul(UnpackedPos, WorldViewProjection);

	float3 UnpackedTangent = Input.Tan * NormalUnpack.x + NormalUnpack.y;
	float3 UnpackedNormal = Input.Normal * NormalUnpack.x + NormalUnpack.y;
	float3x3 ObjI = transpose(GetTangentBasis(UnpackedTangent, UnpackedNormal, GetBinormalFlipping(Input)));

	float3 ObjSpaceEyeVec = ObjectSpaceCamPos - UnpackedPos;

	Output.P_Normals_Fog.xyz = normalize(UnpackedNormal);
	Output.P_Normals_Fog.w = GetFogValue(UnpackedPos.xyz, ObjectSpaceCamPos.xyz);

	Output.EyeVec.xyz = mul(ObjSpaceEyeVec, ObjI);

	#if _POINTLIGHT_
		Output.LightVec.xyz = mul(Lights[0].pos - UnpackedPos, ObjI);
	#else
		Output.LightVec.xyz = mul(-Lights[0].dir, ObjI);
	#endif

	#if _BASE_
		Output.P_Base_Detail.xy = Input.TexSets[TexBaseInd].xy * TexUnpack;
	#endif
	#if (_DETAIL_ || _NDETAIL_)
		Output.P_Base_Detail.zw = Input.TexSets[TexDetailInd].xy * TexUnpack;
	#endif

	#if _DIRT_
		Output.P_Dirt_Crack.xy = Input.TexSets[TexDirtInd].xy * TexUnpack;
	#endif
	#if _CRACK_
		Output.P_Dirt_Crack.zw = Input.TexSets[TexCrackInd].xy * TexUnpack;
	#endif

	#if	_LIGHTMAP_
		Output.LightMapTex.xy =  Input.TexSets[TexLightMapInd].xy * TexUnpack * LightMapOffset.xy + LightMapOffset.zw;
	#endif

	#if _SHADOW_ && _LIGHTMAP_
		Output.ShadowTex = GetShadowProjection(UnpackedPos);
	#endif

	return Output;
}

float2 CalcParallax(float2 HeightTexCoords, sampler2D HeightSampler, float4 ScaleBias, float3 EyeVec)
{
	float2 Height = tex2D(HeightSampler, HeightTexCoords).aa;
	float2 EyeVecN = EyeVec.xy * float2(1.0, -1.0);
	float4 FakeBias = float4(FH2_HARDCODED_PARALLAX_BIAS, FH2_HARDCODED_PARALLAX_BIAS, 0.0, 0.0);
	Height = Height * FakeBias.xy + FakeBias.wz;
	return HeightTexCoords + Height * EyeVecN.xy;
}

float4 GetCompositeDiffuse(VS2PS Input, float3 TanEyeVec, out float Gloss)
{
	float4 Diffuse = 0.0;
	Gloss = StaticGloss;

	#if _BASE_
		Diffuse = tex2D(DiffuseMapSampler, Input.P_Base_Detail.xy);
	#endif

	#if _PARALLAXDETAIL_
		float4 Detail = tex2D(DetailMapSampler, CalcParallax(Input.P_Base_Detail.zw, NormalMapSampler, ParallaxScaleBias, TanEyeVec));
	#elif _DETAIL_
		float4 Detail = tex2D(DetailMapSampler, Input.P_Base_Detail.zw);
	#endif

	#if (_DETAIL_ || _PARALLAXDETAIL_)
		// tl: assumes base has .a = 1 (which should be the case)
		// Diffuse.rgb *= Detail.rgb;
		Diffuse *= Detail;
		#if (!_ALPHATEST_)
			Gloss = Detail.a;
			Diffuse.a = Transparency.a;
		#else
			Diffuse.a *= Transparency.a;
		#endif
	#else
		Diffuse.a *= Transparency.a;
	#endif

	#if _DIRT_
		Diffuse.rgb *= tex2D(DirtMapSampler, Input.P_Dirt_Crack.xy).rgb;
	#endif

	#if _CRACK_
		float4 Crack = tex2D(CrackMapSampler, Input.P_Dirt_Crack.zw);
		Diffuse.rgb = lerp(Diffuse.rgb, Crack.rgb, Crack.a);
	#endif

	return Diffuse;
}

// This also includes the composite Gloss map
float3 GetCompositeNormals(VS2PS Input, float3 TanEyeVec)
{
	float3 Normals = 0.0;

	#if	_NBASE_
		Normals = tex2D(NormalMapSampler, Input.P_Base_Detail.xy);
	#endif

	#if _PARALLAXDETAIL_
		Normals = tex2D(NormalMapSampler, CalcParallax(Input.P_Base_Detail.zw, NormalMapSampler, ParallaxScaleBias, TanEyeVec));
	#elif _NDETAIL_
		Normals = tex2D(NormalMapSampler, Input.P_Base_Detail.zw);
	#endif

	#if _NCRACK_
		float4 CrackNormal = tex2D(CrackNormalMapSampler, Input.P_Dirt_Crack.zw);
		float CrackMask = tex2D(CrackMapSampler, Input.P_Dirt_Crack.zw).a;
		Normals = lerp(Normals, CrackNormal.rgb, CrackMask);
	#endif

	return Normals * 2.0 - 1.0;
}

float3 GetLightmap(VS2PS Input)
{
	#if _LIGHTMAP_
		return tex2D(LightMapSampler, Input.LightMapTex.xy).rgb;
	#else
		return 1.0;
	#endif
}

float4 StaticMesh_PS(VS2PS Input) : COLOR
{
	#if _FINDSHADER_
		return float4(1.0, 1.0, 0.4, 1.0);
	#endif

	float3 EyeVec = normalize(Input.EyeVec.xyz);
	float3 LightVec = normalize(Input.LightVec.xyz);
	float3 HalfVec = normalize(LightVec + EyeVec);

	#if defined(USE_DETAIL)
		float3 Normals = normalize(GetCompositeNormals(Input, EyeVec));
	#else
		float3 Normals = normalize(Input.P_Normals_Fog.xyz);
	#endif

	float Gloss;
	float4 FinalColor = GetCompositeDiffuse(Input, EyeVec, Gloss);

	#if _POINTLIGHT_
		#if !defined(USE_DETAIL)
			Normals = float3(0.0, 0.0, 1.0);
		#endif

		float Attenuation = GetRadialAttenuation(Input.LightVec.xyz, Lights[0].attenuation);
		float3 DiffuseColor = GetDiffuseValue(Normals, LightVec) * Lights[0].color;
		float3 SpecularColor = (GetSpecularValue(Normals, HalfVec) * Gloss) * StaticSpecularColor;

		float3 Lighting = DiffuseColor + SpecularColor;
		Lighting = saturate(Lighting * Attenuation * Input.P_Normals_Fog.w);

		FinalColor.rgb = (FinalColor.rgb * Lighting) * 2.0;
		return FinalColor;
	#else
		// Directional light + Lightmap etc
		float3 Lightmap = GetLightmap(Input);

		#if _SHADOW_ && _LIGHTMAP_
			Lightmap.g *= GetShadowFactor(ShadowMapSampler, Input.ShadowTex);
		#endif

		#if defined(USE_DETAIL)
			float3 Diffuse = GetDiffuseValue(Normals, LightVec) * Lights[0].color;
			// Pre-calc: Lightmap.b *= invDot
			float3 BumpedSky = Lightmap.b * dot(Normals, skyNormal) * StaticSkyColor;
			Diffuse = BumpedSky + Diffuse * Lightmap.g;
			Diffuse += Lightmap.r * SinglePointColor; // tl: Jonas, disable once we know which materials are actually affected.
		#else
			float DotLN = GetDiffuseValue(Normals, -Lights[0].dir);
			float3 Diffuse = saturate(DotLN * Lights[0].color);
			float3 InvDot = saturate(saturate(1.0 - DotLN) * StaticSkyColor.rgb * skyNormal.z);

			#if _LIGHTMAP_
				// Add ambient here as well to get correct ambient for surfaces parallel to the sun
				float3 BumpedSky = Lightmap.b * InvDot;
				float3 BumpedDiff = Diffuse + BumpedSky;
				Diffuse = lerp(BumpedSky, BumpedDiff, Lightmap.g);
				Diffuse += Lightmap.r * SinglePointColor;
			#else
				float3 BumpedSky = InvDot;
				Diffuse *= Lightmap.g;
				Diffuse += BumpedSky;
			#endif
		#endif

		float Specular = GetSpecularValue(Normals, HalfVec) * Gloss;
		FinalColor.rgb = (FinalColor.rgb * Diffuse) * 2.0;
		FinalColor.rgb += (Specular * Lightmap.g) * StaticSpecularColor;
	#endif

	#if !_POINTLIGHT_
		FinalColor.rgb = ApplyFog(FinalColor.rgb, Input.P_Normals_Fog.w);
	#endif

	return FinalColor;
};

technique defaultTechnique
{
	pass P0
	{
		VertexShader = compile vs_3_0 StaticMesh_VS();
		PixelShader = compile ps_3_0 StaticMesh_PS();

		ZFunc = LESS;

		#if defined(ENABLE_WIREFRAME)
			FillMode = WireFrame;
		#endif

		#if _POINTLIGHT_
			ZFunc = LESSEQUAL;
			AlphaBlendEnable = TRUE;
			SrcBlend = ONE;
			DestBlend = ONE;
		#endif
		AlphaTestEnable = < AlphaTest >;
		AlphaRef = 127; // temporary hack by johan because "m_shaderSettings.m_alphaTestRef = 127" somehow doesn't work
	}
}
