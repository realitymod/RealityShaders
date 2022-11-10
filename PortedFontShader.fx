
/*
	Description: Renders command-line font
*/

#include "shaders/RealityGraphics.fxh"

/*
	[Attributes from app]
*/

uniform float4 _Alpha : BLENDALPHA;

/*
	[Textures and samplers]
*/

uniform texture Tex0: TEXLAYER0;

sampler SampleTex0_Clamp = sampler_state
{
	Texture = (Tex0);
	AddressU = CLAMP;
	AddressV = CLAMP;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = LINEAR;
	SRGBTexture = FALSE;
};

sampler SampleTex0_Wrap = sampler_state
{
	Texture = (Tex0);
	AddressU = WRAP;
	AddressV = WRAP;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = LINEAR;
	SRGBTexture = FALSE;
};

struct APP2VS
{
    float4 HPos : POSITION;
    float3 Color : COLOR;
    float2 TexCoord0 : TEXCOORD0;
};

struct VS2PS
{
    float4 HPos : POSITION;
    float3 Color : COLOR0;
    float2 TexCoord : TEXCOORD0;
};

VS2PS HPos_VS(APP2VS Input)
{
	VS2PS Output;
	Output.HPos = Input.HPos;
	Output.Color = saturate(Input.Color);
 	Output.TexCoord = Input.TexCoord0;
	return Output;
}

float4 HPos_PS(VS2PS Input) : COLOR
{
	float4 OutputColor = tex2D(SampleTex0_Clamp, Input.TexCoord);
	float4 NoAlpha = float4(1.0, 1.0, 1.0, 0.0);
	OutputColor = dot(OutputColor, NoAlpha);
	OutputColor.rgb = OutputColor.rgb * Input.Color;
	return OutputColor;
}

technique Text_States <bool Restore = true;>
{
	pass BeginStates
	{
		ZEnable = FALSE;
		AlphaBlendEnable = TRUE;
		// SrcBlend = INVSRCCOLOR;
		// DestBlend = SRCCOLOR;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;
	}
	
	pass EndStates { }
}

technique Text <
	int Declaration[] = 
	{
		// StreamNo, DataType, Usage, UsageIdx
		0, D3DDECLTYPE_FLOAT4, D3DDECLUSAGE_POSITION, 0,
		0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 0,
		0, D3DDECLTYPE_FLOAT2, D3DDECLUSAGE_TEXCOORD, 0,
		DECLARATION_END	// End macro
	};
>
{
	pass p0
	{		
		VertexShader = compile vs_3_0 HPos_VS();
		PixelShader = compile ps_3_0 HPos_PS(); 
	}
}

technique Overlay_States <bool Restore = true;>
{
	pass BeginStates
	{
		CullMode = NONE;
		ZEnable = FALSE;
		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;
	}
	
	pass EndStates { }
}

float4 Overlay_HPos_PS(VS2PS Input) : COLOR
{
	float4 InputTexture0 = tex2D(SampleTex0_Wrap, Input.TexCoord);
	return InputTexture0 * float4(1.0, 1.0, 1.0, _Alpha.a);
}

technique Overlay <
	int Declaration[] = 
	{
		// StreamNo, DataType, Usage, UsageIdx
		0, D3DDECLTYPE_FLOAT4, D3DDECLUSAGE_POSITION, 0,
		0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 0,
		0, D3DDECLTYPE_FLOAT2, D3DDECLUSAGE_TEXCOORD, 0,
		DECLARATION_END	// End macro
	};
	int TechniqueStates = D3DXFX_DONOTSAVESHADERSTATE;
>
{
	pass p0
	{
		VertexShader = compile vs_3_0 HPos_VS();
		PixelShader = compile ps_3_0 Overlay_HPos_PS();
	}
}
