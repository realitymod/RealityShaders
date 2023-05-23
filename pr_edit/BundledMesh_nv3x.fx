// NEW SHADOW STUFF--------------------------------------
struct VO_HemiAndSunShadows
{
	float4 HPos : POSITION;
	float2 TexCoord0 : TEXCOORD0;
	float3 LightVec : TEXCOORD1;
	float3 HalfVec : TEXCOORD2;
	float3 GroundUVAndLerp : TEXCOORD3;
	float4 EnvMap : TEXCOORD4;
	float4 TexShadow1 : TEXCOORD5;
	float Fog : FOG;
};
float3 CalcReflectionVector(float3 ViewToPos, float3 Normal)
{
    return normalize(reflect(ViewToPos, Normal));
}

float refractionIndexRatio = 0.15;
static float R0 = pow(1.0 - refractionIndexRatio, 2.0) / pow(1.0 + refractionIndexRatio, 2.0);

VO_HemiAndSunShadows BasicShader (appdataAnimatedUV input)
{
	VO_HemiAndSunShadows Out = (VO_HemiAndSunShadows)0;

	// Compensate for lack of UBYTE4 on Geforce3
	int4 IndexVector = D3DCOLORtoUBYTE4(input.BlendIndices);
	int IndexArray[4] = (int[4])IndexVector;

	Out.TexCoord0 = input.TexCoord0;

	float3 Pos = mul(input.Pos, mOneBoneSkinning[IndexArray[0]]);
	Out.HPos = mul(float4(Pos.xyz, 1.0f), viewProjMatrix);

	// Shadow
	// Out.TexShadow =  mul(Pos, ViewPortMatrix);
	Out.TexShadow1 =  mul(float4(Pos, 1), vpLightTrapezMat);
	float2 TexShadow2 = mul(float4(Pos, 1), vpLightMat).zw;
	TexShadow2.x -= 0.003;
	Out.TexShadow1.z = (TexShadow2.x*Out.TexShadow1.w)/TexShadow2.y; 	// (zL*wT)/wL == zL/wL post homo

	// Hemi lookup values
	float3 AlmostNormal = mul(input.Normal, mOneBoneSkinning[IndexArray[0]]);
	Out.GroundUVAndLerp.xy = ((Pos + (hemiMapInfo.z/2) + AlmostNormal * 1).xz - hemiMapInfo.xy) / hemiMapInfo.z;
	Out.GroundUVAndLerp.y = 1 - Out.GroundUVAndLerp.y;
	Out.GroundUVAndLerp.z = (AlmostNormal.y+1)/2;
	Out.GroundUVAndLerp.z -= hemiMapInfo.w;

	// Cross product * flip to create BiNormal
	float flip = 1;
	float3 binormal = normalize(cross(input.Tan, input.Normal)) * flip;

	// Need to calculate the WorldI based on each matBone skinning world matrix
	float3x3 TanBasis = float3x3(input.Tan, binormal, input.Normal);

	// Calculate WorldTangent directly... inverse is the transpose for affine rotations
	float3x3 worldI = transpose(mul(TanBasis, mOneBoneSkinning[IndexArray[0]]));

	// Transform Light dir to Object space
	float3 normalizedTanLightVec = normalize(mul(-lightDir, worldI));
	Out.LightVec = normalizedTanLightVec;

	// Transform eye pos to tangent space 
	float3 worldEyeVec = normalize(Pos - eyePos.xyz);
	float3 tanEyeVec = mul(-worldEyeVec, worldI);

	Out.HalfVec = normalize(normalizedTanLightVec + normalize(tanEyeVec));
	Out.Fog = calcFog(Out.HPos.w);

	// Environment map
	float3 ReflectionVector = CalcReflectionVector(worldEyeVec, AlmostNormal);
	Out.EnvMap.xyz = ReflectionVector;
	Out.EnvMap.w = pow((R0 + (1.0 - R0) * (1.0 - dot(-worldEyeVec, AlmostNormal))), 2);

	return Out;
}

VO_HemiAndSunShadows vs_HemiAndSunShadows(appdataAnimatedUV input)
{
	VO_HemiAndSunShadows Out = BasicShader (input);
	return Out;
}

