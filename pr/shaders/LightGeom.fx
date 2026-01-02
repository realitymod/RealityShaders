#line 2 "LightGeom.fx"

/*
    Handles geometry lighting calculations.
*/

#include "shaders/RealityGraphics.fxh"
#include "shaders/shared/RealityDepth.fxh"
#if !defined(_HEADERS_)
	#include "RealityGraphics.fxh"
	#include "shared/RealityDepth.fxh"
#endif

/*
	[Attributes from app]
*/

float4x4 _WorldViewProj : WorldViewProj;
float4x4 _WorldView : WorldView;
float4 _LightColor : LightColor;
float3 _SpotDir : SpotDir;
float _ConeAngle : ConeAngle;
// float3 _SpotPosition : SpotPosition;

struct APP2VS
{
	float4 Pos : POSITION;
};

struct VS2PS
{
	float4 HPos : POSITION;
	float4 Pos : TEXCOORD0;
};

VS2PS VS_PointLight(APP2VS Input)
{
	VS2PS Output = (VS2PS)0.0;

	Output.HPos = mul(float4(Input.Pos.xyz, 1.0), _WorldViewProj);
	Output.Pos = Output.HPos;

	// Output Depth
	#if PR_LOG_DEPTH
		Output.Pos.w = Output.HPos.w + 1.0;
	#endif

	return Output;
}

RGraphics_PS2FB PS_PointLight(VS2PS Input)
{
	RGraphics_PS2FB Output = (RGraphics_PS2FB)0.0;

	Output.Color = _LightColor;

	#if PR_LOG_DEPTH
		Output.Depth = RDepth_ApplyLogarithmicDepth(Input.Pos.w);
	#endif

	return Output;
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
		ZFunc = PR_ZFUNC_WITHEQUAL;
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

VS2PS_Spot VS_SpotLight(APP2VS Input)
{
	VS2PS_Spot Output = (VS2PS_Spot)0.0;

 	Output.HPos = mul(float4(Input.Pos.xyz, 1.0), _WorldViewProj);
	// Transform vertex
	float3 VertPos = mul(float4(Input.Pos.xyz, 1.0), _WorldView);
	Output.Pos.xyz = -normalize(VertPos);

	// Output Depth
	#if PR_LOG_DEPTH
		Output.Pos.w = Output.HPos.w + 1.0;
	#endif

	Output.SpotDir = mul(_SpotDir, (float3x3)_WorldView);

	return Output;
}

RGraphics_PS2FB PS_SpotLight(VS2PS_Spot Input)
{
	RGraphics_PS2FB Output = (RGraphics_PS2FB)0.0;

	float3 LightDir = normalize(Input.Pos.xyz);
	float3 SpotDir = normalize(Input.SpotDir.xyz);
	float DotLD = saturate(dot(LightDir, SpotDir));
	float ConicalAtt = saturate((DotLD * DotLD) - (1.0 - _ConeAngle));

	Output.Color = _LightColor * ConicalAtt;

	#if PR_LOG_DEPTH
		Output.Depth = RDepth_ApplyLogarithmicDepth(Input.Pos.w);
	#endif

	return Output;
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
		ZFunc = PR_ZFUNC_WITHEQUAL;
		ZWriteEnable = TRUE;

		StencilEnable = TRUE;
		StencilFunc = ALWAYS;
		StencilPass = ZERO;

 		VertexShader = compile vs_3_0 VS_SpotLight();
		PixelShader = compile ps_3_0 PS_SpotLight();
	}
}
