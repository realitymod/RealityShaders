#line 2 "StaticMesh.fx"

/*
	Description:
	- Builds shadow map for staticmesh (buildings, static props)
	- Outputs used in RaShaderSTM.fx
*/

#include "shaders/RealityGraphics.fx"

#include "shaders/CommonVertexLight.fx"

/*
	[Uniform data from app]
*/

uniform float4x4 _WorldViewProj : WorldViewProjection;
uniform float4x4 _WorldViewMat : WorldView;
uniform float4x4 _WorldViewITMat : WorldViewIT;
uniform float4x4 _ViewInverseMat : ViewI;
uniform float4x4 _WorldMat : World;

uniform float4 _AmbientColor : Ambient = { 0.0, 0.0, 0.0, 1.0 };
uniform float4 _DiffColor : Diffuse = { 1.0, 1.0, 1.0, 1.0 };
uniform float4 _SpecColor : Specular = { 0.0, 0.0, 0.0, 1.0 };
uniform float4 _FuzzyLightScaleValue : FuzzyLightScaleValue = { 1.75, 1.75, 1.75, 1.0 };
uniform float4 _LightmapOffset : LightmapOffset;
uniform float _DropShadowClipheight : DROPSHADOWCLIPHEIGHT;
uniform float4 _ParallaxScaleBias : PARALLAXSCALEBIAS;

uniform float4x4 _LightMat : vpLightMat;
uniform float4x4 _LightTrapezMat : vpLightTrapezMat;
uniform float4 _PosUnpack : POSUNPACK;
uniform float _TexUnpack : TEXUNPACK;

uniform bool _AlphaTest : AlphaTest = false;

uniform float4 _ParaboloidValues : ParaboloidValues;
uniform float4 _ParaboloidZValues : ParaboloidZValues;

uniform float4 _Attenuation : Attenuation; // SHADOW

uniform texture Texture_0: TEXLAYER0;
uniform texture Texture_1: TEXLAYER1;
uniform texture Texture_2: TEXLAYER2;
uniform texture Texture_3: TEXLAYER3;
uniform texture Texture_4: TEXLAYER4;
uniform texture Texture_5: TEXLAYER5;
uniform texture Texture_6: TEXLAYER6;
uniform texture Texture_7: TEXLAYER7;

float4 _LightPos : LightPosition : register(vs_3_0, c12)
<
	string Object = "PointLight";
	string Space = "World";
> = { 0.0, 0.0, 1.0, 1.0 };

float4 _LightDir : LightDirection;
float4 _SunColor : SunColor;
float4 _EyePos : EyePos;
float4 _EyePosObjectSpace : EyePosObjectSpace;

sampler Sampler_Shadow_Alpha = sampler_state
{
	Texture = (Texture_0);
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = LINEAR;
	AddressU = WRAP;
	AddressV = WRAP;
};

sampler Sampler_Wrap_0 = sampler_state
{
	Texture = (Texture_0);
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = LINEAR;
	AddressU = WRAP;
	AddressV = WRAP;
};

sampler Sampler_Color_LUT = sampler_state
{
	Texture = (Texture_2);
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	AddressU = Clamp;
	AddressV = Clamp;
};




struct APP2VS
{
	float4 Pos : POSITION;
	float3 Normal : NORMAL;
	float2 TexCoord : TEXCOORD0;
	float3 Tan : TANGENT;
	float3 Binorm : BINORMAL;
};

struct VS2PS_Simple
{
	float4 HPos : POSITION;
	float2 TexCoord : TEXCOORD0;
};

VS2PS_Simple StaticMesh_Simple_VS(APP2VS Input, uniform float4x4 WorldViewProj)
{
	VS2PS_Simple Output;
	Output.HPos = mul(float4(Input.Pos.xyz, 1.0), WorldViewProj);
	Output.TexCoord = Input.TexCoord;
	return Output;
}

float4 StaticMesh_Simple_PS(VS2PS_Simple Input) : COLOR
{
	float4 Ambient = float4(1.0, 1.0, 1.0, 0.8);
	float4 NormalMap = tex2D(Sampler_Wrap_0, Input.TexCoord);
	return NormalMap * Ambient;
}

technique alpha_one
{
	pass p0
	{
		ZEnable = TRUE;
		ZWriteEnable = FALSE;
		CullMode = NONE;
		AlphaBlendEnable = TRUE;

		SrcBlend = SRCALPHA;
		DestBlend = ONE;

		AlphaTestEnable = TRUE;
		AlphaRef = 0;
		AlphaFunc = GREATER;

		VertexShader = compile vs_3_0 StaticMesh_Simple_VS(_WorldViewProj);
		PixelShader = compile ps_3_0 StaticMesh_Simple_PS();
	}
}




struct APP2VS_ShadowMap
{
	float4 Pos : POSITION;
	float2 Tex : TEXCOORD0;
};

struct VS2PS_ShadowMap
{
	float4 HPos : POSITION;
	float2 PosZW : TEXCOORD0;
};

struct VS2PS_ShadowMap_Alpha
{
	float4 HPos : POSITION;
	float2 Tex : TEXCOORD0;
	float2 PosZW : TEXCOORD1;
};

