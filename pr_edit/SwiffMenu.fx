#line 2 "SwiffMenu.fx"

#include "shaders/RaCommon.fx"


float4x4 WorldView : TRANSFORM;
float4 DiffuseColor : DIFFUSE;
float4 TexGenS : TEXGENS;
float4 TexGenT : TEXGENT;
texture TexMap : TEXTURE;
float Time : TIME;

sampler TexMapSampler = sampler_state
{
    Texture = <TexMap>;
    AddressU = Wrap;
    AddressV = Wrap;
    MinFilter = Linear;
    MagFilter = Linear;
    MipFilter = Linear;
};

sampler TexMapSamplerClamp = sampler_state
{
    Texture = <TexMap>;
    AddressU = Clamp;
    AddressV = Clamp;
    MinFilter = Linear;
    MagFilter = Linear;
    MipFilter = None;
};

sampler TexMapSamplerWrap = sampler_state
{
    Texture = <TexMap>;
    AddressU = Wrap;
    AddressV = Wrap;
    MinFilter = Linear;
    MagFilter = Linear;
    MipFilter = None;
};

struct VS_SHAPE
{
	float4 Position : POSITION;
	float4 Diffuse : COLOR0;
};

struct VS_TS0
{
	float4 Position : POSITION;
	float2 TexCoord : TEXCOORD0;
};


struct VS_TS3
{
	float4 Position : POSITION;
	float2 TexCoord : TEXCOORD0;
	float4 Diffuse : COLOR0;
};

struct VS_SHAPETEXTURE
{
	float4 Position : POSITION;
	float4 Diffuse : COLOR0;
	float4 Selector : COLOR1;
	float2 TexCoord : TEXCOORD0;
};

struct VS_TEXTURE
{
	float4 Position : POSITION;
	float4 Diffuse : COLOR0;
	float2 TexCoord : TEXCOORD0;
};

VS_SHAPE VSShape(float3 Position : POSITION, float4 VtxColor : COLOR0)
{
	VS_SHAPE Out = (VS_SHAPE)0;
	// Out.Position = mul(float4(Position.xy, 0.0f, 1.0), WorldView);
	Out.Position = float4(Position.xy, 0.0f, 1.0);
	Out.Diffuse = VtxColor/*DiffuseColor*/;
	return Out;
}

VS_SHAPE VSLine(float3 Position : POSITION)
{
	VS_SHAPE Out = (VS_SHAPE)0;
	// Out.Position = mul(float4(Position.xy, 0.0f, 1.0), WorldView);
	// Out.Position = float4(Position.xy, 0.0f, 1.0);
	Out.Position = float4(Position.xy, 0.0f, 1.0);
	Out.Diffuse = DiffuseColor;
	return Out;
}

VS_SHAPETEXTURE VSShapeTexture(float3 Position : POSITION)
{
	VS_SHAPETEXTURE Out = (VS_SHAPETEXTURE)0;
	Out.Position = mul(float4(Position.xy, 0.0f, 1.0), WorldView);
	Out.Diffuse = DiffuseColor;
	Out.Selector = Position.zzzz;
	float4 texPos = float4(Position.xy, 0.0, 1.0);
	Out.TexCoord.x = mul(texPos, TexGenS);
	Out.TexCoord.y = mul(texPos, TexGenT);
	return Out;
}

float4 PSRegularWrap(VS_SHAPETEXTURE input) : COLOR
{
	float4 color;
	float4 tex = tex2D(TexMapSamplerWrap, input.TexCoord);
	// return tex.aaaa;
	color.rgb = tex*input.Diffuse*input.Selector + input.Diffuse*(1-input.Selector);
	color.a = tex.a*input.Diffuse.a;
	return color;
}

float4 PSRegularClamp(VS_SHAPETEXTURE input) : COLOR
{
	float4 color;
	float4 tex = tex2D(TexMapSamplerClamp, input.TexCoord);
	// return tex.aaaa+float4(1,1,1,1);
	color.rgb = tex*input.Diffuse*input.Selector + input.Diffuse*(1-input.Selector);
	color.a = tex.a*input.Diffuse.a;
	return color;
}

float4 PSDiffuse(VS_SHAPE input) : COLOR
{
	return input.Diffuse;
}


