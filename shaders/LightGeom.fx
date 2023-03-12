
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
	float4 Pos : TEXCOORD0;
};

struct PS2FB
{
	float4 Color : COLOR;
	#if defined(LOG_DEPTH)
		float Depth : DEPTH;
	#endif
};

VS2PS PointLight_VS(APP2VS Input)
{
	VS2PS Output = (VS2PS)0;

	Output.HPos = mul(float4(Input.Pos.xyz, 1.0), _WorldViewProj);
	Output.Pos = Output.HPos;
	#if defined(LOG_DEPTH)
		Output.Pos.w = Output.HPos.w + 1.0; // Output depth
	#endif

	return Output;
}

PS2FB PointLight_PS(VS2PS Input)
{
	PS2FB Output = (PS2FB)0;

	Output.Color = _LightColor;

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);
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
	pass Pass0
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
	float4 Pos : TEXCOORD0;
	float3 LightDir : TEXCOORD1;
};

VS2PS_Spot SpotLight_VS(APP2VS Input)
{
	VS2PS_Spot Output = (VS2PS_Spot)0;

 	Output.HPos = mul(float4(Input.Pos.xyz, 1.0), _WorldViewProj);

	// Transform vertex
	float3 VertPos = mul(float4(Input.Pos.xyz, 1.0), _WorldView);
	Output.Pos.xyz = -normalize(VertPos);
	#if defined(LOG_DEPTH)
		Output.Pos.w = Output.HPos.w + 1.0; // Output depth
	#endif

	Output.LightDir = mul(_SpotDir, (float3x3)_WorldView);

	return Output;
}

PS2FB SpotLight_PS(VS2PS_Spot Input)
{
	PS2FB Output = (PS2FB)0;

	float3 LightVec = normalize(Input.Pos.xyz);
	float3 LightDir = normalize(Input.LightDir.xyz);
	float DotLD = saturate(dot(LightVec, LightDir));
	float ConicalAtt = saturate((DotLD * DotLD) - (1.0 - _ConeAngle));

	Output.Color = _LightColor * ConicalAtt;

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);
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
	pass Pass0
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
