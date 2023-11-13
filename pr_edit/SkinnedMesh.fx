// Description: 1,2 bone skinning 
// Author: Mats Dal


// Note: obj space light vectors
float4 sunLightDir : SunLightDirection;
float4 lightDir : LightDirection;
// float hemiMapInfo.z : hemiMapInfo.z;
float normalOffsetScale : NormalOffsetScale;
// float hemiMapInfo.w : hemiMapInfo.w;

// offset x/y hemiMapInfo.z z / hemiMapInfo.w w
float4 hemiMapInfo : HemiMapInfo;

float4 skyColor : SkyColor;
float4 ambientColor : AmbientColor;
float4 sunColor : SunColor;

float4 lightPos : LightPosition;
float attenuationSqrInv : AttenuationSqrInv;
float4 lightColor : LightColor;

float shadowAlphaThreshold : SHADOWALPHATHRESHOLD;

float coneAngle : ConeAngle;

float4 worldEyePos : WorldEyePos;

float4 objectEyePos : ObjectEyePos;

float4x4 mLightVP : LIGHTVIEWPROJ;
	float4x4 mLightVP2 : LIGHTVIEWPROJ2;
	float4x4 mLightVP3 : LIGHTVIEWPROJ3;
float4 vViewportMap : VIEWPORTMAP;

dword dwStencilRef : STENCILREF = 0;

float4x4 mWorld : World;
float4x4 mWorldT : WorldT;
float4x4 mWorldView : WorldView;
float4x4 mWorldViewI : WorldViewI; // (WorldViewIT)T = WorldViewI
float4x4 mWorldViewProj : WorldViewProjection;
float4x3 mBoneArray[26] : BoneArray;// : register(c15) < bool sparseArray = true; int arrayStart = 15; >;

float4x4 vpLightMat : vpLightMat;
float4x4 vpLightTrapezMat : vpLightTrapezMat;

float4 paraboloidValues : ParaboloidValues;
float4 paraboloidZValues : ParaboloidZValues;

texture texture0: TEXLAYER0;
texture texture1: TEXLAYER1;
texture texture2: TEXLAYER2;
texture texture3: TEXLAYER3;
texture texture4: TEXLAYER4;


sampler sampler0 = sampler_state { Texture = (texture0); MipFilter = LINEAR; MinFilter = LINEAR; MagFilter = LINEAR; };
sampler sampler1 = sampler_state { Texture = (texture1); MipFilter = LINEAR; MinFilter = LINEAR; MagFilter = LINEAR; };
sampler sampler2 = sampler_state { Texture = (texture2); MinFilter = LINEAR; MagFilter = LINEAR; };
sampler sampler3 = sampler_state { Texture = (texture3); MipFilter = LINEAR; MinFilter = LINEAR; MagFilter = LINEAR; };
sampler sampler4 = sampler_state { Texture = (texture4); MipFilter = LINEAR; MinFilter = LINEAR; MagFilter = LINEAR; };

sampler sampler2point = sampler_state { Texture = (texture2); MinFilter = POINT; MagFilter = POINT; };
sampler sampler3point = sampler_state { Texture = (texture3); MinFilter = POINT; MagFilter = POINT; };
sampler sampler4point = sampler_state { Texture = (texture4); MinFilter = POINT; MagFilter = POINT; };

struct APP2VS
{
	float4 Pos : POSITION;    
	float3 Normal : NORMAL;
	float BlendWeights : BLENDWEIGHT;
	float4 BlendIndices : BLENDINDICES;    
	float2 TexCoord0 : TEXCOORD0;
};

// object based lighting

void skinSoldierForPP(uniform int NumBones, in APP2VS indata, in float3 lightVec, out float3 Pos, out float3 Normal, out float3 SkinnedLVec)
{
	float LastWeight = 0.0;
	Pos = 0.0;
	Normal = 0.0;    
	SkinnedLVec = 0.0;
	
	// Compensate for lack of UBYTE4 on Geforce3
	int4 IndexVector = D3DCOLORtoUBYTE4(indata.BlendIndices);
	
	// Cast the vectors to arrays for use in the for loop below
	float BlendWeightsArray[1] = (float[1])indata.BlendWeights;
	int IndexArray[4] = (int[4])IndexVector;    
	
	// Calculate the pos/normal using the "normal" weights 
	// and accumulate the weights to calculate the last weight
	for (int iBone = 0; iBone < NumBones-1; iBone++)
	{
		LastWeight += BlendWeightsArray[iBone];
		
		Pos += mul(indata.Pos, mBoneArray[IndexArray[iBone]]) * BlendWeightsArray[iBone];
		Normal += mul(indata.Normal, mBoneArray[IndexArray[iBone]]) * BlendWeightsArray[iBone];
		float3x3 mat = transpose((float3x3)mBoneArray[IndexArray[iBone]]);
		SkinnedLVec += mul(lightVec, mat) * BlendWeightsArray[iBone];
	}
	LastWeight = 1.0 - LastWeight; 
	
	// Now that we have the calculated weight, add in the final influence
	Pos += mul(indata.Pos, mBoneArray[IndexArray[NumBones-1]]) * LastWeight;
	Normal += mul(indata.Normal, mBoneArray[IndexArray[NumBones-1]]) * LastWeight;
	float3x3 mat = transpose((float3x3)mBoneArray[IndexArray[NumBones-1]]);
	SkinnedLVec += mul(lightVec, mat) * LastWeight;
	
	// Normalize normals
	Normal = normalize(Normal);
	// SkinnedLVec = normalize(SkinnedLVec); // Don't normalize
}

void skinSoldierForPointPP(uniform int NumBones, in APP2VS indata, in float3 lightVec, out float3 Pos, out float3 Normal, out float3 SkinnedLVec)
{
	float LastWeight = 0.0;
	Pos = 0.0;
	Normal = 0.0;    
	SkinnedLVec = 0.0;
	
	// Compensate for lack of UBYTE4 on Geforce3
	int4 IndexVector = D3DCOLORtoUBYTE4(indata.BlendIndices);
	
	// Cast the vectors to arrays for use in the for loop below
	float BlendWeightsArray[1] = (float[1])indata.BlendWeights;
	int IndexArray[4] = (int[4])IndexVector;    
	
	// Calculate the pos/normal using the "normal" weights 
	// and accumulate the weights to calculate the last weight
	for (int iBone = 0; iBone < NumBones-1; iBone++)
	{
		LastWeight += BlendWeightsArray[iBone];
		
		float3 sPos = mul(indata.Pos, mBoneArray[IndexArray[iBone]]);
		Pos += sPos * BlendWeightsArray[iBone];
		Normal += mul(indata.Normal, mBoneArray[IndexArray[iBone]]) * BlendWeightsArray[iBone];
		float3x3 mat = transpose((float3x3)mBoneArray[IndexArray[iBone]]);
		float3 localLVec = lightVec - sPos;
		SkinnedLVec += mul(localLVec, mat) * BlendWeightsArray[iBone];
	}
	LastWeight = 1.0 - LastWeight; 
	
	// Now that we have the calculated weight, add in the final influence
	float3 sPos = mul(indata.Pos, mBoneArray[IndexArray[NumBones-1]]);
	Pos += sPos * LastWeight;
	Normal += mul(indata.Normal, mBoneArray[IndexArray[NumBones-1]]) * LastWeight;
	float3x3 mat = transpose((float3x3)mBoneArray[IndexArray[NumBones-1]]);
	float3 localLVec = lightVec - sPos;
	SkinnedLVec += mul(localLVec, mat) * LastWeight;
	
	// Normalize normals
	Normal = normalize(Normal);
	// SkinnedLVec = normalize(SkinnedLVec); // Don't normalize
}

void skinSoldierForSpotPP(uniform int NumBones, in APP2VS indata, in float3 lightVec, in float3 lightDir, out float3 Pos, out float3 Normal, out float3 SkinnedLVec, out float3 SkinnedLDir)
{
	float LastWeight = 0.0;
	Pos = 0.0;
	Normal = 0.0;    
	SkinnedLVec = 0.0;
	SkinnedLDir = 0.0;
	
	// Compensate for lack of UBYTE4 on Geforce3
	int4 IndexVector = D3DCOLORtoUBYTE4(indata.BlendIndices);
	
	// Cast the vectors to arrays for use in the for loop below
	float BlendWeightsArray[1] = (float[1])indata.BlendWeights;
	int IndexArray[4] = (int[4])IndexVector;    
	
	// Calculate the pos/normal using the "normal" weights 
	// and accumulate the weights to calculate the last weight
	for (int iBone = 0; iBone < NumBones-1; iBone++)
	{
		LastWeight += BlendWeightsArray[iBone];
		
		float3 sPos = mul(indata.Pos, mBoneArray[IndexArray[iBone]]);
		Pos += sPos * BlendWeightsArray[iBone];
		Normal += mul(indata.Normal, mBoneArray[IndexArray[iBone]]) * BlendWeightsArray[iBone];
		float3x3 mat = transpose((float3x3)mBoneArray[IndexArray[iBone]]);
		float3 localLVec = lightVec - sPos;
		SkinnedLVec += mul(localLVec, mat) * BlendWeightsArray[iBone];
		SkinnedLDir += mul(lightDir, mat) * BlendWeightsArray[iBone];
	}
	LastWeight = 1.0f - LastWeight; 
	
	// Now that we have the calculated weight, add in the final influence
	float3 sPos = mul(indata.Pos, mBoneArray[IndexArray[NumBones-1]]);
	Pos += sPos * LastWeight;
	Normal += mul(indata.Normal, mBoneArray[IndexArray[NumBones-1]]) * LastWeight;
	float3x3 mat = transpose((float3x3)mBoneArray[IndexArray[NumBones-1]]);
	float3 localLVec = lightVec - sPos;
	SkinnedLVec += mul(localLVec, mat) * LastWeight;
	SkinnedLDir += mul(lightDir, mat) * LastWeight;
	
	// Normalize normals
	Normal = normalize(Normal);
	SkinnedLVec = SkinnedLVec;// normalize(SkinnedLVec);
	SkinnedLDir = normalize(SkinnedLDir);
}


// tangent based lighting

struct APP2VStangent
{
	float4 Pos : POSITION;    
	float3 Normal : NORMAL;
	float BlendWeights : BLENDWEIGHT;
	float4 BlendIndices : BLENDINDICES;    
	float2 TexCoord0 : TEXCOORD0;
    float3 Tan : TANGENT;
};

