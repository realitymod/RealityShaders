#define LEAF_MOVEMENT 0.04

#include "shaders/RaCommon.fx"
 
// lightDir * LIGHT_MUL + LIGHT_ADD

float4 Ambient;
Light Lights[1];
float4 PosUnpack;
float TexUnpack;

struct VS_OUTPUT
{
	float4 Pos : POSITION0;
	float2 Tex0 : TEXCOORD0;
	float4 Color : COLOR1;
	// float Fog : FOG;
	float4 zComp : COLOR0;
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
 	"PositionPacked",
 	"Normal",
	"TBasePacked2D"
};
VS_OUTPUT basicVertexShader
(
float3 inPos: POSITION0,
float3 leafNormal: NORMAL,
float2 tex0 : TEXCOORD0
)
{
	VS_OUTPUT Out = (VS_OUTPUT)0;

	inPos *= PosUnpack;
	
	WindSpeed += 5;
	inPos +=  sin(GlobalTime * inPos.y * WindSpeed / 4) * LEAF_MOVEMENT * clamp(abs(inPos.z * inPos.x), 0, WindSpeed / 10);

	Out.Pos = mul(float4(inPos, 1), WorldViewProjection);

	// Out.Fog = calcFog(Out.Pos.w);
	Out.Tex0 = tex0 * TexUnpack;

	// float LdotN = 1 - saturate(length(Lights[0].pos.xyz - inPos) * Lights[0].attenuation);
	float3 lightVec = float3(Lights[0].pos.xyz - inPos);
	
	float LdotN = saturate((dot(leafNormal, -normalize(lightVec))));
	
	LdotN *= 1 - saturate(dot(lightVec, lightVec) * Lights[0].attenuation);
	Out.Color.rgb = Lights[0].color * LdotN;
	Out.Color.a = Transparency;
	
	Out.Color *= calcFog(Out.Pos.w);

	return Out;
}

float4 basicPixelShader(VS_OUTPUT VsOut) : COLOR
{
	float4 diffuseMap = tex2D(DiffuseMapSampler, VsOut.Tex0);
	float3 color = VsOut.Color * diffuseMap.rgb;
	
	return float4(color, diffuseMap.a);
};

string GlobalParameters[] =
{
	"GlobalTime",
	"FogRange",
	"ViewProjection",
	"Ambient"
};

string TemplateParameters[] = 
{
	"DiffuseMap"
};

string InstanceParameters[] =
{
	"WorldViewProjection",
	"Transparency",
	"WindSpeed",
	"Lights"
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

		AlphaTestEnable = TRUE;//< AlphaTest >;
// AlphaBlendEnable= < AlphaBlendEnable >;

		AlphaRef = 127;//< alphaRef >;

// AlphaRef = 127; // temporary hack by johan because "m_shaderSettings.m_alphaTestRef = 127" somehow doesn't work
		FogEnable = false;
// texturefactor = < textureFactor >; 
		CullMode = NONE;
	}
}
