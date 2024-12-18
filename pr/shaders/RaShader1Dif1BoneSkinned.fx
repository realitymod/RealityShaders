#line 2 "RaShader1Dif1BoneSkinned.fx"

/*
	Include header files
*/

#include "shaders/RealityGraphics.fxh"
#include "shaders/shared/RealityDepth.fxh"
#include "shaders/shared/RealityDirectXTK.fxh"
#include "shaders/RaCommon.fxh"
#if !defined(_HEADERS_)
	#include "RealityGraphics.fxh"
	#include "shared/RealityDepth.fxh"
	#include "shared/RealityDirectXTK.fxh"
	#include "RaCommon.fxh"
#endif

/*
	Description: Renders object's diffuse map

	Global variables we use to hold the view matrix, projection matrix, ambient material, diffuse material, and the light vector that describes the direction to the light source. These variables are initialized from the application.
*/

float4x4 Bones[26];
bool AlphaBlendEnable = false;

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

string TemplateParameters[] =
{
	"DiffuseMap",
	"ViewProjection"
};

string InstanceParameters[] =
{
	"Bones",
	"AlphaBlendEnable",
};

string reqVertexElement[] =
{
	"Position",
	"TBase2D",
	"Bone4Idcs"
};

struct APP2VS
{
	float3 Pos : POSITION0;
	float2 Tex0 : TEXCOORD0;
	float4 BlendIndices : BLENDINDICES;
};

struct VS2PS
{
	float4 HPos : POSITION;
	float3 Tex0 : TEXCOORD0;
};

struct PS2FB
{
	float4 Color : COLOR0;
	#if defined(LOG_DEPTH)
		float Depth : DEPTH;
	#endif
};

VS2PS VS_DiffuseBone(APP2VS Input)
{
	VS2PS Output = (VS2PS)0.0;

	// Compensate for lack of UBYTE4 on Geforce3
	int4 IndexVector = D3DCOLORtoUBYTE4(Input.BlendIndices);
	int IndexArray[4] = (int[4])IndexVector;

	Output.HPos = mul(float4(Input.Pos.xyz, 1.0), mul(Bones[IndexArray[0]], ViewProjection));
	Output.Tex0.xy = Input.Tex0;

	// Output Depth
	#if defined(LOG_DEPTH)
		Output.Tex0.z = Output.HPos.w + 1.0;
	#endif

	return Output;
}

PS2FB PS_DiffuseBone(VS2PS Input)
{
	PS2FB Output = (PS2FB)0.0;

	float4 ColorTex = tex2D(SampleDiffuseMap, Input.Tex0.xy);

	Output.Color = ColorTex * float4(1.0, 0.0, 1.0, 1.0);

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Tex0.z);
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

		AlphaTestEnable = (AlphaTest);
		AlphaRef = (alphaRef);

		AlphaBlendEnable = (AlphaBlendEnable);
		SrcBlend = (srcBlend);
		DestBlend = (destBlend);

		VertexShader = compile vs_3_0 VS_DiffuseBone();
		PixelShader = compile ps_3_0 PS_DiffuseBone();
	}
}