VO_HemiAndSunShadows vs_HemiAndSunShadowsAnimatedUV(appdataAnimatedUV input)
{
	VO_HemiAndSunShadows Out = BasicShader (input);

	// NOTE: In theory this gets evaluated once (compiler magic)
	int4 IndexVector = D3DCOLORtoUBYTE4(input.BlendIndices);
	int IndexArray[4] = (int[4])IndexVector;
	
	float3x3 tmp = uvMatrix[IndexArray[3]];
	Out.TexCoord0 = mul(float3(input.TexCoord1, 1.0), tmp).xy + input.TexCoord0;
	// TODO: (ROD) Gotta rotate the tangent space as well as the uv

	return Out;
}

//#define DOT3_LIGHT
//#define SPEC_LIGHT
//#define HEMI_LIGHT
//#define DIFFUSE_MAP
//#define GLOSS _MAP
//#define GI_MAP
//#define NORMAL_MAP
//#define DISABLE_HEMI
//#define DISABLE_POINT

float4 ps_HemiAndSunShadows(VO_HemiAndSunShadows indata) : COLOR
{
	float4 outColor = (float4)1;

	float4 TN = tex2D(sampler0, indata.TexCoord0);
	TN.rgb = normalize(TN.rgb * 2 - 1);

	float4 dot3Light = saturate(dot(normalize(indata.LightVec), TN));

	float3 specular = pow(dot(normalize(indata.HalfVec), TN), 64) * TN.a;


	// dynamic shadows
	{
		float dirShadow = 1;

		float4 texel = float4(0.5 / 1024.0, 0.5 / 1024.0, 0, 0);
		float4 samples;
		samples.x = tex2Dproj(ShadowMapSampler, indata.TexShadow1);
		samples.y = tex2Dproj(ShadowMapSampler, indata.TexShadow1 + float4(texel.x, 0, 0, 0));
		samples.z = tex2Dproj(ShadowMapSampler, indata.TexShadow1 + float4(0, texel.y, 0, 0));
		samples.w = tex2Dproj(ShadowMapSampler, indata.TexShadow1 + texel);
		
		float4 cmpbits = samples >= saturate(indata.TexShadow1.z/indata.TexShadow1.w);
		dirShadow = dot(cmpbits, float4(0.25, 0.25, 0.25, 0.25));

		// killing both spec and dot3 if we are in shadows
		dot3Light *= dirShadow;
		specular *= dirShadow;
	}
	
	float4 TD = tex2D(sampler3, indata.TexCoord0);

	float4 groundcolor = tex2D(sampler1, indata.GroundUVAndLerp.xy);
	float4 hemicolor = lerp(groundcolor, skyColor, indata.GroundUVAndLerp.z) * ambientColor;

	float4 GI = tex2D(sampler2, indata.TexCoord0);

	outColor.rgb = (hemicolor + (dot3Light * sunColor))  * TD * GI;
	outColor.rgb += specular * sunColor;
	outColor.a = TD.a;
	
	// Environment map
	// NOTE: eyePos.w is just a reflection scaling value. Why do we have this besides the reflectivity (gloss map)data?
	float3 envmapColor = texCUBE(samplerCube4, indata.EnvMap.xyz) * TN.a * eyePos.w;
	outColor.rgb += envmapColor * 2;
	outColor.a += indata.EnvMap.w * TD.a;

#ifdef NORMAL_MAP
	outColor.rgb = TN.rgb;
#endif
#ifdef GI_MAP
	outColor.rgb = GI;
#endif
#ifdef HEMI_LIGHT
	outColor.rgb = hemicolor * ambientColor;
#endif
#ifdef DOT3_LIGHT
	outColor = dot3Light;
#endif
#ifdef SPEC_LIGHT
	outColor = float4(specular, 1);
#endif
#ifdef DIFFUSE_MAP
	outColor = TD;
#endif
#ifdef GLOSS_MAP
	outColor = TN.a;
#endif
#ifdef DISABLE_HEMI
	outColor = 0;
#endif

	return outColor;
};

technique HemiAndSun
{
	pass P0
	{
		srcBlend = srcAlpha;
		destBlend = invSrcAlpha;
		
		fogenable = true;

 		VertexShader = compile vs_1_1 vs_HemiAndSunShadows();
		PixelShader = compile PS2_EXT ps_HemiAndSunShadows();
	}
	pass P1
	{
		srcBlend = srcAlpha;
		destBlend = invSrcAlpha;
		
		fogenable = true;

 		VertexShader = compile vs_1_1 vs_HemiAndSunShadowsAnimatedUV();
		PixelShader = compile PS2_EXT ps_HemiAndSunShadows();
	}
}

