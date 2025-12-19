#line 2 "RaShader1Dif.fx"

/*
	Include header files
*/

#include "shaders/RealityGraphics.fxh"
#include "shaders/shared/RealityDepth.fxh"
#include "shaders/shared/RealityDirectXTK.fxh"
#include "shaders/shared/RealityPixel.fxh"
#include "shaders/RaCommon.fxh"
#if !defined(_HEADERS_)
	#include "RealityGraphics.fxh"
	#include "shared/RealityDepth.fxh"
	#include "shared/RealityDirectXTK.fxh"
	#include "shared/RealityPixel.fxh"
	#include "RaCommon.fxh"
#endif

/*
	Description: Renders object's diffuse map
*/

float4 WorldSpaceCamPos;

texture DiffuseMap;
sampler SampleDiffuseMap = sampler_state
{
	Texture = (DiffuseMap);
	MipFilter = LINEAR;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	AddressU = WRAP;
	AddressV = WRAP;
};

string GlobalParameters[] =
{
	"FogColor",
	"FogRange",
	"WorldSpaceCamPos"
};

string TemplateParameters[] =
{
	"DiffuseMap",
	"ViewProjection",
	"AlphaTest"
};

string InstanceParameters[] =
{
	"World",
	"Transparency",
};

// INPUTS TO THE VERTEX SHADER FROM THE APP
string reqVertexElement[] =
{
	"Position",
	"TBase2D"
};

struct APP2VS
{
	float3 Pos : POSITION0;
	float2 Tex0 : TEXCOORD0;
};

struct VS2PS
{
	float4 HPos : POSITION;
	float4 Pos : TEXCOORD0;
	float2 Tex0 : TEXCOORD1;
};

struct PS2FB
{
	float4 Color : COLOR0;
	#if defined(LOG_DEPTH)
		float Depth : DEPTH;
	#endif
};

VS2PS VS_Diffuse(APP2VS Input)
{
	VS2PS Output = (VS2PS)0.0;

	Output.HPos = mul(float4(Input.Pos.xyz, 1.0), mul(World, ViewProjection));
	// World-space data
	Output.Pos.xyz = GetWorldPos(Input.Pos.xyz);

	// Output Depth
	#if defined(LOG_DEPTH)
		Output.Pos.w = Output.HPos.w + 1.0;
	#endif

	Output.Tex0 = Input.Tex0;

	return Output;
}

PS2FB PS_Diffuse(VS2PS Input)
{
	PS2FB Output = (PS2FB)0.0;

	float3 WorldPos = Input.Pos.xyz;

	Output.Color = RDirectXTK_SRGBToLinearEst(tex2D(SampleDiffuseMap, Input.Tex0));
	ApplyFog(Output.Color.rgb, GetFogValue(WorldPos, WorldSpaceCamPos.xyz));
	RDirectXTK_TonemapAndLinearToSRGBEst(Output.Color);

	#if defined(LOG_DEPTH)
		Output.Depth = RDepth_ApplyLogarithmicDepth(Input.Pos.w);
	#endif

	return Output;
};

technique defaultTechnique
{
	pass p0
	{
		#if defined(ENABLE_WIREFRAME)
			FillMode = WireFrame;
		#endif

		ZEnable = TRUE;
		ZFunc = PR_ZFUNC_WITHEQUAL;

		AlphaTestEnable = TRUE; // <AlphaTest>;
		AlphaRef = (alphaRef);
		AlphaRef = PR_ALPHA_REF; // temporary hack by johan because "m_shaderSettings.m_alphaTestRef = 127" somehow doesn't work

		AlphaBlendEnable = (alphaBlendEnable);
		SrcBlend = (srcBlend);
		DestBlend = (destBlend);

		VertexShader = compile vs_3_0 VS_Diffuse();
		PixelShader = compile ps_3_0 PS_Diffuse();
	}
}
