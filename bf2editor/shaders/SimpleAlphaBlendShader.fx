#line 2 "SimpleAlphaBlendShader.fx"

/*
    This shader provides simple alpha blending functionality for transparent objects. It handles basic texture-based transparency with alpha blending and supports fundamental transparent rendering techniques.
*/

#include "shaders/RealityGraphics.fxh"
#include "shaders/shared/RealityDepth.fxh"
#if !defined(_HEADERS_)
	#include "RealityGraphics.fxh"
	#include "shared/RealityDepth.fxh"
#endif

float4x4 _WorldViewProj : WorldViewProjection;

texture BaseTex: TEXLAYER0
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
	float4 Color : COLOR0;
	#if PR_LOG_DEPTH
		float Depth : DEPTH;
	#endif
};

VS2PS VS_Shader(APP2VS Input)
{
	VS2PS Output = (VS2PS)0.0;

	Output.HPos = mul(float4(Input.Pos.xyz, 1.0), _WorldViewProj);
	Output.Tex0.xy = Input.Tex0;

	// Output Depth
	#if PR_LOG_DEPTH
		Output.Tex0.z = Output.HPos.w + 1.0;
	#endif

	return Output;
}

PS2FB PS_Shader(VS2PS Input)
{
	PS2FB Output = (PS2FB)0.0;

	Output.Color = tex2D(SampleBaseTex, Input.Tex0.xy);

	#if PR_LOG_DEPTH
		Output.Depth = RDepth_ApplyLogarithmicDepth(Input.Tex0.z);
	#endif

	return Output;
}

technique t0_States <bool Restore = true;>
{
	pass BeginStates
	{
		ZEnable = TRUE;
		ZFunc = PR_ZFUNC_WITHEQUAL;
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
	pass p0
	{
		VertexShader = compile vs_3_0 VS_Shader();
		PixelShader = compile ps_3_0 PS_Shader();
	}
}
