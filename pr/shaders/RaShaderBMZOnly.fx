#line 2 "RaShaderBMZOnly.fx"

/*
	Include header files
*/

#include "shaders/RealityGraphics.fxh"
#include "shaders/shared/RealityDepth.fxh"
#include "shaders/RaCommon.fxh"
#include "shaders/RaDefines.fx"
#include "shaders/RaShaderBM.fxh"
#if !defined(_HEADERS_)
	#include "RealityGraphics.fxh"
	#include "shared/RealityDepth.fxh"
	#include "RaCommon.fxh"
	#include "RaDefines.fx"
	#include "RaShaderBM.fxh"
#endif

/*
	Description: ZOnly shader for bundledmesh (dynamic, nonhuman objects)
*/

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
	float4 Pos : TEXCOORD0;
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

VS2PS VS_BM_ZOnly(APP2VS Input)
{
	VS2PS Output = (VS2PS)0.0;

	Output.HPos = mul(GetWorldPos(Input), ViewProjection);
	Output.Pos = Output.HPos;

	// Output Depth
	#if defined(LOG_DEPTH)
		Output.Pos.w = Output.HPos.w + 1.0;
	#endif
	
	return Output;
}

RGraphics_PS2FB PS_BM_ZOnly(VS2PS Input)
{
	RGraphics_PS2FB Output = (RGraphics_PS2FB)0.0;
	Output.Color = 0.0;

	#if defined(LOG_DEPTH)
		Output.Depth = RDepth_ApplyLogarithmicDepth(Input.Pos.w);
	#endif

	return Output;
}

technique Variable
{
	pass p0
	{
		AlphaBlendEnable = FALSE;
		AlphaTestEnable = FALSE;

		ZEnable = TRUE;
		ZFunc = PR_ZFUNC_WITHEQUAL;
		ZWriteEnable = TRUE;

		ColorWriteEnable = 0;
		CullMode = CCW;

		VertexShader = compile vs_3_0 VS_BM_ZOnly();
		PixelShader = compile ps_3_0 PS_BM_ZOnly();
	}
}
