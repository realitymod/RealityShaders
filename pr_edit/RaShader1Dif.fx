#include "shaders/RaCommon.fx"

struct VS_OUTPUT
{
	float4 Pos : POSITION0;
	float2 Tex0 : TEXCOORD0;
	float2 Tex1 : TEXCOORD1;
	float Fog : FOG;
};

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

// INPUTS TO THE VERTEX SHADER FROM THE APP
string reqVertexElement[] = 
{
 	"Position",
 	"TBase2D"
};

VS_OUTPUT basicVertexShader
(
float3 inPos: POSITION0,
float2 tex0 : TEXCOORD0
)
{
	VS_OUTPUT Out = (VS_OUTPUT)0.0;

	Out.Pos = mul(float4(inPos, 1), mul(World, ViewProjection));
	Out.Fog = calcFog(Out.Pos.w);
	Out.Tex0 = tex0;

	return Out;
}

string GlobalParameters[] = 
{
	"FogRange"
};

string TemplateParameters[] = 
{
	"DiffuseMap",
	"ViewProjection",
	"AlphaTest"
};

string InstanceParameters[] = 
{
	"World",
	"Transparency"
};

float4 basicPixelShader(VS_OUTPUT VsOut) : COLOR
{
	float4 diffuseMap = tex2D(DiffuseMapSampler, VsOut.Tex0);
	return diffuseMap;
};

technique defaultTechnique
{
	pass P0
	{
		vertexShader = compile vs_1_1 basicVertexShader();
		pixelShader = compile ps_1_1 basicPixelShader();

#ifdef ENABLE_WIREFRAME
		FillMode = WireFrame;
#endif

		AlphaTestEnable = true;//< AlphaTest >;
		AlphaBlendEnable= < alphaBlendEnable >;
		AlphaRef = < alphaRef >;
		SrcBlend = < srcBlend >;
		DestBlend = < destBlend >;

		AlphaRef = 127; // temporary hack by johan because "m_shaderSettings.m_alphaTestRef = 127" somehow doesn't work

		fogenable = true;
	}
}
