#line 2 "BundledMesh.fx"
#include "shaders/datatypes.fx"
//#include "shaders/common.dfx"

// UNIFORM INPUTS
float4x4 viewProjMatrix : WorldViewProjection;// : register(vs_1_1, c0);  
float4x4 viewInverseMatrix : ViewI; //: register(vs_1_1, c8);
float4x3 mOneBoneSkinning[26]: matONEBONESKINNING;// : register(c15) < bool sparseArray = true; int arrayStart = 15; >;
float4x4 viewMatrix : ViewMatrix;
float4x4 viewITMatrix : ViewITMatrix;

float4 ambColor : Ambient = {0.0f, 0.0f, 0.0f, 1.0f};
float4 diffColor : Diffuse = {1.0f, 1.0f, 1.0f, 1.0f};
float4 specColor : Specular = {0.0f, 0.0f, 0.0f, 1.0f};

float4x4 vpLightMat : vpLightMat;
float4x4 vpLightTrapezMat : vpLightTrapezMat;
float4 PosUnpack : POSUNPACK;

float2 vTexProjOffset : TEXPROJOFFSET;

float2 zLimitsInv : ZLIMITSINV;

float shadowAlphaThreshold : SHADOWALPHATHRESHOLD;
float4x4 mLightVP : LIGHTVIEWPROJ;
float4 vViewportMap : VIEWPORTMAP;

dword dwStencilRef : STENCILREF = 0;
float4 eyePos : EYEPOS = {0.0f, 0.0f, 1.0f, .25f};
float altitudeFactor : ALTITUDEFACTOR = 0.7f;

texture texture0: TEXLAYER0;
texture texture1: TEXLAYER1;
texture texture2: TEXLAYER2;
texture texture3: TEXLAYER3;
texture texture4: TEXLAYER4;

// SHADOW BUFFER DATA---
/*
texture ShadowMap:			ShadowMapTex;
sampler ShadowMapSampler = sampler_state
{
	Texture = (ShadowMap);
	AddressU = CLAMP;
	AddressV = CLAMP;
	MinFilter = POINT;
	MagFilter = POINT;
	MipFilter = NONE;
};

texture ShadowMapOccluder:	ShadowMapOccluderTex;
sampler ShadowMapOccluderSampler = sampler_state
{
	Texture = (ShadowMapOccluder);
	AddressU = CLAMP;
	AddressV = CLAMP;
	MinFilter = POINT;
	MagFilter = POINT;
	MipFilter = NONE;
};
*/

float4x4 ViewPortMatrix:	ViewPortMatrix;
float4 ViewportMap:	ViewportMap;

bool alphaBlendEnable:	AlphaBlendEnable;

sampler sampler0 = sampler_state { Texture = (texture0); AddressU = CLAMP; AddressV = CLAMP; MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = LINEAR; };
sampler sampler1 = sampler_state { Texture = (texture1); AddressU = CLAMP; AddressV = CLAMP; MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = LINEAR; };
sampler sampler2 = sampler_state { Texture = (texture2); AddressU = CLAMP; AddressV = CLAMP; MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = LINEAR; };
sampler sampler3 = sampler_state { Texture = (texture3); AddressU = CLAMP; AddressV = CLAMP; MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = LINEAR; };
// sampler sampler3 = sampler_state { Texture = (texture3); };
sampler sampler1point = sampler_state { Texture = (texture1); AddressU = CLAMP; AddressV = CLAMP; MinFilter = POINT; MagFilter = POINT; };
sampler sampler2point = sampler_state { Texture = (texture2); AddressU = CLAMP; AddressV = CLAMP; MinFilter = POINT; MagFilter = POINT; };

sampler samplerNormal2 = sampler_state { Texture = (texture2); AddressU = WRAP; AddressV = WRAP; MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = LINEAR; };
samplerCUBE samplerCube2 = sampler_state { Texture = (texture2); AddressU = WRAP; AddressV = WRAP; MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = LINEAR; };
samplerCUBE samplerCube3 = sampler_state { Texture = (texture3); AddressU = WRAP; AddressV = WRAP; MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = LINEAR; };
samplerCUBE samplerCube4 = sampler_state { Texture = (texture4); AddressU = WRAP; AddressV = WRAP; MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = LINEAR; };

sampler sampler2Aniso = sampler_state 
{ 
	Texture = (texture2); 
	AddressU = CLAMP; 
	AddressV = CLAMP; 
	MinFilter = Anisotropic;
	MagFilter = LINEAR; 
	MipFilter = LINEAR; 
	MaxAnisotropy = 8;
};

float4 lightPos : LightPosition;

// float4 eyePos;

float4 lightDir : LightDirection;

// offset x/y heightmapsize z / hemilerpbias w
float4 hemiMapInfo : HemiMapInfo;

// float heightmapSize : HeightmapSize;
// float hemiLerpBias : HemiLerpBias;
float normalOffsetScale : NormalOffsetScale;

