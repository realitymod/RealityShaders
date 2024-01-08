#include "shaders/RaCommon.fx"
#include "shaders/RaDefines.fx"
#include "shaders/RaShaderBMCommon.fx"

// Dependencies and sanity checks
// Tmp
#ifndef _HASUVANIMATION_
#define _HASUVANIMATION_ 0
#endif
#ifndef _HASNORMALMAP_
#define _HASNORMALMAP_ 0
#endif
#ifndef _HASGIMAP_
#define _HASGIMAP_ 0
#endif
#ifndef _HASENVMAP_
#define _HASENVMAP_ 0
#endif
#if _HASENVMAP_
	#define _FRESNELVALUES_ 1
#else
	#define _FRESNELVALUES_ 0
#endif
#ifndef _USEHEMIMAP_
#define _USEHEMIMAP_ 0
#endif
#ifndef _HASSHADOW_
#define _HASSHADOW_ 0
#endif
#ifndef _HASCOLORMAPGLOSS_
#define _HASCOLORMAPGLOSS_ 0
#endif
#ifndef _HASDOT3ALPHATEST_
#define _HASDOT3ALPHATEST_ 0
#endif

// Lighting stuff
// tl: turn this off for lower rapath settings
#if RAPATH >= 2
	#define _USEPERPIXELNORMALIZE_ 0
	#define _USERENORMALIZEDTEXTURES_ 0
#else
	#define _USEPERPIXELNORMALIZE_ 1
	#define _USERENORMALIZEDTEXTURES_ 1
#endif

#if _HASNORMALMAP_ || _HASCOLORMAPGLOSS_
	// Need to do perpixel light for bumped material
	// and it's reasonable to have it for per-pixel glossing as well
	#define _HASPERPIXELLIGHTING_ 1
#else
	#define _HASPERPIXELLIGHTING_ 0
#endif

#if _POINTLIGHT_
	// Disable these code portions for point lights
	#define _HASGIMAP_ 0
	#define _HASENVMAP_ 0
	#define _USEHEMIMAP_ 0
	#define _HASSHADOW_ 0
	// Do per-pixel, and do not per-vertex normalize
	#define _HASPERPIXELLIGHTING_ 1
	#define _USEPERPIXELNORMALIZE_ 1
	#define _USERENORMALIZEDTEXTURES_ 0
	// We'd still like fresnel, though
	#define _FRESNELVALUES_ 1
#endif

// tl: We now allocate color interpolators for vertex lighting to avoid redundant texture ops

// Setup interpolater mappings
#if _USEHEMIMAP_
	#define __HEMINTERPIDX 0
#endif
#if _HASSHADOW_
	#define __SHADOWINTERPIDX _USEHEMIMAP_
#endif
#if _FRESNELVALUES_
	#define __ENVMAPINTERPIDX _USEHEMIMAP_+_HASSHADOW_
#endif
#if _HASPERPIXELLIGHTING_
	#define __LVECINTERPIDX _USEHEMIMAP_+_HASSHADOW_+_FRESNELVALUES_
	#define __HVECINTERPIDX _USEHEMIMAP_+_HASSHADOW_+_FRESNELVALUES_+1
	#if !_HASNORMALMAP_
		#define __WNORMALINTERPIDX _USEHEMIMAP_+_HASSHADOW_+_FRESNELVALUES_+2
	#endif
#else
// #define __DIFFUSEINTERPIDX _USEHEMIMAP_+_HASSHADOW_+_FRESNELVALUES_
// #define __SPECULARINTERPIDX _USEHEMIMAP_+_HASSHADOW_+_FRESNELVALUES_+1
#endif

//#define MAX_INTERPS (_USEHEMIMAP_+_HASSHADOW_+_FRESNELVALUES_+2 + (_HASPERPIXELLIGHTING_&&!_HASNORMALMAP_))
#define MAX_INTERPS (_USEHEMIMAP_+_HASSHADOW_+_FRESNELVALUES_+ (2*_HASPERPIXELLIGHTING_) + (_HASPERPIXELLIGHTING_&&!_HASNORMALMAP_))

