#include "shaders/RaCommon.fx"

float4 ObjectSpaceCamPos;

texture DiffuseMap;
sampler DiffuseMapSampler = sampler_state
{
	Texture = (DiffuseMap);
	MipFilter = LINEAR;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	AddressU = WRAP;
	AddressV = WRAP;
};

string GlobalParameters[] =
{
	"FogColor",
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
	"Transparency",
	"ObjectSpaceCamPos"
};

// INPUTS TO THE VERTEX SHADER FROM THE APP
string reqVertexElement[] =
{
	"Position",
	"TBase2D"
};

struct APP2VS
{
	float3 Pos : POSITION0;
	float2 Tex0 : TEXCOORD0;
};

struct VS2PS
{
	float4 Pos : POSITION0;
	float2 Tex0 : TEXCOORD0;
	float2 Tex1 : TEXCOORD1;
	float Fog : FOG;
};

VS2PS Diffuse_VS(APP2VS Input)
{
	VS2PS Output = (VS2PS)0;

	Output.Pos = mul(float4(Input.Pos.xyz, 1.0), mul(World, ViewProjection));
	Output.Fog = GetFogValue(Input.Pos.xyz, ObjectSpaceCamPos.xyz);
	Output.Tex0 = Input.Tex0;

	return Output;
}

float4 Diffuse_PS(VS2PS Input) : COLOR
{
	float4 DiffuseMap = tex2D(DiffuseMapSampler, Input.Tex0);
	DiffuseMap.rgb = ApplyFog(DiffuseMap.rgb, Input.Fog);
	return DiffuseMap;
};

technique defaultTechnique
{
	pass P0
	{
		VertexShader = compile vs_3_0 Diffuse_VS();
		PixelShader = compile ps_3_0 Diffuse_PS();

		#if defined(ENABLE_WIREFRAME)
			FillMode = WireFrame;
		#endif

		AlphaTestEnable = TRUE; // < AlphaTest >;
		AlphaBlendEnable = <alphaBlendEnable>;
		AlphaRef = <alphaRef>;
		SrcBlend = <srcBlend>;
		DestBlend = <destBlend>;

		AlphaRef = 127; // temporary hack by johan because "m_shaderSettings.m_alphaTestRef = 127" somehow doesn't work
	}
}
