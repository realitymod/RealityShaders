
/*
	Description: Renders game font
*/

/*
	[Attributes from app]
*/

uniform float4x4 _WorldView : TRANSFORM;
uniform float4 _DiffuseColor : DIFFUSE;

/*
	[Textures and samplers]
*/

#define CREATE_SAMPLER(SAMPLER_NAME, TEXTURE, FILTER) \
	sampler SAMPLER_NAME = sampler_state \
	{ \
		Texture = (TEXTURE); \
		MinFilter = FILTER; \
		MagFilter = FILTER; \
		MipFilter = NONE; \
		AddressU = CLAMP; \
		AddressV = CLAMP; \
	}; \

uniform texture TexMap : TEXTURE;
CREATE_SAMPLER(SampleTexMap, TexMap, POINT)
CREATE_SAMPLER(SampleTexMap_Linear, TexMap, LINEAR)

struct APP2VS
{
	float4 Pos : POSITION;
	float2 TexCoord : TEXCOORD0;
	float4 Color : COLOR;
};

struct VS2PS_REGULAR
{
	float4 HPos : POSITION;
	float2 TexCoord : TEXCOORD0;
	float4 Diffuse : TEXCOORD1;
};

void VS_Regular(in APP2VS Input, out VS2PS_REGULAR Output)
{
	// Output.Output.HPos = mul(float4(Input.Pos.xy, 0.5, 1.0), _WorldView);
	Output.HPos = float4(Input.Pos.xy, 0.5, 1.0);
	Output.TexCoord = Input.TexCoord;
	Output.Diffuse = saturate(Input.Color);
}

void PS_Regular(in VS2PS_REGULAR Input, out float4 Output : COLOR0)
{
	Output = tex2D(SampleTexMap, Input.TexCoord) * Input.Diffuse;
}

void PS_Regular_Scaled(in VS2PS_REGULAR Input, out float4 Output : COLOR0)
{
	Output = tex2D(SampleTexMap_Linear, Input.TexCoord) * Input.Diffuse;
}

void VS_SelectionQuad(in float3 Pos : POSITION, out float4 HPos : POSITION)
{
	HPos = mul(float4(Pos.xy, 0.0, 1.0), _WorldView);
}

void PS_SelectionQuad(out float4 Output : COLOR0)
{
	Output = saturate(_DiffuseColor);
}

technique Regular
{
	pass p0
	{
		AlphaTestEnable = FALSE;

		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		VertexShader = compile vs_3_0 VS_Regular();
		PixelShader = compile ps_3_0 PS_Regular();
	}
}

technique RegularScaled
{
	pass p0
	{
		AlphaTestEnable = FALSE;

		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		VertexShader = compile vs_3_0 VS_Regular();
		PixelShader = compile ps_3_0 PS_Regular_Scaled();
	}
}

technique SelectionQuad
{
	pass p0
	{
		AlphaTestEnable = FALSE;

		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		VertexShader = compile vs_3_0 VS_SelectionQuad();
		PixelShader = compile ps_3_0 PS_SelectionQuad();
	}
}
