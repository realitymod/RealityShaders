#include "shaders/dataTypes.fx"
#include "shaders/RaCommon.fx"
 
Light Lights[1];
float4 OverGrowthAmbient;

struct VS_OUTPUT
{
	float4 Pos : POSITION0;
	float2 Tex0 : TEXCOORD0;
	float4 Color : TEXCOORD1;
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
 	"Normal",
	"TBase2D"
};

VS_OUTPUT basicVertexShader
(
float4 inPos: POSITION0,
float3 normal: NORMAL,
float2 tex0 : TEXCOORD0
)
{
	VS_OUTPUT Out = (VS_OUTPUT)0;

	Out.Pos = mul(float4(inPos.xyz, 1), WorldViewProjection);

	Out.Fog = calcFog(Out.Pos.w);
	Out.Tex0 = tex0 / 32767.0f;

	normal = normal * 2.0f - 1.0f;

	float LdotN = saturate((dot(normal, -Lights[0].dir)));

	Out.Color.rgb = CEXP(Lights[0].color) * LdotN * (inPos.w / 32767) * (inPos.w / 32767);
	Out.Color.rgb += OverGrowthAmbient * (inPos.w / 32767);

	return Out;
}

// There will be small differences between this lighting and the one produced by the static mesh shader,
// not enough to worry about, ambient is added here and lerped in the static mesh, etc
// NOTE: could be an issue at some point.
float4 basicPixelShader(VS_OUTPUT VsOut) : COLOR
{
	float4 diffuseMap = tex2D(DiffuseMapSampler, VsOut.Tex0) * 2;
	float3 color = diffuseMap.rgb * VsOut.Color.rgb;
	return float4(color, Transparency.a);
};

string GlobalParameters[] =
{
	"GlobalTime",
	"FogRange",
	"FogColor",
};

string TemplateParameters[] = 
{
	"DiffuseMap"
};

string InstanceParameters[] =
{
	"WorldViewProjection",
	"Lights",
	"OverGrowthAmbient",
	"Transparency"
};

technique defaultTechnique
{
	pass P0
	{
		vertexShader = compile vs_1_1 basicVertexShader();
		pixelShader = compile PSMODEL basicPixelShader();

#ifdef ENABLE_WIREFRAME
		FillMode = WireFrame;
#endif
		FogEnable = true;
	}
}
