#line 2 "SplineShader.fx"

float4x4 _WorldViewProj : WorldViewProjection;
float4 _Diffuse : DiffuseColor;

struct APP2VS
{
	float4 Pos : POSITION;
	float3 Normal : NORMAL;
};

struct VS2PS
{
	float4 HPos : POSITION;
};

VS2PS VS_Spline(APP2VS Input) : POSITION
{
	VS2PS Output = (VS2PS)0;
	float4 Pos = float4(Input.Pos.xyz * (0.035 * Input.Normal), Input.Pos.w);
	Output.HPos = mul(Pos, _WorldViewProj);
	return Output;
}

float4 PS_Spline() : COLOR0
{
	return _Diffuse;
}

float4 VS_ControlPoint(float4 Pos : POSITION) : POSITION
{
	return mul(Pos, _WorldViewProj);
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
		AlphaBlendEnable = FALSE;
		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;
	
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
		DepthBias = -0.0003;
	
		VertexShader = compile vs_3_0 VS_ControlPoint();
		PixelShader = compile ps_3_0 PS_ControlPoint();
	}
}
