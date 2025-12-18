#line 2 "RaShaderLeafPointLight.fx"

#define LEAF_MOVEMENT 0.04

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

float4 Ambient;
Light Lights[1];
float4 PosUnpack;
float TexUnpack;

string GlobalParameters[] =
{
	"GlobalTime",
	"FogRange",
	"ViewProjection",
	"Ambient"
};

string TemplateParameters[] =
{
	"DiffuseMap"
};

string InstanceParameters[] =
{
	"WorldViewProjection",
	"Transparency",
	"WindSpeed",
	"Lights"
};

// INPUTS TO THE VERTEX SHADER FROM THE APP
string reqVertexElement[] =
{
	"PositionPacked",
	"Normal",
	"TBasePacked2D"
};

texture DiffuseMap;
sampler SampleDiffuseMap = sampler_state
{
	Texture = (DiffuseMap);
	MipFilter = LINEAR;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	AddressU = WRAP;
	AddressV = WRAP;
	MipMapLodBias = 0;
};

struct APP2VS
{
	float3 Pos: POSITION0;
	float3 Normal: NORMAL;
	float2 Tex0 : TEXCOORD0;
};

struct VS2PS
{
	float4 HPos : POSITION0;
	float3 Tex0 : TEXCOORD0;
	float4 Color : TEXCOORD1;
};

struct PS2FB
{
	float4 Color : COLOR0;
	#if defined(LOG_DEPTH)
		float Depth : DEPTH;
	#endif
};

VS2PS VS_Basic(APP2VS Input)
{
	VS2PS Output = (VS2PS)0.0;

	// Unpack wind position
	Input.Pos *= PosUnpack;

	// Warp geometry
	float Speed = WindSpeed + 5.0;
	Input.Pos += sin(GlobalTime * Input.Pos.y * Speed / 4.0) * LEAF_MOVEMENT * clamp(abs(Input.Pos.z * Input.Pos.x), 0.0, Speed / 10.0);

	Output.HPos = mul(float4(Input.Pos, 1.0), WorldViewProjection);
	Output.Tex0 = float3(Input.Tex0 * TexUnpack, Output.HPos.w);

	// Output Depth
	#if defined(LOG_DEPTH)
		Output.Tex0.z = Output.HPos.w + 1.0;
	#endif

	float3 LightVec = float3(Lights[0].pos.xyz - normalize(Input.Pos));
	float HalfNL = RDirectXTK_GetHalfNL(Input.Normal, -normalize(LightVec));
	float Attenuation = RPixel_GetLightAttenuation(LightVec, Lights[0].attenuation);
	Output.Color.rgb = Lights[0].color * (HalfNL * Attenuation);
	Output.Color.a = Transparency;

	return Output;
}

PS2FB PS_Basic(VS2PS Input)
{
	PS2FB Output = (PS2FB)0.0;

	float4 DiffuseMap = RDirectXTK_SRGBToLinearEst(tex2D(SampleDiffuseMap, Input.Tex0.xy));
	float3 Color = DiffuseMap.rgb * Input.Color.rgb;

	Output.Color = float4(Color, DiffuseMap.a);
	RDirectXTK_TonemapAndLinearToSRGBEst(Output.Color);
	Output.Color.rgb *= Ra_GetFogValue(Input.Tex0.z, 0.0);

	#if defined(LOG_DEPTH)
		Output.Depth = RDepth_ApplyLogarithmicDepth(Input.Tex0.z);
	#endif

	return Output;
};

technique defaultTechnique
{
	pass p0
	{
		#if defined(ENABLE_WIREFRAME)
			FillMode = WIREFRAME;
		#endif

		ZEnable = TRUE;
		ZFunc = PR_ZFUNC_WITHEQUAL;

		CullMode = NONE;

		AlphaTestEnable = TRUE; // (AlphaTest);
		AlphaRef = PR_ALPHA_REF; // (alphaRef);

		VertexShader = compile vs_3_0 VS_Basic();
		PixelShader = compile ps_3_0 PS_Basic();
	}
}
