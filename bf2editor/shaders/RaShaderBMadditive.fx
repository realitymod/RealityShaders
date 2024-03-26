
/*
	Include header files
*/

#include "shaders/RealityGraphics.fxh"
#include "shaders/shared/RealityDepth.fxh"
#include "shaders/shared/RealityDirectXTK.fxh"
#include "shaders/RaCommon.fxh"
#include "shaders/RaShaderBM.fxh"
#if !defined(_HEADERS_)
	#include "RealityGraphics.fxh"
	#include "shared/RealityDepth.fxh"
	#include "shared/RealityDirectXTK.fxh"
	#include "RaCommon.fxh"
	#include "RaShaderBM.fxh"
#endif

/*
	Description: Renders additive lighting for bundledmesh (dynamic, nonhuman objects)
*/

string GenerateStructs[] =
{
	"reqVertexElement",
	"GlobalParameters",
	"TemplateParameters",
	"InstanceParameters"
};

string reqVertexElement[] =
{
	"Position",
	"Normal",
	"Bone4Idcs",
	"TBase2D"
};

string GlobalParameters[] =
{
	"ViewProjection"
};

string TemplateParameters[] =
{
	"DiffuseMap"
};

string InstanceParameters[] =
{
	"GeomBones",
	"Transparency"
};

struct APP2VS
{
	float4 Pos : POSITION;
	// float3 Normal : NORMAL;
	float4 BlendIndices : BLENDINDICES;
	float4 Tex0 : TEXCOORD0;
};

struct VS2PS
{
	float4 HPos : POSITION;
	float4 Pos : TEXCOORD0;
	float4 Tex0 : TEXCOORD1;
};

struct PS2FB
{
	float4 Color : COLOR0;
	#if defined(LOG_DEPTH)
		float Depth : DEPTH;
	#endif
};

VS2PS VS_BM_Additive(APP2VS Input)
{
	VS2PS Output = (VS2PS)0.0;

	int4 IndexVector = D3DCOLORtoUBYTE4(Input.BlendIndices);
	int IndexArray[4] = (int[4])IndexVector;

	Output.HPos = float4(mul(Input.Pos, GeomBones[IndexArray[0]]), 1.0);
	Output.HPos = mul(Output.HPos, ViewProjection);
	Output.Pos = Output.HPos;

	// Output Depth
	#if defined(LOG_DEPTH)
		Output.Pos.w = Output.HPos.w + 1.0;
	#endif

	Output.Tex0 = Input.Tex0;

	return Output;
}

PS2FB PS_BM_Additive(VS2PS Input)
{
	PS2FB Output = (PS2FB)0.0;

	float4 OutputColor = SRGBToLinearEst(tex2D(SampleDiffuseMap, Input.Tex0.xy));
	OutputColor.rgb *= Transparency;

	Output.Color = OutputColor;
	TonemapAndLinearToSRGBEst(Output.Color);

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);
	#endif

	return Output;
}

technique defaultTechnique
{
	pass p0
	{
		#if defined(ENABLE_WIREFRAME)
			FillMode = WireFrame;
		#endif

		ZEnable = TRUE;
		ZFunc = ALWAYS;
		ZWriteEnable = FALSE;

		AlphaTestEnable = TRUE;
		AlphaRef = 0;
		AlphaFunc = GREATER;

		AlphaBlendEnable = TRUE;
		SrcBlend = ONE; // SRCALPHA;
		DestBlend = ONE; // INVSRCALPHA;

		VertexShader = compile vs_3_0 VS_BM_Additive();
		PixelShader = compile ps_3_0 PS_BM_Additive();
	}
}
