#include "shaders/RealityGraphics.fxh"
#include "shaders/RaCommon.fxh"
#include "shaders/RaShaderSTMCommon.fxh"

/*
	Description:
	- Renders lighting for staticmesh (buildings, static props)
	- Calculates tangent-space lighting
*/

// tl: Alias packed data indices to regular indices:
#if defined(TexBasePackedInd)
	#define BaseTexID TexBasePackedInd
#endif
#if defined(TexDetailPackedInd)
	#define DetailTexID TexDetailPackedInd
#endif
#if defined(TexDirtPackedInd)
	#define DirtTexID TexDirtPackedInd
#endif
#if defined(TexCrackPackedInd)
	#define CrackTexID TexCrackPackedInd
#endif
#if defined(TexLightMapPackedInd)
	#define LightMapTexID TexLightMapPackedInd
#endif

#if (_NBASE_ || _NDETAIL_ || _NCRACK_ || _PARALLAXDETAIL_)
	#define _PERPIXEL_
#endif

// Only use crackmap if we have a per-pixel normalmap
#if !defined(_PERPIXEL_)
	#undef _CRACK_
#endif

#undef _DEBUG_
// #define _DEBUG_
#if defined(_DEBUG_)
	#define _PERPIXEL_
	#define POINTLIGHT
#endif

#define PARALLAX_BIAS 0.0025

// Common vars
Light Lights[NUM_LIGHTS];

struct APP2VS
{
	float4 Pos : POSITION;
	float3 Normal : NORMAL;
	float3 Tan : TANGENT;
	float4 TexSets[NUM_TEXSETS] : TEXCOORD0;
};

struct VS2PS
{
	float4 HPos : POSITION;
	float4 Pos : TEXCOORD0;

	float3 WorldTangent : TEXCOORD1;
	float3 WorldBinormal : TEXCOORD2;
	float3 WorldNormal : TEXCOORD3;

	float4 BaseAndDetail : TEXCOORD4; // .xy = BaseTex; .zw = DetailTex;
	float4 DirtAndCrack : TEXCOORD5; // .xy = DirtTex; .zw = CrackTex;
	float4 LightMapTex : TEXCOORD6;
	float4 ShadowTex : TEXCOORD7;
};

struct PS2FB
{
	float4 Color : COLOR;
	#if defined(LOG_DEPTH)
		float Depth : DEPTH;
	#endif
};

/*
	Common vertex shader methods
*/

float GetBinormalFlipping(APP2VS Input)
{
	return 1.0 + Input.Pos.w * -2.0;
}

VS2PS StaticMesh_VS(APP2VS Input)
{
	VS2PS Output = (VS2PS)0;

	// Get object-space data
	float4 ObjectPos = float4(Input.Pos.xyz, 1.0) * PosUnpack;
	float3 ObjectTangent = Input.Tan * NormalUnpack.x + NormalUnpack.y; // Unpack object-space tangent
	float3 ObjectNormal = Input.Normal * NormalUnpack.x + NormalUnpack.y; // Unpack object-space normal
	float3x3 ObjectTBN = GetTangentBasis(ObjectTangent, ObjectNormal, GetBinormalFlipping(Input));

	// Output HPos
	Output.HPos = mul(ObjectPos, WorldViewProjection);

	// Output world-space data
	Output.Pos.xyz = GetWorldPos(ObjectPos.xyz);
	#if defined(LOG_DEPTH)
		Output.Pos.w = Output.HPos.w + 1.0; // Output depth
	#endif
	float3x3 WorldTBN = mul(ObjectTBN, (float3x3)World);
	Output.WorldTangent = WorldTBN[0];
	Output.WorldBinormal = WorldTBN[1];
	Output.WorldNormal = WorldTBN[2];

	#if _BASE_
		Output.BaseAndDetail.xy = Input.TexSets[BaseTexID].xy * TexUnpack;
	#endif
	#if _DETAIL_ || _NDETAIL_
		Output.BaseAndDetail.zw = Input.TexSets[DetailTexID].xy * TexUnpack;
	#endif

	#if _DIRT_
		Output.DirtAndCrack.xy = Input.TexSets[DirtTexID].xy * TexUnpack;
	#endif
	#if _CRACK_
		Output.DirtAndCrack.zw = Input.TexSets[CrackTexID].xy * TexUnpack;
	#endif

	#if	_LIGHTMAP_
		Output.LightMapTex.xy = Input.TexSets[LightMapTexID].xy * TexUnpack * LightMapOffset.xy + LightMapOffset.zw;
	#endif

	#if _SHADOW_ && _LIGHTMAP_
		Output.ShadowTex = GetShadowProjection(ObjectPos);
	#endif

	return Output;
}

