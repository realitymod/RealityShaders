
#include "shaders/RaCommon.fx"
#include "shaders/RaShaderBMCommon.fx"

string GenerateStructs[] =
{
	"reqVertexElement",
	"GlobalParameters",
	"TemplateParameters",
	"InstanceParameters"
};

string reqVertexElement[] = {
	"Position",
	"Normal",
	"Bone4Idcs",
	"TBase2D"
};

string GlobalParameters[] = {
	"ViewProjection"
};

string TemplateParameters[] = {
	"DiffuseMap"
};

string InstanceParameters[] = {
	"GeomBones",
	"Transparency"
};

struct VS_IN
{
	float4 Pos : POSITION;
// float3 Normal : NORMAL;
	float4 BlendIndices : BLENDINDICES;  
	float4 Tex : TEXCOORD0;
};


struct VS_OUT
{
	float4 Pos : POSITION0;
	float4 Tex : TEXCOORD0;
	float Fog : FOG;
};

VS_OUT vs(VS_IN indata)
{
	VS_OUT Out = (VS_OUT)0;
 
 	int4 IndexVector = D3DCOLORtoUBYTE4(indata.BlendIndices);
	int IndexArray[4] = (int[4])IndexVector;
	
	Out.Pos = float4(mul(indata.Pos, GeomBones[IndexArray[0]]), 1);
	Out.Pos = mul(Out.Pos, ViewProjection);
	Out.Fog = calcFog(Out.Pos.w);
	Out.Tex = indata.Tex;

	return Out;
}


float4 ps(VS_OUT indata) : COLOR
{
	float4 outCol = tex2D(DiffuseMapSampler, indata.Tex);
	outCol.rgb *= Transparency;
	return outCol;
}

technique defaultTechnique
{
	pass P0
	{
		vertexShader = compile vs_1_1 vs();
		pixelShader = compile ps_1_3 ps();

#ifdef ENABLE_WIREFRAME
		FillMode = WireFrame;
#endif
		ZFunc = ALWAYS;
		AlphaTestEnable = TRUE;
		AlphaRef = 0;
		AlphaFunc = GREATER;
		AlphaBlendEnable = TRUE;
		SrcBlend = ONE;// SRCALPHA;
		DestBlend = ONE;// INVSRCALPHA;
	}
}