float4 GetShadowProjCoords(float4 Pos, float4x4 matTrap, float4x4 matLight)
{
 	float4 shadowcoords = mul(Pos, matTrap);
 	float2 lightZW = mul(Pos, matLight).zw;
	shadowcoords.z = (lightZW.x*shadowcoords.w) / lightZW.y; // (zL*wT)/wL == zL/wL post homo
	return shadowcoords;
}

VS2PS_ShadowMap ShadowMap_VS(APP2VS_ShadowMap Input)
{
	VS2PS_ShadowMap Output;

 	float4 UnpackPos = float4(Input.Pos.xyz * _PosUnpack.xyz, 1.0);
 	float4 WorldPos = mul(UnpackPos, _WorldMat);
	Output.HPos = GetShadowProjCoords(float4(WorldPos.xyz, 1.0), _LightTrapezMat, _LightMat);
 	Output.PosZW.xy = Output.HPos.zw;
	return Output;
}

VS2PS_ShadowMap_Alpha ShadowMap_Alpha_VS(APP2VS_ShadowMap Input)
{
	VS2PS_ShadowMap_Alpha Output;

 	float4 UnpackPos = float4(Input.Pos.xyz * _PosUnpack.xyz, 1.0);
 	float4 WorldPos = mul(UnpackPos, _WorldMat);
	Output.HPos = GetShadowProjCoords(WorldPos, _LightTrapezMat, _LightMat);
 	Output.PosZW.xy = Output.HPos.zw;
	Output.Tex = Input.Tex * _TexUnpack;
	return Output;
}

float4 ShadowMap_PS(VS2PS_ShadowMap Input) : COLOR
{
	#if NVIDIA
		return 0;
	#else
		return Input.PosZW.x / Input.PosZW.y;
	#endif
}

float4 ShadowMap_Alpha_PS(VS2PS_ShadowMap_Alpha Input) : COLOR
{
	const float AlphaRef = 96.0f / 255.0f;
	float4 Alpha = tex2D(Sampler_Shadow_Alpha, Input.Tex);
	#if NVIDIA
		return Alpha;
	#else
		clip(Alpha.a - AlphaRef);
		return Input.PosZW.x/Input.PosZW.y;
	#endif
}

technique DrawShadowMap
{
	pass directionalspot
	{
		#if NVIDIA
			ColorWriteEnable = 0; // 0x0000000F;
		#endif

		AlphaBlendEnable = FALSE;
		ZEnable = TRUE;
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;
		ScissorTestEnable = TRUE;

		VertexShader = compile vs_3_0 ShadowMap_VS();
		PixelShader = compile ps_3_0 ShadowMap_PS();
	}

	pass directionalspotalpha
	{
		#if NVIDIA
			ColorWriteEnable = 0; // 0x0000000F;
			AlphaTestEnable = TRUE;
			AlphaRef = 96;
			AlphaFunc = GREATER;
		#endif

		CullMode = CW;
		AlphaBlendEnable = FALSE;
		ZEnable = TRUE;
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;
		ScissorTestEnable = TRUE;

		VertexShader = compile vs_3_0 ShadowMap_Alpha_VS();
		PixelShader = compile ps_3_0 ShadowMap_Alpha_PS();
	}

	pass point_
	{
		#if NVIDIA
			ColorWriteEnable = 0; // 0x0000000F;
		#endif

		AlphaBlendEnable = FALSE;
		ZEnable = TRUE;
		ZWriteEnable = TRUE;
		ScissorTestEnable = TRUE;

		VertexShader = compile vs_3_0 ShadowMap_VS();
		PixelShader = compile ps_3_0 ShadowMap_PS();
	}
}
//#endif

// We actually don't need to have 2 techniques here
// but it is kept for back-compatibility with original BF2
technique DrawShadowMapNV
{
	pass directionalspot
	{
		#if NVIDIA
			ColorWriteEnable = 0; // 0x0000000F;
		#endif

		AlphaBlendEnable = FALSE;
		ZEnable = TRUE;
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;
		ScissorTestEnable = TRUE;

		VertexShader = compile vs_3_0 ShadowMap_VS();
		PixelShader = compile ps_3_0 ShadowMap_PS();
	}

	pass directionalspotalpha
	{
		#if NVIDIA
			ColorWriteEnable = 0; // 0x0000000F;
			AlphaTestEnable = TRUE;
			AlphaRef = 96;
			AlphaFunc = GREATER;
		#endif

		CullMode = CW;

		AlphaBlendEnable = FALSE;
		ZEnable = TRUE;
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;
		ScissorTestEnable = TRUE;

		VertexShader = compile vs_3_0 ShadowMap_Alpha_VS();
		PixelShader = compile ps_3_0 ShadowMap_Alpha_PS();
	}

	pass point_
	{
		#if NVIDIA
			ColorWriteEnable = 0; // 0x0000000F;
		#endif

		AlphaBlendEnable = FALSE;
		ZEnable = TRUE;
		ZWriteEnable = TRUE;
		ScissorTestEnable = TRUE;

		VertexShader = compile vs_3_0 ShadowMap_VS();
		PixelShader = compile ps_3_0 ShadowMap_PS();
	}
}