float2 GetParallax(float2 TexCoords, float3 ViewVec)
{
	float Height = tex2D(SampleNormalMap, TexCoords).a;
	Height = (Height * 2.0) - 1.0;
	Height = Height * ParallaxScaleBias.xy + ParallaxScaleBias.wz;
	ViewVec = ViewVec * float3(1.0, -1.0, 1.0);
	return TexCoords + ((Height * ViewVec.xy) * PARALLAX_BIAS);
}

float4 GetDiffuseMap(VS2PS Input, float3 TanViewVec, out float DiffuseGloss)
{
	float4 Diffuse = 1.0;
	DiffuseGloss = StaticGloss;

	#if _BASE_
		Diffuse = tex2D(SampleDiffuseMap, Input.BaseAndDetail.xy);
	#endif

	// TODO: Fix parallax mapping
	#if (_DETAIL_ || _PARALLAXDETAIL_)
		float4 Detail = tex2D(SampleDetailMap, Input.BaseAndDetail.zw);
	#endif

	#if (_DETAIL_ || _PARALLAXDETAIL_)
		Diffuse.rgb *= Detail.rgb;
		Diffuse.a = Detail.a;
		#if (!_ALPHATEST_)
			DiffuseGloss = Detail.a;
			Diffuse.a = Transparency.a;
		#else
			Diffuse.a *= Transparency.a;
		#endif
	#else
		Diffuse.a *= Transparency.a;
	#endif

	#if _DIRT_
		float4 DirtMap = tex2D(SampleDirtMap, Input.DirtAndCrack.xy);
		Diffuse.rgb *= DirtMap.rgb;
	#endif

	#if _CRACK_
		float4 Crack = tex2D(SampleCrackMap, Input.DirtAndCrack.zw);
		Diffuse.rgb = lerp(Diffuse.rgb, Crack.rgb, Crack.a);
	#endif

	return Diffuse;
}

// This also includes the composite Gloss map
float3 GetNormalMap(VS2PS Input, float3 TanViewVec, float3x3 WorldTBN)
{
	#if defined(_PERPIXEL_)
		float3 TangentNormals = float3(0.0, 0.0, 1.0);
		#if	_NBASE_
			TangentNormals = tex2D(SampleNormalMap, Input.BaseAndDetail.xy).xyz;
		#endif
		#if _PARALLAXDETAIL_
			TangentNormals = tex2D(SampleNormalMap, GetParallax(Input.BaseAndDetail.zw, TanViewVec)).xyz;
		#elif _NDETAIL_
			TangentNormals = tex2D(SampleNormalMap, Input.BaseAndDetail.zw).xyz;
		#endif
		#if _NCRACK_
			float3 CrackTangentNormals = tex2D(SampleCrackNormalMap, Input.DirtAndCrack.zw).xyz;
			float CrackMask = tex2D(SampleCrackMap, Input.DirtAndCrack.zw).a;
			TangentNormals = lerp(TangentNormals, CrackTangentNormals, CrackMask);
		#endif

		// [tangent-space] -> [object-space] -> [world-space]
		TangentNormals = normalize((TangentNormals * 2.0) - 1.0);
		float3 WorldNormals = normalize(mul(TangentNormals, WorldTBN));
		return WorldNormals;
	#else
		return WorldTBN[2];
	#endif
}

float3 GetLightmap(VS2PS Input)
{
	#if _LIGHTMAP_
		return tex2D(SampleLightMap, Input.LightMapTex.xy).rgb;
	#else
		return 1.0;
	#endif
}

