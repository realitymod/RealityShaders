#line 2 "SplineShader.fx"

float4x4 mWorldViewProj : WorldViewProjection;
float4 vDiffuse : DiffuseColor;

float4 SplineVS(float4 Pos : POSITION, float3 Normal : NORMAL) : POSITION
{
	Pos.xyz -= 0.035 * Normal;
	return mul(Pos, mWorldViewProj);
}

float4 SplinePS() : COLOR0
{
	return vDiffuse;
// return float4(1, 0, 0, 0.5);
}

float4 ControlPointVS(float4 Pos : POSITION) : POSITION
{
	return mul(Pos, mWorldViewProj);
}

float4 ControlPointPS() : COLOR0
{
	return vDiffuse;
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
	    // Lighting = TRUE;
		// FillMode = WIREFRAME;
		// ColorWriteEnable = 0;
		// ZWriteEnable = 0;
		// ZEnable = (zbuffer);
		// ZEnable = FALSE;
		DepthBias = -0.0003;
AlphaBlendEnable = TRUE;
SrcBlend = SRCALPHA;
DestBlend = INVSRCALPHA;

	
		VertexShader = compile vs_1_1 SplineVS();
		PixelShader = compile ps_1_1 SplinePS();
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
	
		VertexShader = compile vs_1_1 ControlPointVS();
		PixelShader = compile ps_1_1 ControlPointPS();
	}
}

