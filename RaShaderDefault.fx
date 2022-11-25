
/*
	Description: Basic shader that outputs a color
*/

#include "shaders/RealityGraphics.fxh"

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
	float Depth : DEPTH;
};

VS2PS Default_VS(APP2VS Input)
{
	VS2PS Output;
	
	Output.HPos = mul(float4(Input.Pos.xyz, 1.0), mul(World, ViewProjection));

	Output.Pos = Output.HPos;

	return Output;
}

PS2FB Default_PS(VS2PS Input)
{
	PS2FB Output;

	Output.Color = float4(0.9, 0.4, 0.8, 1.0);
	Output.Depth = ApplyLogarithmicDepth(Input.Pos.z);

	return Output;
};

technique defaultShader
{
	pass Pass0
	{
		#if defined(ENABLE_WIREFRAME)
			FillMode = WireFrame;
		#endif

		AlphaBlendEnable = <alphaBlendEnable>;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		CullMode = NONE;
		AlphaTestEnable = FALSE;

		SRGBWriteEnable = FALSE;

		VertexShader = compile vs_3_0 Default_VS();
		PixelShader = compile ps_3_0 Default_PS();
	}
}
