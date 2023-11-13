#line 2 "StaticMesh.fx"
#include "Shaders/commonVertexLight.fx"

// UNIFORM INPUTS
float4x4 viewProjMatrix : WorldViewProjection : register(c0);  
float4x4 worldViewMatrix : WorldView; //: register(vs_1_1, c8);
float4x4 worldViewITMatrix : WorldViewIT; //: register(vs_1_1, c8);
float4x4 viewInverseMatrix : ViewI; //: register(vs_1_1, c8);
// float4x3 mOneBoneSkinning[26]: matONEBONESKINNING : register(c15) < bool sparseArray = true; int arrayStart = 15; >;
float4x4 worldMatrix : World;// : register(vs_1_1, c0);  

float4 ambColor : Ambient = {0.0, 0.0, 0.0, 1.0};
float4 diffColor : Diffuse = {1.0, 1.0, 1.0, 1.0};
float4 specColor : Specular = {0.0, 0.0, 0.0, 1.0};
float4 fuzzyLightScaleValue : FuzzyLightScaleValue = {1.75,1.75,1.75,1};
float4 lightmapOffset : LightmapOffset;
float dropShadowClipheight : DROPSHADOWCLIPHEIGHT;
float4 parallaxScaleBias : PARALLAXSCALEBIAS;

bool alphaTest : AlphaTest = false;

float4 paraboloidValues : ParaboloidValues;
float4 paraboloidZValues : ParaboloidZValues;

texture texture0: TEXLAYER0;
texture texture1: TEXLAYER1;
texture texture2: TEXLAYER2;
texture texture3: TEXLAYER3;
texture texture4: TEXLAYER4;
texture texture5: TEXLAYER5;
texture texture6: TEXLAYER6;
texture texture7: TEXLAYER7;

// sampler diffuseSampler = sampler_state
sampler samplerWrap0 = sampler_state
{
	Texture = <texture0>;
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
	MipMapLodBias = 0;
	AddressU = Wrap;
	AddressV = Wrap;
};

// sampler normalSampler = sampler_state
sampler samplerWrap1 = sampler_state
{
	Texture = <texture1>;
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
	MipMapLodBias = 0;
	AddressU = Wrap;
	AddressV = Wrap;
};

sampler samplerWrap2 = sampler_state
{
	Texture = <texture2>;
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
	MipMapLodBias = 0;
	AddressU = Wrap;
	AddressV = Wrap;
};

sampler samplerWrap3 = sampler_state
{
	Texture = <texture3>;
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
	MipMapLodBias = 0;
	AddressU = Wrap;
	AddressV = Wrap;
};

sampler samplerWrap4 = sampler_state
{
	Texture = <texture4>;
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
	MipMapLodBias = 0;
	AddressU = Wrap;
	AddressV = Wrap;
};

sampler samplerWrap5 = sampler_state
{
	Texture = <texture5>;
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
	MipMapLodBias = 0;
	AddressU = Wrap;
	AddressV = Wrap;
};

sampler samplerWrap6 = sampler_state
{
	Texture = <texture6>;
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
	MipMapLodBias = 0;
	AddressU = Wrap;
	AddressV = Wrap;
};

sampler samplerWrap7 = sampler_state
{
	Texture = <texture7>;
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
	MipMapLodBias = 0;
	AddressU = Wrap;
	AddressV = Wrap;
};

sampler samplerWrapAniso0 = sampler_state
{
	Texture = <texture0>;
	MinFilter = Anisotropic;
	MagFilter = Linear;
	MipFilter = Linear;
	MipMapLodBias = 0;
	AddressU = Wrap;
	AddressV = Wrap;
	MaxAnisotropy = 8;
};


sampler samplerWrapAniso1 = sampler_state
{
	Texture = <texture1>;
	MinFilter = Anisotropic;
	MagFilter = Linear;
	MipFilter = Linear;
	MipMapLodBias = 0;
	AddressU = Wrap;
	AddressV = Wrap;
	MaxAnisotropy = 8;
};

