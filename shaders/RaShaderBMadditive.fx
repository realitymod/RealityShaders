#include "shaders/RealityGraphics.fxh"
#include "shaders/RaCommon.fxh"
#include "shaders/RaShaderBMCommon.fxh"
#line 5 "RaShaderBMadditive.fx"

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
	float4 Color : COLOR;
	#if defined(LOG_DEPTH)
		float Depth : DEPTH;
	#endif
};

VS2PS BM_Additive_VS(APP2VS Input)
{
	VS2PS Output = (VS2PS)0;

	int4 IndexVector = D3DCOLORtoUBYTE4(Input.BlendIndices);
	int IndexArray[4] = (int[4])IndexVector;

	Output.HPos = float4(mul(Input.Pos, GeomBones[IndexArray[0]]), 1.0);
	Output.HPos = mul(Output.HPos, ViewProjection);
	Output.Pos = Output.HPos;
	#if defined(LOG_DEPTH)
		Output.Pos.w = Output.HPos.w + 1.0; // Output depth
	#endif

	Output.Tex0 = Input.Tex0;

	return Output;
}

PS2FB BM_Additive_PS(VS2PS Input)
{
	PS2FB Output = (PS2FB)0;

	float4 OutputColor = tex2D(SampleDiffuseMap, Input.Tex0);
	OutputColor.rgb *= Transparency;

	Output.Color = OutputColor;

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);
	#endif

	return Output;
}

technique defaultTechnique
{
	pass Pass0
	{
		#if defined(ENABLE_WIREFRAME)
			FillMode = WireFrame;
		#endif

		ZFunc = ALWAYS;
		ZWriteEnable = FALSE;

		AlphaTestEnable = TRUE;
		AlphaRef = 0;
		AlphaFunc = GREATER;

		AlphaBlendEnable = TRUE;
		SrcBlend = ONE; // SRCALPHA;
		DestBlend = ONE; // INVSRCALPHA;

		VertexShader = compile vs_3_0 BM_Additive_VS();
		PixelShader = compile ps_3_0 BM_Additive_PS();
	}
}