void skinSoldierForPPtangent(uniform int NumBones, in APP2VStangent indata, in float3 lightVec, out float3 Pos, out float3 Normal, out float3 SkinnedLVec, out float4 wPos, out float3 HalfVec)
{
	float LastWeight = 0.0;
	Pos = 0.0;
	Normal = 0.0;    
	SkinnedLVec = 0.0;
	
	// Compensate for lack of UBYTE4 on Geforce3
	int4 IndexVector = D3DCOLORtoUBYTE4(indata.BlendIndices);
	
	// Cast the vectors to arrays for use in the for loop below
	float BlendWeightsArray[1] = (float[1])indata.BlendWeights;
	int IndexArray[4] = (int[4])IndexVector;    
	
	float3 binormal = normalize(cross(indata.Tan, indata.Normal));
	float3x3 TanBasis = float3x3(indata.Tan, 
					binormal, 
					indata.Normal);
	float3x3 worldI;	
	float3x3 mat;	

	// Calculate the pos/normal using the "normal" weights 
	// and accumulate the weights to calculate the last weight
	for (int iBone = 0; iBone < NumBones-1; iBone++)
	{
		LastWeight += BlendWeightsArray[iBone];
		
		Pos += mul(indata.Pos, mBoneArray[IndexArray[iBone]]) * BlendWeightsArray[iBone];
		
		// Calculate WorldTangent directly... inverse is the transpose for affine rotations
		worldI = mul(TanBasis, mBoneArray[IndexArray[iBone]]);
		Normal += worldI[2] * BlendWeightsArray[iBone]; 
		
		mat = transpose(worldI);
		SkinnedLVec += mul(lightVec, mat) * BlendWeightsArray[iBone];
		
	}
	LastWeight = 1.0 - LastWeight; 
	
	// Now that we have the calculated weight, add in the final influence
	Pos += mul(indata.Pos, mBoneArray[IndexArray[NumBones-1]]) * LastWeight;
	
	// Calculate WorldTangent directly... inverse is the transpose for affine rotations
	worldI = mul(TanBasis, mBoneArray[IndexArray[NumBones-1]]);
	Normal += worldI[2]  * LastWeight; 
	
	mat = transpose(worldI);
	SkinnedLVec += mul(lightVec, mat) * LastWeight;

	// Calculate HalfVector
	wPos = mul(float4(Pos.xyz, 1.0), mWorld); 
	float3 tanEyeVec = mul(worldEyePos - wPos, mat);
	HalfVec = normalize(normalize(tanEyeVec) + SkinnedLVec);
	
	// Normalize normals
	Normal = normalize(Normal);
	// SkinnedLVec = normalize(SkinnedLVec); // Don't normalize
}

void skinSoldierForPointPPtangent(uniform int NumBones, in APP2VStangent indata, in float3 lightVec, out float3 Pos, out float3 Normal, out float3 SkinnedLVec, out float3 HalfVec)
{
	float LastWeight = 0.0;
	Pos = 0.0;
	Normal = 0.0;    
	SkinnedLVec = 0.0;
	
	// Compensate for lack of UBYTE4 on Geforce3
	int4 IndexVector = D3DCOLORtoUBYTE4(indata.BlendIndices);
	
	// Cast the vectors to arrays for use in the for loop below
	float BlendWeightsArray[1] = (float[1])indata.BlendWeights;
	int IndexArray[4] = (int[4])IndexVector;    
	
	float3 binormal = normalize(cross(indata.Tan, indata.Normal));
	float3x3 TanBasis = float3x3(indata.Tan, 
					binormal, 
					indata.Normal);
	float3x3 worldI;	
	float3x3 mat;	

	// Calculate the pos/normal using the "normal" weights 
	// and accumulate the weights to calculate the last weight
	for (int iBone = 0; iBone < NumBones-1; iBone++)
	{
		LastWeight += BlendWeightsArray[iBone];
		
		float3 sPos = mul(indata.Pos, mBoneArray[IndexArray[iBone]]);
		Pos += sPos * BlendWeightsArray[iBone];
		
		// Calculate WorldTangent directly... inverse is the transpose for affine rotations
		worldI = mul(TanBasis, mBoneArray[IndexArray[iBone]]);
		Normal += worldI[2] * BlendWeightsArray[iBone]; 
		mat = transpose(worldI);
		
		float3 localLVec = lightVec - sPos;
		SkinnedLVec += mul(localLVec, mat) * BlendWeightsArray[iBone];
	}
	LastWeight = 1.0 - LastWeight; 
	
	// Now that we have the calculated weight, add in the final influence
	float3 sPos = mul(indata.Pos, mBoneArray[IndexArray[NumBones-1]]);
	Pos += sPos * LastWeight;

	worldI = mul(TanBasis, mBoneArray[IndexArray[NumBones-1]]);
	Normal += worldI[2]  * LastWeight; 
	mat = transpose(worldI);
	float3 localLVec = lightVec - sPos;
	SkinnedLVec += mul(localLVec, mat) * LastWeight;

	// Calculate HalfVector
	float4 wPos = mul(float4(Pos.xyz, 1.0), mWorld); 
	float3 tanEyeVec = mul(worldEyePos - wPos, mat);
	HalfVec = normalize(normalize(tanEyeVec) + SkinnedLVec);
	
	// Normalize normals
	Normal = normalize(Normal);
	// SkinnedLVec = normalize(SkinnedLVec); // Don't normalize
}

void skinSoldierForSpotPPtangent(uniform int NumBones, in APP2VStangent indata, in float3 lightVec, in float3 lightDir, out float3 Pos, out float3 Normal, out float3 SkinnedLVec, out float3 SkinnedLDir, out float3 HalfVec)
{
	float LastWeight = 0.0;
	Pos = 0.0;
	Normal = 0.0;    
	SkinnedLVec = 0.0;
	SkinnedLDir = 0.0;
	
	// Compensate for lack of UBYTE4 on Geforce3
	int4 IndexVector = D3DCOLORtoUBYTE4(indata.BlendIndices);
	
	// Cast the vectors to arrays for use in the for loop below
	float BlendWeightsArray[1] = (float[1])indata.BlendWeights;
	int IndexArray[4] = (int[4])IndexVector;    
	
	float3 binormal = normalize(cross(indata.Tan, indata.Normal));
	float3x3 TanBasis = float3x3(indata.Tan, 
					binormal, 
					indata.Normal);
	float3x3 worldI;	
	float3x3 mat;	

	// Calculate the pos/normal using the "normal" weights 
	// and accumulate the weights to calculate the last weight
	for (int iBone = 0; iBone < NumBones-1; iBone++)
	{
		LastWeight += BlendWeightsArray[iBone];
		
		float3 sPos = mul(indata.Pos, mBoneArray[IndexArray[iBone]]);
		Pos += sPos * BlendWeightsArray[iBone];
		// Calculate WorldTangent directly... inverse is the transpose for affine rotations
		worldI = mul(TanBasis, mBoneArray[IndexArray[iBone]]);
		Normal += worldI[2] * BlendWeightsArray[iBone]; 
		mat = transpose(worldI);
		
		float3 localLVec = lightVec - sPos;
		SkinnedLVec += mul(localLVec, mat) * BlendWeightsArray[iBone];
		SkinnedLDir += mul(lightDir, mat) * BlendWeightsArray[iBone];
	}
	LastWeight = 1.0 - LastWeight; 
	
	// Now that we have the calculated weight, add in the final influence
	float3 sPos = mul(indata.Pos, mBoneArray[IndexArray[NumBones-1]]);
	Pos += sPos * LastWeight;
	// Calculate WorldTangent directly... inverse is the transpose for affine rotations
	worldI = mul(TanBasis, mBoneArray[IndexArray[NumBones-1]]);
	Normal += worldI[2] * LastWeight; 
	mat = transpose(worldI);
	
	float3 localLVec = lightVec - sPos;
	SkinnedLVec += mul(localLVec, mat) * LastWeight;
	SkinnedLDir += mul(lightDir, mat) * LastWeight;

	// Calculate HalfVector
	float4 wPos = mul(float4(Pos.xyz, 1.0), mWorld); 
	float3 tanEyeVec = mul(worldEyePos - wPos, mat);
	HalfVec = normalize(normalize(tanEyeVec) + SkinnedLVec);
	
	// Normalize normals
	Normal = normalize(Normal);
	// SkinnedLVec = SkinnedLVec;// normalize(SkinnedLVec);
	SkinnedLDir = normalize(SkinnedLDir);
}


void skinSoldierForPV(uniform int NumBones, in APP2VS indata, out float3 Pos, out float3 Normal)
{
	float LastWeight = 0.0;
	Pos = 0.0;
	Normal = 0.0;    

	// Compensate for lack of UBYTE4 on Geforce3
	int4 IndexVector = D3DCOLORtoUBYTE4(indata.BlendIndices);
	
	// Cast the vectors to arrays for use in the for loop below
	float BlendWeightsArray[1] = (float[1])indata.BlendWeights;
	int IndexArray[4] = (int[4])IndexVector;    
	
	// Calculate the pos/normal using the "normal" weights 
	// and accumulate the weights to calculate the last weight
	for (int iBone = 0; iBone < NumBones-1; iBone++)
	{
		LastWeight += BlendWeightsArray[iBone];
		
		Pos += mul(indata.Pos, mBoneArray[IndexArray[iBone]]) * BlendWeightsArray[iBone];
		Normal += mul(indata.Normal, mBoneArray[IndexArray[iBone]]) * BlendWeightsArray[iBone];
	}
	LastWeight = 1.0 - LastWeight; 
	
	// Now that we have the calculated weight, add in the final influence
	Pos += mul(indata.Pos, mBoneArray[IndexArray[NumBones-1]]) * LastWeight;
	Normal += mul(indata.Normal, mBoneArray[IndexArray[NumBones-1]]) * LastWeight;
	
	// Normalize normals
	Normal = normalize(Normal);
}

struct VS2PS_PP
{
	float4 Pos : POSITION;
	float2 Tex0 : TEXCOORD0;
	float3 GroundUVAndLerp : TEXCOORD1;
	float3 SkinnedLVec : TEXCOORD2;
	float3 HalfVec : TEXCOORD3;
};

//----------- pp object based lighting

VS2PS_PP VShader_HemiAndSunPP(APP2VS indata, uniform int NumBones)
{
	VS2PS_PP outdata;
	float3 Pos, Normal, SkinnedLVec;
	
	skinSoldierForPP(NumBones, indata, -sunLightDir, Pos, Normal, SkinnedLVec);
	
	// Transform position into view and then projection space
	outdata.Pos = mul(float4(Pos.xyz, 1.0), mWorldViewProj); 

 	// Hemi lookup values
	float4 wPos = mul(float4(Pos.xyz, 1.0), mWorld); 
 	outdata.GroundUVAndLerp.xy = ((wPos +(hemiMapInfo.z/2) + Normal*1/*normalOffsetScale*/).xz - hemiMapInfo.xy)/ hemiMapInfo.z;
	outdata.GroundUVAndLerp.y = 1-outdata.GroundUVAndLerp.y;
	outdata.GroundUVAndLerp.z = (Normal.y+1/*normalOffsetScale*/)/2;
	outdata.GroundUVAndLerp.z -= hemiMapInfo.w;
	
	//[TS:040201] Please note that "normalize(worldEyePos-wPos") is in worldspace while "SkinnedLVec" is in SkinnedSpace/ObjectSpace can this be correct??
	// outdata.HalfVec = normalize(normalize(worldEyePos-wPos) + SkinnedLVec);
	outdata.HalfVec = normalize(normalize(objectEyePos-Pos) + SkinnedLVec);
	outdata.SkinnedLVec = normalize(SkinnedLVec);
	 	
	outdata.Tex0 = indata.TexCoord0;
	
	return outdata;
}