sampler samplerWrapAniso2 = sampler_state
{
	Texture = <texture2>;
	MinFilter = Anisotropic;
	MagFilter = Linear;
	MipFilter = Linear;
	MipMapLodBias = 0;
	AddressU = Wrap;
	AddressV = Wrap;
};

sampler samplerWrapAniso3 = sampler_state
{
	Texture = <texture3>;
	MinFilter = Anisotropic;
	MagFilter = Linear;
	MipFilter = Linear;
	MipMapLodBias = 0;
	AddressU = Wrap;
	AddressV = Wrap;
	MaxAnisotropy = 8;
};

sampler samplerWrapAniso4 = sampler_state
{
	Texture = <texture4>;
	MinFilter = Anisotropic;
	MagFilter = Linear;
	MipFilter = Linear;
	MipMapLodBias = 0;
	AddressU = Wrap;
	AddressV = Wrap;
	MaxAnisotropy = 8;
};

sampler samplerWrapAniso5 = sampler_state
{
	Texture = <texture5>;
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
	MipMapLodBias = 0;
	AddressU = Wrap;
	AddressV = Wrap;
	MaxAnisotropy = 8;
};

sampler samplerWrapAniso6 = sampler_state
{
	Texture = <texture6>;
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
	MipMapLodBias = 0;
	AddressU = Wrap;
	AddressV = Wrap;
	MaxAnisotropy = 8;
};

sampler samplerWrapAniso7 = sampler_state
{
	Texture = <texture7>;
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
	MipMapLodBias = 0;
	AddressU = Wrap;
	AddressV = Wrap;
	MaxAnisotropy = 8;
};


sampler samplerClamp0 = sampler_state
{
	Texture = <texture0>;
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
	MipMapLodBias = 0;
	AddressU = Clamp;
	AddressV = Clamp;
};

// sampler normalSampler = sampler_state
sampler samplerClamp1 = sampler_state
{
	Texture = <texture1>;
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
	MipMapLodBias = 0;
	AddressU = Clamp;
	AddressV = Clamp;
};

sampler samplerClamp2 = sampler_state
{
	Texture = <texture2>;
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
	MipMapLodBias = 0;
	AddressU = Clamp;
	AddressV = Clamp;
};

sampler samplerClamp3 = sampler_state
{
	Texture = <texture3>;
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
	MipMapLodBias = 0;
	AddressU = Clamp;
	AddressV = Clamp;
};

sampler samplerClamp4 = sampler_state
{
	Texture = <texture4>;
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
	MipMapLodBias = 0;
	AddressU = Clamp;
	AddressV = Clamp;
};

sampler samplerClamp5 = sampler_state
{
	Texture = <texture5>;
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
	MipMapLodBias = 0;
	AddressU = Clamp;
	AddressV = Clamp;
};

sampler samplerClamp6 = sampler_state
{
	Texture = <texture6>;
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
	MipMapLodBias = 0;
	AddressU = Clamp;
	AddressV = Clamp;
};

sampler samplerClamp7 = sampler_state
{
	Texture = <texture7>;
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
	MipMapLodBias = 0;
	AddressU = Clamp;
	AddressV = Clamp;
};

sampler sampler0clamppoint = sampler_state { Texture = (texture0); AddressU = CLAMP; AddressV = CLAMP; MinFilter = POINT; MagFilter = POINT; MipFilter = NONE; };
sampler sampler1clamppoint = sampler_state { Texture = (texture1); AddressU = CLAMP; AddressV = CLAMP; MinFilter = POINT; MagFilter = POINT; MipFilter = NONE; };
sampler sampler2clamppoint = sampler_state { Texture = (texture2); AddressU = CLAMP; AddressV = CLAMP; MinFilter = POINT; MagFilter = POINT; MipFilter = NONE; };
sampler sampler3clamppoint = sampler_state { Texture = (texture3); AddressU = CLAMP; AddressV = CLAMP; MinFilter = POINT; MagFilter = POINT; MipFilter = NONE; };
sampler sampler4clamppoint = sampler_state { Texture = (texture4); AddressU = CLAMP; AddressV = CLAMP; MinFilter = POINT; MagFilter = POINT; MipFilter = NONE; };
sampler sampler5clamppoint = sampler_state { Texture = (texture5); AddressU = CLAMP; AddressV = CLAMP; MinFilter = POINT; MagFilter = POINT; MipFilter = NONE; };
sampler sampler6clamppoint = sampler_state { Texture = (texture6); AddressU = CLAMP; AddressV = CLAMP; MinFilter = POINT; MagFilter = POINT; MipFilter = NONE; };

