//#define _FORCE_1_4_SHADERS_ 1

#if _FORCE_1_4_SHADERS_
	//#include "shaders/STM1_4.fx"

	// 1_4 settings
	// remove features
	#define _CRACK_ 0
	#define _PARALLAXDETAIL_ 0
	#define _NBASE_ 0
	#define _NDETAIL_ 0
	#define _CRACK_ 0
	#define _NCRACK_ 0
	#define _SHADOW_ 0
	#define _USESPECULAR_ 0
	#define _USEPERPIXELNORMALIZE_ 0
#else
	// Quality settings.
	#if RAPATH <= 1
		#define _USEPERPIXELNORMALIZE_ 1
	#else
		#define _USEPERPIXELNORMALIZE_ 0
	#endif
	
	// if we want to run the same path on 1_4 we should disable this.
	#define _USERENORMALIZEDTEXTURES_ 1
	#define _USESPECULAR_ 1
	//#define USEVERTEXSPECULAR 1
#endif

#include "shaders/RaCommon.fx"
#include "shaders/RaShaderSTMCommon.fx"

#define skyNormal float3(0.78,0.52,0.65)


// tl: Alias packed data indices to regular indices:
#ifdef TexBasePackedInd
	#define TexBaseInd TexBasePackedInd
#endif
#ifdef TexDetailPackedInd
	#define TexDetailInd TexDetailPackedInd
#endif
#ifdef TexDirtPackedInd
	#define TexDirtInd TexDirtPackedInd
#endif
#ifdef TexCrackPackedInd
	#define TexCrackInd TexCrackPackedInd
#endif
#ifdef TexLightMapPackedInd
	#define TexLightMapInd TexLightMapPackedInd
#endif

#if (_NBASE_||_NDETAIL_ || _NCRACK_ || _PARALLAXDETAIL_)
	#define PERPIXEL
#else
	#define _CRACK_ 0 // We do not allow crack if we run on the non per pixel path.
#endif

#define MPSMODEL PSMODEL

struct VS_IN
{
	float4 Pos : POSITION;
	float3 Normal : NORMAL;
	float3 Tan : TANGENT;
	float4 TexSets[NUM_TEXSETS] : TEXCOORD0;
};

// setup interpolators
#ifdef PERPIXEL
	#define __LVEC_INTER 0
	#define __EYEVEC_INTER 1
	#define __TEXBASE_INTER 2
#else
	#define __LVEC_INTER 0
	#define __EYEVEC_INTER 1
	//#define __NORMAL_INTER 2
	#define __TEXBASE_INTER 2
#endif


	#define __TEXLMAP_INTER __TEXBASE_INTER + _LIGHTMAP_
#if (_DETAIL_||_NDETAIL_||_PARALLAXDETAIL_)
	#define __TEXDETAIL_INTER __TEXLMAP_INTER + 1
#else
	#define __TEXDETAIL_INTER __TEXLMAP_INTER
#endif

#if _SHADOW_
	#define __TEXSHADOW_INTER __TEXDETAIL_INTER+1
#else
	#define __TEXSHADOW_INTER __TEXDETAIL_INTER
#endif

#if _DIRT_
	#define __TEXDIRT_INTER __TEXSHADOW_INTER + 1
#else
	#define __TEXDIRT_INTER __TEXSHADOW_INTER
#endif

#if (_CRACK_||_NCRACK_)
	#define __TEXCRACK_INTER __TEXDIRT_INTER+1
#else
	#define __TEXCRACK_INTER __TEXDIRT_INTER
#endif

#define MAX_INTERPS __TEXCRACK_INTER + 1

struct VS_OUT
{
	float4 Pos : POSITION0;
	float4 InvDotAndLightAtt : COLOR0;
	float4 ColorOrPointLightFog : COLOR1;
	float4 Interpolated[MAX_INTERPS] : TEXCOORD0;
	
	float Fog : FOG;
};

// common vars
Light Lights[NUM_LIGHTS];

float getBinormalFlipping(VS_IN input)
{
	return 1.f + input.Pos.w * -2.f;
}

float3x3 getTanBasisTranspose(VS_IN input, float3 Normal, float3 Tan)
{
	// Cross product to create BiNormal
	float flip = getBinormalFlipping(input);
	float3 binormal = normalize(cross(Tan, Normal)) * flip;
	
	// calculate the objI
	return transpose(float3x3(Tan, binormal, Normal));
}

float3 getVectorTo(float3 vertexPos, float3 camPos)
{
	return camPos - vertexPos;
}

