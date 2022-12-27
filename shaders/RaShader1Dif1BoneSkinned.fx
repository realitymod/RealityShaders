
/*
	Description: Renders object's diffuse map

	Global variables we use to hold the view matrix, projection matrix,
	ambient material, diffuse material, and the light vector that
	describes the direction to the light source. These variables are
	initialized from the application.
*/

#include "shaders/RealityGraphics.fxh"
#include "shaders/RaCommon.fxh"

uniform bool AlphaBlendEnable = false;
uniform float4x4 Bones[26];
uniform float4 ObjectSpaceCamPos;

uniform texture DiffuseMap;
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
	"ObjectSpaceCamPos"
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
	float4 Color : COLOR;
	float Depth : DEPTH;
};

VS2PS DiffuseBone_VS(APP2VS Input)
{
	VS2PS Output = (VS2PS)0;

	// Compensate for lack of UBYTE4 on Geforce3
	int4 IndexVector = D3DCOLORtoUBYTE4(Input.BlendIndices);
	int IndexArray[4] = (int[4])IndexVector;

	Output.HPos = mul(float4(Input.Pos.xyz, 1.0), mul(Bones[IndexArray[0]], ViewProjection));
	Output.Tex0.xy = Input.Tex0;
	Output.Tex0.z = Output.HPos.w + 1.0; // Output depth

	return Output;
}

PS2FB DiffuseBone_PS(VS2PS Input)
{
	PS2FB Output;

	float4 ColorTex = tex2D(SampleDiffuseMap, Input.Tex0.xy);

	Output.Color = ColorTex * float4(1.0, 0.0, 1.0, 1.0);
	Output.Depth = ApplyLogarithmicDepth(Input.Tex0.z);

	return Output;
};

technique defaultTechnique
{
	pass Pass0
	{
		#if defined(ENABLE_WIREFRAME)
			FillMode = WireFrame;
		#endif

		AlphaTestEnable = (AlphaTest);
		AlphaRef = (alphaRef);

		AlphaBlendEnable = (AlphaBlendEnable);
		SrcBlend = (srcBlend);
		DestBlend = (destBlend);

		VertexShader = compile vs_3_0 DiffuseBone_VS();
		PixelShader = compile ps_3_0 DiffuseBone_PS();
	}
}
