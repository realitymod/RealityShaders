
/*
	Description: Renders simple blendop shader
*/

#include "shaders/RealityGraphics.fxh"

uniform float4x4 _WorldViewProj : WorldViewProjection;

uniform texture BaseTex: TEXLAYER0
<
	string File = "aniso2.dds";
	string TextureType = "2D";
>;

sampler SampleBaseTex = sampler_state
{
	Texture = (BaseTex);
	// Target = Texture2D;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = LINEAR;
    AddressU = WRAP;
    AddressV = WRAP;
	SRGBTexture = FALSE;
};

struct APP2VS
{
    float4 Pos : POSITION;
    float2 Tex0 : TEXCOORD0;
};

struct VS2PS
{
    float4 HPos : POSITION;
    float3 Tex0 : TEXCOORD0;
};

struct PS2FB
{
	float4 Color : COLOR;
	float Depth : DEPTH;
};

VS2PS Shader_VS(APP2VS Input)
{
	VS2PS Output;

	Output.HPos = mul(float4(Input.Pos.xyz, 1.0), _WorldViewProj);

	Output.Tex0.xy = Input.Tex0;
	Output.Tex0.z = Output.HPos.w; // Output depth

	return Output;
}

PS2FB Shader_PS(VS2PS Input)
{
	PS2FB Output;

	Output.Color = tex2D(SampleBaseTex, Input.Tex0.xy);
	Output.Depth = ApplyLogarithmicDepth(Input.Tex0.z);

	return Output;
}

technique t0_States <bool Restore = true;>
{
	pass BeginStates
	{
		ZEnable = TRUE;
		ZWriteEnable = TRUE; // MatsD 030903: Due to transparent isn't sorted yet. Write Z values

		CullMode = NONE;

		AlphaBlendEnable = TRUE;
		SrcBlend = ONE; // SRCALPHA;
		DestBlend = ONE; // INVSRCALPHA;
	}

	pass EndStates { }
}

technique t0
{
	pass Pass0
	{
		VertexShader = compile vs_3_0 Shader_VS();
		PixelShader = compile ps_3_0 Shader_PS();
	}
}
