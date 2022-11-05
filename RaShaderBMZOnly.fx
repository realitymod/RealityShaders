
/*
	Description: ZOnly shader for bundledmesh (dynamic, nonhuman objects)
*/

#include "shaders/RealityGraphics.fxh"

string reqVertexElement[] =
{
	"PositionPacked",
	"NormalPacked8",
	"Bone4Idcs",
	"TBasePacked2D"
};

string GlobalParameters[] =
{
	"ViewProjection",
};

string InstanceParameters[] =
{
	"World",
	"AlphaBlendEnable",
	"DepthWrite",
	"CullMode",
	"AlphaTest",
	"AlphaTestRef",
	"GeomBones",
	"PosUnpack",
	"TexUnpack",
	"NormalUnpack"
};

#define NUM_LIGHTS 1
#define NUM_TEXSETS 1
#define TexBasePackedInd 0

#include "shaders/RaCommon.fxh"
#include "shaders/RaDefines.fx"
#include "shaders/RaShaderBMCommon.fxh"

struct APP2VS
{
	float4 Pos : POSITION;
	float3 Normal : NORMAL;
	float4 BlendIndices : BLENDINDICES;
	float2 TexDiffuse : TEXCOORD0;
	float2 TexUVRotCenter : TEXCOORD1;
	float3 Tan : TANGENT;
};

struct VS2PS
{
	float4 HPos : POSITION;
};

float4x3 GetSkinnedWorldMatrix(APP2VS Input)
{
	int4 IndexVector = D3DCOLORtoUBYTE4(Input.BlendIndices);
	int IndexArray[4] = (int[4])IndexVector;
	return GeomBones[IndexArray[0]];
}

float4 GetWorldPos(APP2VS Input)
{
	float4 unpackedPos = Input.Pos * PosUnpack;
	return float4(mul(unpackedPos, GetSkinnedWorldMatrix(Input)), 1.0);
}

VS2PS BM_ZOnly_VS(APP2VS Input)
{
	VS2PS Output = (VS2PS)0;
	Output.HPos = mul(GetWorldPos(Input), ViewProjection); // Output HPOS
	return Output;
}

technique Variable
{
	pass p0
	{
		VertexShader = compile vs_3_0 BM_ZOnly_VS();
		PixelShader = NULL;

		AlphaBlendEnable = FALSE;
		AlphaTestEnable = FALSE;
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;
		ColorWriteEnable = 0;
		CullMode = CCW;
	}
}
