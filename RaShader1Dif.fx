
/*
	Description: Renders object's diffuse map
*/

#include "shaders/RealityGraphics.fxh"

#include "shaders/RaCommon.fxh"

uniform float4 ObjectSpaceCamPos;

uniform texture DiffuseMap;
sampler SampleDiffuseMap = sampler_state
{
	Texture = (DiffuseMap);
	MipFilter = LINEAR;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	AddressU = WRAP;
	AddressV = WRAP;
	SRGBTexture = FALSE;
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
	float4 HPos : POSITION;
	float2 Tex0 : TEXCOORD0;
	float3 VertexPos : TEXCOORD1;
};

VS2PS Diffuse_VS(APP2VS Input)
{
	VS2PS Output = (VS2PS)0;

	Output.HPos = mul(float4(Input.Pos.xyz, 1.0), mul(World, ViewProjection));
	Output.VertexPos = Input.Pos.xyz;
	Output.Tex0 = Input.Tex0;

	return Output;
}

float4 Diffuse_PS(VS2PS Input) : COLOR
{
	float4 DiffuseMap = tex2D(SampleDiffuseMap, Input.Tex0);
	ApplyFog(DiffuseMap.rgb, GetFogValue(Input.VertexPos.xyz, ObjectSpaceCamPos.xyz));
	return DiffuseMap;
};

technique defaultTechnique
{
	pass P0
	{
		#if defined(ENABLE_WIREFRAME)
			FillMode = WireFrame;
		#endif

		AlphaTestEnable = TRUE; // < AlphaTest >;
		AlphaRef = <alphaRef>;
		AlphaRef = 127; // temporary hack by johan because "m_shaderSettings.m_alphaTestRef = 127" somehow doesn't work

		AlphaBlendEnable = <alphaBlendEnable>;
		SrcBlend = <srcBlend>;
		DestBlend = <destBlend>;

		VertexShader = compile vs_3_0 Diffuse_VS();
		PixelShader = compile ps_3_0 Diffuse_PS();
	}
}
