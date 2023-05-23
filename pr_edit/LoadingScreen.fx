
float4x4 WorldViewProj : TRANSFORM;
texture TexMap : TEXTURE;

sampler TexMapSampler = sampler_state
{
    Texture = <TexMap>;
    AddressU = Wrap;
    AddressV = Wrap;
    MinFilter = Linear;
    MagFilter = Linear;
    MipFilter = Linear;
};


struct VS_OUT
{
	float4 Position : POSITION;
	float4 Diffuse : COLOR0;
	float2 TexCoord : TEXCOORD0;
};

VS_OUT VSScreen(float3 Position : POSITION,float4 Diffuse : COLOR0,float2 TexCoord : TEXCOORD0)
{
	VS_OUT Out = (VS_OUT)0;
	Out.Position = float4(Position.x, Position.y, 0, 1);
	Out.Diffuse = Diffuse;
	Out.TexCoord = TexCoord;
	return Out;
}

technique Screen
{
	pass P0
	{
		VertexShader = compile vs_1_1 VSScreen();
		PixelShader = NULL;
		ColorOp[0]   = Modulate;
		ColorArg1[0] = Texture;
		ColorArg2[0] = Diffuse;
		AlphaOp[0]   = SelectArg1;
		AlphaArg1[0] = Diffuse;
		ColorOp[1] = Disable;
		AlphaOp[1] = Disable;
		AlphaBlendEnable = false;
		StencilEnable = false;
		AlphaTestEnable = false;
		CullMode = None;
		TexCoordIndex[0] =0;
		TextureTransformFlags[0] = Disable;
		Sampler[0] = <TexMapSampler>;
	}
}