float4 skyColor : SkyColor;
float4 ambientColor : AmbientColor;
float4 sunColor : SunColor;

float attenuationSqrInv : AttenuationSqrInv;
float4 lightColor : LightColor;
float coneAngle : ConeAngle;

float4 paraboloidValues : ParaboloidValues;
float4 paraboloidZValues : ParaboloidZValues;

float4x3 uvMatrix[8]: UVMatrix;

sampler diffuseSampler = sampler_state
{
	Texture = <texture0>;
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
// MipMapLodBias = 0;
	AddressU = Wrap;
	AddressV = Wrap;
};

sampler normalSampler = sampler_state
{
	Texture = <texture1>;
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
// MipMapLodBias = 0;
	AddressU = Wrap;
	AddressV = Wrap;
};

sampler dummySampler = sampler_state
{
	MinFilter = Linear;
	MagFilter = Linear;
	AddressU = Clamp;
	AddressV = Clamp;
};

sampler colorLUTSampler = sampler_state
{
	Texture = <texture2>;
	MinFilter = Linear;
	MagFilter = Linear;
	AddressU = Clamp;
	AddressV = Clamp;
};

struct appdata {
	float4 Pos : POSITION;    
	float3 Normal : NORMAL;
	float4 BlendIndices : BLENDINDICES;  
	float2 TexCoord : TEXCOORD0;
	float3 Tan : TANGENT;
	float3 Binorm : BINORMAL;
};

struct appdataDiffuseZ
{
	float4 Pos : POSITION;    
	float4 BlendIndices : BLENDINDICES;  
	float2 TexCoord : TEXCOORD0;
};

struct appdataDiffuseZAnimatedUV
{
	float4 Pos : POSITION;    
	float4 BlendIndices : BLENDINDICES;  
	float2 TexCoord0 : TEXCOORD0;
	float2 TexCoord1 : TEXCOORD1;
};

struct appdataAnimatedUV {
	float4 Pos : POSITION;    
	float3 Normal : NORMAL;
	float4 BlendIndices : BLENDINDICES;  
	float2 TexCoord0 : TEXCOORD0;
	float2 TexCoord1 : TEXCOORD1;
	float3 Tan : TANGENT;
	float3 Binorm : BINORMAL;
};

struct VS_OUTPUT {
	float4 HPos : POSITION;
	float2 NormalMap : TEXCOORD0;
	float3 LightVec : TEXCOORD1;
	float3 HalfVec : TEXCOORD2;
	float2 DiffMap : TEXCOORD3;
	float Fog : FOG;
};

struct VS_OUTPUT20 {
	float4 HPos : POSITION;
	float2 Tex0 : TEXCOORD0;
	float3 LightVec : TEXCOORD1;
	float3 HalfVec : TEXCOORD2;
	float Fog : FOG;
};


struct VS_OUTPUTSS {
	float4 HPos : POSITION;
	float4 TanNormal : COLOR0;
	float4 TanLight : COLOR1;
	float2 NormalMap : TEXCOORD0;
	float3 LightVec : TEXCOORD1;
	float3 HalfVec : TEXCOORD2;
	float2 DiffMap : TEXCOORD3;
	float Fog : FOG;
};

struct VS_OUTPUT2 {
	float4 HPos : POSITION;
	float2 TexCoord : TEXCOORD0;
	float4 Diffuse : COLOR;
	float Fog : FOG;
};


VS_OUTPUT bumpSpecularVertexShaderBlinn1
(
	appdata input,
	uniform float4x4 ViewProj,
	uniform float4x4 ViewInv,
	uniform float4 LightPos
)
{
	VS_OUTPUT Out = (VS_OUTPUT)0;
   	
   	float4 Constants = float4(0.5, 0.5, 0.5, 1.0);
   	
   	// Compensate for lack of UBYTE4 on Geforce3
	int4 IndexVector = D3DCOLORtoUBYTE4(input.BlendIndices);
	int IndexArray[4] = (int[4])IndexVector;
 
 	float3 Pos = mul(input.Pos, mOneBoneSkinning[IndexArray[0]]);
 	Out.HPos = mul(float4(Pos.xyz, 1.0f), ViewProj);
 	
	// Cross product to create BiNormal
	float3 binormal = normalize(cross(input.Tan, input.Normal));
	
	// Need to calculate the WorldI based on each matBone skinning world matrix
	float3x3 TanBasis = float3x3(input.Tan, 
						binormal, 
						input.Normal);
	// Calculate WorldTangent directly... inverse is the transpose for affine rotations
	float3x3 worldI = transpose(mul(TanBasis, mOneBoneSkinning[IndexArray[0]]));

	// Pass-through texcoords
	Out.NormalMap = input.TexCoord;
	Out.DiffMap = input.TexCoord;

	// Transform Light pos to Object space
// float4 matsLightDir = float4(0.2, 0.8, -0.2, 1.);
// float3 matsLightDir = float3(0.0, 1.0, 0.0);
	float3 matsLightDir = float3(0.5, 0.5, 0.0);
	float3 normalizedTanLightVec = normalize(mul(matsLightDir, worldI));

	Out.LightVec = normalizedTanLightVec;

	// Transform eye pos to tangent space 
	float3 worldEyeVec = ViewInv[3].xyz - Pos;
	float3 tanEyeVec = mul(worldEyeVec, worldI);

	Out.HalfVec = normalize(normalizedTanLightVec + normalize(tanEyeVec));
	Out.Fog = 0;// calcFog(Out.HPos.w);
	
	return Out;
}

