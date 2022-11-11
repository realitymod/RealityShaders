
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

float4 Default_VS(float3 Pos : POSITION0) : POSITION0
{
	return mul(float4(Pos.xyz, 1.0), mul(World, ViewProjection));
}

float4 Default_PS() : COLOR
{
	return float4(0.9, 0.4, 0.8, 1.0);
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

		VertexShader = compile vs_3_0 Default_VS();
		PixelShader = compile ps_3_0 Default_PS();
	}
}
