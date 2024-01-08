
/*
	Description: Renders loading screen at startup
*/

/*
	[Attributes from app]
*/

uniform float4x4 _WorldViewProj : TRANSFORM;

/*
	[Textures and samplers]
*/

uniform texture TexMap : TEXTURE;

sampler SampleTexMap = sampler_state
{
	Texture = (TexMap);
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = LINEAR;
	AddressU = WRAP;
	AddressV = WRAP;
};

struct APP2VS
{
	float3 Pos : POSITION;
	float2 Tex : TEXCOORD0;
	float4 Color : COLOR0;
};

struct VS2PS
{
	float4 HPos : POSITION;
	float2 Tex : TEXCOORD0;
	float4 Color : TEXCOORD1;
};

void VS_Screen(in APP2VS Input, out VS2PS Output)
{
	Output.HPos = float4(Input.Pos.xy, 0.0, 1.0);
	Output.Tex = Input.Tex;
	Output.Color = saturate(Input.Color);
}

void PS_Screen(in VS2PS Input, out float4 Output : COLOR0)
{
	float4 ColorTex = tex2D(SampleTexMap, Input.Tex);
	Output.rgb = ColorTex.rgb * Input.Color.rgb;
	Output.a = Input.Color.a;
}

technique Screen
{
	pass p0
	{
		CullMode = NONE;
		StencilEnable = FALSE;
		AlphaTestEnable = FALSE;
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_3_0 VS_Screen();
		PixelShader = compile ps_3_0 PS_Screen();
	}
}