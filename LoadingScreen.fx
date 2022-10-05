
/*
	[Attributes from app]
*/

uniform float4x4 _WorldViewProj : TRANSFORM;

/*
	[Textures and samplers]
*/

uniform texture TexMap : TEXTURE;

sampler Sampler_TexMap = sampler_state
{
    Texture = (TexMap);
    AddressU = WRAP;
    AddressV = WRAP;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
};

struct VS2PS
{
	float4 Position : POSITION;
	float4 Diffuse : COLOR0;
	float2 TexCoord : TEXCOORD0;
};

VS2PS Screen_VS(float3 Position : POSITION, float4 Diffuse : COLOR0, float2 TexCoord : TEXCOORD0)
{
	VS2PS Out = (VS2PS)0;
	Out.Position = float4(Position.xy, 0.0, 1.0);
	Out.Diffuse = saturate(Diffuse);
	Out.TexCoord = TexCoord;
	return Out;
}

float4 Screen_PS(VS2PS Input) : COLOR
{
	float4 InputTexture0 = tex2D(Sampler_TexMap, Input.TexCoord);
	float4 OutputColor;
	OutputColor.rgb = InputTexture0.rgb * Input.Diffuse.rgb;
	OutputColor.a = Input.Diffuse.a;
	return OutputColor;
}

technique Screen
{
	pass P0
	{
		VertexShader = compile vs_3_0 Screen_VS();
		PixelShader = compile ps_3_0 Screen_PS();

		AlphaBlendEnable = FALSE;
		StencilEnable = FALSE;
		AlphaTestEnable = FALSE;
		CullMode = NONE;
	}
}