// Point Lights
struct VO_PointLight
{
	float4 HPos : POSITION;
	float2 TexCoord0 : TEXCOORD0;
	float3 LightVec : TEXCOORD1;
	float3 HalfVec : TEXCOORD2;
	float4 EyeVecAndReflection: TEXCOORD7;
	float4 TexShadow : TEXCOORD4;
	float Fog : FOG;
};

VO_PointLight BasicShaderPoint (appdataAnimatedUV input)
{
	VO_PointLight Out = (VO_PointLight)0;

	// Compensate for lack of UBYTE4 on Geforce3
	int4 IndexVector = D3DCOLORtoUBYTE4(input.BlendIndices);
	int IndexArray[4] = (int[4])IndexVector;

	Out.TexCoord0 = input.TexCoord0;

	float3 Pos = mul(input.Pos, mOneBoneSkinning[IndexArray[0]]);
	Out.HPos = mul(float4(Pos.xyz, 1.0f), viewProjMatrix);

	// Cross product * flip to create BiNormal
	float flip = 1;
	float3 binormal = normalize(cross(input.Tan, input.Normal)) * flip;

	// Need to calculate the WorldI based on each matBone skinning world matrix
	float3x3 TanBasis = float3x3(input.Tan, binormal, input.Normal);

	// Calculate WorldTangent directly... inverse is the transpose for affine rotations
	float3x3 worldI = transpose(mul(TanBasis, mOneBoneSkinning[IndexArray[0]]));

	// Transform Light dir to Object space
	float attenuation = 1 - saturate(dot(lightPos - Pos, lightPos - Pos) * attenuationSqrInv);
	float3 normalizedTanLightVec = normalize(mul(lightPos - Pos, worldI)) * attenuation ;

	Out.LightVec = normalizedTanLightVec;

	// Transform eye pos to tangent space 
	float3 worldEyeVec = normalize(Pos - eyePos.xyz);
	float3 tanEyeVec = mul(-worldEyeVec, worldI);

	Out.HalfVec = normalize(normalizedTanLightVec + normalize(tanEyeVec));

	Out.Fog = calcFog(Out.HPos.w);

	return Out;
}

VO_PointLight vs_pointLight(appdataAnimatedUV input)
{
	VO_PointLight Out = BasicShaderPoint (input);
	return Out;
}

VO_PointLight vs_pointLightAnimated(appdataAnimatedUV input)
{
	VO_PointLight Out = BasicShaderPoint (input);

	// NOTE: In theory this gets evaluated once (compiler magic)
	int4 IndexVector = D3DCOLORtoUBYTE4(input.BlendIndices);
	int IndexArray[4] = (int[4])IndexVector;

	float3x3 tmp = uvMatrix[IndexArray[3]];
	Out.TexCoord0 = mul(float3(input.TexCoord1, 1.0), tmp).xy + input.TexCoord0;

	// TODO: (ROD) Gotta rotate the tangent space as well as the uv

	return Out;
}

float4 ps_pointLight(VO_PointLight inData) : COLOR
{
	float4 outColor = (float4)0;

	float4 TN = tex2D(sampler0, inData.TexCoord0);
	TN.rgb = TN.rgb * 2 - 1;

	float4 dot3Light = saturate(dot(inData.LightVec, TN));

	float3 specular = pow(dot(normalize(inData.HalfVec), TN), 128) * TN.a;
	
	float4 TD = tex2D(sampler3, inData.TexCoord0);

	outColor.rgb = dot3Light * TD * lightColor;

	outColor.rgb += specular * lightColor;

	outColor.a = TD.a;

#ifdef NORMAL_MAP
	outColor.rgb = TN.rgb;
#endif
#ifdef DOT3_LIGHT
	outColor = dot3Light;
#endif
#ifdef SPEC_LIGHT
	outColor = float4(specular, 1);
#endif
#ifdef DIFFUSE_MAP
	outColor = TD;
#endif
#ifdef GLOSS_MAP
	outColor = TN.a;
#endif
#ifdef DISABLE_POINT
	outColor = 0;
#endif

// return float4(inData.LightVec, 1);	
	return outColor;
}

technique PointLight
{
	pass P0
	{
		alphablendenable = true;
		srcBlend = one;
		destBlend = one;

		fogenable = false;

 		VertexShader = compile vs_1_1 vs_pointLight();
		PixelShader = compile ps_2_0 ps_pointLight();
	}
	
	pass P1
	{
		alphablendenable = true;
		srcBlend = one;
		destBlend = one;

		fogenable = false;

 		VertexShader = compile vs_1_1 vs_pointLightAnimated();
		PixelShader = compile ps_2_0 ps_pointLight();
	}
}
//--------------------------------------------------------