// common vertex shader methods
VS_OUT 
vsStaticMesh(VS_IN indata)
{
	VS_OUT Out = (VS_OUT)0;
 
 	// output position early
 	float4 unpackedPos = float4(indata.Pos.xyz,1) * PosUnpack;
 	Out.Pos = mul(unpackedPos, WorldViewProjection);
	float3 unpackedNormal = indata.Normal * NormalUnpack.x + NormalUnpack.y;
    
	#if _POINTLIGHT_
		float3 unpackedTan = indata.Tan * NormalUnpack.x + NormalUnpack.y;
		float3x3 objI = getTanBasisTranspose(indata, unpackedNormal, unpackedTan);
	
		Out.Interpolated[__EYEVEC_INTER].rgb = mul(getVectorTo(unpackedPos, ObjectSpaceCamPos), objI);
		Out.Interpolated[__LVEC_INTER].rgb = mul(getVectorTo(unpackedPos, Lights[0].pos), objI);
		
		// Transform eye pos to tangent space 
		#if (!_USEPERPIXELNORMALIZE_)
			Out.Interpolated[__EYEVEC_INTER].rgb = normalize(Out.Interpolated[__EYEVEC_INTER].rgb);
		#endif
	
		Out.InvDotAndLightAtt.b = Lights[0].attenuation;						
	#else
		#ifdef PERPIXEL
			float3 unpackedTan = indata.Tan * NormalUnpack.x + NormalUnpack.y;
			float3x3 objI = getTanBasisTranspose(indata, unpackedNormal, unpackedTan);
		
			Out.Interpolated[__EYEVEC_INTER].rgb = mul(getVectorTo(unpackedPos, ObjectSpaceCamPos), objI);
			Out.Interpolated[__LVEC_INTER].rgb = mul(-Lights[0].dir, objI);
			
			// Transform eye pos to tangent space 
			#if (!_USEPERPIXELNORMALIZE_)
				Out.Interpolated[__EYEVEC_INTER].rgb = normalize(Out.Interpolated[__EYEVEC_INTER].rgb);
				Out.Interpolated[__LVEC_INTER].rgb = normalize(Out.Interpolated[__LVEC_INTER].rgb);
			#endif
		
			Out.InvDotAndLightAtt.a = 1-(saturate(dot(unpackedNormal*0.2, -Lights[0].dir)));
			Out.InvDotAndLightAtt.b = Lights[0].attenuation;
		#else

			#ifdef USEVERTEXSPECULAR
				float ndotl = dot(-Lights[0].dir, unpackedNormal);
				float vdotr = dot(reflect(Lights[0].dir, unpackedNormal), normalize(getVectorTo(unpackedPos, ObjectSpaceCamPos)));
				float4 lighting = lit(ndotl, vdotr, 32);
				// Out.Interpolated[__NORMAL_INTER].rgb = lighting.z * CEXP(StaticSpecularColor);	
			#else
				float3 unpackedTan = indata.Tan * NormalUnpack.x + NormalUnpack.y;
				float3x3 objI = getTanBasisTranspose(indata, unpackedNormal, unpackedTan);
			
				Out.Interpolated[__EYEVEC_INTER].rgb = mul(getVectorTo(unpackedPos, ObjectSpaceCamPos), objI);
				Out.Interpolated[__LVEC_INTER].rgb = mul(-Lights[0].dir, objI);

				// Out.Interpolated[__EYEVEC_INTER].rgb = getVectorTo(unpackedPos, ObjectSpaceCamPos);
				// Out.Interpolated[__LVEC_INTER].rgb = -Lights[0].dir;
				#if (!_USEPERPIXELNORMALIZE_)
					Out.Interpolated[__EYEVEC_INTER].rgb = normalize(Out.Interpolated[__EYEVEC_INTER].rgb);
					Out.Interpolated[__LVEC_INTER].rgb = normalize(Out.Interpolated[__LVEC_INTER].rgb);
				#endif
				
			#endif
						
			float invDot = 1-saturate(dot(unpackedNormal*0.2, -Lights[0].dir));
			Out.InvDotAndLightAtt.rgb = skyNormal.z * CEXP(StaticSkyColor) * invDot;
			Out.ColorOrPointLightFog.rgb =  saturate(dot(unpackedNormal, -Lights[0].dir))*CEXP(Lights[0].color);
		#endif
	#endif
	
	#if _LIGHTMAP_
		 Out.Interpolated[__TEXLMAP_INTER].xy =  indata.TexSets[TexLightMapInd].xy * TexUnpack * LightMapOffset.xy + LightMapOffset.zw;
	#endif
	
	#if _BASE_
		Out.Interpolated[__TEXBASE_INTER].xy = indata.TexSets[TexBaseInd].xy * TexUnpack;
	#endif
	
	#if (_DETAIL_ || _NDETAIL_)
		Out.Interpolated[__TEXDETAIL_INTER].xy = indata.TexSets[TexDetailInd].xy * TexUnpack;
	#endif
	
	#if _DIRT_
		Out.Interpolated[__TEXDIRT_INTER].xy = indata.TexSets[TexDirtInd].xy * TexUnpack;
	#endif
	
	#if _CRACK_
		Out.Interpolated[__TEXCRACK_INTER].xy = indata.TexSets[TexCrackInd].xy * TexUnpack;
	#endif 
	
	#if _SHADOW_
		Out.Interpolated[__TEXSHADOW_INTER] = calcShadowProjectionExact(unpackedPos);
	#endif
	 
	 #if _POINTLIGHT_
		Out.ColorOrPointLightFog.a = calcFog(Out.Pos.w);
	#else
		Out.Fog = calcFog(Out.Pos.w);
	#endif

	return Out;
}