// Rod's magic numbers ;-)
#define refractionIndexRatio 0.15
#define R0 (pow(1.0 - refractionIndexRatio, 2.0) / pow(1.0 + refractionIndexRatio, 4.0))


struct BMVariableVSInput
{
   	float4 Pos : POSITION;    
	float3 Normal : NORMAL;
	float4 BlendIndices : BLENDINDICES;  
	float2 TexDiffuse : TEXCOORD0;
	float2 TexUVRotCenter : TEXCOORD1;
	float3 Tan : TANGENT;
};

struct BMVariableVSOutput
{
	float4 HPos : POSITION;
#if _POINTLIGHT_ || !_HASPERPIXELLIGHTING_
	float4 SpecularLightOrPointFog : COLOR1;
#endif
#if !_HASPERPIXELLIGHTING_
	float4 DiffuseLight : COLOR0;
#endif
	float2 TexDiffuse : TEXCOORD0;
#if MAX_INTERPS
	float4 Interpolated[MAX_INTERPS] : TEXCOORD1;
#endif
	float Fog : FOG;
};

float4x3 getSkinnedWorldMatrix(BMVariableVSInput input)
{
	int4 IndexVector = D3DCOLORtoUBYTE4(input.BlendIndices);
	int IndexArray[4] = (int[4])IndexVector;
	return GeomBones[IndexArray[0]];
}

float3x3 getSkinnedUVMatrix(BMVariableVSInput input)
{
	int4 IndexVector = D3DCOLORtoUBYTE4(input.BlendIndices);
	int IndexArray[4] = (int[4])IndexVector;
	return (float3x3)UserData.uvMatrix[IndexArray[3]];
}

float getBinormalFlipping(BMVariableVSInput input)
{
	int4 IndexVector = D3DCOLORtoUBYTE4(input.BlendIndices);
	int IndexArray[4] = (int[4])IndexVector;
	return 1.f + IndexArray[2] * -2.f;
}

float4 getWorldPos(BMVariableVSInput input)
{
	float4 unpackedPos = input.Pos * PosUnpack;
	return float4(mul(unpackedPos, getSkinnedWorldMatrix(input)), 1);
}


float3 getWorldNormal(BMVariableVSInput input)
{
	float3 unpackedNormal = input.Normal * NormalUnpack.x + NormalUnpack.y;
	return mul(unpackedNormal, getSkinnedWorldMatrix(input)); // tl: We don't scale/shear objects
}

float4 calcGroundUVAndLerp(BMVariableVSInput input)
{
	// HemiMapConstants: offset x/y heightmapsize z / hemilerpbias w

	float4 GroundUVAndLerp = 0;
	GroundUVAndLerp.xy = ((getWorldPos(input) + (HemiMapConstants.z/2) + getWorldNormal(input) * 1).xz - HemiMapConstants.xy) / HemiMapConstants.z;
	GroundUVAndLerp.y = 1 - GroundUVAndLerp.y;
	
	// localHeight scale, 1 for top and 0 for bottom
	float localHeight = (getWorldPos(input).y - GeomBones[0][3][1]) * InvHemiHeightScale;
	
	float offset = (localHeight * 2 - 1) + HeightOverTerrain;
	offset = clamp(offset, -2 * (1 - HeightOverTerrain), 0.8); // For TL: seems like taking this like away doesn't change much, take it out?
	GroundUVAndLerp.z = clamp((getWorldNormal(input).y + offset) * 0.5 + 0.5, 0, 0.9);

	return GroundUVAndLerp;
}

float4 calcUVRotation(BMVariableVSInput input)
{
	// TODO: (ROD) Gotta rotate the tangent space as well as the uv
	float2 uv = mul(float3(input.TexUVRotCenter * TexUnpack, 1.0), getSkinnedUVMatrix(input)).xy + input.TexDiffuse * TexUnpack;
	return float4(uv.x, uv.y, 0, 1);
}

