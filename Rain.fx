
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

texture Tex0 : TEXTURE;

sampler SampleTex0 = sampler_state
{
	Texture = (Tex0);
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = LINEAR;
	AddressU = CLAMP;
	AddressV = CLAMP;
	SRGBTexture = FALSE;
};

struct APP2PS
{
	float3 Pos: POSITION;
	float4 Data : COLOR0;
	float2 TexCoord: TEXCOORD0;
};

struct VS2PS_Point
{
	float4 HPos: POSITION;
	float2 TexCoord : TEXCOORD0;
	float4 Color : COLOR0;
	float PointSize : PSIZE;
};

VS2PS_Point Point_VS(APP2PS Input)
{
	VS2PS_Point Output;

	float3 CellPos = _CellPositions[Input.Data.x];
	float3 Deviation = _Deviations[Input.Data.y];
	float3 ParticlePos = Input.Pos + CellPos + Deviation;

	float3 CamDelta = abs(_CameraPos.xyz - ParticlePos.xyz);
	float CamDist = length(CamDelta);
	CamDelta = (CamDelta - _FadeOutRange) / _FadeOutDelta;

	float Alpha = 1.0f - length(saturate(CamDelta));

	Output.Color = saturate(float4(_ParticleColor.rgb, _ParticleColor.a * Alpha));
	Output.HPos = mul(float4(ParticlePos, 1.0), _WorldViewProj);
	Output.TexCoord = Input.TexCoord;
	Output.PointSize = min(_ParticleSize * rsqrt(_PointScale[0] + _PointScale[1] * CamDist), _MaxParticleSize);

	return Output;
}

float4 Point_PS(VS2PS_Point Input) : COLOR
{
	float4 TexCol = tex2D(SampleTex0, Input.TexCoord);
	return TexCol * Input.Color;
}

technique Point
{
	pass Pass0
	{
		ZEnable = TRUE;
		ZFunc = LESSEQUAL;
		ZWriteEnable = FALSE; // TRUE;
		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = ONE; // INVSRCALPHA;
		CullMode = NONE;

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
	float2 TexCoord : TEXCOORD0;
	float4 Color : COLOR0;
};

VS2PS_Line Line_VS(APP2PS Input)
{
	VS2PS_Line Output;

	float3 CellPos = _CellPositions[Input.Data.x];
	float3 ParticlePos = Input.Pos + CellPos;

	float3 CamDelta = abs(_CameraPos.xyz - ParticlePos.xyz);
	CamDelta = (CamDelta - _FadeOutRange) / _FadeOutDelta;
	float Alpha = 1.0f - length(saturate(CamDelta));

	Output.Color = saturate(float4(_ParticleColor.rgb, _ParticleColor.a * Alpha));
	Output.HPos = mul(float4(ParticlePos, 1.0), _WorldViewProj);
	Output.TexCoord = Input.TexCoord;

	return Output;
}

float4 Line_PS(VS2PS_Line Input) : COLOR
{
	return Input.Color;
}

technique Line
{
	pass Pass0
	{
		ZEnable = TRUE;
		ZFunc = LESSEQUAL;
		ZWriteEnable = FALSE; // TRUE;
		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = ONE; // INVSRCALPHA;
		CullMode = NONE;

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
	float2 TexCoord : TEXCOORD0;
	float4 Color : COLOR0;
};

VS2PS_Cell Cells_VS(APP2PS Input)
{
	VS2PS_Cell Output;

	float3 CellPos = _CellPositions[Input.Data.x];
	float3 ParticlePos = Input.Pos + CellPos;

	Output.Color = saturate(_ParticleColor);
	Output.HPos = mul(float4(ParticlePos, 1.0), _WorldViewProj);
	Output.TexCoord = Input.TexCoord;

	return Output;
}

float4 Cells_PS(VS2PS_Cell Input) : COLOR
{
	return Input.Color;
}

technique Cells
{
	pass Pass0
	{
		ZEnable = TRUE;
		ZFunc = LESSEQUAL;
		ZWriteEnable = FALSE; // TRUE;
		AlphaBlendEnable = TRUE;
		SrcBlend = SrcAlpha;
		DestBlend = ONE; // INVSRCALPHA;
		CullMode = NONE;

		VertexShader = compile vs_3_0 Cells_VS();
		PixelShader = compile ps_3_0 Cells_PS();
	}
}