VS_TS0 VSTS0_0(float3 Position : POSITION)
{
	VS_TS0 Out = (VS_TS0)0;
	Out.Position = mul(float4(Position.xy, 0.0f, 1.0), WorldView);
	float4 texPos = float4(Position.xy+sin(Time*1)*240.5, 0.0, 1.0);
	Out.TexCoord.x = (mul(texPos, TexGenS) + sin(Time*0.1)*0.1)*0.8+0.1;
	Out.TexCoord.y = (mul(texPos, TexGenT) + cos(Time*0.12+0.2)*0.1)*0.8+0.1;
	return Out;
}

VS_SHAPE VSTS0_1(float3 Position : POSITION)
{
	VS_SHAPE Out = (VS_SHAPE)0;
	Out.Position = mul(float4(Position.xy, 0.0f, 1.0), WorldView);

	float a = sin(Time*1)*0.2+0.2+cos(Time*0.31)*0.1+0.1;
	Out.Diffuse = float4(a,a,a,a);

	// float r = 0.0;
	// float g = 0.6;
	// float b = 1;
	// Out.Diffuse = float4(r,g,b,0.7);
	return Out;
}


VS_TS3 VSTS1_0(float3 Position : POSITION)
{
	VS_TS3 Out = (VS_TS3)0;
	Out.Position = mul(float4(Position.xy, 0.0f, 1.0), WorldView);
	float4 texPos = float4(Position.xy, 0.0, 1.0);
	Out.TexCoord.x = mul(texPos, TexGenS);
	Out.TexCoord.y = mul(texPos, TexGenT) + Time*0.005;
	Out.Diffuse = float4(1,1,1,1);
	return Out;
}


VS_TS3 VSTS2_0(float3 Position : POSITION)
{
	VS_TS3 Out = (VS_TS3)0;
	Out.Position = mul(float4(Position.xy, 0.0f, 1.0), WorldView);
	float4 texPos = float4(Position.xy, 0.0, 1.0);
	Out.TexCoord.x = mul(texPos, TexGenS);
	Out.TexCoord.y = mul(texPos, TexGenT);
	float a = sin(Time*1+1)*0.15+0.4 + cos(Time*33)*0.03+0.03;
	Out.Diffuse = float4(1,1,1,a);

	return Out;
}

VS_TS3 VSTS3_0(float3 Position : POSITION)
{
	VS_TS3 Out = (VS_TS3)0;
	Out.Position = mul(float4(Position.xy, 0.0f, 1.0), WorldView);
	float4 texPos = float4(Position.xy+sin(Time*1+0.2)*240.5, 0.0, 1.0);
	Out.TexCoord.x = (mul(texPos, TexGenS) + sin(Time*0.1)*0.1)*0.8+0.1;
	Out.TexCoord.y = (mul(texPos, TexGenT) + cos(Time*0.12+0.2)*0.1)*0.8+0.1;
	float a = sin(Time*1)*0.15+0.4 + cos(Time*33)*0.03+0.03;
	Out.Diffuse = float4(1,1,1,a);
	return Out;
}

float4 PSTS0_0(VS_TS0 input) : COLOR
{
	// float4 color;
	return tex2D(TexMapSamplerWrap, input.TexCoord);
	// float4 tex = tex2D(TexMapSamplerWrap, input.TexCoord);
	// color.rgb = tex;
	// color.a = tex.a*input.Diffuse.a;
	// return color;
}

float4 PSRegularTSX(VS_TS3 input) : COLOR
{
	return tex2D(TexMapSamplerWrap, input.TexCoord) * input.Diffuse;
}


technique Shape
{
	pass P0
	{
		VertexShader = compile vs_1_1 VSShape();
		PixelShader = compile ps_1_1 PSDiffuse();
		/*PixelShader = NULL;
		TexCoordIndex[0] =0;
		TextureTransformFlags[0] = Disable;*/
    	// Sampler[0] = <TexMapSamplerWrap>;
	}
}


technique ShapeTextureWrap
{
	pass P0
	{
		VertexShader = compile vs_1_1 VSShapeTexture();
		PixelShader = compile ps_1_1 PSRegularWrap();
		AlphaTestEnable = false;
		/*AlphaRef = 128;
		AlphaFunc = GREATER;		*/
		/*PixelShader = NULL;
		TexCoordIndex[0] =0;
		TextureTransformFlags[0] = Disable;
    	Sampler[0] = <TexMapSamplerWrap>;*/
	}
}

