//
// ZOnlyShader
//


string reqVertexElement[] = {
	"PositionPacked",
	"NormalPacked8",
	"Bone4Idcs",
	"TBasePacked2D"
};

string GlobalParameters[] = {
	"ViewProjection",
};


string InstanceParameters[] = {
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

#include "shaders/RaCommon.fx"
#include "shaders/RaDefines.fx"
#include "shaders/RaShaderBMCommon.fx"

struct BMVariableVSInput
{
   	float4 Pos : POSITION;    
	float3 Normal : NORMAL;
	float4 BlendIndices : BLENDINDICES;  
	float2 TexDiffuse : TEXCOORD0;
	float2 TexUVRotCenter : TEXCOORD1;
	float3 Tan : TANGENT;
};

struct BMVariableVSOutput
{
	float4 HPos : POSITION;
};

float4x3 getSkinnedWorldMatrix(BMVariableVSInput input)
{
	int4 IndexVector = D3DCOLORtoUBYTE4(input.BlendIndices);
	int IndexArray[4] = (int[4])IndexVector;
	return GeomBones[IndexArray[0]];
}

float4 getWorldPos(BMVariableVSInput input)
{
	float4 unpackedPos = input.Pos * PosUnpack;
	return float4(mul(unpackedPos, getSkinnedWorldMatrix(input)), 1);
}

BMVariableVSOutput vs(BMVariableVSInput input)
{
	BMVariableVSOutput Out = (BMVariableVSOutput)0;

	Out.HPos = mul(getWorldPos(input), ViewProjection);	// output HPOS
	
	return Out;
}

technique Variable
{
	pass p0
	{
		VertexShader = compile VSMODEL vs();
		PixelShader = NULL;

		AlphaBlendEnable = FALSE;
		AlphaTestEnable = FALSE;
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;
		ColorWriteEnable = 0;
		CullMode = CCW;		
	}
}
