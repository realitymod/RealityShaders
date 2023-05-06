#include "shaders/RealityGraphics.fxh"

/*
	Description: Basic shader that outputs a color
*/

uniform float4x4 World;
uniform float4x4 ViewProjection;
uniform int textureFactor = 0xffAFFFaF;
uniform bool alphaBlendEnable = false;

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

struct PS2FB
{
	float4 Color : COLOR;
	#if defined(LOG_DEPTH)
		float Depth : DEPTH;
	#endif
};

VS2PS Default_VS(APP2VS Input)
{
	VS2PS Output = (VS2PS)0;
	
	Output.HPos = mul(float4(Input.Pos.xyz, 1.0), mul(World, ViewProjection));
	Output.Pos = Output.HPos;
	#if defined(LOG_DEPTH)
		Output.Pos.w = Output.HPos.w + 1.0; // Output depth
	#endif

	return Output;
}

PS2FB Default_PS(VS2PS Input)
{
	PS2FB Output = (PS2FB)0;

	Output.Color = float4(0.9, 0.4, 0.8, 1.0);

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);
	#endif

	return Output;
};

technique defaultShader
{
	pass Pass0
	{
		#if defined(ENABLE_WIREFRAME)
			FillMode = WireFrame;
		#endif

		CullMode = NONE;
		AlphaTestEnable = FALSE;

		AlphaBlendEnable = (alphaBlendEnable);
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		VertexShader = compile vs_3_0 Default_VS();
		PixelShader = compile ps_3_0 Default_PS();
	}
}
