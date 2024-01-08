
/*
	Include header files
*/

#include "shaders/RealityGraphics.fxh"
#include "shaders/shared/RealityDepth.fxh"
#if !defined(INCLUDED_HEADERS)
	#include "RealityGraphics.fxh"
	#include "shared/RealityDepth.fxh"
#endif

/*
	Description: Renders rain effect
*/

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
	float4 Color : COLOR0;
	#if defined(LOG_DEPTH)
		float Depth : DEPTH;
	#endif
};

void VS_Point(in APP2PS Input, out VS2PS Output)
{
	Output = (VS2PS)0.0;

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
}

void PS_Point(in VS2PS Input, out PS2FB Output)
{
	Output.Color = tex2D(SampleTex0, Input.Tex0.xy)  * Input.Color;

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Tex0.z);
	#endif
}

technique Point
{
	pass p0
	{
		CullMode = NONE;

		ZEnable = TRUE;
		ZFunc = LESSEQUAL;
		ZWriteEnable = FALSE; // TRUE;

		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = ONE; // INVSRCALPHA;

		VertexShader = compile vs_3_0 VS_Point();
		PixelShader = compile ps_3_0 PS_Point();
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

void VS_Line(in APP2PS Input, out VS2PS_Line Output)
{
	Output = (VS2PS)0.0;

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
}

void PS_Line(in VS2PS_Line Input, out PS2FB Output)
{
	Output.Color = Input.Color;

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Tex0.z);
	#endif
}

technique Line
{
	pass p0
	{
		CullMode = NONE;

		ZEnable = TRUE;
		ZFunc = LESSEQUAL;
		ZWriteEnable = FALSE; // TRUE;

		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = ONE; // INVSRCALPHA;

		VertexShader = compile vs_3_0 VS_Line();
		PixelShader = compile ps_3_0 PS_Line();
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

void VS_Cells(in APP2PS Input, out VS2PS_Cell Output)
{
	Output = (VS2PS)0.0;

	float3 CellPos = _CellPositions[Input.Data.x];
	float3 ParticlePos = Input.Pos + CellPos;

	Output.Color = saturate(_ParticleColor);
	Output.HPos = mul(float4(ParticlePos, 1.0), _WorldViewProj);
	Output.Tex0.xy = Input.Tex0;
	#if defined(LOG_DEPTH)
		Output.Tex0.z = Output.HPos.w + 1.0; // Output depth
	#endif
}

void PS_Cells(in VS2PS_Cell Input, out PS2FB Output)
{
	Output.Color = Input.Color;

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Tex0.z);
	#endif
}

technique Cells
{
	pass p0
	{
		CullMode = NONE;

		ZEnable = TRUE;
		ZFunc = LESSEQUAL;
		ZWriteEnable = FALSE; // TRUE;

		AlphaBlendEnable = TRUE;
		SrcBlend = SrcAlpha;
		DestBlend = ONE; // INVSRCALPHA;

		VertexShader = compile vs_3_0 VS_Cells();
		PixelShader = compile ps_3_0 PS_Cells();
	}
}