sampler sampler0wrappoint = sampler_state { Texture = (texture0); AddressU = WRAP; AddressV = WRAP; MinFilter = POINT; MagFilter = POINT; MipFilter = NONE; };
sampler sampler1wrappoint = sampler_state { Texture = (texture1); AddressU = WRAP; AddressV = WRAP; MinFilter = POINT; MagFilter = POINT; MipFilter = NONE; };
sampler sampler2wrappoint = sampler_state { Texture = (texture2); AddressU = WRAP; AddressV = WRAP; MinFilter = POINT; MagFilter = POINT; MipFilter = NONE; };
sampler sampler3wrappoint = sampler_state { Texture = (texture3); AddressU = WRAP; AddressV = WRAP; MinFilter = POINT; MagFilter = POINT; MipFilter = NONE; };
sampler sampler4wrappoint = sampler_state { Texture = (texture4); AddressU = WRAP; AddressV = WRAP; MinFilter = POINT; MagFilter = POINT; MipFilter = NONE; };
sampler sampler5wrappoint = sampler_state { Texture = (texture5); AddressU = WRAP; AddressV = WRAP; MinFilter = POINT; MagFilter = POINT; MipFilter = NONE; };
sampler sampler6wrappoint = sampler_state { Texture = (texture6); AddressU = WRAP; AddressV = WRAP; MinFilter = POINT; MagFilter = POINT; MipFilter = NONE; };


sampler colorLUTSampler = sampler_state
{
    Texture = <texture2>;
	MinFilter = Linear;
	MagFilter = Linear;
	AddressU = Clamp;
	AddressV = Clamp;
};

sampler dummySampler = sampler_state
{
	MinFilter = Linear;
	MagFilter = Linear;
	AddressU = Clamp;
	AddressV = Clamp;
};

float4 lightPos : LightPosition : register(vs_1_1, c12)
<
    string Object = "PointLight";
    string Space = "World";
> = {0.0, 0.0, 1.0, 1.0};

float4 lightDir : LightDirection;
float4 sunColor : SunColor;
float4 eyePos : EyePos;
float4 eyePosObjectSpace : EyePosObjectSpace;

struct appdata {
    float4 Pos : POSITION;    
    float3 Normal : NORMAL;
    float2 TexCoord : TEXCOORD0;
    float3 Tan : TANGENT;
    float3 Binorm : BINORMAL;
};

struct VS_OUTPUT {
	float4 HPos : POSITION;
	float2 NormalMap : TEXCOORD0;
	float3 LightVec : TEXCOORD1;
	float3 HalfVec : TEXCOORD2;
	float2 DiffMap : TEXCOORD3;
};

struct VS_OUTPUTSS {
	float4 HPos : POSITION;
	float4 TanNormal : COLOR0;
	float4 TanLight : COLOR1;
	float2 NormalMap : TEXCOORD0;
	float3 LightVec : TEXCOORD1;
	float3 HalfVec : TEXCOORD2;
	float2 DiffMap : TEXCOORD3;
};

struct VS_OUTPUT2 {
    float4 HPos : POSITION;
    float2 TexCoord : TEXCOORD0;
	float4 Diffuse : COLOR;
};

struct VS_OUTPUT3 {
    float4 HPos : POSITION;
    float2 TexCoord : TEXCOORD0;
};


VS_OUTPUT3 VSimpleShader(appdata input, 
	uniform float4x4 wvp)
{
	VS_OUTPUT3 outdata;
 
	outdata.HPos = mul(float4(input.Pos.xyz, 1.0), wvp);
	outdata.TexCoord = input.TexCoord;

	return outdata;
}