technique ShapeTextureClamp
{
	pass P0
	{
		VertexShader = compile vs_1_1 VSShapeTexture();
		PixelShader = compile ps_1_1 PSRegularClamp();
		/*AlphaTestEnable = true;
		AlphaRef = 77;
		AlphaFunc = GREATER;		*/
		/*PixelShader = NULL;
		TexCoordIndex[0] =0;
		TextureTransformFlags[0] = Disable;
	    Sampler[0] = <TexMapSamplerClamp>;*/
	}
}

technique Line
{
	pass P0
	{
		VertexShader = compile vs_1_1 VSLine();
		PixelShader = NULL;
		AlphaTestEnable = false;
		TexCoordIndex[0] =0;
		TextureTransformFlags[0] = Disable;
	    Sampler[0] = <TexMapSamplerClamp>;
	}
}

technique TS0
{
	pass P0
	{
		VertexShader = compile vs_1_1 VSTS0_0();
		PixelShader = compile ps_1_1 PSTS0_0();
		AlphaTestEnable = false;

		/*PixelShader = NULL;
		TexCoordIndex[0] =0;
		TextureTransformFlags[0] = Disable;
	    	Sampler[0] = <TexMapSamplerWrap>;
		ColorOp[0]   = SelectArg1;
		ColorArg1[0] = Texture;
		AlphaOp[0]   = Modulate;
		AlphaArg1[0] = Texture;
		AlphaArg2[0] = Diffuse;
		ColorOp[1] = Disable;
		AlphaOp[1] = Disable;*/

	}
	pass P1
	{
		VertexShader = compile vs_1_1 VSTS0_1();
		PixelShader = compile ps_1_1 PSDiffuse();
		AlphaTestEnable = false;
		/*PixelShader = NULL;
		ColorOp[0]   = Disable;
		AlphaOp[0]   = Disable;*/

	}

}

technique TS1
{
	pass P0
	{
		VertexShader = compile vs_1_1 VSTS1_0();
		PixelShader = compile ps_1_1 PSRegularTSX();
		AlphaTestEnable = false;

		/*PixelShader = NULL;
		TexCoordIndex[0] =0;
		TextureTransformFlags[0] = Disable;
	    	Sampler[0] = <TexMapSamplerWrap>;
		ColorOp[0]   = Modulate;
		ColorArg1[0] = Texture;
		ColorArg2[0] = Diffuse;
		AlphaOp[0]   = Modulate;
		AlphaArg1[0] = Texture;
		AlphaArg2[0] = Diffuse;
		ColorOp[1] = Disable;
		AlphaOp[1] = Disable;*/

	}
}

technique TS2
{
	pass P0
	{
		VertexShader = compile vs_1_1 VSTS2_0();
		PixelShader = compile ps_1_1 PSRegularTSX();
		AlphaTestEnable = false;
		/*PixelShader = NULL;
		TexCoordIndex[0] =0;
		TextureTransformFlags[0] = Disable;
	    	Sampler[0] = <TexMapSamplerWrap>;
		ColorOp[0]   = Modulate;
		ColorArg1[0] = Texture;
		ColorArg2[0] = Diffuse;
		AlphaOp[0]   = Modulate;
		AlphaArg1[0] = Texture;
		AlphaArg2[0] = Diffuse;
		ColorOp[1] = Disable;
		AlphaOp[1] = Disable;*/

	}
}

technique TS3
{
	pass P0
	{
		VertexShader = compile vs_1_1 VSTS3_0();
		PixelShader = compile ps_1_1 PSRegularTSX();
		AlphaTestEnable = false;
		/*PixelShader = NULL;
		TexCoordIndex[0] =0;
		TextureTransformFlags[0] = Disable;
	    	Sampler[0] = <TexMapSamplerWrap>;
		ColorOp[0]   = Modulate;
		ColorArg1[0] = Texture;
		ColorArg2[0] = Diffuse;
		AlphaOp[0]   = Modulate;
		AlphaArg1[0] = Texture;
		AlphaArg2[0] = Diffuse;
		ColorOp[1] = Disable;
		AlphaOp[1] = Disable;*/

	}
}