VS_OUTPUT20 bumpSpecularVertexShaderBlinn20
(
	appdata input,
	uniform float4x4 ViewProj,
	uniform float4x4 ViewInv,
	uniform float4 LightPos
)
{
	VS_OUTPUT20 Out = (VS_OUTPUT20)0;
   	
   	float4 Constants = float4(0.5, 0.5, 0.5, 1.0);
   	
   	// Compensate for lack of UBYTE4 on Geforce3
	int4 IndexVector = D3DCOLORtoUBYTE4(input.BlendIndices);
	int IndexArray[4] = (int[4])IndexVector;
 
 	float3 Pos = mul(input.Pos, mOneBoneSkinning[IndexArray[0]]);
 	Out.HPos = mul(float4(Pos.xyz, 1.0), ViewProj);
 	
	// Cross product to create BiNormal
	float3 binormal = normalize(cross(input.Tan, input.Normal));
	
	// Need to calculate the WorldI based on each matBone skinning world matrix
	float3x3 TanBasis = float3x3(input.Tan, 
						binormal, 
						input.Normal);
	// Calculate WorldTangent directly... inverse is the transpose for affine rotations
	float3x3 worldI = transpose(mul(TanBasis, mOneBoneSkinning[IndexArray[0]]));

	// Pass-through texcoords
	Out.Tex0 = input.TexCoord;

	// Transform Light pos to Object space
// float4 matsLightDir = float4(0.2, 0.8, -0.2, 1.0);
// float3 matsLightDir = float3(0.0, 1.0, 0.0);
	float3 matsLightDir = float3(0.5, 0.5, 0.0);
	float3 normalizedTanLightVec = normalize(mul(matsLightDir, worldI));

	Out.LightVec = normalizedTanLightVec;

	// Transform eye pos to tangent space 
	float3 worldEyeVec = ViewInv[3].xyz - Pos;
	float3 tanEyeVec = mul(worldEyeVec, worldI);

	Out.HalfVec = normalize(normalizedTanLightVec + normalize(tanEyeVec));
	Out.Fog = 0;// calcFog(Out.HPos.w);
	
	return Out;
}


float4 PShade2(VS_OUTPUT20 i)
: COLOR 
{
    float4 cosang, tDiffuse, tNormal, col, tShadow;
    float3 tLight;
    
    // Sample diffuse texture and Normal map 
    tDiffuse = tex2D(diffuseSampler, i.Tex0);    
	
    // sample tLight (_bx2 = 2 * source � 1)
    tNormal = 2 * tex2D(normalSampler, i.Tex0) - 1;
    tLight = 2 * i.LightVec - 1;

	// return float4(tLight.xyz,1.f);
	      
    // DP Lighting in tangent space (where normal map is based)
    // Modulate with Diffuse texture
    col = dot(tNormal.xyz, tLight) * tDiffuse;    

    // N.H for specular term
    cosang = dot(tNormal.xyz,i.HalfVec);    
    // Raise to a power for falloff
    cosang = pow(cosang, 32)*tNormal.w;  // try changing the power to 255!  
	
	// return float4(tNormal.www,1.0);
	// return float4(cosang.xyz,1.0);
	// return float4(col.xyz,1.0);
    // Sample shadow texture
    tShadow = tex2D(sampler3, i.Tex0);    
	
	// return float4(tShadow.xyz,1.0);
    // Add to diffuse lit texture value
    float4 res = (col + cosang)*tShadow;
    // float4 res = col*tShadow;
	return float4(res.xyz,tDiffuse.w);   
}