struct VS2PS_PP_Shadow
{
	float4 Pos : POSITION;
	float2 Tex0 : TEXCOORD0;
	float3 GroundUVAndLerp : TEXCOORD1;
	float3 SkinnedLVec : TEXCOORD2;
	float3 HalfVec : TEXCOORD3;
	float4 ShadowTex : TEXCOORD4;
};

VS2PS_PP_Shadow VShader_HemiAndSunAndShadowPP(APP2VS indata, uniform int NumBones)
{
	VS2PS_PP_Shadow outdata;
	float3 Pos, Normal, SkinnedLVec;
	
	skinSoldierForPP(NumBones, indata, -sunLightDir, Pos, Normal, SkinnedLVec);
	
	// Transform position into view and then projection space
	outdata.Pos = mul(float4(Pos.xyz, 1.0), mWorldViewProj); 

	// Shadow
	outdata.ShadowTex =  mul(float4(Pos, 1), vpLightTrapezMat);
	float2 TexShadow2 = mul(float4(Pos, 1), vpLightMat).zw;
	TexShadow2.x -= 0.007;
	outdata.ShadowTex.z = (TexShadow2.x*outdata.ShadowTex.w)/TexShadow2.y; 	// (zL*wT)/wL == zL/wL post homo

 	// Hemi lookup values
	float4 wPos = mul(float4(Pos.xyz, 1.0), mWorld); 
 	outdata.GroundUVAndLerp.xy = ((wPos +(hemiMapInfo.z/2) + Normal*1/*normalOffsetScale*/).xz - hemiMapInfo.xy)/ hemiMapInfo.z;
	outdata.GroundUVAndLerp.y = 1-outdata.GroundUVAndLerp.y;
	outdata.GroundUVAndLerp.z = (Normal.y+1/*normalOffsetScale*/)/2;
	outdata.GroundUVAndLerp.z -= hemiMapInfo.w;
	
	//[TS:040201] Please note that "normalize(worldEyePos-wPos") is in worldspace while "SkinnedLVec" is in SkinnedSpace/ObjectSpace can this be correct??
	// outdata.HalfVec = normalize(normalize(worldEyePos-wPos) + SkinnedLVec);
	outdata.HalfVec = normalize(normalize(objectEyePos-Pos) + SkinnedLVec);
	outdata.SkinnedLVec = normalize(SkinnedLVec);
	 	
	outdata.Tex0 = indata.TexCoord0;
	
	return outdata;
}


float4 PShader_HemiAndSunPP(VS2PS_PP indata) : COLOR
{
	float4 groundcolor = tex2D(sampler0, indata.GroundUVAndLerp.xy);
	float4 hemicolor = lerp(groundcolor, skyColor, indata.GroundUVAndLerp.z);
	float4 normal = tex2D(sampler1, indata.Tex0);
	float3 expnormal = normalize((normal * 2) - 1);
	float3 suncol = saturate(dot(expnormal.rgb, indata.SkinnedLVec)) * sunColor;
	float specular = pow(dot(expnormal.rgb, indata.HalfVec), 36)*normal.a;

	float4 totalcolor = float4(suncol, specular);	// Do something with spec-alpha later on
	totalcolor *= groundcolor.a*groundcolor.a;
	totalcolor.rgb += ambientColor*hemicolor;
	return totalcolor;
}

float4 PShader_HemiAndSunAndShadowPP(VS2PS_PP_Shadow indata) : COLOR
{
	float4 groundcolor = tex2D(sampler0, indata.GroundUVAndLerp.xy);
	float4 hemicolor = lerp(groundcolor, skyColor, indata.GroundUVAndLerp.z);
	float4 normal = tex2D(sampler1, indata.Tex0);
		float3 expnormal = normalize((normal * 2) - 1);
	float3 suncol = saturate(dot(expnormal.rgb, indata.SkinnedLVec)) * sunColor;
	float specular = pow(dot(expnormal.rgb, indata.HalfVec), 36)*normal.a;

	float4 texel = float4(1.0/1024.0, 1.0/1024.0, 0, 0);
	float4 samples;
	// indata.ShadowTex.xy = clamp(indata.ShadowTex.xy, vViewportMap.xy, vViewportMap.zw);
	samples.x = tex2Dproj(sampler3point, indata.ShadowTex);
	samples.y = tex2Dproj(sampler3point, indata.ShadowTex + float4(texel.x, 0, 0, 0));
	samples.z = tex2Dproj(sampler3point, indata.ShadowTex + float4(0, texel.y, 0, 0));
	samples.w = tex2Dproj(sampler3point, indata.ShadowTex + texel);
	
	float4 staticSamples;
	staticSamples.x = tex2D(sampler2, indata.ShadowTex + float2(-texel.x*1, -texel.y*2)).b;
	staticSamples.y = tex2D(sampler2, indata.ShadowTex + float2(texel.x*1, -texel.y*2)).b;
	staticSamples.z = tex2D(sampler2, indata.ShadowTex + float2(-texel.x*1,  texel.y*2)).b;
	staticSamples.w = tex2D(sampler2, indata.ShadowTex + float2(texel.x*1,  texel.y*2)).b;
	staticSamples.x = dot(staticSamples.xyzw, 0.25);
	
	float4 cmpbits = samples > saturate(indata.ShadowTex.z/indata.ShadowTex.w);
	float avgShadowValue = dot(cmpbits, float4(0.25, 0.25, 0.25, 0.25));

	float totShadow = avgShadowValue.x*staticSamples.x;

	float4 totalcolor = float4(suncol, specular*totShadow*totShadow);	// Do something with spec-alpha later on
	totalcolor.rgb *= totShadow;
	totalcolor.rgb += ambientColor*hemicolor;
	
	return totalcolor;
}


float4 PShader_HemiAndSunAndColorPP(VS2PS_PP indata) : COLOR
{
	float4 groundcolor = tex2D(sampler0, indata.GroundUVAndLerp.xy);
	float4 hemicolor = lerp(groundcolor, skyColor, indata.GroundUVAndLerp.z);
	float4 normal = tex2D(sampler1, indata.Tex0);
		float3 expnormal = normalize((normal * 2) - 1);
	float3 suncol = saturate(dot(expnormal.rgb, indata.SkinnedLVec)) * sunColor;
	float specular = pow(dot(expnormal.rgb, indata.HalfVec), 36)*normal.a;

	float4 totalcolor = saturate(float4(suncol*groundcolor.a*groundcolor.a+ambientColor*hemicolor, specular));	// Do something with spec-alpha later on
	
	float4 color = tex2D(sampler2, indata.Tex0);
	totalcolor.rgb *= color.rgb;

	totalcolor.rgb += specular;	
	totalcolor.a = color.a;
	
	return totalcolor;
}

float4 PShader_HemiAndSunAndShadowAndColorPP(VS2PS_PP_Shadow indata) : COLOR
{
	float4 groundcolor = tex2D(sampler0, indata.GroundUVAndLerp.xy);
	float4 hemicolor = lerp(groundcolor, skyColor, indata.GroundUVAndLerp.z);
	float4 normal = tex2D(sampler1, indata.Tex0);
	float3 expnormal = normalize((normal * 2) - 1);
	float3 suncol = saturate(dot(expnormal.rgb, indata.SkinnedLVec)) * sunColor;
	float specular = pow(dot(expnormal.rgb, indata.HalfVec), 36)*normal.a;

	float4 texel = float4(0.5/1024.0, 0.5/1024.0, 0, 0);
	float4 samples;
	// indata.ShadowTex.xy = clamp(indata.ShadowTex.xy, vViewportMap.xy, vViewportMap.zw);
	samples.x = tex2Dproj(sampler4point, indata.ShadowTex);
	samples.y = tex2Dproj(sampler4point, indata.ShadowTex + float4(texel.x, 0, 0, 0));
	samples.z = tex2Dproj(sampler4point, indata.ShadowTex + float4(0, texel.y, 0, 0));
	samples.w = tex2Dproj(sampler4point, indata.ShadowTex + texel);
	
	float4 staticSamples;
	staticSamples.x = tex2D(sampler3, indata.ShadowTex + float2(-texel.x*1, -texel.y*2)).b;
	staticSamples.y = tex2D(sampler3, indata.ShadowTex + float2(texel.x*1, -texel.y*2)).b;
	staticSamples.z = tex2D(sampler3, indata.ShadowTex + float2(-texel.x*1,  texel.y*2)).b;
	staticSamples.w = tex2D(sampler3, indata.ShadowTex + float2(texel.x*1,  texel.y*2)).b;
	staticSamples.x = dot(staticSamples.xyzw, 0.25);
	
	float4 cmpbits = samples > saturate(indata.ShadowTex.z/indata.ShadowTex.w);
	float avgShadowValue = dot(cmpbits, float4(0.25, 0.25, 0.25, 0.25));

	float totShadow = avgShadowValue.x*staticSamples.x;
// return avgShadowValue;
	float4 color = tex2D(sampler2, indata.Tex0);
	float4 totalcolor = saturate(float4(suncol*totShadow+ambientColor*hemicolor, specular));	// Do something with spec-alpha later on
	totalcolor.rgb *= color.rgb;
	totalcolor.rgb += specular*totShadow*totShadow;
	totalcolor.a = color.a;
	
	return totalcolor;
}


// Max 2 bones skinning supported!
VertexShader vsArray_HemiAndSunPP[2] = { compile vs_1_1 VShader_HemiAndSunPP(1), compile vs_1_1 VShader_HemiAndSunPP(2) };
VertexShader vsArray_HemiAndSunAndShadowPP[2] = { compile vs_1_1 VShader_HemiAndSunAndShadowPP(1), compile vs_1_1 VShader_HemiAndSunAndShadowPP(2) };


technique t0_HemiAndSunPP
{
	pass p0
	{
		CullMode = CCW;
		ZEnable = TRUE;	
		AlphaBlendEnable = FALSE;
		AlphaTestEnable = FALSE;
		// AlphaBlendEnable = TRUE;
		
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;
	
		VertexShader = (vsArray_HemiAndSunPP[1]);
		// PixelShader = compile ps_1_4 PShader_HemiAndSunPP();
		PixelShader = compile ps_2_0 PShader_HemiAndSunPP();
	}

	pass p0
	{
		CullMode = CCW;
		ZEnable = TRUE;	
		AlphaBlendEnable = FALSE;
		AlphaTestEnable = FALSE;
		// AlphaBlendEnable = TRUE;
		
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;
	
		VertexShader = (vsArray_HemiAndSunAndShadowPP[1]);
		// PixelShader = compile ps_1_4 PShader_HemiAndSunPP();
		PixelShader = compile ps_2_0 PShader_HemiAndSunAndShadowPP();
	}
}