technique alpha_one
{
	pass p0 
	{		
		ZEnable = true;
		ZWriteEnable = false;
		CullMode = NONE;
		AlphaBlendEnable = true;
		
		// SrcBlend = ONE;
		SrcBlend = SRCALPHA;
		DestBlend = ONE;
		
		AlphaTestEnable = true;
		AlphaRef = 0;
		AlphaFunc = GREATER;
		// FillMode = WIREFRAME;

		VertexShader = compile vs_1_1 VSimpleShader(viewProjMatrix);
		
		Sampler[0] = <samplerWrap0>;
		
		PixelShader = asm 
		{
			ps.1.1
			
			def c0,1,1,1,0.8 // ambient
			
			tex t0 // NormalMap
			mul r0, t0, c0 
			// mul r0.a, t0.a,c0.x
		};
	}
}

struct APPDATA_ShadowMap {
    float4 Pos : POSITION;    
};

struct VS2PS_ShadowMap
{
	float4 Pos : POSITION;
	float4 PosZW : TEXCOORD0;
};

VS2PS_ShadowMap vsShadowMap(APPDATA_ShadowMap input)
{
	VS2PS_ShadowMap Out;
   	   	 
 	Out.Pos = mul(input.Pos, viewProjMatrix);

	Out.PosZW.xy = Out.Pos.zw;
	
 	float4 wPos = mul(input.Pos, worldMatrix);
	Out.PosZW.zw = wPos.y - dropShadowClipheight;
	// Out.PosZW.zw = wPos.y - 50;
	// TL: change to real clipplane
	return Out;
}

float4 psShadowMap(VS2PS_ShadowMap indata) : COLOR
{
	clip(indata.PosZW.w);
// return clamp(indata.PosZW.x/25, 0.4, 1);
// return indata.PosZW.x + 0.5;
// return indata.PosZW.x/indata.PosZW.y;
	return 0;
}

VS2PS_ShadowMap vsShadowMapPoint(APPDATA_ShadowMap input)
{
	VS2PS_ShadowMap Out;
   	   	
   	// Compensate for lack of UBYTE4 on Geforce3
	// int4 IndexVector = D3DCOLORtoUBYTE4(input.BlendIndices);
	// int IndexArray[4] = (int[4])IndexVector;
 
  	float4 oPos = input.Pos;// float4(mul(input.Pos, mOneBoneSkinning[IndexArray[0]]), 1);
 	// float4 vPos = mul(oPos, viewProjMatrix);
 	Out.Pos = mul(oPos, viewProjMatrix);
 	
	Out.Pos.z *= paraboloidValues.x;
	Out.PosZW = Out.Pos.zwww/10.0 + 0.5;
	
 	float d = length(Out.Pos.xyz);
 	Out.Pos.xyz /= d;
	Out.Pos.z += 1;
 	Out.Pos.x /= Out.Pos.z;
 	Out.Pos.y /= Out.Pos.z;
	Out.Pos.z = (d*paraboloidZValues.x) + paraboloidZValues.y;
	Out.Pos.w = 1;
 	
	return Out;
}

float4 psShadowMapPoint(VS2PS_ShadowMap indata) : COLOR
{
	clip(indata.PosZW.x-0.5);
	return indata.PosZW.x - 0.5;
}

technique DrawShadowMap
{
	pass directionalspot 
	{
		AlphaBlendEnable = FALSE;
		ZEnable = TRUE;
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;
// CullMode = NONE;
		ScissorTestEnable = TRUE;
// ScissorTestEnable = FALSE;

		// ClipPlaneEnable = 1;	// Enable clipplane 0

		VertexShader = compile vs_1_1 vsShadowMap();
		PixelShader = compile ps_2_0 psShadowMap();
	}

	pass point 
	{
		AlphaBlendEnable = FALSE;
		ZEnable = TRUE;
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;

		ScissorTestEnable = TRUE;

		VertexShader = compile vs_1_1 vsShadowMapPoint();
		PixelShader = compile ps_2_0 psShadowMapPoint();
	}
}

#include "Shaders/StaticMesh_r3x0.fx"
#include "Shaders/StaticMesh_debug.fx"
#include "Shaders/StaticMesh_lightmapgen.fx"
