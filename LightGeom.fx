
/*
	Description: Renders pointlight and spotlights
*/

#include "shaders/RealityGraphics.fxh"

/*
	[Attributes from app]
*/

uniform float4x4 _WorldViewProj : WorldViewProj;
uniform float4x4 _WorldView : WorldView;
uniform float4 _LightColor : LightColor;
uniform float3 _SpotDir : SpotDir;
uniform float _ConeAngle : ConeAngle;
// uniform float3 _SpotPosition : SpotPosition;

struct APP2VS
{
	float4 Pos : POSITION;
};

struct VS2PS
{
	float4 HPos : POSITION;
};

VS2PS PointLight_VS(APP2VS Input)
{
	VS2PS Output;
	Output.HPos = mul(float4(Input.Pos.xyz, 1.0f), _WorldViewProj);
	return Output;
}

float4 PointLight_PS() : COLOR
{
	return _LightColor;
}

technique Pointlight
<
	int Declaration[] =
	{
		// StreamNo, DataType, Usage, UsageIdx
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_POSITION, 0 },
		DECLARATION_END	// End macro
	};
>
{
	pass p0
	{
		CullMode = NONE;
		ZEnable = TRUE;
		ZFunc = LESSEQUAL;
		ZWriteEnable = TRUE;
		StencilEnable = TRUE;
		StencilFunc = ALWAYS;
		StencilPass = ZERO;

 		VertexShader = compile vs_3_0 PointLight_VS();
		PixelShader = compile ps_3_0 PointLight_PS();
	}
}

struct VS2PS_Spot
{
	float4 HPos : POSITION;
	float3 LightDir : TEXCOORD0;
	float3 LightVec : TEXCOORD1;
};

VS2PS_Spot SpotLight_VS(APP2VS Input)
{
	VS2PS_Spot Output;
 	Output.HPos = mul(float4(Input.Pos.xyz, 1.0f), _WorldViewProj);

	// transform vertex
	float3 VertPos = mul(float4(Input.Pos.xyz, 1.0f), _WorldView);
	Output.LightVec = -normalize(VertPos);

	// transform LightDir to objectSpace
	Output.LightDir = mul(_SpotDir, float3x3(_WorldView[0].xyz, _WorldView[1].xyz, _WorldView[2].xyz));

	return Output;
}

float4 SpotLight_PS(VS2PS_Spot Input) : COLOR
{
	float3 LightVec = normalize(Input.LightVec);
	float3 LightDir = normalize(Input.LightDir);
	float ConicalAtt = saturate(pow(saturate(dot(LightVec, LightDir)), 2.0) + (1.0f - _ConeAngle));
	return _LightColor * ConicalAtt;
}

technique Spotlight
<
	int Declaration[] =
	{
		// StreamNo, DataType, Usage, UsageIdx
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_POSITION, 0 },
		DECLARATION_END	// End macro
	};
>
{
	pass p0
	{
		CullMode = NONE;
		ZEnable = TRUE;
		ZFunc = LESSEQUAL;
		ZWriteEnable = TRUE;
		StencilEnable = TRUE;
		StencilFunc = ALWAYS;
		StencilPass = ZERO;

 		VertexShader = compile vs_3_0 SpotLight_VS();
		PixelShader = compile ps_3_0 SpotLight_PS();
	}
}
