
/*
	Include header files
*/

#include "shaders/shared/RealityDepth.fxh"
#if !defined(_HEADERS_)
	#include "shared/RealityDepth.fxh"
#endif

/*
	Description:
	- Builds shadow map for staticmesh (buildings, static props)
	- Outputs used in RaShaderSTM.fx
*/

/*
	[Uniform data from app]
*/

float4x4 _WorldViewProj : WorldViewProjection;
float4x4 _WorldViewMat : WorldView;
float4x4 _WorldViewITMat : WorldViewIT;
float4x4 _ViewInverseMat : ViewI;
float4x4 _WorldMat : World;

float4 _AmbientColor : Ambient = { 0.0, 0.0, 0.0, 1.0 };
float4 _DiffColor : Diffuse = { 1.0, 1.0, 1.0, 1.0 };
float4 _SpecColor : Specular = { 0.0, 0.0, 0.0, 1.0 };

float4 _FuzzyLightScaleValue : FuzzyLightScaleValue = { 1.75, 1.75, 1.75, 1.0 };
float4 _LightmapOffset : LightmapOffset;
float _DropShadowClipheight : DROPSHADOWCLIPHEIGHT;
float4 _ParallaxScaleBias : PARALLAXSCALEBIAS;

float4x4 _vpLightMat : vpLightMat;
float4x4 _vpLightTrapezMat : vpLightTrapezMat;
float4 _PosUnpack : POSUNPACK;
float _TexUnpack : TEXUNPACK;

bool _AlphaTest : AlphaTest = false;

float4 _ParaboloidValues : ParaboloidValues;
float4 _ParaboloidZValues : ParaboloidZValues;

float4 _Attenuation : Attenuation; // SHADOW

float4 _LightPos : LightPosition : register(vs_3_0, c12)
<
	string Object = "PointLight";
	string Space = "World";
> = { 0.0, 0.0, 1.0, 1.0 };

float4 _LightDir : LightDirection;
float4 _SunColor : SunColor;
float4 _EyePos : EyePos;
float4 _EyePosObjectSpace : EyePosObjectSpace;

/*
	[Textures and Samplers]
*/

#define CREATE_SAMPLER(SAMPLER_NAME, TEXTURE, ADDRESS) \
	sampler SAMPLER_NAME = sampler_state \
	{ \
		Texture = (TEXTURE); \
		MinFilter = LINEAR; \
		MagFilter = LINEAR; \
		MipFilter = LINEAR; \
		AddressU = ADDRESS; \
		AddressV = ADDRESS; \
	}; \

texture Tex0: TEXLAYER0;
texture Tex1: TEXLAYER1;
texture Tex2: TEXLAYER2;
texture Tex3: TEXLAYER3;
texture Tex4: TEXLAYER4;
texture Tex5: TEXLAYER5;
texture Tex6: TEXLAYER6;
texture Tex7: TEXLAYER7;

CREATE_SAMPLER(SampleShadowAlpha, Tex0, WRAP)
CREATE_SAMPLER(SampleTex0_Wrap, Tex0, WRAP)
CREATE_SAMPLER(SampleColorLUT, Tex2, CLAMP)

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

VS2PS_Simple VS_StaticMesh_Simple(APP2VS Input)
{
	VS2PS_Simple Output = (VS2PS_Simple)0.0;
	Output.HPos = mul(float4(Input.Pos.xyz, 1.0), _WorldViewProj);
	Output.TexCoord = Input.TexCoord;
	return Output;
}

float4 PS_StaticMesh_Simple(VS2PS_Simple Input) : COLOR0
{
	float4 Ambient = float4(1.0, 1.0, 1.0, 0.8);
	float4 NormalMap = tex2D(SampleTex0_Wrap, Input.TexCoord);
	return NormalMap * Ambient;
}

