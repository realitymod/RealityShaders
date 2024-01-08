
/*
	Description: Shaders for main menu
*/

uniform float4x4 WorldView : TRANSFORM;
uniform float4 DiffuseColor : DIFFUSE;
uniform float4 TexGenS : TEXGENS;
uniform float4 TexGenT : TEXGENT;
uniform float Time : TIME;

#define CREATE_SAMPLER(SAMPLER_NAME, TEXTURE, ADDRESS) \
	sampler SAMPLER_NAME = sampler_state \
	{ \
		Texture = (TEXTURE); \
		MinFilter = LINEAR; \
		MagFilter = LINEAR; \
		MipFilter = NONE; \
		AddressU = ADDRESS; \
		AddressV = ADDRESS; \
	}; \

uniform texture TexMap : TEXTURE;
CREATE_SAMPLER(SampleTexMap_Clamp, TexMap, CLAMP)
CREATE_SAMPLER(SampleTexMap_Wrap, TexMap, WRAP)

struct APP2VS_Shape
{
	float3 Pos : POSITION;
	float4 Color : COLOR0;
};

struct VS2PS_Shape
{
	float4 HPos : POSITION;
	float4 Diffuse : TEXCOORD0;
};

struct VS2PS_ShapeTexture
{
	float4 HPos : POSITION;
	float2 TexCoord : TEXCOORD0;
	float4 Diffuse : TEXCOORD1;
	float4 Selector : TEXCOORD2;
};

void VS_Shape(in APP2VS_Shape Input, out VS2PS_Shape Output)
{
	Output = (VS2PS_Shape)0.0;

	Output.HPos = float4(Input.Pos.xy, 0.0, 1.0);
	Output.Diffuse = saturate(Input.Color);
}

void VS_Line(in float3 Position : POSITION, out VS2PS_Shape Output)
{
	Output = (VS2PS_Shape)0.0;

	Output.HPos = float4(Position.xy, 0.0, 1.0);
	Output.Diffuse = saturate(DiffuseColor);
}

void VS_ShapeTexture(in float3 Position : POSITION, out VS2PS_ShapeTexture Output)
{
	Output = (VS2PS_ShapeTexture)0;

	Output.HPos = mul(float4(Position.xy, 0.0, 1.0), WorldView);
	Output.Diffuse = saturate(DiffuseColor);
	Output.Selector = saturate(Position.zzzz);

	float4 TexPos = float4(Position.xy, 0.0, 1.0);
	Output.TexCoord.x = mul(TexPos, TexGenS);
	Output.TexCoord.y = mul(TexPos, TexGenT);
}

void PS_RegularWrap(in VS2PS_ShapeTexture Input, out float4 Output : COLOR0)
{
	float4 Tex = tex2D(SampleTexMap_Wrap, Input.TexCoord);

	Output.rgb = lerp(Input.Diffuse, Tex * Input.Diffuse, Input.Selector);
	Output.a = Tex.a * Input.Diffuse.a;
}

void PS_RegularClamp(in VS2PS_ShapeTexture Input, out float4 Output : COLOR0)
{
	float4 Tex = tex2D(SampleTexMap_Clamp, Input.TexCoord);

	Output.rgb = lerp(Input.Diffuse, Tex * Input.Diffuse, Input.Selector);
	Output.a = Tex.a * Input.Diffuse.a;
}

void PS_Diffuse(in VS2PS_Shape Input, out float4 Output : COLOR0)
{
	Output = Input.Diffuse;
}

void PS_Line(in VS2PS_Shape Input, out float4 Output : COLOR0)
{
	Output = Input.Diffuse;
}

technique Shape
{
	pass p0
	{
		VertexShader = compile vs_3_0 VS_Shape();
		PixelShader = compile ps_3_0 PS_Diffuse();
	}
}

technique ShapeTextureWrap
{
	pass p0
	{
		VertexShader = compile vs_3_0 VS_ShapeTexture();
		PixelShader = compile ps_3_0 PS_RegularWrap();
	}
}

technique ShapeTextureClamp
{
	pass p0
	{
		VertexShader = compile vs_3_0 VS_ShapeTexture();
		PixelShader  = compile ps_3_0 PS_RegularClamp();
	}
}

technique Line
{
	pass p0
	{
		AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_Line();
		PixelShader = compile ps_3_0 PS_Line();
	}
}