#if _PARALLAXDETAIL_
float2 
calculateParallaxCoordinatesFromAlpha(float2 inHeightTexCoords, sampler2D inHeightSampler, float4 inScaleBias, float3 inEyeVecNormalized)
{
	float2 height = tex2D(inHeightSampler, inHeightTexCoords).aa;
	float2 eyeVecN = inEyeVecNormalized.xy * float2(1,-1);

	height = height * inScaleBias.xy + inScaleBias.wz;
	return inHeightTexCoords + height * eyeVecN.xy;
}
#endif


float4 
getCompositeDiffuse(VS_OUT indata, float3 normTanEyeVec, out float gloss)
{
	// float4 base, detail, dirt, crack;
	float4 totalDiffuse = 0;
	gloss = StaticGloss;
	
#if _BASE_
	totalDiffuse = tex2D(DiffuseMapSampler, indata.Interpolated[__TEXBASE_INTER].xy);
#endif

#if _PARALLAXDETAIL_
	float4 detail = tex2D(DetailMapSampler, calculateParallaxCoordinatesFromAlpha(indata.Interpolated[__TEXDETAIL_INTER].xy, NormalMapSampler, ParallaxScaleBias, normTanEyeVec));
#elif _DETAIL_
	float4 detail = tex2D(DetailMapSampler, indata.Interpolated[__TEXDETAIL_INTER].xy);
#endif

#if (_DETAIL_|| _PARALLAXDETAIL_)
	// tl: assumes base has .a = 1 (which should be the case)
// totalDiffuse.rgb *= detail.rgb;
	totalDiffuse *= detail;
	#if (!_ALPHATEST_)
		gloss = detail.a;
		totalDiffuse.a = Transparency.a;
	#else
		totalDiffuse.a *= Transparency.a;
	#endif
#else
	totalDiffuse.a *= Transparency.a;
#endif 

#if _DIRT_
	totalDiffuse.rgb *= tex2D(DirtMapSampler, indata.Interpolated[__TEXDIRT_INTER].xy).rgb;
#endif
		
#if _CRACK_
	float4 crack = tex2D(CrackMapSampler, indata.Interpolated[__TEXCRACK_INTER].xy);
	totalDiffuse.rgb = lerp(totalDiffuse.rgb, crack.rgb, crack.a);
#endif
	
	return totalDiffuse;
}

float3 reNormalize(float3 t)
{
	return normalize(t);
	// float3 tempVec = t;
	// return (tempVec * (1 - saturate(dot(tempVec, tempVec))) + tempVec * 2)/2;
	
	// float3 tempVec = 0.5*(t);
	// return (tempVec * (1 - saturate(dot(tempVec, tempVec))) + tempVec * 2)/2;
	
}

// This also includes the composite gloss map
float3 
getCompositeNormals(VS_OUT indata, float3 normTanEyeVec)
{
	float3 totalNormal = 0;
	
	#if _NBASE_
		totalNormal = tex2D(NormalMapSampler, indata.Interpolated[__TEXBASE_INTER].xy);
	#endif

	#if _PARALLAXDETAIL_
		totalNormal = tex2D(NormalMapSampler, calculateParallaxCoordinatesFromAlpha(indata.Interpolated[__TEXDETAIL_INTER].xy, NormalMapSampler, ParallaxScaleBias, normTanEyeVec));
	#elif _NDETAIL_
		totalNormal = tex2D(NormalMapSampler, indata.Interpolated[__TEXDETAIL_INTER].xy);
	#endif

	#if _NCRACK_
		float4 cracknormal = tex2D(CrackNormalMapSampler, indata.Interpolated[__TEXCRACK_INTER].xy);
		float crackmask = tex2D(CrackMapSampler, indata.Interpolated[__TEXCRACK_INTER].xy).a;
		totalNormal = lerp(totalNormal, cracknormal.rgb, crackmask);
	#endif

	#if _USERENORMALIZEDTEXTURES_
		totalNormal.xyz = normalize(totalNormal.xyz * 2 - 1);
	#else
		totalNormal.xyz = totalNormal.xyz * 2 - 1;
	#endif

	return totalNormal;
}


