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
	#define PERPIXEL
#endif

// Only use crackmap if we have a per-pixel normalmap
#if !defined(PERPIXEL)
	#undef _CRACK_
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

	float3 ObjectTangent : TEXCOORD1;
	float3 ObjectBinormal : TEXCOORD2;
	float3 ObjectNormal : TEXCOORD3;

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

	// Get object-space properties
	float4 ObjectPos = float4(Input.Pos.xyz, 1.0) * PosUnpack;
	float3 ObjectTangent = Input.Tan * NormalUnpack.x + NormalUnpack.y; // Unpack object-space tangent
	float3 ObjectNormal = Input.Normal * NormalUnpack.x + NormalUnpack.y; // Unpack object-space normal
	float3x3 ObjectTBN = GetTangentBasis(ObjectTangent, ObjectNormal, GetBinormalFlipping(Input));

	// Output HPos
	Output.HPos = mul(ObjectPos, WorldViewProjection);
	Output.Pos.xyz = ObjectPos.xyz;
	#if defined(LOG_DEPTH)
		Output.Pos.w = Output.HPos.w + 1.0; // Output depth
	#endif

	// Output object-space properties
	Output.ObjectTangent = ObjectTBN[0];
	Output.ObjectBinormal = ObjectTBN[1];
	Output.ObjectNormal = ObjectTBN[2];

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

// TODO: Ask Project Reality Team for editor shader source
float2 GetParallax(float2 TexCoords, float3 ViewVec)
{
	float Height = tex2D(SampleNormalMap, TexCoords).a;
	Height = (Height * 2.0) - 1.0;
	Height = Height * ParallaxScaleBias.xy + ParallaxScaleBias.wz;
	ViewVec = ViewVec * float3(1.0, -1.0, 1.0);
	return TexCoords + ((Height * ViewVec.xy) * PARALLAX_BIAS);
}

float4 GetDiffuseMap(VS2PS Input, float3 TanEyeVec, out float DiffuseGloss)
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
float3 GetNormalMap(VS2PS Input, float3 TanEyeVec)
{
	float3 Normals = float3(0.0, 0.0, 1.0);

	#if	_NBASE_
		Normals = tex2D(SampleNormalMap, Input.BaseAndDetail.xy).xyz;
	#endif

	#if _PARALLAXDETAIL_
		Normals = tex2D(SampleNormalMap, GetParallax(Input.BaseAndDetail.zw, TanEyeVec)).xyz;
	#elif _NDETAIL_
		Normals = tex2D(SampleNormalMap, Input.BaseAndDetail.zw).xyz;
	#endif

	#if _NCRACK_
		float3 CrackNormal = tex2D(SampleCrackNormalMap, Input.DirtAndCrack.zw).xyz;
		float CrackMask = tex2D(SampleCrackMap, Input.DirtAndCrack.zw).a;
		Normals = lerp(Normals, CrackNormal, CrackMask);
	#endif

	#if defined(PERPIXEL)
		Normals = normalize((Normals * 2.0) - 1.0);
	#endif

	return Normals;
}

float3 GetLightmap(VS2PS Input)
{
	#if _LIGHTMAP_
		return tex2D(SampleLightMap, Input.LightMapTex.xy).rgb;
	#else
		return 1.0;
	#endif
}

float3 GetObjectLightVec(float3 ObjectPos)
{
	#if _POINTLIGHT_
		return Lights[0].pos - ObjectPos;
	#else
		return -Lights[0].dir;
	#endif
}

PS2FB StaticMesh_PS(VS2PS Input)
{
	PS2FB Output = (PS2FB)0;

	// Get object-space properties
	float3 ObjectPos = Input.Pos.xyz;
	float3 ObjectTangent = normalize(Input.ObjectTangent);
	float3 ObjectBinormal = normalize(Input.ObjectBinormal);
	float3 ObjectNormal = normalize(Input.ObjectNormal);
	float3x3 ObjectTBN = float3x3(ObjectTangent, ObjectBinormal, ObjectNormal);

	// mul(mat, vec) == mul(vec, transpose(mat))
	float3 ObjectLightVec = GetObjectLightVec(ObjectPos);
	float3 LightVec = normalize(mul(ObjectTBN, ObjectLightVec));
	float3 ViewVec = normalize(mul(ObjectTBN, ObjectSpaceCamPos - ObjectPos));

	float4 OutputColor = 1.0;
	float Gloss;
	float4 ColorMap = GetDiffuseMap(Input, ViewVec, Gloss);
	float3 NormalVec = GetNormalMap(Input, ViewVec);

	ColorPair Light = ComputeLights(NormalVec, LightVec, ViewVec, SpecularPower);
	Light.Diffuse = (Light.Diffuse * Lights[0].color);
	Light.Specular = (Light.Specular * Gloss) * Lights[0].color;

	#if _POINTLIGHT_
		float Attenuation = GetLightAttenuation(ObjectLightVec, Lights[0].attenuation);
		Light.Diffuse *= Attenuation;
		Light.Specular *= Attenuation;
		OutputColor.rgb = (ColorMap.rgb * Light.Diffuse) + Light.Specular;
		OutputColor.rgb *= GetFogValue(ObjectPos, ObjectSpaceCamPos);
	#else
		// Directional light + Lightmap etc
		float3 Lightmap = GetLightmap(Input);
		#if _LIGHTMAP_ && _SHADOW_
			Lightmap.g *= GetShadowFactor(SampleShadowMap, Input.ShadowTex);
		#endif

		// We divide the normal by 5.0 to prevent complete darkness for surfaces facing away from the sun
		float DotLN = saturate(dot(NormalVec.xyz / 5.0, -Lights[0].dir));
		float InvDotLN = saturate((1.0 - DotLN) * 0.65);

		// We add ambient to get correct ambient for surfaces parallel to the sun
		float3 Ambient = (StaticSkyColor * InvDotLN) * Lightmap.b;
		float3 BumpedDiffuse = Light.Diffuse + Ambient;

		Light.Diffuse = lerp(Ambient, BumpedDiffuse, Lightmap.g);
		Light.Diffuse += (Lightmap.r * SinglePointColor);
		Light.Specular = Light.Specular * Lightmap.g;

		OutputColor.rgb = ((ColorMap.rgb * 2.0) * Light.Diffuse) + Light.Specular;
	#endif

	OutputColor.a = ColorMap.a;

	Output.Color = OutputColor;

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);
	#endif

	#if !_POINTLIGHT_
		ApplyFog(Output.Color.rgb, GetFogValue(ObjectPos, ObjectSpaceCamPos));
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
