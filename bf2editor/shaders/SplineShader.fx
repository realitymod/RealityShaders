#include "shaders/RealityGraphics.fxh"
#if !defined(_HEADERS_)
	#include "RealityGraphics.fxh"
#endif

float4x4 _WorldViewProj : WorldViewProjection;
float4 _Diffuse : DiffuseColor;

struct APP2VS_Spline
{
	float4 Pos : POSITION;
	float3 Normal : NORMAL;
};

struct APP2VS_ControlPoint
{
	float4 Pos : POSITION;
};

struct VS2PS
{
	float4 HPos : POSITION;
};

VS2PS VS_Spline(APP2VS_Spline Input)
{
	VS2PS Output = (VS2PS)0.0;
	Input.Pos.xyz -= 0.035 * Input.Normal;
	Output.HPos = mul(Input.Pos, _WorldViewProj);
	return Output;
}

float4 PS_Spline() : COLOR0
{
	return _Diffuse;
}

VS2PS VS_ControlPoint(APP2VS_ControlPoint Input)
{
	VS2PS Output = (VS2PS)0.0;
	Output.HPos = mul(Input.Pos, _WorldViewProj);
	return Output;
}

float4 PS_ControlPoint() : COLOR0
{
	return _Diffuse;
}

technique spline
<
	int DetailLevel = DLHigh+DLNormal+DLLow+DLAbysmal;
	int Compatibility = CMPR300+CMPNV2X;
	int Declaration[] = 
	{
		// StreamNo, DataType, Usage, UsageIdx
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_POSITION, 0 },
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_NORMAL, 0 },
		DECLARATION_END // End macro
	};
>
{
	pass p0
	{
		CullMode = NONE;
		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		#if PR_IS_REVERSED_Z
			DepthBias = 0.0003;
		#else
			DepthBias = -0.0003;
		#endif
	
		VertexShader = compile vs_3_0 VS_Spline();
		PixelShader = compile ps_3_0 PS_Spline();
	}
}

technique controlpoint
<
	int DetailLevel = DLHigh+DLNormal+DLLow+DLAbysmal;
	int Compatibility = CMPR300+CMPNV2X;
	int Declaration[] = 
	{
		// StreamNo, DataType, Usage, UsageIdx
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_POSITION, 0 },
		DECLARATION_END // End macro
	};
>
{
	pass p0
	{
		CullMode = NONE;
		AlphaBlendEnable = FALSE;

		#if PR_IS_REVERSED_Z
			DepthBias = 0.0003;
		#else
			DepthBias = -0.0003;
		#endif

		VertexShader = compile vs_3_0 VS_ControlPoint();
		PixelShader = compile ps_3_0 PS_ControlPoint();
	}
}