VS_OUTPUT2 diffuseVertexShader
(
	appdata input,
	uniform float4x4 ViewProj,
	uniform float4x4 ViewInv,
	uniform float4 LightPos,
	uniform float4 EyePos
)
{
	VS_OUTPUT2 Out = (VS_OUTPUT2)0;
   	
   	// Compensate for lack of UBYTE4 on Geforce3
	int4 IndexVector = D3DCOLORtoUBYTE4(input.BlendIndices);
    int IndexArray[4] = (int[4])IndexVector;
 
	// float3 Pos = input.Pos;
 	float3 Pos = mul(input.Pos, mOneBoneSkinning[IndexArray[0]]);
 	Out.HPos = mul(float4(Pos.xyz, 1.0), ViewProj);
 	// Out.HPos = mul(input.Pos, WorldViewProj);
	
	float3 Normal = input.Normal;
	// float3 Normal = mul(input.Normal, mOneBoneSkinning[IndexArray[0]]);
	Normal = normalize(Normal);

	// Pass-through texcoords
	Out.TexCoord = input.TexCoord;
	
	// Need to calculate the WorldI based on each matBone skinning world matrix
	// There must be a more efficient way to do this...
	// Inverse is simplified to M-1 = Rt * T, 
	// where Rt is the transpose of the rotaional part and T is the translation
	float4x4 worldI;
	float3x3 R;
	R[0] = float3(mOneBoneSkinning[IndexArray[0]][0].xyz);
	R[1] = float3(mOneBoneSkinning[IndexArray[0]][1].xyz);
	R[2] = float3(mOneBoneSkinning[IndexArray[0]][2].xyz);
	float3x3 Rtranspose = transpose(R);
	float3 T = mul(mOneBoneSkinning[IndexArray[0]][3],Rtranspose);
	worldI[0] = float4(Rtranspose[0].xyz,T.x); 
	worldI[1] = float4(Rtranspose[1].xyz,T.y); 
	worldI[2] = float4(Rtranspose[2].xyz,T.z); 
	worldI[3] = float4(0.0,0.0,0.0,1.0);

	// Transform Light pos to Object space
	float3 matsLightDir = float3(0.2, 0.8, -0.2);
	float3 lightDirObjSpace = mul(-matsLightDir, worldI);
	float3 normalizedLightVec = normalize(lightDirObjSpace);
	
	float color = 0.8 + max(0.0, dot(Normal, normalizedLightVec));
	Out.Diffuse = float4(color, color, color, 1.0);    
	Out.Fog = 0;// calcFog(Out.HPos.w);
	
	return Out;
}


technique Full_States <bool Restore = true;> {
	pass BeginStates {
		AlphaTestEnable = TRUE;
		AlphaRef = 0;
		AlphaFunc = GREATER;

		Sampler[1] = <dummySampler>;
		Sampler[2] = <colorLUTSampler>;
	}
	
	pass EndStates {
	}
}

technique Full
{
	pass p0 
	{		
 		VertexShader = compile vs_1_1 bumpSpecularVertexShaderBlinn1(viewProjMatrix,
										viewInverseMatrix,
										lightPos);

		Sampler[0] = <normalSampler>;
		Sampler[3] = <diffuseSampler>;
		
		PixelShader = asm 
		{
			ps.1.1
			def c0,0.4,0.4,0.4,1 // ambient
// def c0,0,0,0,1 // ambient
			def c1,1,1,1,1 // diffuse
			def c2,1,1,1,1 // specular
			
			tex t0 // NormalMap
			texm3x2pad t1, t0_bx2 // u = N'.L'
			texm3x2tex t2, t0_bx2 // v = N'.H', sample(u,v)
			tex t3 // DiffuseMap
			
			mad_sat r0, t2, c1, c0 // (diff.I * diff.C) + amb
			mul r0, t3, r0 // diff.Tex * diff&amb 
			
			mul r1, t0.a, t2.a // gloss * spec.I 
			mad_sat r0, r1, c2, r0 // (spec.I&gloss * spec.C) + diff&ambTex
		};
	}
}

technique Full20
{
	pass p0 
	{		
		ZEnable = true;
		ZWriteEnable = true;
		AlphaBlendEnable = false;
		AlphaTestEnable = true;
		AlphaRef = 0;
		AlphaFunc = GREATER;
		
		VertexShader = compile vs_1_1 bumpSpecularVertexShaderBlinn20(viewProjMatrix,
										viewInverseMatrix,
										lightPos);
										
		PixelShader = compile PS2_EXT PShade2();
										
	}
}

technique t1
{
	pass p0 
	{		
	
		ZEnable = true;
		ZWriteEnable = true;
		// CullMode = NONE;
		AlphaBlendEnable = false;
		AlphaTestEnable = true;
		AlphaRef = 0;
		AlphaFunc = GREATER;
		// FillMode = WIREFRAME;
		
 		VertexShader = compile vs_1_1 diffuseVertexShader(viewProjMatrix,
 															viewInverseMatrix,
 															lightPos,
 															eyePos);
		
		
		Sampler[0] = <diffuseSampler>;
		
		PixelShader = asm 
		{
			ps.1.1
			def c0,0,0,0,1 // ambient
			def c1,1,1,1,1 // diffuse
			def c2,1,1,1,1 // specular
			
			tex t0
			mul r0, t0, v0
		};
	}
}


struct VS_OUTPUT_Alpha
{
	float4 HPos : POSITION;
	float2 DiffuseMap : TEXCOORD0;
	float4 Tex1 : TEXCOORD1;
	float Fog : FOG;
};

struct VS_OUTPUT_AlphaEnvMap
{
	float4 HPos : POSITION;
	float2 DiffuseMap : TEXCOORD0;
	float4 TexPos : TEXCOORD1;
	float2 NormalMap : TEXCOORD2;
	float4 TanToCubeSpace1 : TEXCOORD3;
	float4 TanToCubeSpace2 : TEXCOORD4;
	float4 TanToCubeSpace3 : TEXCOORD5;
	float4 EyeVecAndReflection: TEXCOORD6;
	float Fog : FOG;
};