technique t0_HemiAndSunAndColorPP
{
	pass p0
	{
		CullMode = CCW;
		ZEnable = TRUE;	
		AlphaBlendEnable = FALSE;
		AlphaTestEnable = FALSE;
		// AlphaBlendEnable = TRUE;
		
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;
	
		VertexShader = (vsArray_HemiAndSunPP[1]);
		PixelShader = compile ps_2_0 PShader_HemiAndSunAndColorPP();
	}
	
	pass p1
	{
		CullMode = CCW;
		ZEnable = TRUE;	
		AlphaBlendEnable = FALSE;
		AlphaTestEnable = FALSE;
		// AlphaBlendEnable = TRUE;
		
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;

		VertexShader = (vsArray_HemiAndSunAndShadowPP[1]);
		PixelShader = compile ps_2_0 PShader_HemiAndSunAndShadowAndColorPP();
	}
}


//----------- pp tangent based lighting

VS2PS_PP VShader_HemiAndSunPPtangent(APP2VStangent indata, uniform int NumBones)
{
	VS2PS_PP outdata;
	float3 Pos, Normal, SkinnedLVec;
	float4 wPos;
	
	skinSoldierForPPtangent(NumBones, indata, -sunLightDir, Pos, Normal, SkinnedLVec, wPos, outdata.HalfVec);
	
	// Transform position into view and then projection space
	outdata.Pos = mul(float4(Pos.xyz, 1.0), mWorldViewProj); 

 	// Hemi lookup values
 	outdata.GroundUVAndLerp.xy = ((wPos +(hemiMapInfo.z/2) + Normal*1/*normalOffsetScale*/).xz - hemiMapInfo.xy)/ hemiMapInfo.z;
	outdata.GroundUVAndLerp.y = 1-outdata.GroundUVAndLerp.y;
	outdata.GroundUVAndLerp.z = (Normal.y+1/*normalOffsetScale*/)/2;
	outdata.GroundUVAndLerp.z -= hemiMapInfo.w;
	
	outdata.SkinnedLVec = normalize(SkinnedLVec);
	 	
	outdata.Tex0 = indata.TexCoord0;
	
	return outdata;
}

VS2PS_PP_Shadow VShader_HemiAndSunAndShadowPPtangent(APP2VStangent indata, uniform int NumBones)
{
	VS2PS_PP_Shadow outdata;
	float3 Pos, Normal, SkinnedLVec;
	float4 wPos;
	
	skinSoldierForPPtangent(NumBones, indata, -sunLightDir, Pos, Normal, SkinnedLVec, wPos, outdata.HalfVec);
	
	// Transform position into view and then projection space
	outdata.Pos = mul(float4(Pos.xyz, 1.0), mWorldViewProj); 

 	// Hemi lookup values
 	outdata.GroundUVAndLerp.xy = ((wPos +(hemiMapInfo.z/2) + Normal*1/*normalOffsetScale*/).xz - hemiMapInfo.xy)/ hemiMapInfo.z;
	outdata.GroundUVAndLerp.y = 1-outdata.GroundUVAndLerp.y;
	outdata.GroundUVAndLerp.z = (Normal.y+1/*normalOffsetScale*/)/2;
	outdata.GroundUVAndLerp.z -= hemiMapInfo.w;

	// Shadow
	outdata.ShadowTex =  mul(float4(Pos, 1), vpLightTrapezMat);
	float2 TexShadow2 = mul(float4(Pos, 1), vpLightMat).zw;
	TexShadow2.x -= 0.007;
	outdata.ShadowTex.z = (TexShadow2.x*outdata.ShadowTex.w)/TexShadow2.y; 	// (zL*wT)/wL == zL/wL post homo

	
	outdata.SkinnedLVec = normalize(SkinnedLVec);
	 	
	outdata.Tex0 = indata.TexCoord0;
	
	return outdata;
}

VertexShader vsArray_HemiAndSunPPtangent[2] = { compile vs_1_1 VShader_HemiAndSunPPtangent(1), compile vs_1_1 VShader_HemiAndSunPPtangent(2) };
VertexShader vsArray_HemiAndSunAndShadowPPtangent[2] = { compile vs_1_1 VShader_HemiAndSunAndShadowPPtangent(1), compile vs_1_1 VShader_HemiAndSunAndShadowPPtangent(2) };

technique t0_HemiAndSunPPtangent
{
	pass p0
	{
		CullMode = CCW;
		AlphaBlendEnable = FALSE;
		AlphaTestEnable = FALSE;
		ZEnable = TRUE;	
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;
	
		VertexShader = (vsArray_HemiAndSunPPtangent[1]);
		// PixelShader = compile ps_1_4 PShader_HemiAndSunPP();
		PixelShader = compile ps_2_0 PShader_HemiAndSunPP();
	}

	pass p1
	{
		CullMode = CCW;
		AlphaBlendEnable = FALSE;
		AlphaTestEnable = FALSE;
		ZEnable = TRUE;	
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;
	
		VertexShader = (vsArray_HemiAndSunAndShadowPPtangent[1]);
		// PixelShader = compile ps_1_4 PShader_HemiAndSunPP();
		PixelShader = compile ps_2_0 PShader_HemiAndSunAndShadowPP();
	}
}

technique t0_HemiAndSunAndColorPPtangent
{
	pass p0
	{
		CullMode = CCW;
		AlphaBlendEnable = FALSE;
		AlphaTestEnable = FALSE;
		ZEnable = TRUE;	
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;
	
		VertexShader = (vsArray_HemiAndSunPPtangent[1]);
		// PixelShader = compile ps_1_4 PShader_HemiAndSunPP();
		PixelShader = compile ps_2_0 PShader_HemiAndSunAndColorPP();
	}

	pass p1
	{
		CullMode = CCW;
		AlphaBlendEnable = FALSE;
		AlphaTestEnable = FALSE;
		ZEnable = TRUE;	
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;
	
		VertexShader = (vsArray_HemiAndSunAndShadowPPtangent[1]);
		// PixelShader = compile ps_1_4 PShader_HemiAndSunPP();
		PixelShader = compile ps_2_0 PShader_HemiAndSunAndShadowAndColorPP();
	}
}


struct VS2PS_PV
{
	float4 Pos : POSITION;
	float3 GroundUVAndLerp : TEXCOORD0;
	float4 DiffAndSpec : COLOR;
};

VS2PS_PV VShader_HemiAndSunPV(APP2VS indata, uniform int NumBones)
{
	VS2PS_PV outdata;
	float3 Pos, Normal;
	
	skinSoldierForPV(NumBones, indata, Pos, Normal);
	
	// Transform position into view and then projection space
	outdata.Pos = mul(float4(Pos.xyz, 1.0), mWorldViewProj); 

 	// Hemi lookup values
	float4 wPos = mul(float4(Pos.xyz, 1.0), mWorld); 
 	outdata.GroundUVAndLerp.xy = ((wPos +(hemiMapInfo.z/2) + Normal*1/*normalOffsetScale*/).xz - hemiMapInfo.xy) / hemiMapInfo.z;
	outdata.GroundUVAndLerp.y = 1-outdata.GroundUVAndLerp.y;
	outdata.GroundUVAndLerp.z = (Normal.y+1/*normalOffsetScale*/)/2;
	outdata.GroundUVAndLerp.z -= hemiMapInfo.w;
	
	float diff = dot(Normal, -sunLightDir);
	float3 objEyeVec = normalize(objectEyePos-Pos);
	float3 halfVec = (-sunLightDir + objEyeVec) * 0.5;
	float spec = dot(Normal, halfVec);
	float4 light = lit(diff, spec, 32);
	outdata.DiffAndSpec.rgb = light.y * sunColor;
	outdata.DiffAndSpec.a = light.z;
	
	return outdata;
}

float4 PShader_HemiAndSunPV(VS2PS_PV indata) : COLOR
{
	float4 groundcolor = tex2D(sampler0, indata.GroundUVAndLerp.xy);
	float4 hemicolor = lerp(groundcolor, skyColor, indata.GroundUVAndLerp.z);

	float4 totalcolor = saturate(float4(indata.DiffAndSpec.rgb*groundcolor.a*groundcolor.a+ambientColor*hemicolor, indata.DiffAndSpec.a));	// Do something with spec-alpha later on
	return totalcolor;
}

// Max 2 bones skinning supported!
VertexShader vsArray_HemiAndSunPV[2] = { compile vs_1_1 VShader_HemiAndSunPV(1),  compile vs_1_1 VShader_HemiAndSunPV(2) };


technique t0_HemiAndSunPV
{
	pass p0
	{
		CullMode = CCW;
		AlphaBlendEnable = FALSE;
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;
	
		VertexShader = (vsArray_HemiAndSunPV[1]);
		// PixelShader = compile ps_1_4 PShader_HemiAndSunPV();
		PixelShader = compile ps_2_0 PShader_HemiAndSunPV();
	}

	pass p1
	{
		CullMode = CCW;
		ZEnable = TRUE;	
		AlphaBlendEnable = FALSE;
		AlphaTestEnable = FALSE;
		
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;
			
		VertexShader = (vsArray_HemiAndSunPV[1]);
		// PixelShader = compile ps_1_4 PShader_HemiAndSunPV();
		PixelShader = compile ps_2_0 PShader_HemiAndSunPV();
	}
}

struct VS2PS_PVCOLOR
{
	float4 Pos : POSITION;
	float2 Tex0 : TEXCOORD0;	
	float3 GroundUVAndLerp : TEXCOORD1;
	float4 DiffAndSpec : COLOR;
};

VS2PS_PVCOLOR VShader_HemiAndSunAndColorPV(APP2VS indata, uniform int NumBones)
{
	VS2PS_PVCOLOR outdata;
	float3 Pos, Normal;
	
	skinSoldierForPV(NumBones, indata, Pos, Normal);
	
	// Transform position into view and then projection space
	outdata.Pos = mul(float4(Pos.xyz, 1.0), mWorldViewProj); 

 	// Hemi lookup values
	float4 wPos = mul(float4(Pos.xyz, 1.0), mWorld); 
 	outdata.GroundUVAndLerp.xy = ((wPos +(hemiMapInfo.z/2) + Normal*1/*normalOffsetScale*/).xz - hemiMapInfo.xy) / hemiMapInfo.z;
	outdata.GroundUVAndLerp.y = 1-outdata.GroundUVAndLerp.y;
	outdata.GroundUVAndLerp.z = (Normal.y+1/*normalOffsetScale*/)/2;
	outdata.GroundUVAndLerp.z -= hemiMapInfo.w;
	
	outdata.Tex0 = indata.TexCoord0;
	float diff = dot(Normal, -sunLightDir);
	float3 objEyeVec = normalize(objectEyePos-Pos);
	float3 halfVec = (-sunLightDir + objEyeVec) * 0.5;
	float spec = dot(Normal, halfVec);
	float4 light = lit(diff, spec, 32);
	outdata.DiffAndSpec.rgb = light.y * sunColor;
	outdata.DiffAndSpec.a = light.z;
	
	return outdata;
}


float4 PShader_HemiAndSunAndColorPV(VS2PS_PVCOLOR indata) : COLOR
{
	float4 groundcolor = tex2D(sampler0, indata.GroundUVAndLerp.xy);
	float4 hemicolor = lerp(groundcolor, skyColor, indata.GroundUVAndLerp.z);

	float4 totalcolor = saturate(float4(indata.DiffAndSpec.rgb*groundcolor.a*groundcolor.a+ambientColor*hemicolor, indata.DiffAndSpec.a));	// Do something with spec-alpha later on
	float4 color = tex2D(sampler1, indata.Tex0);
	totalcolor.rgb *= color.rgb;
	totalcolor.rgb += indata.DiffAndSpec.a; 
	
	totalcolor.a = color.a;
	
	return totalcolor;
}

