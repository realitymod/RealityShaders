#line 2 "RaShaderDefault.fx"

/*
	Include header files
*/

#include "shaders/RealityGraphics.fxh"
#include "shaders/shared/RealityDepth.fxh"
#if !defined(_HEADERS_)
	#include "RealityGraphics.fxh"
	#include "shared/RealityDepth.fxh"
#endif

/*
	Description: A basic shader that outputs a solid color.
*/

float4x4 World;
float4x4 ViewProjection;
int textureFactor = 0xffAFFFaF;
bool alphaBlendEnable = false;

string reqVertexElement[] =
{
	"Position"
};

string InstanceParameters[] =
{
	"World",
	"ViewProjection"
};

struct APP2VS
{
	float3 Pos : POSITION0;
};

struct VS2PS
{
	float4 HPos : POSITION0;
	float4 Pos : TEXCOORD0;
};

VS2PS VS_Default(APP2VS Input)
{
	VS2PS Output = (VS2PS)0.0;
	
	Output.HPos = mul(float4(Input.Pos.xyz, 1.0), mul(World, ViewProjection));
	Output.Pos = Output.HPos;

	// Output Depth
	#if PR_LOG_DEPTH
		Output.Pos.w = Output.HPos.w + 1.0;
	#endif

	return Output;
}

RGraphics_PS2FB PS_Default(VS2PS Input)
{
	RGraphics_PS2FB Output = (RGraphics_PS2FB)0.0;

	Output.Color = float4(0.9, 0.4, 0.8, 1.0);

	#if PR_LOG_DEPTH
		Output.Depth = RDepth_ApplyLogarithmicDepth(Input.Pos.w);
	#endif

	return Output;
};

technique defaultShader
{
	pass p0
	{
		#if defined(ENABLE_WIREFRAME)
			FillMode = WireFrame;
		#endif

		ZEnable = TRUE;
		ZFunc = PR_ZFUNC_WITHEQUAL;

		CullMode = NONE;
		AlphaTestEnable = FALSE;

		AlphaBlendEnable = (alphaBlendEnable);
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		VertexShader = compile vs_3_0 VS_Default();
		PixelShader = compile ps_3_0 PS_Default();
	}
}
