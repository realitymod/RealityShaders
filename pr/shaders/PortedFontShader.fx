
/*
	Description: Renders command-line font
*/

/*
	[Attributes from app]
*/

uniform float4 _Alpha : BLENDALPHA;

/*
	[Textures and samplers]
*/

#define CREATE_SAMPLER(SAMPLER_NAME, TEXTURE, ADDRESS) \
	sampler SAMPLER_NAME = sampler_state \
	{ \
		Texture = (TEXTURE); \
		MinFilter = LINEAR; \
		MagFilter = LINEAR; \
		MipFilter = LINEAR; \
		AddressU = ADDRESS; \
		AddressV = ADDRESS; \
	}; \

uniform texture Tex0: TEXLAYER0;
CREATE_SAMPLER(SampleTex0_Clamp, Tex0, CLAMP)
CREATE_SAMPLER(SampleTex0_Wrap, Tex0, WRAP)

struct APP2VS
{
	float4 HPos : POSITION;
	float3 Color : COLOR;
	float2 TexCoord0 : TEXCOORD0;
};

struct VS2PS
{
	float4 HPos : POSITION;
	float3 Color : TEXCOORD0;
	float2 TexCoord : TEXCOORD1;
};

void VS_HPos(in APP2VS Input, out VS2PS Output)
{
	Output.HPos = Input.HPos;
	Output.Color = saturate(Input.Color);
	Output.TexCoord = Input.TexCoord0;
}

void PS_HPos(in VS2PS Input, out float4 Output : COLOR0)
{
	float4 ColorTex = tex2D(SampleTex0_Clamp, Input.TexCoord);
	float4 NoAlpha = float4(1.0, 1.0, 1.0, 0.0);
	Output = dot(ColorTex, NoAlpha);
	Output.rgb = Output.rgb * Input.Color;
}

technique Text_States <bool Restore = true;>
{
	pass BeginStates
	{
		ZEnable = FALSE;
		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA; // INVSRCCOLOR;
		DestBlend = INVSRCALPHA; // SRCCOLOR;
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
		VertexShader = compile vs_3_0 VS_HPos();
		PixelShader = compile ps_3_0 PS_HPos();
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

void PS_Overlay_HPos(in VS2PS Input, out float4 Output : COLOR0)
{
	float4 ColorTex = tex2D(SampleTex0_Wrap, Input.TexCoord);
	Output = ColorTex * float4(1.0, 1.0, 1.0, _Alpha.a);
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
		VertexShader = compile vs_3_0 VS_HPos();
		PixelShader = compile ps_3_0 PS_Overlay_HPos();
	}
}