struct VS2PS_PVCOLOR_SHADOW
{
	float4 Pos : POSITION;
	float2 Tex0 : TEXCOORD0;	
	float3 GroundUVAndLerp : TEXCOORD1;
	float4 ShadowTex : TEXCOORD2;
	float4 DiffAndSpec : COLOR;
};


VS2PS_PVCOLOR_SHADOW VShader_HemiAndSunAndShadowAndColorPV(APP2VS indata, uniform int NumBones)
{
	VS2PS_PVCOLOR_SHADOW outdata = (VS2PS_PVCOLOR_SHADOW)0;
	float3 Pos, Normal;
	
	skinSoldierForPV(NumBones, indata, Pos, Normal);
	
	// Transform position into view and then projection space
	outdata.Pos = mul(float4(Pos.xyz, 1.0), mWorldViewProj); 
	// outdata.Pos = mul(float4(indata.Pos.xyz, 1.0), mWorldViewProj); 
	// Pos = outdata.Pos;
	// Normal = float3(0,0,1);


	// Shadow
	outdata.ShadowTex =  mul(float4(Pos, 1), vpLightTrapezMat);
	float2 TexShadow2 = mul(float4(Pos, 1), vpLightMat).zw;
	TexShadow2.x -= 0.007;
	outdata.ShadowTex.z = (TexShadow2.x*outdata.ShadowTex.w)/TexShadow2.y; 	// (zL*wT)/wL == zL/wL post homo

 	// Hemi lookup values
	float4 wPos = mul(float4(Pos.xyz, 1.0), mWorld); 
 	outdata.GroundUVAndLerp.xy = ((wPos +(hemiMapInfo.z/2) + Normal*1).xz - hemiMapInfo.xy) / hemiMapInfo.z;
	outdata.GroundUVAndLerp.y = 1-outdata.GroundUVAndLerp.y;
	outdata.GroundUVAndLerp.z = (Normal.y+1)/2;
	outdata.GroundUVAndLerp.z -= hemiMapInfo.w;
	
	outdata.Tex0 = indata.TexCoord0;
	float diff = dot(Normal, -sunLightDir);
	float3 objEyeVec = normalize(objectEyePos-Pos);
	float3 halfVec = (-sunLightDir + objEyeVec) * 0.5;
	float spec = dot(Normal, halfVec);
	float4 light = lit(diff, spec, 32);
	outdata.DiffAndSpec.rgb = sunColor * light.y;
	outdata.DiffAndSpec.a = light.z;
	
	// outdata.DiffAndSpec.rgb = dot(Normal, -sunLightDir) * sunColor;
	// outdata.DiffAndSpec.a = dot(Normal, normalize(normalize(objectEyePos-Pos) - sunLightDir));


	return outdata;
}


float4 PShader_HemiAndSunAndShadowAndColorPV(VS2PS_PVCOLOR_SHADOW indata) : COLOR
{
	float4 groundcolor = tex2D(sampler0, indata.GroundUVAndLerp.xy);
	float4 hemicolor = lerp(groundcolor, skyColor, indata.GroundUVAndLerp.z);

	float4 texel = float4(1.0/1024.0, 1.0/1024.0, 0, 0);
	float4 samples;
	// indata.ShadowTex.xy = clamp(indata.ShadowTex.xy, vViewportMap.xy, vViewportMap.zw);

	samples.x = tex2Dproj(sampler4point, indata.ShadowTex);
	samples.y = tex2Dproj(sampler4point, indata.ShadowTex + float4(texel.x, 0, 0, 0));
	samples.z = tex2Dproj(sampler4point, indata.ShadowTex + float4(0, texel.y, 0, 0));
	samples.w = tex2Dproj(sampler4point, indata.ShadowTex + texel);
	
	float4 staticSamples;
	staticSamples.x = tex2D(sampler3, indata.ShadowTex + float2(-texel.x*1, -texel.y*2)).b;
	staticSamples.y = tex2D(sampler3, indata.ShadowTex + float2(texel.x*1, -texel.y*2)).b;
	staticSamples.z = tex2D(sampler3, indata.ShadowTex + float2(-texel.x*1,  texel.y*2)).b;
	staticSamples.w = tex2D(sampler3, indata.ShadowTex + float2(texel.x*1,  texel.y*2)).b;
	staticSamples.x = dot(staticSamples.xyzw, 0.25);
	
	float4 cmpbits = samples > saturate(indata.ShadowTex.z);
	float avgShadowValue = dot(cmpbits, float4(0.25, 0.25, 0.25, 0.25));

	float totShadow = avgShadowValue.x*staticSamples.x;

	float4 totalcolor = saturate(float4(indata.DiffAndSpec.rgb*totShadow+ambientColor*hemicolor, indata.DiffAndSpec.a));	// Do something with spec-alpha later on
	float4 color = tex2D(sampler1, indata.Tex0);
	totalcolor.rgb *= color.rgb;
	totalcolor.rgb += indata.DiffAndSpec.a *totShadow*totShadow; 

	totalcolor.a = color.a;
	
	return totalcolor;
}

// Max 2 bones skinning supported!
VertexShader vsArray_HemiAndSunAndColorPV[2] = { compile vs_1_1 VShader_HemiAndSunAndColorPV(1),  compile vs_1_1 VShader_HemiAndSunAndColorPV(2) };
VertexShader vsArray_HemiAndSunAndShadowAndColorPV[2] = { compile vs_1_1 VShader_HemiAndSunAndShadowAndColorPV(1),  compile vs_1_1 VShader_HemiAndSunAndShadowAndColorPV(2) };


technique t0_HemiAndSunAndColorPV
{

	pass p0
	{
		CullMode = CCW;
		AlphaBlendEnable = FALSE;
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;
	
		VertexShader = (vsArray_HemiAndSunAndColorPV[1]);
		// PixelShader = compile ps_1_4 PShader_HemiAndSunPV();
		PixelShader = compile ps_2_0 PShader_HemiAndSunAndColorPV();
	}
	pass p1
	{
		CullMode = CCW;
		AlphaBlendEnable = FALSE;
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;

		VertexShader = (vsArray_HemiAndSunAndShadowAndColorPV[1]);
		// PixelShader = compile ps_1_4 PShader_HemiAndSunPV();
		PixelShader = compile ps_2_0 PShader_HemiAndSunAndShadowAndColorPV();

	}
}


struct VS2PS_PointLight_PV
{
	float4 Pos : POSITION;
	float3 Diffuse : COLOR;
	float2 Tex0 : TEXCOORD0;
};

VS2PS_PointLight_PV VShader_PointLightPV(APP2VS indata, uniform int NumBones)
{
	VS2PS_PointLight_PV outdata;
	float3 Pos, Normal;
	
	skinSoldierForPV(NumBones, indata, Pos, Normal);
	
	// Transform position into view and then projection space
	outdata.Pos = mul(float4(Pos.xyz, 1.0), mWorldViewProj); 

	// Lighting. Shade (Ambient + etc.)
	// float4 wPos = mul(float4(Pos.xyz, 1.0), mWorld); 	
	float3 lvec = lightPos - Pos.xyz;
	float3 lvecNormalized = normalize(lvec);
	
	float radialAtt = 1-saturate(dot(lvec,lvec)*attenuationSqrInv);

	outdata.Diffuse = dot(lvecNormalized, Normal);
	outdata.Diffuse *= lightColor * radialAtt;

	outdata.Tex0 = indata.TexCoord0;
	
	return outdata;
}

float4 PShader_PointLightPV(VS2PS_PointLight_PV indata) : COLOR
{
	return float4(indata.Diffuse,0);
}

// Max 2 bones skinning supported!
VertexShader vsArray_PointLightPV[2] = { compile vs_1_1 VShader_PointLightPV(1), 
                            compile vs_1_1 VShader_PointLightPV(2) };


technique t0_PointLightPV
{
	pass p0
	{
		AlphaBlendEnable = TRUE;
		SrcBlend = ONE;
		DestBlend = ONE;

		ZWriteEnable = FALSE;
		ZFunc = EQUAL;
	
		VertexShader = (vsArray_PointLightPV[1]);
		PixelShader = compile ps_1_1 PShader_PointLightPV();
	}
}

//----------- pp object based lighting

struct VS2PS_PointLight_PP
{
	float4 Pos : POSITION;
	float2 Tex0 : TEXCOORD0;
	float4 SkinnedLVec : TEXCOORD1;
	float3 HalfVec : TEXCOORD2;
};

VS2PS_PointLight_PP VShader_PointLightPP(APP2VS indata, uniform int NumBones)
{
	VS2PS_PointLight_PP outdata;
	float3 Pos, Normal, SkinnedLVec;
	
	skinSoldierForPointPP(NumBones, indata, lightPos, Pos, Normal, SkinnedLVec);
	
	// Transform position into view and then projection space
	outdata.Pos = mul(float4(Pos.xyz, 1.0), mWorldViewProj); 
	float4 wPos = mul(float4(Pos.xyz, 1.0), mWorld); 
	
	//[TS:040201] Please note that "normalize(worldEyePos-wPos") is in worldspace while "SkinnedLVec" is in SkinnedSpace/ObjectSpace can this be correct??
	// outdata.HalfVec = normalize(normalize(worldEyePos-wPos) + SkinnedLVec);
	outdata.HalfVec = normalize(normalize(objectEyePos-Pos) + SkinnedLVec);
	float3 nrmSkinnedLVec = normalize(SkinnedLVec);
	outdata.SkinnedLVec.xyz = nrmSkinnedLVec;
	
	// Skinnedmeshes are highly tesselated, so..
	float radialAtt = 1-saturate(dot(SkinnedLVec,SkinnedLVec)*attenuationSqrInv);
	outdata.SkinnedLVec.w = radialAtt;
 	
	outdata.Tex0 = indata.TexCoord0;
	
	return outdata;
}

float4 PShader_PointLightPP(VS2PS_PointLight_PP indata) : COLOR
{
// float3 normalizedLVec = normalize(indata.SkinnedLVec);
// float radialAtt = 1-saturate(dot(indata.SkinnedLVec,indata.SkinnedLVec)*attenuationSqrInv);

	float4 expandedNormal = tex2D(sampler1, indata.Tex0);
	expandedNormal.xyz = ((expandedNormal.xyz * 2) - 1);
	float2 intensityuv = float2(dot(indata.SkinnedLVec.xyz,expandedNormal.xyz), dot(indata.HalfVec,expandedNormal));
	float4 realintensity = float4(intensityuv.rrr,pow(intensityuv.g,36)*expandedNormal.a);
	realintensity *= lightColor * indata.SkinnedLVec.w;// radialAtt;
	return realintensity;
}

// Max 2 bones skinning supported!
VertexShader vsArray_PointLightPP[2] = { compile vs_1_1 VShader_PointLightPP(1), 
                            compile vs_1_1 VShader_PointLightPP(2) };


