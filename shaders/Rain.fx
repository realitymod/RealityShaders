
/*
	Description: Renders rain effect
*/

#include "shaders/RealityGraphics.fxh"

float4x4 _WorldViewProj : WORLDVIEWPROJ;
float4 _CellPositions[32] : CELLPOSITIONS;
float4 _Deviations[16] : DEVIATIONGROUPS;
float4 _ParticleColor: PARTICLECOLOR;
float4 _CameraPos : CAMERAPOS;
float3 _FadeOutRange : FADEOUTRANGE;
float3 _FadeOutDelta : FADEOUTDELTA;
float3 _PointScale : POINTSCALE;
float _ParticleSize : PARTICLESIZE;
float _MaxParticleSize : PARTICLEMAXSIZE;

uniform texture Tex0 : TEXTURE;
sampler SampleTex0 = sampler_state
{
	Texture = (Tex0);
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = LINEAR;
	AddressU = CLAMP;
	AddressV = CLAMP;
};

struct APP2PS
{
	float3 Pos: POSITION;
	float4 Data : COLOR0;
	float2 Tex0 : TEXCOORD0;
};

struct VS2PS
{
	float4 HPos : POSITION;
	float3 Tex0 : TEXCOORD0;
	float4 Color : TEXCOORD1;
	float PointSize : PSIZE;
};

struct PS2FB
{
	float4 Color : COLOR;
	#if defined(LOG_DEPTH)
		float Depth : DEPTH;
	#endif
};

VS2PS Point_VS(APP2PS Input)
{
	VS2PS Output = (VS2PS)0;

	float3 CellPos = _CellPositions[Input.Data.x];
	float3 Deviation = _Deviations[Input.Data.y];
	float3 ParticlePos = Input.Pos + CellPos + Deviation;

	float3 CamDelta = abs(_CameraPos.xyz - ParticlePos.xyz);
	float CamDist = length(CamDelta);
	CamDelta = (CamDelta - _FadeOutRange) / _FadeOutDelta;
	float Alpha = 1.0 - length(saturate(CamDelta));

	Output.HPos = mul(float4(ParticlePos, 1.0), _WorldViewProj);
	Output.Tex0.xy = Input.Tex0;
	#if defined(LOG_DEPTH)
		Output.Tex0.z = Output.HPos.w + 1.0; // Output depth
	#endif

	Output.Color = saturate(float4(_ParticleColor.rgb, _ParticleColor.a * Alpha));
	Output.PointSize = min(_ParticleSize * rsqrt(_PointScale[0] + _PointScale[1] * CamDist), _MaxParticleSize);

	return Output;
}

PS2FB Point_PS(VS2PS Input)
{
	PS2FB Output = (PS2FB)0;

	float4 ColorTex = tex2D(SampleTex0, Input.Tex0.xy);

	Output.Color = ColorTex  * Input.Color;

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Tex0.z);
	#endif

	return Output;
}

technique Point
{
	pass Pass0
	{
		CullMode = NONE;

		ZEnable = TRUE;
		ZFunc = LESSEQUAL;
		ZWriteEnable = FALSE; // TRUE;

		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = ONE; // INVSRCALPHA;

		VertexShader = compile vs_3_0 Point_VS();
		PixelShader = compile ps_3_0 Point_PS();
	}
}

/*
	Line Technique
*/

struct VS2PS_Line
{
	float4 HPos : POSITION;
	float3 Tex0 : TEXCOORD0;
	float4 Color : TEXCOORD1;
};

VS2PS_Line Line_VS(APP2PS Input)
{
	VS2PS_Line Output = (VS2PS_Line)0;

	float3 CellPos = _CellPositions[Input.Data.x];
	float3 ParticlePos = Input.Pos + CellPos;

	float3 CamDelta = abs(_CameraPos.xyz - ParticlePos.xyz);
	CamDelta = (CamDelta - _FadeOutRange) / _FadeOutDelta;
	float Alpha = 1.0 - length(saturate(CamDelta));

	Output.Color = saturate(float4(_ParticleColor.rgb, _ParticleColor.a * Alpha));
	Output.HPos = mul(float4(ParticlePos, 1.0), _WorldViewProj);
	Output.Tex0.xy = Input.Tex0;
	#if defined(LOG_DEPTH)
		Output.Tex0.z = Output.HPos.w + 1.0; // Output depth
	#endif

	return Output;
}

PS2FB Line_PS(VS2PS_Line Input)
{
	PS2FB Output = (PS2FB)0;

	Output.Color = Input.Color;

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Tex0.z);
	#endif

	return Output;
}

technique Line
{
	pass Pass0
	{
		CullMode = NONE;

		ZEnable = TRUE;
		ZFunc = LESSEQUAL;
		ZWriteEnable = FALSE; // TRUE;

		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = ONE; // INVSRCALPHA;

		VertexShader = compile vs_3_0 Line_VS();
		PixelShader = compile ps_3_0 Line_PS();
	}
}

/*
	Debug Cell Technique
*/

struct VS2PS_Cell
{
	float4 HPos: POSITION;
	float3 Tex0 : TEXCOORD0;
	float4 Color : TEXCOORD1;
};

VS2PS_Cell Cells_VS(APP2PS Input)
{
	VS2PS_Cell Output = (VS2PS_Cell)0;

	float3 CellPos = _CellPositions[Input.Data.x];
	float3 ParticlePos = Input.Pos + CellPos;

	Output.Color = saturate(_ParticleColor);
	Output.HPos = mul(float4(ParticlePos, 1.0), _WorldViewProj);
	Output.Tex0.xy = Input.Tex0;
	#if defined(LOG_DEPTH)
		Output.Tex0.z = Output.HPos.w + 1.0; // Output depth
	#endif

	return Output;
}

PS2FB Cells_PS(VS2PS_Cell Input)
{
	PS2FB Output = (PS2FB)0;

	Output.Color = Input.Color;

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Tex0.z);
	#endif

	return Output;
}

technique Cells
{
	pass Pass0
	{
		CullMode = NONE;

		ZEnable = TRUE;
		ZFunc = LESSEQUAL;
		ZWriteEnable = FALSE; // TRUE;

		AlphaBlendEnable = TRUE;
		SrcBlend = SrcAlpha;
		DestBlend = ONE; // INVSRCALPHA;

		VertexShader = compile vs_3_0 Cells_VS();
		PixelShader = compile ps_3_0 Cells_PS();
	}
}
