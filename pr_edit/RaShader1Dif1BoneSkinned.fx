// Global variables we use to hold the view matrix,	projection matrix,
// ambient material, diffuse material, and the light vector that 
// describes the direction to the light source.	 These variables are 
// initialized from the application.
#include "shaders/RaCommon.fx"

bool AlphaBlendEnable = false;

float4x4 Bones[26];
float4x4 world;
vector textureFactor = float4(1.0f, 1.0f, 1.0f, 1.0f);

texture DiffuseMap;
sampler DiffuseMapSampler = sampler_state
{
	Texture = (DiffuseMap);
	MipFilter = LINEAR;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	AddressU = WRAP;
	AddressV = WRAP;
	MipMapLodBias = 0;
};

//-----------VS/PS----

struct VS_OUTPUT
{
	float4 Pos : POSITION0;
	float2 Tex : TEXCOORD0;
	float Fog : FOG;
};

string reqVertexElement[] = 
{
 	"Position",
 	"TBase2D",
 	"Bone4Idcs"
};

VS_OUTPUT basicVertexShader
(
float3 inPos: POSITION0,
float2 tex0 : TEXCOORD0,
float4 blendIndices : BLENDINDICES
)
{
	VS_OUTPUT Out = (VS_OUTPUT)0.0;

	// Compensate for lack of UBYTE4 on Geforce3
	int4 indexVector = D3DCOLORtoUBYTE4(blendIndices);
	int indexArray[4] = (int[4])indexVector;

	Out.Pos = mul(float4(inPos, 1), mul(Bones[indexArray[0]], ViewProjection));
	Out.Fog = calcFog(Out.Pos.w);
	Out.Tex = tex0;

	return Out;
}

float4 PixelShader(VS_OUTPUT VsOut) : COLOR
{
	return tex2D(DiffuseMapSampler, VsOut.Tex) * float4(1,0,1,1);
};

string TemplateParameters[] = 
{
	"DiffuseMap",
	"ViewProjection"
};

string InstanceParameters[] = 
{
	"Bones",
	"AlphaBlendEnable"
};

technique defaultTechnique
{
	pass P0
	{
		vertexShader = compile vs_1_1 basicVertexShader();
		pixelShader = compile ps_1_3 PixelShader();

#ifdef ENABLE_WIREFRAME
		FillMode = WireFrame;
#endif

		AlphaTestEnable = < AlphaTest >;
		AlphaBlendEnable= < AlphaBlendEnable >;
		AlphaRef = < alphaRef >;
		SrcBlend = < srcBlend >;
		DestBlend = < destBlend >;
	}
}