technique t0_PointLightPP
{
	pass p0
	{
		AlphaBlendEnable = TRUE;
		SrcBlend = ONE;
		DestBlend = ONE;

		ZWriteEnable = FALSE;
		ZFunc = EQUAL;
	
		VertexShader = (vsArray_PointLightPP[1]);
		PixelShader = compile ps_2_0 PShader_PointLightPP();
	}
}

//----------- pp tangent based lighting

VS2PS_PointLight_PP VShader_PointLightPPtangent(APP2VStangent indata, uniform int NumBones)
{
	VS2PS_PointLight_PP outdata;
	float3 Pos, Normal, SkinnedLVec;
	
	skinSoldierForPointPPtangent(NumBones, indata, lightPos, Pos, Normal, SkinnedLVec,outdata.HalfVec);
	
	// Transform position into view and then projection space
	outdata.Pos = mul(float4(Pos.xyz, 1.0), mWorldViewProj); 
	
	float3 nrmSkinnedLVec = normalize(SkinnedLVec);
	outdata.SkinnedLVec.xyz = nrmSkinnedLVec;
	
	// Skinnedmeshes are highly tesselated, so..
	float radialAtt = 1-saturate(dot(SkinnedLVec,SkinnedLVec)*attenuationSqrInv);
	outdata.SkinnedLVec.w = radialAtt;
 	
	outdata.Tex0 = indata.TexCoord0;
	
	return outdata;
}

// Max 2 bones skinning supported!
VertexShader vsArray_PointLightPPtangent[2] = { compile vs_1_1 VShader_PointLightPPtangent(1), 
                            compile vs_1_1 VShader_PointLightPPtangent(2) };


technique t0_PointLightPPtangent
{
	pass p0
	{
		AlphaBlendEnable = TRUE;
		SrcBlend = ONE;
		DestBlend = ONE;

		ZWriteEnable = FALSE;
		ZFunc = EQUAL;
	
		VertexShader = (vsArray_PointLightPPtangent[1]);
		PixelShader = compile ps_2_0 PShader_PointLightPP();
	}
}


struct VS2PS_SpotLight_PV
{
	float4 Pos : POSITION;
	float3 Diffuse : COLOR;
	float2 Tex0 : TEXCOORD0;
};

VS2PS_SpotLight_PV VShader_SpotLightPV(APP2VS indata, uniform int NumBones)
{
	VS2PS_SpotLight_PV outdata;
	float3 Pos, Normal;
	
	skinSoldierForPV(NumBones, indata, Pos, Normal);
	
	// Transform position into view and then projection space
	outdata.Pos = mul(float4(Pos.xyz, 1.0f), mWorldViewProj); 

	float3 lvec = lightPos - Pos.xyz;
	float3 lvecnorm = normalize(lvec);
	
	float radialAtt = 1-saturate(dot(lvec,lvec)*attenuationSqrInv);
	float offCenter = dot(lvecnorm, lightDir);
	float conicalAtt = saturate(offCenter-(1-coneAngle))/coneAngle;

	outdata.Diffuse = dot(lvecnorm,Normal) * lightColor;
	outdata.Diffuse *= conicalAtt*radialAtt;
	 	
	outdata.Tex0 = indata.TexCoord0;
	
	return outdata;
}

float4 PShader_SpotLightPV(VS2PS_SpotLight_PV indata) : COLOR
{
	return float4(indata.Diffuse,0);
}

// Max 2 bones skinning supported!
VertexShader vsArray_SpotLightPV[2] = { compile vs_1_1 VShader_SpotLightPV(1), 
                            compile vs_1_1 VShader_SpotLightPV(2)
                           };


technique t0_SpotLightPV
{
	pass p0
	{
		AlphaBlendEnable = TRUE;
		SrcBlend = ONE;
		DestBlend = ONE;

		ZWriteEnable = FALSE;
		ZFunc = EQUAL;
	
		VertexShader = (vsArray_SpotLightPV[1]);
		PixelShader = compile ps_1_1 PShader_SpotLightPV();
	}
}

struct VS2PS_SpotLight_PP
{
	float4 Pos : POSITION;
	float2 Tex0 : TEXCOORD0;
	float4 SkinnedLVec : TEXCOORD1;
	// float3 SkinnedLDir : TEXCOORD2;
	float3 HalfVec : TEXCOORD3;
};

VS2PS_SpotLight_PP VShader_SpotLightPP(APP2VS indata, uniform int NumBones)
{
	VS2PS_SpotLight_PP outdata;
	float3 Pos, Normal, SkinnedLVec, SkinnedLDir;
	
	skinSoldierForSpotPP(NumBones, indata, lightPos, lightDir, Pos, Normal, SkinnedLVec, SkinnedLDir);
	
	// Transform position into view and then projection space
	outdata.Pos = mul(float4(Pos.xyz, 1.0), mWorldViewProj); 
	float4 wPos = mul(float4(Pos.xyz, 1.0), mWorld); 
	
	//[TS:040201] Please note that "normalize(worldEyePos-wPos") is in worldspace while "SkinnedLVec" is in SkinnedSpace/ObjectSpace can this be correct??
	// outdata.HalfVec = normalize(normalize(worldEyePos-wPos) + SkinnedLVec);
	outdata.HalfVec = normalize(normalize(objectEyePos-Pos) + SkinnedLVec);
	float3 nrmSkinnedLVec = normalize(SkinnedLVec);
	outdata.SkinnedLVec.xyz = nrmSkinnedLVec;
	// outdata.SkinnedLDir = SkinnedLDir;
	
	// Skinnedmeshes are highly tesselated, so..
	float radialAtt = 1-saturate(dot(SkinnedLVec,SkinnedLVec)*attenuationSqrInv);
	float offCenter = dot(nrmSkinnedLVec, SkinnedLDir);
	float conicalAtt = saturate(offCenter-(1-coneAngle))/coneAngle;
	outdata.SkinnedLVec.w = radialAtt * conicalAtt;
	
	outdata.Tex0 = indata.TexCoord0;
	
	return outdata;
}

float4 PShader_SpotLightPP(VS2PS_SpotLight_PP indata) : COLOR
{	
	// float3 normalizedLVec = normalize(indata.SkinnedLVec);	
	// float radialAtt = 1-saturate(dot(indata.SkinnedLVec,indata.SkinnedLVec)*attenuationSqrInv);
	// float offCenter = dot(normalizedLVec, normalize(indata.SkinnedLDir));
	// float conicalAtt = saturate(offCenter-(1-coneAngle))/coneAngle;

	float4 expandedNormal = tex2D(sampler1, indata.Tex0);
	expandedNormal.xyz = (expandedNormal.xyz * 2) - 1;
	float2 intensityuv = float2(dot(indata.SkinnedLVec,expandedNormal), dot(indata.HalfVec,expandedNormal));
	float4 realintensity = float4(intensityuv.rrr,pow(intensityuv.g,36)*expandedNormal.a);
	realintensity.rgb *= lightColor;
	return realintensity * indata.SkinnedLVec.w;//* conicalAtt * radialAtt;
}

// Max 2 bones skinning supported!
VertexShader vsArray_SpotLightPP[2] = { compile vs_1_1 VShader_SpotLightPP(1), 
                            compile vs_1_1 VShader_SpotLightPP(2)
                           };


technique t0_SpotLightPP
{
	pass p0
	{
		AlphaBlendEnable = TRUE;
		SrcBlend = ONE;
		DestBlend = ONE;

		ZWriteEnable = FALSE;
		ZFunc = EQUAL;
	
		VertexShader = (vsArray_SpotLightPP[1]);
		PixelShader = compile ps_2_0 PShader_SpotLightPP();
	}
}

// pp tangent based lighting

VS2PS_SpotLight_PP VShader_SpotLightPPtangent(APP2VStangent indata, uniform int NumBones)
{
	VS2PS_SpotLight_PP outdata;
	float3 Pos, Normal, SkinnedLVec, SkinnedLDir;
	
	skinSoldierForSpotPPtangent(NumBones, indata, lightPos, lightDir, Pos, Normal, SkinnedLVec, SkinnedLDir,outdata.HalfVec);
	
	// Transform position into view and then projection space
	outdata.Pos = mul(float4(Pos.xyz, 1.0), mWorldViewProj); 
	float4 wPos = mul(float4(Pos.xyz, 1.0), mWorld); 
	
	//[TS:040201] Please note that "normalize(worldEyePos-wPos") is in worldspace while "SkinnedLVec" is in SkinnedSpace/ObjectSpace can this be correct??
	// outdata.HalfVec = normalize(normalize(worldEyePos-wPos) + SkinnedLVec);
	outdata.HalfVec = normalize(normalize(objectEyePos-Pos) + SkinnedLVec);
	float3 nrmSkinnedLVec = normalize(SkinnedLVec);
	outdata.SkinnedLVec.xyz = nrmSkinnedLVec;
	// outdata.SkinnedLDir = SkinnedLDir;
	
	// Skinnedmeshes are highly tesselated, so..
	float radialAtt = 1-saturate(dot(SkinnedLVec,SkinnedLVec)*attenuationSqrInv);
	float offCenter = dot(nrmSkinnedLVec, SkinnedLDir);
	float conicalAtt = saturate(offCenter-(1-coneAngle))/coneAngle;
	outdata.SkinnedLVec.w = radialAtt * conicalAtt;
	
	outdata.Tex0 = indata.TexCoord0;
	
	return outdata;
}

// Max 2 bones skinning supported!
VertexShader vsArray_SpotLightPPtangent[2] = { compile vs_1_1 VShader_SpotLightPPtangent(1), 
                            compile vs_1_1 VShader_SpotLightPPtangent(2)
                           };


technique t0_SpotLightPPtangent
{
	pass p0
	{
		AlphaBlendEnable = TRUE;
		SrcBlend = ONE;
		DestBlend = ONE;

		ZWriteEnable = FALSE;
		ZFunc = EQUAL;
	
		VertexShader = (vsArray_SpotLightPPtangent[1]);
		PixelShader = compile ps_2_0 PShader_SpotLightPP();
	}
}


struct VS2PS_MulDiffuse
{
	float4 Pos : POSITION;
	float2 Tex0 : TEXCOORD0;
};

VS2PS_MulDiffuse VShader_MulDiffuse(APP2VS indata, uniform int NumBones)
{
	VS2PS_MulDiffuse outdata;
	float3 Pos, Normal;
	
	skinSoldierForPV(NumBones, indata, Pos, Normal);
	
	// Transform position into view and then projection space
	outdata.Pos = mul(float4(Pos.xyz, 1.0f), mWorldViewProj); 

	outdata.Tex0 = indata.TexCoord0;
	
	return outdata;
}

float4 PShader_MulDiffuse(VS2PS_MulDiffuse indata) : COLOR
{
	return tex2D(sampler0, indata.Tex0);
}

// Max 2 bones skinning supported!
VertexShader vsArray_MulDiffuse[2] = { compile vs_1_1 VShader_MulDiffuse(1), 
                            compile vs_1_1 VShader_MulDiffuse(2)
                           };


