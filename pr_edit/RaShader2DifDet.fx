#include "shaders/RaCommon.fx"
 
#define LIGHT_ADD float3(0.5, 0.5, 0.5)

int srcBlend = 5;
int destBlend = 6;
bool AlphaBlendEnable = true;

int alphaRef = 20;

float Transparency;

Light Lights[1];
vector textureFactor = float4(1.0f, 1.0f, 1.0f, 1.0f);

struct VS_OUTPUT
{
	float4 Pos : POSITION0;
	float2 Tex0 : TEXCOORD0;
	float2 Tex1 : TEXCOORD1;
	float4 Color : COLOR;
	float Fog : FOG;
};

texture DetailMap;
sampler DetailMapSampler = sampler_state
{
	Texture = (DetailMap);
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
 	"Normal",
 	"TBase2D",
 	"TDetail2D",
};

float4x4 World;
float4x4 ViewProjection;

VS_OUTPUT basicVertexShader
(
float3 inPos: POSITION0,
float3 inNormal: NORMAL,
float2 tex0 : TEXCOORD0,
float2 tex1 : TEXCOORD1
)
{
	VS_OUTPUT Out = (VS_OUTPUT)0.0;

	Out.Pos = mul(float4(inPos, 1), mul(World, ViewProjection));
	Out.Fog = calcFog(FogRange, Out.Pos.w);
	Out.Tex0 = tex0;
	Out.Tex1 = tex1;
	
	float3 normal = mul(inNormal, World);
	Out.Color.rgb = (saturate(dot(normal, -Lights[0].dir) * Lights[0].color) + LIGHT_ADD);
	Out.Color.a = 1.0;

	return Out;
}

string GlobalParameters[] = 
{
	"FogRange",
	"ViewProjection"
};

string TemplateParameters[] = 
{
	"DiffuseMap",
	"DetailMap",
};

string InstanceParameters[] = 
{
	"World",
	"Transparency",
	"AlphaBlendEnable",
	"Lights"
};

float4 basicPixelShader(VS_OUTPUT VsOut) : COLOR
{
	float4 FinalColor;
	FinalColor.rgb = VsOut.Color * tex2D(DiffuseMapSampler, VsOut.Tex0) * tex2D(DetailMapSampler, VsOut.Tex1);
	FinalColor.a = tex2D(DiffuseMapSampler, VsOut.Tex0).a;
	return FinalColor;
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

		AlphaTestEnable = < AlphaTest >;
		AlphaBlendEnable= < AlphaBlendEnable >;
		AlphaRef = < alphaRef >;
		SrcBlend = < srcBlend >;
		DestBlend = < destBlend >;

		AlphaRef = 127; // temporary hack by johan because "m_shaderSettings.m_alphaTestRef = 127" somehow doesn't work

		fogenable = true;
	}
}