VS_OUTPUT_Alpha vsAlpha(appdata input, uniform float4x4 ViewProj)
{
	VS_OUTPUT_Alpha Out;
   	   	
   	// Compensate for lack of UBYTE4 on Geforce3
	int4 IndexVector = D3DCOLORtoUBYTE4(input.BlendIndices);
	int IndexArray[4] = (int[4])IndexVector;
 
 	float3 Pos = mul(input.Pos, mOneBoneSkinning[IndexArray[0]]);
 	Out.HPos = mul(float4(Pos.xyz, 1.0), ViewProj);
 	
	Out.DiffuseMap = input.TexCoord.xy;

	/*Out.Tex1.xy = Out.HPos.xy/Out.HPos.w;
 	Out.Tex1.xy = (Out.Tex1.xy + 1) / 2;
 	Out.Tex1.y = 1-Out.Tex1.y;
 	*/
 // Hacked to only support 800/600
 	Out.Tex1.xy = Out.HPos.xy/Out.HPos.w;
 	Out.Tex1.xy = (Out.Tex1.xy * 0.5) + 0.5;
 	Out.Tex1.y = 1-Out.Tex1.y;
  	Out.Tex1.xy += vTexProjOffset;
// Out.Tex1.x += 0.000625;
// Out.Tex1.y += 0.000833;
	Out.Tex1.xy = Out.Tex1.xy * Out.HPos.w;
	Out.Tex1.zw = Out.HPos.zw;
	Out.Fog = 0;// calcFog(Out.HPos.w);
	
	return Out;
}

float4 psAlpha(VS_OUTPUT_Alpha indata) : COLOR
{
	float4 projlight = tex2Dproj(sampler1, indata.Tex1);
	float4 OutCol;
	OutCol = tex2D(sampler0, indata.DiffuseMap);
	OutCol.rgb *= projlight.rgb;
	OutCol.rgb += projlight.a;
	return OutCol;
}

VS_OUTPUT_AlphaEnvMap vsAlphaEnvMap(appdata input, uniform float4x4 ViewProj)
{
	VS_OUTPUT_AlphaEnvMap Out = (VS_OUTPUT_AlphaEnvMap)0;
   	   	
   	// Compensate for lack of UBYTE4 on Geforce3
	int4 IndexVector = D3DCOLORtoUBYTE4(input.BlendIndices);
	int IndexArray[4] = (int[4])IndexVector;
 
 	float3 Pos = mul(input.Pos, mOneBoneSkinning[IndexArray[0]]);
 	Out.HPos = mul(float4(Pos.xyz, 1.0), ViewProj);
 	
	/*Out.Tex1.xy = Out.HPos.xy/Out.HPos.w;
 	Out.Tex1.xy = (Out.Tex1.xy + 1) / 2;
 	Out.Tex1.y = 1-Out.Tex1.y;
 	*/
 // Hacked to only support 800/600
 	Out.TexPos.xy = Out.HPos.xy/Out.HPos.w;
 	Out.TexPos.xy = (Out.TexPos.xy * 0.5) + 0.5;
 	Out.TexPos.y = 1-Out.TexPos.y;
 	Out.TexPos.xy += vTexProjOffset;
// Out.Tex1.x += 0.000625;
// Out.Tex1.y += 0.000833;
	Out.TexPos.xy = Out.TexPos.xy * Out.HPos.w;
	Out.TexPos.zw = Out.HPos.zw;

	// Pass-through texcoords
	Out.DiffuseMap = input.TexCoord;
	Out.NormalMap = input.TexCoord;
	// Cross product to create BiNormal
	float3 binormal = normalize(cross(input.Tan, input.Normal));
	
	// Need to calculate the TanToCubeState based on each matBone skinning world matrix
	float3x3 TanToObjectBasis;
	TanToObjectBasis[0] = float3(input.Tan.x, binormal.x, input.Normal.x);
	TanToObjectBasis[1] = float3(input.Tan.y, binormal.y, input.Normal.y);
	TanToObjectBasis[2] = float3(input.Tan.z, binormal.z, input.Normal.z);
	Out.TanToCubeSpace1.x = dot(mOneBoneSkinning[IndexArray[0]][0].xyz,TanToObjectBasis[0]);
	Out.TanToCubeSpace1.y = dot(mOneBoneSkinning[IndexArray[0]][1].xyz,TanToObjectBasis[0]);
	Out.TanToCubeSpace1.z = dot(mOneBoneSkinning[IndexArray[0]][2].xyz,TanToObjectBasis[0]);
	Out.TanToCubeSpace2.x = dot(mOneBoneSkinning[IndexArray[0]][0].xyz,TanToObjectBasis[1]);
	Out.TanToCubeSpace2.y = dot(mOneBoneSkinning[IndexArray[0]][1].xyz,TanToObjectBasis[1]);
	Out.TanToCubeSpace2.z = dot(mOneBoneSkinning[IndexArray[0]][2].xyz,TanToObjectBasis[1]);
	Out.TanToCubeSpace3.x = dot(mOneBoneSkinning[IndexArray[0]][0].xyz,TanToObjectBasis[2]);
	Out.TanToCubeSpace3.y = dot(mOneBoneSkinning[IndexArray[0]][1].xyz,TanToObjectBasis[2]);
	Out.TanToCubeSpace3.z = dot(mOneBoneSkinning[IndexArray[0]][2].xyz,TanToObjectBasis[2]);
	// Transform eye pos to tangent space 
	Out.EyeVecAndReflection.xyz =  Pos - eyePos.xyz; 
	Out.EyeVecAndReflection.w = eyePos.w;
	Out.Fog = 0;// calcFog(Out.HPos.w);
	return Out;
}