technique alpha_one
{
	pass p0
	{
		ZEnable = TRUE;
		ZFunc = LESSEQUAL;
		ZWriteEnable = FALSE;
		CullMode = NONE;

		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = ONE;

		AlphaTestEnable = TRUE;
		AlphaRef = 0;
		AlphaFunc = GREATER;

		VertexShader = compile vs_3_0 VS_StaticMesh_Simple();
		PixelShader = compile ps_3_0 PS_StaticMesh_Simple();
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
	float4 DepthPos : TEXCOORD0;
	float2 Tex0 : TEXCOORD1;
};

VS2PS_ShadowMap VS_ShadowMap(APP2VS_ShadowMap Input)
{
	VS2PS_ShadowMap Output = (VS2PS_ShadowMap)0.0;

	float4 UnpackPos = Input.Pos * _PosUnpack;
	float4 WorldPos = mul(float4(UnpackPos.xyz, 1.0), _WorldMat);

	Output.HPos = GetMeshShadowProjection(WorldPos, _vpLightTrapezMat, _vpLightMat);
	Output.DepthPos = Output.HPos; // Output shadow depth

	Output.Tex0 = Input.Tex * _TexUnpack;

	return Output;
}

float4 PS_ShadowMap(VS2PS_ShadowMap Input) : COLOR0
{
	#if NVIDIA
		return 0;
	#else
		return Input.DepthPos.z / Input.DepthPos.w;
	#endif
}

float4 PS_ShadowMap_Alpha(VS2PS_ShadowMap Input) : COLOR0
{
	const float AlphaRef = 96.0 / 255.0;
	float4 Alpha = tex2D(SampleShadowAlpha, Input.Tex0);
	#if NVIDIA
		return Alpha;
	#else
		clip(Alpha.a - AlphaRef);
		return Input.DepthPos.z / Input.DepthPos.w;
	#endif
}

#define GET_RENDERSTATES_SHADOWMAP \
	CullMode = CW; \
	ZEnable = TRUE; \
	ZFunc = LESSEQUAL; \
	ZWriteEnable = TRUE; \
	ScissorTestEnable = TRUE; \
	AlphaBlendEnable = FALSE; \

technique DrawShadowMap
{
	pass DirectionalSpot
	{
		#if NVIDIA
			ColorWriteEnable = 0; // 0x0000000F;
		#endif

		GET_RENDERSTATES_SHADOWMAP
		VertexShader = compile vs_3_0 VS_ShadowMap();
		PixelShader = compile ps_3_0 PS_ShadowMap();
	}

	pass DirectionalSpotAlpha
	{
		#if NVIDIA
			ColorWriteEnable = 0; // 0x0000000F;
			AlphaTestEnable = TRUE;
			AlphaRef = 96;
			AlphaFunc = GREATER;
		#endif

		GET_RENDERSTATES_SHADOWMAP
		VertexShader = compile vs_3_0 VS_ShadowMap();
		PixelShader = compile ps_3_0 PS_ShadowMap_Alpha();
	}

	pass Point_
	{
		#if NVIDIA
			ColorWriteEnable = 0; // 0x0000000F;
		#endif

		GET_RENDERSTATES_SHADOWMAP
		VertexShader = compile vs_3_0 VS_ShadowMap();
		PixelShader = compile ps_3_0 PS_ShadowMap();
	}
}

// We actually don't need to have 2 techniques here
// but it is kept for back-compatibility with original BF2
technique DrawShadowMapNV
{
	pass DirectionalSpot
	{
		#if NVIDIA
			ColorWriteEnable = 0; // 0x0000000F;
		#endif

		GET_RENDERSTATES_SHADOWMAP
		VertexShader = compile vs_3_0 VS_ShadowMap();
		PixelShader = compile ps_3_0 PS_ShadowMap();
	}

	pass DirectionalSpotAlpha
	{
		#if NVIDIA
			ColorWriteEnable = 0; // 0x0000000F;
			AlphaTestEnable = TRUE;
			AlphaRef = 96;
			AlphaFunc = GREATER;
		#endif

		GET_RENDERSTATES_SHADOWMAP
		VertexShader = compile vs_3_0 VS_ShadowMap();
		PixelShader = compile ps_3_0 PS_ShadowMap_Alpha();
	}

	pass Point_
	{
		#if NVIDIA
			ColorWriteEnable = 0; // 0x0000000F;
		#endif

		GET_RENDERSTATES_SHADOWMAP
		VertexShader = compile vs_3_0 VS_ShadowMap();
		PixelShader = compile ps_3_0 PS_ShadowMap();
	}
}