float3x3 createWorld2TanMat(BMVariableVSInput input)
{
	// Cross product * flip to create BiNormal
	float flip = getBinormalFlipping(input);
	float3 unpackedNormal = input.Normal * NormalUnpack.x + NormalUnpack.y;
	float3 unpackedTan = input.Tan * NormalUnpack.x + NormalUnpack.y;
	float3 binormal = normalize(cross(unpackedTan, unpackedNormal)) * flip;

	// Need to calculate the WorldI based on each matBone skinning world matrix
	float3x3 TanBasis = float3x3(unpackedTan, binormal, unpackedNormal);

	// Calculate WorldTangent directly... inverse is the transpose for affine rotations
	float3x3 worldI = transpose(mul(TanBasis, getSkinnedWorldMatrix(input)));

	return worldI;
}

// NOTE: This returns un-normalized for point, because point needs to be attenuated.
float3 getLightVec(BMVariableVSInput input)
{
#if _POINTLIGHT_
	return (Lights[0].pos - getWorldPos(input).xyz);
#else
	float3 lvec = -Lights[0].dir;
	#if _HASCOCKPIT_
		// tl: Skin lighting vector to part to create static cockpit lighting
		lvec = mul(lvec, getSkinnedWorldMatrix(input));
	#endif
	return lvec;
#endif
}

BMVariableVSOutput vs(BMVariableVSInput input)
{
	BMVariableVSOutput Out = (BMVariableVSOutput)0.0;

	Out.HPos = mul(getWorldPos(input), ViewProjection);	// output HPOS

#if _HASUVANIMATION_
	Out.TexDiffuse = calcUVRotation(input);				// pass-through rotate coords
#else
	Out.TexDiffuse = input.TexDiffuse * TexUnpack; 		// pass-through texcoord
#endif

#if _USEHEMIMAP_
	Out.Interpolated[__HEMINTERPIDX] = calcGroundUVAndLerp(input);
#endif

#if _HASSHADOW_
	Out.Interpolated[__SHADOWINTERPIDX] = calcShadowProjection(getWorldPos(input));
#endif

	
	float3 worldEyeVec = normalize(WorldSpaceCamPos.xyz - getWorldPos(input).xyz);
	
#if _HASPERPIXELLIGHTING_ && _HASNORMALMAP_ // Do tangent space bumped pixel lighting
	float3x3 world2TanMat = createWorld2TanMat(input);
	float3 tanEyeVec = mul(worldEyeVec, world2TanMat);
	float3 tanLightVec = mul(getLightVec(input), world2TanMat);
	Out.Interpolated[__LVECINTERPIDX].xyz = tanLightVec;
	Out.Interpolated[__HVECINTERPIDX].xyz = normalize(tanLightVec) + normalize(tanEyeVec);	
	#if !_USEPERPIXELNORMALIZE_ // normalize HVec as well because pixel shader won't
		Out.Interpolated[__LVECINTERPIDX].xyz = normalize(tanLightVec);
		Out.Interpolated[__HVECINTERPIDX].xyz = normalize(Out.Interpolated[__HVECINTERPIDX].xyz);
	#endif 
#elif _HASPERPIXELLIGHTING_ // Do world space non-bumped pixel lighting
	// tl: Object space would be cheaper, but more cumbersome
	Out.Interpolated[__LVECINTERPIDX].xyz = getLightVec(input);
	Out.Interpolated[__HVECINTERPIDX].xyz = getLightVec(input) + normalize(WorldSpaceCamPos-getWorldPos(input));
	Out.Interpolated[__WNORMALINTERPIDX].xyz = getWorldNormal(input);
	#if !_USEPERPIXELNORMALIZE_ // normalize HVec as well because pixel shader won't
		Out.Interpolated[__HVECINTERPIDX].xyz = normalize(Out.Interpolated[__HVECINTERPIDX].xyz);
		Out.Interpolated[__WNORMALINTERPIDX].xyz = normalize(Out.Interpolated[__WNORMALINTERPIDX].xyz);
	#endif
#else // Do vertex lighting
	float ndotl = dot(getLightVec(input), getWorldNormal(input));
	// float ndoth = dot(normalize(getLightVec(input)+worldEyeVec), getWorldNormal(input));
	float vdotr = dot(reflect(-getLightVec(input), getWorldNormal(input)), worldEyeVec);
	float4 lighting = lit(ndotl, vdotr, SpecularPower);
	#if _POINTLIGHT_
		float attenuation = length(Lights[0].pos - getWorldPos(input)) * Lights[0].attenuation;
		lighting.yz *= attenuation;
	#endif
	Out.DiffuseLight.xyz = lighting.y * DiffuseColorAndAmbient;
#if !_USEHEMIMAP_
	Out.DiffuseLight.xyz += DiffuseColorAndAmbient.w;
#endif
	Out.DiffuseLight.w = lighting.y;
	Out.DiffuseLight *= 0.5;
	Out.SpecularLightOrPointFog = lighting.z * SpecularColor;
	#if _HASSTATICGLOSS_
		Out.SpecularLightOrPointFog = clamp(Out.SpecularLightOrPointFog, 0, StaticGloss);
	#endif
	Out.SpecularLightOrPointFog *= 0.5;	
#endif

#if _FRESNELVALUES_
	Out.Interpolated[__ENVMAPINTERPIDX].xyz = -reflect(worldEyeVec, getWorldNormal(input));
	Out.Interpolated[__ENVMAPINTERPIDX].w = pow((R0 + (1.0 - R0) * (1.0 - dot(worldEyeVec, getWorldNormal(input)))), 2);
#endif

#if _POINTLIGHT_
	Out.SpecularLightOrPointFog = calcFog(Out.HPos.w);
#else
	Out.Fog = calcFog(Out.HPos.w); 		// always fog
#endif
	
	return Out;
}