float4 psAlphaEnvMap(VS_OUTPUT_AlphaEnvMap indata) : COLOR
{
	float4 accumLight = tex2Dproj(sampler1, indata.TexPos);
	float4 outCol;
	outCol = tex2D(sampler0, indata.DiffuseMap);
	outCol.rgb *= accumLight.rgb;
	float4 normalmap = tex2D(sampler2, indata.NormalMap);
	float3 expandedNormal = (normalmap.xyz * 2) - 1;
	float3 worldNormal;
	worldNormal.x = dot(indata.TanToCubeSpace1.xyz,expandedNormal);
	worldNormal.y = dot(indata.TanToCubeSpace2.xyz,expandedNormal);
	worldNormal.z = dot(indata.TanToCubeSpace3.xyz,expandedNormal);
	float3 lookup = reflect(normalize(indata.EyeVecAndReflection.xyz),normalize(worldNormal));
	// return float4(lookup.rgb,1);
	float3 envmapColor = texCUBE(samplerCube3,lookup)*normalmap.a*indata.EyeVecAndReflection.w;

	outCol.rgb += accumLight.a + envmapColor;

	return outCol;
}


technique alpha
{
	pass p0 
	{		
		ZEnable = TRUE;
		ZWriteEnable = FALSE;
		CullMode = NONE;
		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;
		AlphaTestEnable = TRUE;
		AlphaRef = 0;
		AlphaFunc = GREATER;
		// TextureTransformFlags[1] = PROJECTED; // This doesn't work very well....

		VertexShader = compile vs_1_1 vsAlpha(viewProjMatrix);
		PixelShader = compile PS2_EXT psAlpha();
		/*Sampler[0] = <sampler0>;
		Sampler[1] = <sampler1>;

		PixelShader = asm 
		{
			ps.1.1

			tex t0 // DiffuseMap
			tex t1 // Accum light
			
			// mul r0.rgb, t0, t1
			//+mov r0.a, t0.a
			mov r0, t1
		};*/
	}

	pass p1EnvMap
	{
		ZEnable = TRUE;
		ZWriteEnable = FALSE;
		CullMode = NONE;
		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;
		AlphaTestEnable = TRUE;
		AlphaRef = 0;
		AlphaFunc = GREATER;
		// TextureTransformFlags[1] = PROJECTED; // This doesn't work very well....

		VertexShader = compile vs_1_1 vsAlphaEnvMap(viewProjMatrix);
		PixelShader = compile PS2_EXT psAlphaEnvMap();
	}
}

struct VS_OUTPUT_AlphaScope {
	float4 HPos : POSITION;
	float3 Tex0AndTrans : TEXCOORD0;
	float2 Tex1 : TEXCOORD1;
	float Fog : FOG;
};

VS_OUTPUT_AlphaScope vsAlphaScope(appdata input, uniform float4x4 ViewProj)
{
	VS_OUTPUT_AlphaScope Out;
   	   	
   	// Compensate for lack of UBYTE4 on Geforce3
	int4 IndexVector = D3DCOLORtoUBYTE4(input.BlendIndices);
	int IndexArray[4] = (int[4])IndexVector;
 
 	float3 Pos = mul(input.Pos, mOneBoneSkinning[IndexArray[0]]);
 	Out.HPos = mul(float4(Pos.xyz, 1.0), ViewProj);

 	float3 wNormal = mul(input.Normal, mOneBoneSkinning[IndexArray[0]]); 	
 	float3 worldEyeVec = normalize(viewInverseMatrix[3].xyz - Pos);

 	float f = dot(wNormal, worldEyeVec);
 	// f = step(0.99, f) * f;
 	f = smoothstep(0.965, 1.0, f);
 	Out.Tex0AndTrans.z = f;
 	 	 	 	 	
	Out.Tex0AndTrans.xy = input.TexCoord;

	Out.Tex1.xy = Out.HPos.xy/Out.HPos.w;
 	Out.Tex1.xy = (Out.Tex1.xy + 1) / 2;
 	Out.Tex1.y = 1-Out.Tex1.y;
 	Out.Fog = 0;// calcFog(Out.HPos.w);
		
	return Out;
}