float3 
getLightmap(VS_OUT indata)
{
	#if _LIGHTMAP_
		return tex2D(LightMapSampler, indata.Interpolated[__TEXLMAP_INTER].xy);
	#else
		return float3(1,1,1);
	#endif
}

float3 
getDiffuseVertexLighting(float3 lightmap, VS_OUT indata)
{
#if _LIGHTMAP_
	float3 diffuse = indata.ColorOrPointLightFog.rgb;
	float3 bumpedSky = lightmap.b * indata.InvDotAndLightAtt.rgb;
	
	// we add ambient here as well to get correct ambient for surfaces parallel to the sun
	float3 bumpedDiff = diffuse + bumpedSky;
	diffuse = lerp(bumpedSky, bumpedDiff, lightmap.g);
	diffuse += lightmap.r * SinglePointColor;
	
#else
	float3 diffuse =	indata.ColorOrPointLightFog.rgb;
	float3 bumpedSky = indata.InvDotAndLightAtt.rgb;

	diffuse *= lightmap.g;
	diffuse += bumpedSky;
#endif

	return diffuse;
}


float3 
getDiffusePixelLighting(float3 lightmap, float3 compNormals, float3 normalizedLightVec, VS_OUT indata)
{
	float3 diffuse = saturate(dot(compNormals, normalizedLightVec)) * CEXP(Lights[0].color);
	// pre-calc: lightmap.b *= invDot
	float3 bumpedSky = lightmap.b * dot(compNormals, skyNormal) * CEXP(StaticSkyColor);
	diffuse = bumpedSky + diffuse*lightmap.g;
	
	diffuse += lightmap.r * CEXP(SinglePointColor); // tl: Jonas, disable once we know which materials are actually affected.
	
	return diffuse;
}

float 
getSpecularPixelLighting(float3 lightmap, float3 compNormals, float3 normalizedLightVec, float3 eyeVec, float gloss)
{
	float3 halfVec = normalize(normalizedLightVec + eyeVec);
	float specular = saturate(dot(compNormals.xyz, halfVec));

	// todo dep texlookup for spec
	specular = pow(specular, 32);
	
	// mask
	specular *= lightmap.g * gloss;
		
	return specular;
}


float3
getPointPixelLighting(VS_OUT indata, float3 compNormal, float3 normLightVec, float3 normEyeVec, float gloss)
{
	float3 pointDiff = saturate(dot(compNormal.xyz, normLightVec)) * Lights[0].color;
	float3 lightPos = indata.Interpolated[__LVEC_INTER].rgb;
	float sat = 1.0 - saturate(dot(lightPos, lightPos) * indata.InvDotAndLightAtt.b);

	#if _USESPECULAR_
		float specular = getSpecularPixelLighting(1, compNormal, normLightVec, normEyeVec, gloss);
		pointDiff += specular * CEXP(StaticSpecularColor);
	#endif

	return saturate(pointDiff * sat * indata.ColorOrPointLightFog.a);
}



