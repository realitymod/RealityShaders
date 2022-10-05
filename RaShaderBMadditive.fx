
#include "shaders/RaCommon.fx"
#include "shaders/RaShaderBMCommon.fx"

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
	float4 Tex : TEXCOORD0;
};

struct VS2PS
{
	float4 Pos : POSITION0;
	float4 Tex : TEXCOORD0;
};

VS2PS BM_Additive_VS(APP2VS Input)
{
	VS2PS Output = (VS2PS)0;

	int4 IndexVector = D3DCOLORtoUBYTE4(Input.BlendIndices);
	int IndexArray[4] = (int[4])IndexVector;

	Output.Pos = float4(mul(Input.Pos, GeomBones[IndexArray[0]]), 1.0);
	Output.Pos = mul(Output.Pos, ViewProjection);
	Output.Tex = Input.Tex;

	return Output;
}

float4 BM_Additive_PS(VS2PS Input) : COLOR
{
	float4 OutColor = tex2D(DiffuseMapSampler, Input.Tex);
	OutColor.rgb *= Transparency;
	return OutColor;
}

technique defaultTechnique
{
	pass P0
	{
		VertexShader = compile vs_3_0 BM_Additive_VS();
		PixelShader = compile ps_3_0 BM_Additive_PS();

		#if defined(ENABLE_WIREFRAME)
			FillMode = WireFrame;
		#endif
		ZFunc = ALWAYS;
		AlphaTestEnable = TRUE;
		AlphaRef = 0;
		AlphaFunc = GREATER;
		AlphaBlendEnable = TRUE;
		SrcBlend = ONE; // SRCALPHA;
		DestBlend = ONE; // INVSRCALPHA;
		ZWriteEnable = FALSE;
	}
}
