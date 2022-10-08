
#include "shaders/RealityGraphics.fx"

uniform float4x4 _WorldViewProj : WorldViewProjection;

uniform texture Base_Texture: TEXLAYER0
<
	string File = "aniso2.dds";
	string TextureType = "2D";
>;

struct APP2VS
{
    float4 Pos : POSITION;    
    float2 Tex0 : TEXCOORD0;
};

struct VS2PS
{
    float4 HPos : POSITION;
    float2 Tex0 : TEXCOORD0;
};

sampler Diffuse_Sampler = sampler_state
{
	Texture = (Base_Texture);
	// Target = Texture2D;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = LINEAR;
    AddressU = WRAP;
    AddressV = WRAP;
};

VS2PS Shader_VS(APP2VS Input)
{
	VS2PS Output;
	Output.HPos = mul(float4(Input.Pos.xyz, 1.0f), _WorldViewProj);
	Output.Tex0 = Input.Tex0;
	return Output;
}

float4 Shader_PS(VS2PS Input) : COLOR
{
	return tex2D(Diffuse_Sampler, Input.Tex0);
}

technique t0_States <bool Restore = true;>
{
	pass BeginStates
	{
		ZEnable = TRUE;
		// MatsD 030903: Due to transparent isn't sorted yet. Write Z values
		ZWriteEnable = TRUE;
		CullMode = NONE;
		AlphaBlendEnable = TRUE;
		SrcBlend = ONE;
		DestBlend = ONE;
		// SrcBlend = SRCALPHA;
		// DestBlend = INVSRCALPHA;
	}
	
	pass EndStates { }
}

technique t0
{
	pass p0 
	{
		VertexShader = compile vs_3_0 Shader_VS();
		PixelShader = compile ps_3_0 Shader_PS();
	}
}

/*technique marked
	{
		pass p0
		{
			CullMode = NONE;
			AlphaBlendEnable = FALSE;
			Lighting = TRUE;
		
			VertexShader = compile vs_3_0 Shader_VS(_WorldViewProj, MaterialAmbient, MaterialDiffuse, LhtDir);
			PixelShader = compile ps_3_0 PShaderMarked(samplebase);
		}
	}
*/
