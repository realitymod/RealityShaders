
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

uniform float4 _LightPos : LightPosition : register(vs_3_0, c12)
<
	string Object = "PointLight";
	string Space = "World";
> = { 0.0, 0.0, 1.0, 1.0 };

uniform float4 _LightDir : LightDirection;
uniform float4 _SunColor : SunColor;
uniform float4 _EyePos : EyePos;
uniform float4 _EyePosObjectSpace : EyePosObjectSpace;

/*
	[Textures and Samplers]
*/

uniform texture Texture_0: TEXLAYER0;
uniform texture Texture_1: TEXLAYER1;
uniform texture Texture_2: TEXLAYER2;
uniform texture Texture_3: TEXLAYER3;
uniform texture Texture_4: TEXLAYER4;
uniform texture Texture_5: TEXLAYER5;
uniform texture Texture_6: TEXLAYER6;
uniform texture Texture_7: TEXLAYER7;

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
	MipFilter = LINEAR;
	AddressU = Clamp;
	AddressV = Clamp;
};

/*
	Normalmap shaders
*/

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

VS2PS_Simple StaticMesh_Simple_VS(APP2VS Input)
{
	VS2PS_Simple Output;
	Output.HPos = mul(float4(Input.Pos.xyz, 1.0), _WorldViewProj);
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

		VertexShader = compile vs_3_0 StaticMesh_Simple_VS();
		PixelShader = compile ps_3_0 StaticMesh_Simple_PS();
	}
}

/*
	Shadowmap shaders
*/

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

float4 GetShadowProjCoords(float4 Pos)
{
 	float4 shadowcoords = mul(Pos, _LightTrapezMat);
 	float2 lightZW = mul(Pos, _LightMat).zw;
	shadowcoords.z = (lightZW.x*shadowcoords.w) / lightZW.y; // (zL*wT)/wL == zL/wL post homo
	return shadowcoords;
}

VS2PS_ShadowMap ShadowMap_VS(APP2VS_ShadowMap Input)
{
	VS2PS_ShadowMap Output;
 	float4 UnpackPos = float4(Input.Pos.xyz * _PosUnpack.xyz, 1.0);
 	float4 WorldPos = mul(UnpackPos, _WorldMat);
	Output.HPos = GetShadowProjCoords(float4(WorldPos.xyz, 1.0));
 	Output.PosZW.xy = Output.HPos.zw;
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

struct VS2PS_ShadowMap_Alpha
{
	float4 HPos : POSITION;
	float2 Tex : TEXCOORD0;
	float2 PosZW : TEXCOORD1;
};

VS2PS_ShadowMap_Alpha ShadowMap_Alpha_VS(APP2VS_ShadowMap Input)
{
	VS2PS_ShadowMap_Alpha Output;
 	float4 UnpackPos = float4(Input.Pos.xyz * _PosUnpack.xyz, 1.0);
 	float4 WorldPos = mul(UnpackPos, _WorldMat);
	Output.HPos = GetShadowProjCoords(WorldPos);
	Output.Tex = Input.Tex * _TexUnpack;
 	Output.PosZW.xy = Output.HPos.zw;
	return Output;
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

#define STATICMESH_SHADOWMAP_RENDERSTATES \
	AlphaBlendEnable = FALSE; \
	ZEnable = TRUE; \
	ZWriteEnable = TRUE; \
	ZFunc = LESSEQUAL; \
	ScissorTestEnable = TRUE; \

#define STATICMESH_POINT_RENDERSTATES \
	AlphaBlendEnable = FALSE; \
	ZEnable = TRUE; \
	ZWriteEnable = TRUE; \
	ScissorTestEnable = TRUE; \

technique DrawShadowMap
{
	pass directionalspot
	{
		#if NVIDIA
			ColorWriteEnable = 0; // 0x0000000F;
		#endif

		STATICMESH_SHADOWMAP_RENDERSTATES
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
		STATICMESH_SHADOWMAP_RENDERSTATES
		VertexShader = compile vs_3_0 ShadowMap_Alpha_VS();
		PixelShader = compile ps_3_0 ShadowMap_Alpha_PS();
	}

	pass point_
	{
		#if NVIDIA
			ColorWriteEnable = 0; // 0x0000000F;
		#endif

		STATICMESH_POINT_RENDERSTATES
		VertexShader = compile vs_3_0 ShadowMap_VS();
		PixelShader = compile ps_3_0 ShadowMap_PS();
	}
}

// We actually don't need to have 2 techniques here
// but it is kept for back-compatibility with original BF2
technique DrawShadowMapNV
{
	pass directionalspot
	{
		#if NVIDIA
			ColorWriteEnable = 0; // 0x0000000F;
		#endif

		STATICMESH_SHADOWMAP_RENDERSTATES
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
		STATICMESH_SHADOWMAP_RENDERSTATES
		VertexShader = compile vs_3_0 ShadowMap_Alpha_VS();
		PixelShader = compile ps_3_0 ShadowMap_Alpha_PS();
	}

	pass point_
	{
		#if NVIDIA
			ColorWriteEnable = 0; // 0x0000000F;
		#endif

		STATICMESH_POINT_RENDERSTATES
		VertexShader = compile vs_3_0 ShadowMap_VS();
		PixelShader = compile ps_3_0 ShadowMap_PS();
	}
}
