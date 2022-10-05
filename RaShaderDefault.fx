
float4x4 World;
float4x4 ViewProjection;
int textureFactor = 0xffAFFFaF;
bool alphaBlendEnable = false;

string reqVertexElement[] =
{
	"Position"
};

string InstanceParameters[] =
{
	"World",
	"ViewProjection"
};

float4 Basic_VS(float3 Pos : POSITION0) : POSITION0
{
    return mul(float4(Pos.xyz, 1.0), mul(World, ViewProjection));
}

float4 Basic_PS() : COLOR
{
	return float4(0.9, 0.4, 0.8, 1.0);
};

technique defaultShader
{
	pass P0
    {
        VertexShader = compile vs_3_0 Basic_VS();
        PixelShader = compile ps_3_0 Basic_PS();
		#if defined(ENABLE_WIREFRAME)
			FillMode = WireFrame;
		#endif
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;
		CullMode = NONE;
		AlphaBlendEnable = <alphaBlendEnable>;
		AlphaTestEnable = FALSE;
	}
}