float4 ps(BMVariableVSOutput input) : COLOR
{
#if _FINDSHADER_
	return 1;
#endif
	float4 outColor = (float4)1;

	float4 texDiffuse = tex2D(DiffuseMapSampler, input.TexDiffuse);
#ifdef DIFFUSE_CHANNEL
	return texDiffuse;
#endif

#if _HASPERPIXELLIGHTING_
	float3 normal = 0;
	#if _HASNORMALMAP_
		float4 tanNormal = tex2D(NormalMapSampler, input.TexDiffuse);
		tanNormal.xyz = tanNormal.xyz * 2 - 1;
		#if _USERENORMALIZEDTEXTURES_
			tanNormal.xyz = normalize(tanNormal.xyz);
		#endif
		normal = tanNormal;
	#else
		normal = input.Interpolated[__WNORMALINTERPIDX];
		#if _USEPERPIXELNORMALIZE_
			normal = fastNormalize(normal, NRMCUBE);
		#endif
	#endif

	#ifdef NORMAL_CHANNEL
		return float4(normal*0.5+0.5, 1);
	#endif

	float3 lightVec = input.Interpolated[__LVECINTERPIDX];
	#if _POINTLIGHT_
		float attenuation = 1 - saturate(dot(lightVec,lightVec) * Lights[0].attenuation);
	#endif
	// tl: don't normalize if lvec is world space sun direction
	#if _USEPERPIXELNORMALIZE_ && (_HASNORMALMAP_ || _POINTLIGHT_)
		lightVec = fastNormalize(lightVec);
	#endif
	
	float4 dot3Light = saturate(dot(lightVec, normal));

	float3 halfVec = input.Interpolated[__HVECINTERPIDX];
	#if _USEPERPIXELNORMALIZE_
		halfVec = fastNormalize(halfVec, (NVIDIA || RAPATH < 1) ? NRMMATH : NRMCUBE);
	#endif

	float3 specular = tex2D(SpecLUT64Sampler, dot(halfVec, normal));

	#if _HASCOLORMAPGLOSS_
		float gloss = texDiffuse.a;
	#elif !_HASSTATICGLOSS_ && _HASNORMALMAP_
		float gloss = tanNormal.a;		
	#else
		float gloss = StaticGloss;
	#endif

	#if !_POINTLIGHT_
		dot3Light *= DiffuseColorAndAmbient;
	#endif

	specular *= gloss;

	#ifdef SHADOW_CHANNEL
		return float4(dot3Light+specular, 1);
	#endif

#else
	float3 dot3Light = input.DiffuseLight.rgb * 2;
	float3 specular = input.SpecularLightOrPointFog.rgb * 2;

	#if _HASCOLORMAPGLOSS_
		float3 gloss = texDiffuse.a;
	#else
		float3 gloss = StaticGloss;
	#endif
	specular *= gloss;
#endif // perpixlight

#if _HASSHADOW_
	float dirShadow = getShadowFactor(ShadowMapSampler, input.Interpolated[__SHADOWINTERPIDX]);

	// killing both spec and dot3 if we are in shadows
	dot3Light *= dirShadow;
	specular *= dirShadow;
#endif

#if _USEHEMIMAP_
	float4 groundcolor = tex2D(HemiMapSampler, input.Interpolated[__HEMINTERPIDX].xy);
 	float3 hemicolor = lerp(groundcolor, HemiMapSkyColor, input.Interpolated[__HEMINTERPIDX].z);
#elif _HASPERPIXELLIGHTING_
	float hemicolor = DiffuseColorAndAmbient.w;
#else
	// tl: by setting this to 0, hlsl will remove it from the compiled code (in an addition).
	// for non-hemi'ed materials, a static ambient will be added to sun color in vertex shader
	const float3 hemicolor = 0.0;
#endif

#if _HASGIMAP_
	float4 GI = tex2D(GIMapSampler, input.TexDiffuse);
#else
	const float4 GI = 1;
#endif

#if _POINTLIGHT_
	outColor.rgb = dot3Light;
#else
	outColor.rgb = hemicolor + dot3Light;
#endif

	float4 diffuseCol = texDiffuse;
	
#if _FRESNELVALUES_
	// tl: Will hlsl auto-distribute these into pre/vs/ps, or leave them as they are?
	float fres = input.Interpolated[__ENVMAPINTERPIDX].w;

	#if _HASENVMAP_
		// NOTE: eyePos.w is just a reflection scaling value. Why do we have this besides the reflectivity (gloss map)data?
		float3 envmapColor = texCUBE(CubeMapSampler, input.Interpolated[__ENVMAPINTERPIDX].xyz);
		diffuseCol.rgb = lerp(diffuseCol, envmapColor, gloss / 4);
	#endif

	diffuseCol.a = lerp(diffuseCol.a, 1, fres);
#endif

	outColor.rgb *= diffuseCol * GI;
	outColor.rgb += specular * GI;

#if _HASDOT3ALPHATEST_
	outColor.a = dot(texDiffuse.rgb, 1);
#else
	#if _HASCOLORMAPGLOSS_
		outColor.a = 1.f;
	#else
		outColor.a = diffuseCol.a;
	#endif
#endif

#if _POINTLIGHT_
	outColor.rgb *= attenuation * input.SpecularLightOrPointFog;
	outColor.a *= attenuation;
#endif

	outColor.rgb = float3(0.0, 1.0, 0.0);

	outColor.a *= Transparency.a;
	return outColor;
}


technique Variable
{
	pass p0
	{
		VertexShader = compile VSMODEL vs();
		PixelShader = compile PSMODEL ps();

//#if NVIDIA && defined(PSVERSION) && PSVERSION <= 14
// TextureTransformFlags[0] = PROJECTED;
//#endif

#ifdef ENABLE_WIREFRAME
		FillMode = WireFrame;
#endif

		AlphaTestEnable = (AlphaTest);
		AlphaRef = (AlphaTestRef);
#if _POINTLIGHT_
		AlphaBlendEnable = true;
		SrcBlend = SRCALPHA;
		DestBlend = ONE;
		Fogenable = false;		
#else
		AlphaBlendEnable = (AlphaBlendEnable);
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;
		ZWriteEnable = (DepthWrite);
		Fogenable = true;
#endif
		
	}
}