technique alphascope
{
	pass p0 
	{		
		ZEnable = TRUE;
		ZWriteEnable = FALSE;
		CullMode = NONE;
		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;
		AlphaTestEnable = TRUE;
		AlphaRef = 0;
		AlphaFunc = GREATER;

		VertexShader = compile vs_1_1 vsAlphaScope(viewProjMatrix);
		
		Sampler[0] = <sampler0>;
		Sampler[1] = <sampler1>;

		PixelShader = asm 
		{
			ps.1.4
			
			texcrd r2.rgb, t0 // Get coords
			texld r1, t1 // Sample Accum light
			
			phase
			
			texld r0, t0 // Sample diff
						
			mul r0.rgb, r0, r1
			mul r0.a, 1-r2.b, r0.a
		};
	}
}

float4 calcShadowProjCoords(float4 Pos, float4x4 matTrap, float4x4 matLight)
{
 	float4 shadowcoords = mul(Pos, matTrap);
 	float2 lightZW = mul(Pos, matLight).zw;
	shadowcoords.z = (lightZW.x*shadowcoords.w) / lightZW.y;			// (zL*wT)/wL == zL/wL post homo
	return shadowcoords;
}


struct VS2PS_ShadowMap
{
	float4 HPos : POSITION;
	float2 PosZW : TEXCOORD0;
};

struct VS2PS_ShadowMapAlpha
{
	float4 HPos : POSITION;
	float4 Tex0PosZW : TEXCOORD0;
};

VS2PS_ShadowMap vsShadowMap(appdata input)
{
	VS2PS_ShadowMap Out = (VS2PS_ShadowMap)0;
   	  	
   	// Compensate for lack of UBYTE4 on Geforce3
	int4 IndexVector = D3DCOLORtoUBYTE4(input.BlendIndices);
	int IndexArray[4] = (int[4])IndexVector;
 
 	float4 unpackPos = input.Pos * PosUnpack;
 	float3 Pos = mul(unpackPos, mOneBoneSkinning[IndexArray[0]]);

 	Out.HPos = calcShadowProjCoords(float4(Pos.xyz, 1.0), vpLightTrapezMat, vpLightMat);
 	Out.PosZW = Out.HPos.zw;

	return Out;
}

float4 psShadowMap(VS2PS_ShadowMap indata) : COLOR
{
	return indata.PosZW.x / indata.PosZW.y;
}