technique t0_MulDiffuse
{
	pass p0
	{
		AlphaBlendEnable = TRUE;
		SrcBlend = DESTCOLOR;
		DestBlend = ZERO;
		// DestBlend = ONE;

		ZWriteEnable = FALSE;
		ZFunc = EQUAL;

		VertexShader = (vsArray_MulDiffuse[1]);
		PixelShader = compile ps_1_1 PShader_MulDiffuse();
	}
}

//----------------
// humanskin
//----------------

struct VS2PS_Skinpre
{
	float4 Pos : POSITION;
	float2 Tex0 : TEXCOORD0;
	float3 SkinnedLVec : TEXCOORD1;
	float3 ObjEyeVec : TEXCOORD2;
	float3 GroundUVAndLerp : TEXCOORD3;
};

VS2PS_Skinpre vsSkinpre(APP2VS indata, uniform int NumBones)
{
	VS2PS_Skinpre outdata;
	float3 Pos, Normal;
	
	skinSoldierForPP(NumBones, indata, -sunLightDir, Pos, Normal, outdata.SkinnedLVec);

	outdata.ObjEyeVec = normalize(objectEyePos-Pos);

	outdata.Pos.xy = indata.TexCoord0 * float2(2,-2) - float2(1, -1);
	outdata.Pos.zw = float2(0, 1);

 	// Hemi lookup values
	float4 wPos = mul(Pos, mWorld); 
 	outdata.GroundUVAndLerp.xy = ((wPos +(hemiMapInfo.z/2) + Normal*1/*normalOffsetScale*/).xz - hemiMapInfo.xy)/ hemiMapInfo.z;
	outdata.GroundUVAndLerp.y = 1-outdata.GroundUVAndLerp.y;
	outdata.GroundUVAndLerp.z = (Normal.y+1/*normalOffsetScale*/)/2;
	outdata.GroundUVAndLerp.z -= hemiMapInfo.w;
	
	outdata.Tex0 = indata.TexCoord0;
	outdata.SkinnedLVec = normalize(outdata.SkinnedLVec);
	
	return outdata;
}

float4 psSkinpre(VS2PS_Skinpre indata) : COLOR
{
	// return float4(indata.ObjEyeVec,0);
	float4 expnormal = tex2D(sampler0, indata.Tex0);
	float4 groundcolor = tex2D(sampler1, indata.GroundUVAndLerp.xy);
	
	expnormal.rgb = (expnormal * 2) - 1;
	float wrapDiff = dot(expnormal, indata.SkinnedLVec) + 0.5;
	wrapDiff = saturate(wrapDiff / 1.5);

	float rimDiff = 1-dot(expnormal, indata.ObjEyeVec);
	rimDiff = pow(rimDiff,3);

	rimDiff *= saturate(0.75-saturate(dot(indata.ObjEyeVec, indata.SkinnedLVec)));
	// rimDiff *= saturate(0.1-saturate(dot(indata.ObjEyeVec, normalize(indata.SkinnedLVec))));
	
	return float4((wrapDiff.rrr + rimDiff)*groundcolor.a*groundcolor.a, expnormal.a);
}

struct VS2PS_Skinpreshadowed
{
	float4 Pos : POSITION;
	float4 Tex0AndHZW : TEXCOORD0;
	float3 SkinnedLVec : TEXCOORD1;
	float4 ShadowTex : TEXCOORD2;
	float3 ObjEyeVec : TEXCOORD3;
};

VS2PS_Skinpreshadowed vsSkinpreshadowed(APP2VS indata, uniform int NumBones)
{
	VS2PS_Skinpreshadowed outdata;
	float3 Pos, Normal;
	
	// don't need as much code for this case.. will rewrite later
	skinSoldierForPP(NumBones, indata, -sunLightDir, Pos, Normal, outdata.SkinnedLVec);

	outdata.ObjEyeVec = normalize(objectEyePos-Pos);

	outdata.ShadowTex = mul(float4(Pos, 1), mLightVP);
	outdata.ShadowTex.z -= 0.007;

	outdata.Pos.xy = indata.TexCoord0 * float2(2,-2) - float2(1, -1);
	outdata.Pos.zw = float2(0, 1);
	outdata.Tex0AndHZW/*.xy*/ = indata.TexCoord0.xyyy;
	
	return outdata;
}

float4 psSkinpreshadowed(VS2PS_Skinpreshadowed indata) : COLOR
{
	float4 expnormal = tex2D(sampler0, indata.Tex0AndHZW);
	expnormal.rgb = (expnormal * 2) - 1;

	float wrapDiff = dot(expnormal, indata.SkinnedLVec) + 0.5;
	wrapDiff = saturate(wrapDiff / 1.5);

	float rimDiff = 1-dot(expnormal, indata.ObjEyeVec);
	rimDiff = pow(rimDiff,3);
	rimDiff *= saturate(0.75-saturate(dot(indata.ObjEyeVec, indata.SkinnedLVec)));

	float2 texel = float2(1.0/1024.0, 1.0/1024.0);
	float4 samples;
	// indata.ShadowTex.xy = clamp(indata.ShadowTex.xy, vViewportMap.xy, vViewportMap.zw);
	samples.x = tex2D(sampler2point, indata.ShadowTex);
	samples.y = tex2D(sampler2point, indata.ShadowTex + float2(texel.x, 0));
	samples.z = tex2D(sampler2point, indata.ShadowTex + float2(0, texel.y));
	samples.w = tex2D(sampler2point, indata.ShadowTex + texel);
	
	float4 staticSamples;
	staticSamples.x = tex2D(sampler1, indata.ShadowTex + float2(-texel.x*1, -texel.y*2)).b;
	staticSamples.y = tex2D(sampler1, indata.ShadowTex + float2(texel.x*1, -texel.y*2)).b;
	staticSamples.z = tex2D(sampler1, indata.ShadowTex + float2(-texel.x*1,  texel.y*2)).b;
	staticSamples.w = tex2D(sampler1, indata.ShadowTex + float2(texel.x*1,  texel.y*2)).b;
	staticSamples.x = dot(staticSamples.xyzw, 0.25);
	
	float4 cmpbits = samples > saturate(indata.ShadowTex.z);
	float avgShadowValue = dot(cmpbits, float4(0.25, 0.25, 0.25, 0.25));

	float totShadow = avgShadowValue.x*staticSamples.x;
	float totDiff = wrapDiff + rimDiff;
	return float4(totDiff, totShadow, saturate(totShadow+0.35), expnormal.a);
}

float4 psSkinpreshadowedNV(VS2PS_Skinpreshadowed indata) : COLOR
{
	float4 expnormal = tex2D(sampler0, indata.Tex0AndHZW);
	expnormal.rgb = (expnormal * 2) - 1;

	float wrapDiff = dot(expnormal, indata.SkinnedLVec) + 0.5;
	wrapDiff = saturate(wrapDiff / 1.5);

	float rimDiff = 1-dot(expnormal, indata.ObjEyeVec);
	rimDiff = pow(rimDiff,3);
	rimDiff *= saturate(0.75-saturate(dot(indata.ObjEyeVec, indata.SkinnedLVec)));

	float2 texel = float2(1.0/1024.0, 1.0/1024.0);
	float avgShadowValue = tex2Dproj(sampler2, indata.ShadowTex); // HW percentage closer filtering.
	
	float4 staticSamples;
	// indata.ShadowTex.xy = clamp(indata.ShadowTex.xy, vViewportMap.xy, vViewportMap.zw);
	staticSamples.x = tex2D(sampler1, indata.ShadowTex + float2(-texel.x*1, -texel.y*2)).b;
	staticSamples.y = tex2D(sampler1, indata.ShadowTex + float2(texel.x*1, -texel.y*2)).b;
	staticSamples.z = tex2D(sampler1, indata.ShadowTex + float2(-texel.x*1,  texel.y*2)).b;
	staticSamples.w = tex2D(sampler1, indata.ShadowTex + float2(texel.x*1,  texel.y*2)).b;
	staticSamples.x = dot(staticSamples.xyzw, 0.25);
	
	// float4 cmpbits = samples > saturate(indata.ShadowTex.z);
	// float avgShadowValue = dot(cmpbits, float4(0.25, 0.25, 0.25, 0.25));

	float totShadow = avgShadowValue.x*staticSamples.x;
	float totDiff = wrapDiff + rimDiff;
	return float4(totDiff, totShadow, saturate(totShadow+0.35), expnormal.a);
}

VS2PS_PP vsSkinapply(APP2VS indata, uniform int NumBones)
{
	VS2PS_PP outdata;
	
	float3 Pos,Normal;
	
	skinSoldierForPP(NumBones, indata, -sunLightDir, Pos, Normal, outdata.SkinnedLVec);
	
	// Transform position into view and then projection space
	outdata.Pos = mul(float4(Pos.xyz, 1.0f), mWorldViewProj); 

 	// Hemi lookup values
	float4 wPos = mul(Pos, mWorld); 
 	outdata.GroundUVAndLerp.xy = ((wPos +(hemiMapInfo.z/2) + Normal*1/*normalOffsetScale*/).xz - hemiMapInfo.xy)/ hemiMapInfo.z;
	outdata.GroundUVAndLerp.y = 1-outdata.GroundUVAndLerp.y;
	outdata.GroundUVAndLerp.z = (Normal.y+1/*normalOffsetScale*/)/2;
	outdata.GroundUVAndLerp.z -= hemiMapInfo.w;

	outdata.Tex0 = indata.TexCoord0;
	outdata.HalfVec = normalize(normalize(objectEyePos-Pos) + outdata.SkinnedLVec);
	outdata.SkinnedLVec = normalize(outdata.SkinnedLVec);

	
	return outdata;
}

float4 psSkinapply(VS2PS_PP indata) : COLOR
{
	// return float4(1,1,1,1);
	float4 groundcolor = tex2D(sampler0, indata.GroundUVAndLerp.xy);
	// return groundcolor;
	float4 hemicolor = lerp(groundcolor, skyColor, indata.GroundUVAndLerp.z);
	float4 expnormal = tex2D(sampler1, indata.Tex0);
	expnormal.rgb = (expnormal * 2) - 1;
	float4 diffuse = tex2D(sampler2, indata.Tex0);
	float4 diffuseLight = tex2D(sampler3, indata.Tex0);
// return diffuseLight;
	// glossmap is in the diffuse alpha channel.
	float specular = pow(dot(expnormal.rgb, indata.HalfVec), 16)*diffuse.a;

	float4 totalcolor = saturate(ambientColor*hemicolor + diffuseLight.r*diffuseLight.b*sunColor);
	// return totalcolor;
	totalcolor *= diffuse;//+specular;

	// what to do what the shadow???
	float shadowIntensity = saturate(diffuseLight.g/*+ShadowIntensityBias*/);
	totalcolor.rgb += specular* shadowIntensity*shadowIntensity;

	return totalcolor;
}


