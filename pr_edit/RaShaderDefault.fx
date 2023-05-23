
float4x4 World;
float4x4 ViewProjection;
int textureFactor = 0xffAFFFaF;
bool alphaBlendEnable = false;
//-----------VS/PS----

string reqVertexElement[] = 
{
 	"Position"
};
float4 vertexShader(float3 inPos: POSITION0) : POSITION0
{
	return mul(float4(inPos, 1), mul(World, ViewProjection));
}

float4 shader() : COLOR
{
	return float4(0.9,0.4,0.8,1);
};

struct VS_OUTPUT
{
	float4 Pos : POSITION0;
};

string InstanceParameters[] =
{
	"World",
	"ViewProjection"
};

technique defaultShader
{
	pass P0
	{
		pixelshader = compile ps_1_1 shader();
		vertexShader= compile vs_1_1 vertexShader();
#ifdef ENABLE_WIREFRAME
		FillMode = WireFrame;
#endif
		SrcBlend = srcalpha;
		DestBlend = invsrcalpha;
		fogenable = false;
		CullMode = NONE;
		AlphaBlendEnable= <alphaBlendEnable>;
		AlphaTestEnable = false;

// TextureFactor = < textureFactor >;
// ColorOp[0] = selectArg1;
// ColorArg1[0] = TFACTOR;

// AlphaOp[0] = selectArg1;
// AlphaArg1[0] = TFACTOR;

// ColorOp[1] = Disable;
// AlphaOp[1] = Disable;
		
	}
}