VS2PS_ShadowMapAlpha vsShadowMapAlpha(appdata input)
{
	VS2PS_ShadowMapAlpha Out;
   	  	
   	// Compensate for lack of UBYTE4 on Geforce3
	int4 IndexVector = D3DCOLORtoUBYTE4(input.BlendIndices);
	int IndexArray[4] = (int[4])IndexVector;
 
 	float4 unpackPos = input.Pos * PosUnpack;
 	float3 Pos = mul(unpackPos, mOneBoneSkinning[IndexArray[0]]);
 	Out.HPos = calcShadowProjCoords(float4(Pos.xyz, 1.0), vpLightTrapezMat, vpLightMat);
 	
 	Out.Tex0PosZW.xy = input.TexCoord;
 	Out.Tex0PosZW.zw = Out.HPos.zw;
	
	return Out;
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

VS2PS_ShadowMap vsShadowMapPoint(appdata input)
{
	VS2PS_ShadowMap Out;
   	  	
   	// Compensate for lack of UBYTE4 on Geforce3
	int4 IndexVector = D3DCOLORtoUBYTE4(input.BlendIndices);
	int IndexArray[4] = (int[4])IndexVector;
 
 	float3 wPos = mul(input.Pos*PosUnpack, mOneBoneSkinning[IndexArray[0]]);
 	float3 hPos = wPos.xyz - lightPos;
	hPos.z *= paraboloidValues.x;
 
	// Out.PosZ = hPos.z/paraboloidValues.z + 0.5;
	
 	float d = length(hPos.xyz);
 	hPos.xyz /= d;
	hPos.z += 1;
 	Out.HPos.x = hPos.x / hPos.z;
 	Out.HPos.y = hPos.y / hPos.z;
	Out.HPos.z = (d*paraboloidZValues.x) + paraboloidZValues.y;
	Out.HPos.w = 1;
 
 	Out.PosZW = Out.HPos.zw;

	return Out;
}

float4 psShadowMapPoint(VS2PS_ShadowMap indata) : COLOR
{
// return 0.5;
	clip(indata.PosZW.x);
	return indata.PosZW.x;
}

VS2PS_ShadowMapAlpha vsShadowMapPointAlpha(appdata input)
{
	VS2PS_ShadowMapAlpha Out;
   	  	
   	// Compensate for lack of UBYTE4 on Geforce3
	int4 IndexVector = D3DCOLORtoUBYTE4(input.BlendIndices);
	int IndexArray[4] = (int[4])IndexVector;
 
 	float3 wPos = mul(input.Pos*PosUnpack, mOneBoneSkinning[IndexArray[0]]);
 	float3 hPos = wPos.xyz - lightPos;
	hPos.z *= paraboloidValues.x;
 
	// Out.PosZ = hPos.z/paraboloidValues.z + 0.5;
	
 	float d = length(hPos.xyz);
 	hPos.xyz /= d;
	hPos.z += 1;
 	Out.HPos.x = hPos.x / hPos.z;
 	Out.HPos.y = hPos.y / hPos.z;
	Out.HPos.z = (d*paraboloidZValues.x) + paraboloidZValues.y;
	Out.HPos.w = 1;
 
 	Out.Tex0PosZW.xy = input.TexCoord;
 	Out.Tex0PosZW.zw = Out.HPos.zw;

	return Out;
}

float4 psShadowMapPointAlpha(VS2PS_ShadowMapAlpha indata) : COLOR
{
	clip(tex2D(sampler0, indata.Tex0PosZW.xy).a-shadowAlphaThreshold);
	clip(indata.Tex0PosZW.z);
	return indata.Tex0PosZW.z;
}

float4 psShadowMapNV(VS2PS_ShadowMap indata) : COLOR
{
// return indata.PosZW.x / indata.PosZW.y;
// return float4(1, 0, 0, 1);
	return 0;
}

technique DrawShadowMapNV
{
	pass directionalspot
	{	
		ColorWriteEnable = 0; // for Fast-Z
		
		ZEnable = TRUE;
		ZFunc = LESSEQUAL;
		ZWriteEnable = TRUE;

		AlphaBlendEnable = FALSE;
		
		ScissorTestEnable = TRUE;
		CullMode = CW;
			
 		VertexShader = compile vs_1_1 vsShadowMap();
		PixelShader = compile ps_1_1 psShadowMapNV();
	}

	pass directionalspotalpha
	{	
		ColorWriteEnable = 0; // for Fast-Z
		
		ZEnable = TRUE;
		ZFunc = LESSEQUAL;
		ZWriteEnable = TRUE;
		
		ScissorTestEnable = TRUE;

 		VertexShader = compile vs_1_1 vsShadowMapAlpha();
		PixelShader = compile ps_1_1 psShadowMapAlphaNV();
	}

	pass point
	{	
		ColorWriteEnable = 0; // for Fast-Z
		
		ZEnable = TRUE;
		ZFunc = LESSEQUAL;
		ZWriteEnable = TRUE;

		ScissorTestEnable = TRUE;
	
 		VertexShader = compile vs_1_1 vsShadowMapPoint();
		PixelShader = compile ps_2_0 psShadowMapNV();
	}

	pass pointalpha
	{	
		ColorWriteEnable = 0; // for Fast-Z
		
		ZEnable = TRUE;
		ZFunc = LESSEQUAL;
		ZWriteEnable = TRUE;

		ScissorTestEnable = TRUE;
	
 		VertexShader = compile vs_1_1 vsShadowMapPointAlpha();
		PixelShader = compile PS2_EXT psShadowMapPointAlpha();
	}
}

technique DrawShadowMap
{
	pass directionalspot
	{	
		ZEnable = TRUE;
		ZFunc = LESSEQUAL;
		ZWriteEnable = TRUE;
		
		// CullMode = NONE;
		
		ScissorTestEnable = TRUE;
			
 		VertexShader = compile vs_1_1 vsShadowMap();
		PixelShader = compile PS2_EXT psShadowMap();
	}

	pass directionalspotalpha
	{	
		ZEnable = TRUE;
		ZFunc = LESSEQUAL;
		ZWriteEnable = TRUE;
		
		ScissorTestEnable = TRUE;
			
 		VertexShader = compile vs_1_1 vsShadowMapAlpha();
		PixelShader = compile PS2_EXT psShadowMapAlpha();
	}

	pass point
	{	
		ZEnable = TRUE;
		ZFunc = LESSEQUAL;
		ZWriteEnable = TRUE;

		ScissorTestEnable = TRUE;
	
 		VertexShader = compile vs_1_1 vsShadowMapPoint();
		PixelShader = compile PS2_EXT psShadowMapPoint();
	}

	pass pointalpha
	{	
		ZEnable = TRUE;
		ZFunc = LESSEQUAL;
		ZWriteEnable = TRUE;

		ScissorTestEnable = TRUE;
	
 		VertexShader = compile vs_1_1 vsShadowMapPointAlpha();
		PixelShader = compile PS2_EXT psShadowMapPointAlpha();
	}
}

//#include "Shaders/BundledMesh_nv3x.fx"
//#include "Shaders/BundledMesh_r3x0.fx"
#include "Shaders/BundledMesh_lightmapgen.fx"
//#include "Shaders/BundledMesh_editor.fx"
//#include "Shaders/BundledMesh_debug.fx"
//#include "Shaders/BundledMesh_leftover.fx"