technique humanskinNV
{
	pass pre
	{
		CullMode = NONE;
		AlphaBlendEnable = FALSE;
		ZEnable = FALSE;
		ZWriteEnable = FALSE;
		ZFunc = LESSEQUAL;

		StencilEnable = FALSE;

		VertexShader = compile vs_1_1 vsSkinpre(2);
		PixelShader = compile ps_2_0 psSkinpre();
	}
	pass preshadowed
	{
		CullMode = NONE;
		AlphaBlendEnable = FALSE;
		ZEnable = FALSE;
		ZWriteEnable = FALSE;
		ZFunc = LESSEQUAL;

		StencilEnable = FALSE;

		VertexShader = compile vs_1_1 vsSkinpreshadowed(2);
		PixelShader = compile ps_2_0 psSkinpreshadowedNV();
	}
	pass apply
	{
		CullMode = CCW;
		AlphaBlendEnable = FALSE;
		ZEnable = TRUE;
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;

		StencilEnable = TRUE;
		StencilRef = (dwStencilRef);
		StencilFunc = ALWAYS;
		StencilZFail = KEEP;
		StencilPass = REPLACE;

		VertexShader = compile vs_1_1 vsSkinapply(2);
		PixelShader = compile ps_2_0 psSkinapply();
	}
}

technique humanskin
{
	pass pre
	{
		CullMode = NONE;
		AlphaBlendEnable = FALSE;
		ZEnable = FALSE;
		ZWriteEnable = FALSE;
		ZFunc = LESSEQUAL;

		StencilEnable = FALSE;

		VertexShader = compile vs_1_1 vsSkinpre(2);
		PixelShader = compile ps_2_0 psSkinpre();
	}
	pass preshadowed
	{
		CullMode = NONE;
		AlphaBlendEnable = FALSE;
		ZEnable = FALSE;
		ZWriteEnable = FALSE;
		ZFunc = LESSEQUAL;

		StencilEnable = FALSE;

		VertexShader = compile vs_1_1 vsSkinpreshadowed(2);
		PixelShader = compile ps_2_0 psSkinpreshadowed();
	}
	pass apply
	{
		CullMode = CCW;
		AlphaBlendEnable = FALSE;
		ZEnable = TRUE;
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;
		// FillMode = WIREFRAME;

		VertexShader = compile vs_1_1 vsSkinapply(2);
		PixelShader = compile ps_2_0 psSkinapply();
	}
}



struct VS2PS_ShadowMap
{
	float4 Pos : POSITION;
	float2 PosZW : TEXCOORD0;
};

VS2PS_ShadowMap vsShadowMap(APP2VS indata)
{
	VS2PS_ShadowMap outdata;
	
	// Compensate for lack of UBYTE4 on Geforce3
	int4 IndexVector = D3DCOLORtoUBYTE4(indata.BlendIndices);
	
	// Cast the vectors to arrays for use in the for loop below
	float BlendWeightsArray[1] = (float[1])indata.BlendWeights;
	int IndexArray[4] = (int[4])IndexVector;    
	
	float3 Pos = mul(indata.Pos, mBoneArray[IndexArray[0]]) * BlendWeightsArray[0];
	Pos += mul(indata.Pos, mBoneArray[IndexArray[1]]) * (1-BlendWeightsArray[0]);
	
 	outdata.Pos = mul(float4(Pos.xyz, 1.0), vpLightTrapezMat);
 	float2 lightZW = mul(float4(Pos.xyz, 1.0), vpLightMat).zw;
	outdata.Pos.z = (lightZW.x*outdata.Pos.w)/lightZW.y;			// (zL*wT)/wL == zL/wL post homo
 	outdata.PosZW = outdata.Pos.zw;
	
	return outdata;
}

float4 psShadowMap(VS2PS_ShadowMap indata) : COLOR
{
// return 0.5;
	return indata.PosZW.x / indata.PosZW.y;
}


struct VS2PS_ShadowMapAlpha
{
	float4 Pos : POSITION;
	float4 Tex0PosZW : TEXCOORD0;
};

VS2PS_ShadowMapAlpha vsShadowMapAlpha(APP2VS indata)
{
	VS2PS_ShadowMapAlpha outdata;
	
	// Compensate for lack of UBYTE4 on Geforce3
	int4 IndexVector = D3DCOLORtoUBYTE4(indata.BlendIndices);
	
	// Cast the vectors to arrays for use in the for loop below
	float BlendWeightsArray[1] = (float[1])indata.BlendWeights;
	int IndexArray[4] = (int[4])IndexVector;    
	
	float3 Pos = mul(indata.Pos, mBoneArray[IndexArray[0]]) * BlendWeightsArray[0];
	Pos += mul(indata.Pos, mBoneArray[IndexArray[1]]) * (1-BlendWeightsArray[0]);
	
 	outdata.Pos = mul(float4(Pos.xyz, 1.0), vpLightTrapezMat);
 	float2 lightZW = mul(float4(Pos.xyz, 1.0), vpLightMat).zw;
	outdata.Pos.z = (lightZW.x*outdata.Pos.w)/lightZW.y;			// (zL*wT)/wL == zL/wL post homo
 	outdata.Tex0PosZW.xy = indata.TexCoord0;
 	outdata.Tex0PosZW.zw = outdata.Pos.zw;

	return outdata;
}

float4 psShadowMapAlpha(VS2PS_ShadowMapAlpha indata) : COLOR
{
	clip(tex2D(sampler0, indata.Tex0PosZW.xy).a-shadowAlphaThreshold);
	return indata.Tex0PosZW.z / indata.Tex0PosZW.w;
}

float4 psShadowMapAlphaNV(VS2PS_ShadowMapAlpha indata) : COLOR
{
	return tex2D(sampler0, indata.Tex0PosZW.xy).a-shadowAlphaThreshold;
}

VS2PS_ShadowMap vsShadowMapPoint(APP2VS indata)
{
	VS2PS_ShadowMap outdata;
	
	// Compensate for lack of UBYTE4 on Geforce3
	int4 IndexVector = D3DCOLORtoUBYTE4(indata.BlendIndices);
	
	// Cast the vectors to arrays for use in the for loop below
	float BlendWeightsArray[1] = (float[1])indata.BlendWeights;
	int IndexArray[4] = (int[4])IndexVector;    
	
	float3 Pos = mul(indata.Pos, mBoneArray[IndexArray[0]]) * BlendWeightsArray[0];
	Pos += mul(indata.Pos, mBoneArray[IndexArray[1]]) * (1-BlendWeightsArray[0]);
	
	outdata.Pos = mul(float4(Pos.xyz, 1.0), mWorldViewProj); 
	
 	outdata.Pos.z *= paraboloidValues.x;
 	float d = length(outdata.Pos.xyz);
 	
 	outdata.Pos.xyz /= d;
	outdata.Pos.z += 1;
 	outdata.Pos.x /= outdata.Pos.z;
 	outdata.Pos.y /= outdata.Pos.z;
 	
	outdata.Pos.z = (d*paraboloidZValues.x) + paraboloidZValues.y;
	outdata.Pos.w = 1;
	
	outdata.PosZW = outdata.Pos.zw;

	return outdata;
}

VS2PS_ShadowMap vsShadowMapPointNV(APP2VS indata)
{
	VS2PS_ShadowMap outdata;
	
	// Compensate for lack of UBYTE4 on Geforce3
	int4 IndexVector = D3DCOLORtoUBYTE4(indata.BlendIndices);
	
	// Cast the vectors to arrays for use in the for loop below
	float BlendWeightsArray[1] = (float[1])indata.BlendWeights;
	int IndexArray[4] = (int[4])IndexVector;    
	
	float3 Pos = mul(indata.Pos, mBoneArray[IndexArray[0]]) * BlendWeightsArray[0];
	Pos += mul(indata.Pos, mBoneArray[IndexArray[1]]) * (1-BlendWeightsArray[0]);
	
	outdata.Pos = mul(float4(Pos.xyz, 1.0), mWorldViewProj); 
 	
	outdata.Pos.z *= paraboloidValues.x;
// outdata.PosZ = outdata.Pos.z/10.0 + 0.5;
// outdata.PosZ = outdata.Pos.z/paraboloidZValues.z;
	
 	float d = length(outdata.Pos.xyz);
 	outdata.Pos.xyz /= d;
	outdata.Pos.z += 1;
 	outdata.Pos.x /= outdata.Pos.z;
 	outdata.Pos.y /= outdata.Pos.z;
	outdata.Pos.z = (d*paraboloidZValues.x) + paraboloidZValues.y;
	outdata.Pos.w = 1;
	
	outdata.PosZW = outdata.Pos.zw;

	return outdata;
}

float4 psShadowMapPoint(VS2PS_ShadowMap indata) : COLOR
{
	// clip(indata.PosZW.x-0.5);
	clip(indata.PosZW.x);
	return indata.PosZW.xxxx;// - 0.5;
}

float4 psShadowMapPointNV(VS2PS_ShadowMap indata) : COLOR
{
	clip(indata.PosZW.x);
	return indata.PosZW.xxxx;
}

float4 psShadowMapNV(VS2PS_ShadowMap indata) : COLOR
{
// return indata.PosZW.x / indata.PosZW.y;
	return 0;
}

technique DrawShadowMapNV
{
	pass directionalspot
	{
		ColorWriteEnable = 0;
		
		AlphaBlendEnable = FALSE;
		ZEnable = TRUE;
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;
		CullMode = CW;

		ScissorTestEnable = TRUE;

		VertexShader = compile vs_1_1 vsShadowMap();
		PixelShader = compile ps_1_1 psShadowMapNV();
	}
	pass directionalspotalpha
	{
		ColorWriteEnable = 0;

		AlphaBlendEnable = FALSE;
		AlphaTestEnable = TRUE;
		AlphaRef = 0;
		ZEnable = TRUE;
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;
		CullMode = CCW;
		
		ScissorTestEnable = TRUE;

		VertexShader = compile vs_1_1 vsShadowMapAlpha();
		PixelShader = compile ps_1_1 psShadowMapAlphaNV();
	}
	pass point
	{
		ColorWriteEnable = 0;
		
		AlphaBlendEnable = FALSE;
		ZEnable = TRUE;
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;

		ScissorTestEnable = TRUE;

		VertexShader = compile vs_1_1 vsShadowMapPointNV();
		PixelShader = compile PS2_EXT psShadowMapPointNV();
	}
}

technique DrawShadowMap
{
	pass directionalspot
	{
		AlphaBlendEnable = FALSE;
		ZEnable = TRUE;
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;
		CullMode = CCW;
		
		ScissorTestEnable = TRUE;

		VertexShader = compile vs_1_1 vsShadowMap();
		PixelShader = compile PS2_EXT psShadowMap();
	}
	pass directionalspotalpha
	{
		AlphaBlendEnable = FALSE;
		ZEnable = TRUE;
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;
		CullMode = CCW;
		
		ScissorTestEnable = TRUE;

		VertexShader = compile vs_1_1 vsShadowMapAlpha();
		PixelShader = compile PS2_EXT psShadowMapAlpha();
	}
	pass point
	{
		AlphaBlendEnable = FALSE;
		ZEnable = TRUE;
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;

		ScissorTestEnable = TRUE;

		VertexShader = compile vs_1_1 vsShadowMapPoint();
		PixelShader = compile PS2_EXT psShadowMapPoint();
	}
}