float3 GetWorldLightVec(float3 WorldPos)
{
	#if _POINTLIGHT_
		return GetWorldLightPos(Lights[0].pos.xyz) - WorldPos;
	#else
		return GetWorldLightDir(-Lights[0].dir.xyz);
	#endif
}

PS2FB StaticMesh_PS(VS2PS Input)
{
	// Initialize variables
	float4 OutputColor = 1.0;
	PS2FB Output = (PS2FB)0;

	// Get world-space data
	float3 WorldPos = Input.Pos.xyz;
	float3 WorldLightVec = GetWorldLightVec(WorldPos);
	float3 NWorldLightVec = normalize(WorldLightVec);
	float3 WorldViewVec = normalize(WorldSpaceCamPos - WorldPos);
	float3x3 WorldTBN =
	{
		normalize(Input.WorldTangent),
		normalize(Input.WorldBinormal),
		normalize(Input.WorldNormal)
	};

	// Get tangent-space data
	// mul(mat, vec) == mul(vec, transpose(mat))
	float3 TanViewVec = normalize(mul(WorldTBN, WorldViewVec));

	// Prepare texture data
	float Gloss;
	float4 ColorMap = GetDiffuseMap(Input, TanViewVec, Gloss);
	float3 WorldNormals = GetNormalMap(Input, TanViewVec, WorldTBN);

	// Prepare lighting data
	ColorPair Light = ComputeLights(WorldNormals, NWorldLightVec, WorldViewVec, SpecularPower);
	Light.Diffuse = (Light.Diffuse * Lights[0].color);
	Light.Specular = (Light.Specular * Gloss) * Lights[0].color;

	#if _POINTLIGHT_
		float Attenuation = GetLightAttenuation(WorldLightVec, Lights[0].attenuation);
		Light.Diffuse *= Attenuation;
		Light.Specular *= Attenuation;
		OutputColor.rgb = (ColorMap.rgb * Light.Diffuse) + Light.Specular;
		OutputColor.rgb *= GetFogValue(WorldPos, WorldSpaceCamPos);
	#else
		// Directional light + Lightmap etc
		float3 Lightmap = GetLightmap(Input);
		#if _LIGHTMAP_ && _SHADOW_
			Lightmap.g *= GetShadowFactor(SampleShadowMap, Input.ShadowTex);
		#endif

		// We divide the normal by 5.0 to prevent complete darkness for surfaces facing away from the sun
		float DotLN = saturate(dot(WorldNormals / 5.0, NWorldLightVec));
		float IDotLN = saturate((1.0 - DotLN) * 0.65);

		// We add ambient to get correct ambient for surfaces parallel to the sun
		float3 Ambient = (StaticSkyColor * IDotLN) * Lightmap.b;
		float3 BumpedDiffuse = Light.Diffuse + Ambient;

		Light.Diffuse = lerp(Ambient, BumpedDiffuse, Lightmap.g);
		Light.Diffuse += (Lightmap.r * SinglePointColor);
		Light.Specular = Light.Specular * Lightmap.g;

		OutputColor.rgb = (ColorMap.rgb * (Light.Diffuse * 2.0)) + Light.Specular;
	#endif

	Output.Color = float4(OutputColor.rgb, ColorMap.a);

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);
	#endif

	#if !_POINTLIGHT_
		ApplyFog(Output.Color.rgb, GetFogValue(WorldPos, WorldSpaceCamPos));
	#endif

	return Output;
};

technique defaultTechnique
{
	pass Pass0
	{
		#if defined(ENABLE_WIREFRAME)
			FillMode = WireFrame;
		#endif

		ZFunc = LESS;
		AlphaTestEnable = (AlphaTest);
		AlphaRef = 127; // temporary hack by johan because "m_shaderSettings.m_alphaTestRef = 127" somehow doesn't work

		#if _POINTLIGHT_
			ZFunc = LESSEQUAL;
			AlphaBlendEnable = TRUE;
			SrcBlend = ONE;
			DestBlend = ONE;
		#endif

		VertexShader = compile vs_3_0 StaticMesh_VS();
		PixelShader = compile ps_3_0 StaticMesh_PS();
	}
}