float4 
psStaticMesh(VS_OUT indata) : COLOR
{
// float x = 0.5;
// return float4(x,x,x,1);
// return 1;
#if _FINDSHADER_
	return float4(1,1,0.4,1);
#endif

	float gloss;
	float4 FinalColor;

#if _POINTLIGHT_
	#if _FORCE_1_4_SHADERS_
		// precaution.
		return 0;
	#endif
	float3 normEyeVec = indata.Interpolated[__EYEVEC_INTER].rgb;
	float3 normLightVec = indata.Interpolated[__LVEC_INTER].rgb;
	
	#if _USEPERPIXELNORMALIZE_ 
		normEyeVec = normalize(normEyeVec);
	#endif
	
	// here we must do it since we upload the unnormalized lightvec
	#if _USEPERPIXELNORMALIZE_ 
		normLightVec = normalize(normLightVec);
	#endif
	FinalColor = getCompositeDiffuse(indata, normEyeVec, gloss);
	
	#ifdef PERPIXEL
		float3 compNormals = getCompositeNormals(indata, normEyeVec);
	#else
		float3 compNormals = float3(0,0,1);
	#endif
	
	float3 diffuse = getPointPixelLighting(indata, compNormals, normLightVec, normEyeVec, gloss);
	
	FinalColor.rgb = 2*(FinalColor * diffuse);
	
	return FinalColor;
	
#else // if _POINTLIGHT_

	#ifdef PERPIXEL
		float3 normEyeVec = indata.Interpolated[__EYEVEC_INTER].rgb;
		#if _USEPERPIXELNORMALIZE_ 
			normEyeVec = normalize(normEyeVec);
		#endif
		
		float3 normLightVec = indata.Interpolated[__LVEC_INTER].rgb;
		#if _USEPERPIXELNORMALIZE_ 
			normLightVec = normalize(normLightVec);
		#endif
			
		FinalColor = getCompositeDiffuse(indata, normEyeVec, gloss);
		
		#ifdef DIFFUSE_CHANNEL
			return float4(FinalColor.rgb,1);
		#endif
		
		float3 compNormals = getCompositeNormals(indata, normEyeVec);
		
		
		// directional light + lightmap etc 
		float3 lightmap = getLightmap(indata);
		
		#if _SHADOW_
			lightmap.g *= getShadowFactorExact(ShadowMapSampler, indata.Interpolated[__TEXSHADOW_INTER], 3);
		#endif
	
		float3 diffuse = getDiffusePixelLighting(lightmap, compNormals.rgb, normLightVec, indata);
			
		#ifdef SHADOW_CHANNEL 
			return float4(diffuse,1);
		#endif
		
		FinalColor.rgb *= 2 * diffuse;
		
		#if _USESPECULAR_
			float specular = getSpecularPixelLighting(lightmap, compNormals, normLightVec, normEyeVec, gloss);
			FinalColor.rgb += specular * CEXP(StaticSpecularColor);
		#endif
		
	#else // if PERPIXEL
	
		FinalColor = getCompositeDiffuse(indata, 0, gloss);

		#ifdef DIFFUSE_CHANNEL
			return float4(FinalColor.rgb,1);
		#endif
		
		float3 lightmap = getLightmap(indata);
	
		#if _SHADOW_
			lightmap.g *= getShadowFactor(ShadowMapSampler, indata.Interpolated[__TEXSHADOW_INTER], 3);		
		#endif

		float3 diffuse = getDiffuseVertexLighting(lightmap, indata);

		#ifdef SHADOW_CHANNEL 
			return float4(diffuse,1);
		#endif

		FinalColor.rgb *= 2 * diffuse;

		#if _USESPECULAR_
			#ifdef USEVERTEXSPECULAR 
				FinalColor.rgb += indata.Interpolated[__NORMAL_INTER].rgb;
			#else
				float3 normEyeVec = indata.Interpolated[__EYEVEC_INTER].rgb;
				#if _USEPERPIXELNORMALIZE_ 
					normEyeVec = normalize(normEyeVec);
				#endif
				float3 normLightVec = indata.Interpolated[__LVEC_INTER].rgb;
			
				// float specular = getSpecularPixelLighting(lightmap, float4(normalize(indata.Interpolated[__NORMAL_INTER].rgb), StaticGloss), normLightVec, normEyeVec);
				float specular = getSpecularPixelLighting(lightmap, float4(0.f,0.f,1.f, StaticGloss), normLightVec, normEyeVec, gloss);
				FinalColor.rgb += specular * CEXP(StaticSpecularColor);
			#endif
		#endif // if _USESPECULAR_
	#endif // if PERPIXEL
#endif // if _POINTLIGHT_

	FinalColor.rgb = float3(0.0, 1.0, 0.0);

	return FinalColor;
};

technique defaultTechnique
{
	pass P0
	{
		vertexShader = compile vs_1_1 vsStaticMesh();
		pixelShader = compile MPSMODEL psStaticMesh();

// In wait of NV driver hack...
//#if NVIDIA && defined(PSVERSION) && PSVERSION <= 14
// TextureTransformFlags[0] = PROJECTED;
//#endif

#ifdef ENABLE_WIREFRAME
		FillMode = WireFrame;
#endif

#if _POINTLIGHT_
		AlphaBlendEnable= true;
		SrcBlend = ONE;
		DestBlend = ONE;
		fogenable = false;
#else
		fogenable = true;
#endif
		AlphaTestEnable = < AlphaTest >;
		AlphaRef = 127; // temporary hack by johan because "m_shaderSettings.m_alphaTestRef = 127" somehow doesn't work
	}
}
//#endif
