
/*
	Include header files
*/

#include "shaders/RealityGraphics.fxh"
#if !defined(INCLUDED_HEADERS)
	#include "RealityGraphics.fxh"
#endif

/*
	Description: Renders pointlight and spotlights
*/

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
	float4 Pos : TEXCOORD0;
};

struct PS2FB
{
	float4 Color : COLOR0;
	#if defined(LOG_DEPTH)
		float Depth : DEPTH;
	#endif
};

void VS_PointLight(in APP2VS Input, out VS2PS Output)
{
	Output = (VS2PS)0.0;

	Output.HPos = mul(float4(Input.Pos.xyz, 1.0), _WorldViewProj);
	Output.Pos = Output.HPos;
	#if defined(LOG_DEPTH)
		Output.Pos.w = Output.HPos.w + 1.0; // Output depth
	#endif
}

void PS_PointLight(in VS2PS Input, out PS2FB Output)
{
	Output.Color = _LightColor;

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);
	#endif
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

 		VertexShader = compile vs_3_0 VS_PointLight();
		PixelShader = compile ps_3_0 PS_PointLight();
	}
}

struct VS2PS_Spot
{
	float4 HPos : POSITION;
	float4 Pos : TEXCOORD0;
	float3 SpotDir : TEXCOORD1;
};

void VS_SpotLight(in APP2VS Input, out VS2PS_Spot Output)
{
	Output = (VS2PS)0.0;

 	Output.HPos = mul(float4(Input.Pos.xyz, 1.0), _WorldViewProj);

	// Transform vertex
	float3 VertPos = mul(float4(Input.Pos.xyz, 1.0), _WorldView);
	Output.Pos.xyz = -normalize(VertPos);
	#if defined(LOG_DEPTH)
		Output.Pos.w = Output.HPos.w + 1.0; // Output depth
	#endif

	Output.SpotDir = mul(_SpotDir, (float3x3)_WorldView);
}

void PS_SpotLight(in VS2PS_Spot Input, out PS2FB Output)
{
	float3 LightDir = normalize(Input.Pos.xyz);
	float3 SpotDir = normalize(Input.SpotDir.xyz);
	float DotLD = saturate(dot(LightDir, SpotDir));
	float ConicalAtt = saturate((DotLD * DotLD) - (1.0 - _ConeAngle));

	Output.Color = _LightColor * ConicalAtt;

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);
	#endif
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

 		VertexShader = compile vs_3_0 VS_SpotLight();
		PixelShader = compile ps_3_0 PS_SpotLight();
	}
}
