
#line 3 "DebugD3DXMeshShapeShader.fx"

#include "shaders/RealityGraphics.fx"

float4x4 _WorldViewProj : WorldViewProjection;
float4x4 _World : World;

string Category = "Effects\\Lighting";

texture texture0 : TEXLAYER0;
sampler sampler0 = sampler_state
{
	Texture = (texture0);
	AddressU = WRAP;
	AddressV = WRAP;
	MinFilter = ANISOTROPIC;
	MagFilter = ANISOTROPIC;
	MaxAnisotropy = 16;
	MipFilter = LINEAR;
};

float _TextureScale : TEXTURESCALE;

float4 _LightDir = { 1.0f, 0.0f, 0.0f, 1.0f }; // Light Direction
float4 _MaterialAmbient : MATERIALAMBIENT = {0.5f, 0.5f, 0.5f, 1.0f};
float4 _MaterialDiffuse : MATERIALDIFFUSE = {1.0f, 1.0f, 1.0f, 1.0f};

// float4 _Alpha : BLENDALPHA = { 1.0f, 1.0f, 1.0f, 1.0f };

float4 _ConeSkinValues : CONESKINVALUES;

struct APP2VS
{
	float4 Pos : POSITION;
	float3 Normal : NORMAL;
	float4 Color : COLOR;
};

struct VS2PS
{
	float4 HPos : POSITION;
	float4 Diffuse : COLOR;
};

struct VS2PS_Grid
{
	float4 HPos : POSITION;
	float4 Diffuse : COLOR;
	float2 Tex : TEXCOORD0;
};

float3 Diffuse(float3 Normal, uniform float4 LightDir)
{
	// N.L Clamped
	return saturate(dot(Normal, LightDir.xyz));
}

VS2PS Debug_Basic_1_VS(APP2VS Input)
{
	VS2PS Output;

 	float3 Pos = mul(Input.Pos, _World);
	Output.HPos = mul(float4(Pos.xyz, 1.0f), _WorldViewProj);

	// Lighting. Shade (Ambient + etc.)
	Output.Diffuse.xyz = _MaterialAmbient.rgb + Diffuse(Input.Normal, _LightDir) * _MaterialDiffuse.xyz;
	Output.Diffuse.w = _MaterialAmbient.a;
	return Output;
}

VS2PS Debug_Basic_2_VS(APP2VS Input)
{
	VS2PS Output;

 	float3 Pos = mul(Input.Pos, _World);
	Output.HPos = mul(float4(Pos.xyz, 1.0f), _WorldViewProj);

	// Lighting. Shade (Ambient + etc.)
	Output.Diffuse.xyz = _MaterialAmbient.rgb;
	Output.Diffuse.w = 0.3f;

	return Output;
}

float4 Debug_Basic_PS(VS2PS Input) : COLOR
{
	return Input.Diffuse;
}

float4 Debug_Marked_PS(VS2PS Input) : COLOR
{
	return Input.Diffuse;
}

technique t0
<
	int DetailLevel = DLHigh+DLNormal+DLLow+DLAbysmal;
	int Compatibility = CMPR300+CMPNV2X;
	int Declaration[] =
	{
		// StreamNo, DataType, Usage, UsageIdx
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_POSITION, 0 },
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_NORMAL, 0 },
		DECLARATION_END	// End macro
	};
>
{
	pass p0
	{
		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		VertexShader = compile vs_3_0 Debug_Basic_1_VS();
		PixelShader = compile ps_3_0 Debug_Basic_PS();
	}
}

VS2PS Debug_Occluder_VS(APP2VS Input)
{
	VS2PS Output;

 	float4 Pos = mul(Input.Pos, _World);
	Output.HPos = mul(Pos, _WorldViewProj);

	Output.Diffuse = 1.0;
	return Output;
}

float4 Debug_Occluder_PS(VS2PS Input) : COLOR
{
	return float4(1.0, 0.5, 0.5, 0.5);
}

technique occluder
<
	int DetailLevel = DLHigh+DLNormal+DLLow+DLAbysmal;
	int Compatibility = CMPR300+CMPNV2X;
	int Declaration[] =
	{
		// StreamNo, DataType, Usage, UsageIdx
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_POSITION, 0 },
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_NORMAL, 0 },
		DECLARATION_END	// End macro
	};
>
{
	pass p0
	{
		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;
		ZWriteEnable = TRUE;
		ZEnable = TRUE;
		ZFunc = LESSEQUAL;

		VertexShader = compile vs_3_0 Debug_Occluder_VS();
		PixelShader = compile ps_3_0 Debug_Occluder_PS();
	}
}

VS2PS Debug_Editor_VS(APP2VS Input, uniform float AmbientColorFactor = 1.0)
{
	VS2PS Output;

 	float4 Pos = Input.Pos;

	float4 TempPos = Input.Pos;
	TempPos.z += 0.5f;

 	float RadScale = lerp(_ConeSkinValues.x, _ConeSkinValues.y, TempPos.z);
	Pos.xy *= RadScale;

 	Pos = mul(Pos, _World);
	Output.HPos = mul(Pos, _WorldViewProj);

	Output.Diffuse.xyz = _MaterialAmbient.rgb * AmbientColorFactor;
	Output.Diffuse.w = _MaterialAmbient.a;

	return Output;
}

technique EditorDebug
<
	int DetailLevel = DLHigh+DLNormal+DLLow+DLAbysmal;
	int Compatibility = CMPR300+CMPNV2X;
>
{
	pass p0
	{
		CullMode = NONE;
		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;
		FillMode = SOLID;
		ZWriteEnable = 1;
		ZEnable = TRUE;
		ShadeMode = FLAT;
		ZFunc = LESSEQUAL;

		VertexShader = compile vs_3_0 Debug_Editor_VS();
		PixelShader = compile ps_3_0 Debug_Basic_PS();
	}

	pass p1
	{
		CullMode = CW;

		ZEnable = TRUE;
		FillMode = WIREFRAME;

		VertexShader = compile vs_3_0 Debug_Editor_VS(0.5);
		PixelShader = compile ps_3_0 Debug_Basic_PS();
	}
}

VS2PS Debug_CollisionMesh_VS(APP2VS Input, uniform float MaterialFactor = 1.0)
{
	VS2PS Output;

	float3 Pos = mul(Input.Pos, _World);
	Output.HPos = mul(float4(Pos.xyz, 1.0f), _WorldViewProj);

	Output.Diffuse.xyz = (_MaterialAmbient.rgb * MaterialFactor) + 0.1f * Diffuse(Input.Normal,float4(-1.0f, -1.0f, 1.0f, 0.0f)) * (_MaterialDiffuse.rgb * MaterialFactor);
	Output.Diffuse.w = 0.8f;

	return Output;
}

technique collisionMesh
<
	int DetailLevel = DLHigh+DLNormal+DLLow+DLAbysmal;
	int Compatibility = CMPR300+CMPNV2X;
>
{
	pass p0
	{
		CullMode = NONE;
		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;
		DepthBias = -0.00001;
		ZWriteEnable = 1;
		ZEnable = TRUE;
		ShadeMode = FLAT;
		ZFunc = LESSEQUAL;


		VertexShader = compile vs_3_0 Debug_CollisionMesh_VS();
		PixelShader = compile ps_3_0 Debug_Basic_PS();
	}

	pass p1
	{
		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;
		ZWriteEnable = 1;
		DepthBias = -0.000018;

		ZEnable = TRUE;
		FillMode = WIREFRAME;

		VertexShader = compile vs_3_0 Debug_CollisionMesh_VS(0.5);
		PixelShader = compile ps_3_0 Debug_Basic_PS();
	}

	pass p2
	{
		FillMode = SOLID;
	}
}

technique marked
<
	int DetailLevel = DLHigh+DLNormal+DLLow+DLAbysmal;
	int Compatibility = CMPR300+CMPNV2X;
	int Declaration[] =
	{
		// StreamNo, DataType, Usage, UsageIdx
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_POSITION, 0 },
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_NORMAL, 0 },
		DECLARATION_END	// End macro
	};
>
{
	pass p0
	{
		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		VertexShader = compile vs_3_0 Debug_Basic_1_VS();
		PixelShader = compile ps_3_0 Debug_Marked_PS();
	}
}

technique gamePlayObject
<
	int DetailLevel = DLHigh+DLNormal+DLLow+DLAbysmal;
	int Compatibility = CMPR300+CMPNV2X;
	int Declaration[] =
	{
		// StreamNo, DataType, Usage, UsageIdx
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_POSITION, 0 },
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_NORMAL, 0 },
		DECLARATION_END	// End macro
	};
>
{
	pass p0
	{
		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;
		ZEnable = TRUE;

		VertexShader = compile vs_3_0 Debug_Basic_2_VS();
		PixelShader = compile ps_3_0 Debug_Basic_PS();
	}
}

technique bounding
<
	int DetailLevel = DLHigh+DLNormal+DLLow+DLAbysmal;
	int Compatibility = CMPR300+CMPNV2X;
	int Declaration[] =
	{
		// StreamNo, DataType, Usage, UsageIdx
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_POSITION, 0 },
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_NORMAL, 0 },
		DECLARATION_END	// End macro
	};
>
{
	pass p0
	{
		AlphaBlendEnable = FALSE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;
		ZWriteEnable = 0;
		ZEnable = FALSE;
		CullMode = NONE;
		FillMode = WIREFRAME;

		VertexShader = compile vs_3_0 Debug_Basic_2_VS();
		PixelShader = compile ps_3_0 Debug_Marked_PS();
	}
}

VS2PS_Grid Debug_Grid_VS(APP2VS Input)
{
	VS2PS_Grid Output;

 	float3 Pos = mul(Input.Pos, _World);
	Output.HPos = mul(float4(Pos.xyz, 1.0f), _WorldViewProj);

	// Lighting. Shade (Ambient + etc.)
	Output.Diffuse.xyz = _MaterialAmbient.rgb + Diffuse(Input.Normal, _LightDir) * _MaterialDiffuse.xyz;
	Output.Diffuse.w = _MaterialAmbient.a;

	Output.Tex = Input.Pos.xz * 0.5 + 0.5;
	Output.Tex *= _TextureScale;

	return Output;
}

float4 Debug_Grid_PS(VS2PS_Grid Input) : COLOR
{
	float4 Output;
	float4 Tex = tex2D(sampler0, Input.Tex);
	Output.rgb = Tex * Input.Diffuse;
	Output.a = (1.0 - Tex.b);// * Input.Diffuse.a;
	return Output;
}

technique grid
<
	int DetailLevel = DLHigh+DLNormal+DLLow+DLAbysmal;
	int Compatibility = CMPR300+CMPNV2X;
	int Declaration[] =
	{
		// StreamNo, DataType, Usage, UsageIdx
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_POSITION, 0 },
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_NORMAL, 0 },
		DECLARATION_END	// End macro
	};
>
{
	pass p0
	{
		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		VertexShader = compile vs_3_0 Debug_Grid_VS();
		PixelShader = compile ps_3_0 Debug_Grid_PS();
	}
}

VS2PS Debug_Pivot_VS(APP2VS Input)
{
	VS2PS Output;

 	float4 Pos = Input.Pos;
 	float RadScale = lerp(_ConeSkinValues.x, _ConeSkinValues.y, Pos.z + 0.5);
	Pos.xy *= RadScale;
 	Pos = mul(Pos, _World);
	Output.HPos = mul(Pos, _WorldViewProj);

	// Lighting. Shade (Ambient + etc.)
	Output.Diffuse.rgb = _MaterialAmbient.rgb;
	Output.Diffuse.a = _MaterialAmbient.a;

	return Output;
}

VS2PS Debug_PivotBox_VS(APP2VS Input)
{
	VS2PS Output;

 	float4 Pos = mul(Input.Pos, _World);
	Output.HPos = mul(Pos, _WorldViewProj);

	// Lighting. Shade (Ambient + etc.)
	Output.Diffuse.rgb = _MaterialAmbient.rgb;
	Output.Diffuse.a = _MaterialAmbient.a;

	return Output;
}

VS2PS Debug_SpotLight_VS(APP2VS Input)
{
	VS2PS Output;

 	float4 Pos = Input.Pos;
 	Pos.z += 0.5;
 	float RadScale = lerp(_ConeSkinValues.x, _ConeSkinValues.y, Pos.z);
	Pos.xy *= RadScale;
 	Pos = mul(Pos, _World);

	Output.HPos = mul(Pos, _WorldViewProj);
	Output.Diffuse.rgb = _MaterialAmbient.rgb;
	Output.Diffuse.a = _MaterialAmbient.a;

	return Output;
}

float4 Debug_SpotLight_PS(VS2PS Input) : COLOR
{
	return Input.Diffuse;
}

technique spotlight
<
	int Declaration[] =
	{
		// StreamNo, DataType, Usage, UsageIdx
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_POSITION, 0 },
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_NORMAL, 0 },
		DECLARATION_END	// End macro
	};
>
{
	pass p0
	{
		CullMode = NONE;
		ColorWriteEnable = 0;
		AlphaBlendEnable = FALSE;
		ZFunc = LESSEQUAL;
		ZWriteEnable = TRUE;

		VertexShader = compile vs_3_0 Debug_SpotLight_VS();
		PixelShader = compile ps_3_0 Debug_SpotLight_PS();
	}

	pass p1
	{
		ColorWriteEnable = Red|Blue|Green|Alpha;
		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;
		ZFunc = EQUAL;
		ZWriteEnable = FALSE;

		VertexShader = compile vs_3_0 Debug_SpotLight_VS();
		PixelShader = compile ps_3_0 Debug_SpotLight_PS();
	}
}

technique pivotBox
<
	int Declaration[] =
	{
		// StreamNo, DataType, Usage, UsageIdx
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_POSITION, 0 },
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_NORMAL, 0 },
		DECLARATION_END	// End macro
	};
>
{
	pass p0
	{
		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;
		ZWriteEnable = 0;
		ZEnable = FALSE;

		VertexShader = compile vs_3_0 Debug_PivotBox_VS();
		PixelShader = compile ps_3_0 Debug_SpotLight_PS();
	}
	pass p1
	{
		ColorWriteEnable = Red|Blue|Green|Alpha;
		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;
		ZFunc = EQUAL;
		ZWriteEnable = FALSE;

		VertexShader = compile vs_3_0 Debug_PivotBox_VS();
		PixelShader = compile ps_3_0 Debug_SpotLight_PS();
	}
}

technique pivot
<
	int Declaration[] =
	{
		// StreamNo, DataType, Usage, UsageIdx
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_POSITION, 0 },
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_NORMAL, 0 },
		DECLARATION_END	// End macro
	};
>
{
	pass p0
	{
		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;
		ZWriteEnable = 0;
		ZEnable = FALSE;

		VertexShader = compile vs_3_0 Debug_Pivot_VS();
		PixelShader = compile ps_3_0 Debug_SpotLight_PS();
	}
	pass p1
	{
		ColorWriteEnable = Red|Blue|Green|Alpha;
		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;
		ZFunc = EQUAL;
		ZWriteEnable = FALSE;

		VertexShader = compile vs_3_0 Debug_Pivot_VS();
		PixelShader = compile ps_3_0 Debug_SpotLight_PS();
	}
}

struct APP2VS_Frustum
{
	float4 Pos : POSITION;
	float4 Col : COLOR;
};

struct VS2PS_Frustum
{
	float4 HPos : POSITION;
	float4 Col : COLOR;
};

VS2PS_Frustum Debug_Frustum_VS(APP2VS_Frustum Input)
{
	VS2PS_Frustum Output;
	Output.HPos = mul(Input.Pos, _WorldViewProj);
	Output.Col = Input.Col;
	return Output;
}

float4 Debug_Frustum_PS(VS2PS_Frustum Input, uniform float AlphaValue) : COLOR
{
	return float4(Input.Col.rgb, Input.Col.a * AlphaValue);
}

technique wirefrustum
{
	pass p0
	{
		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = ONE;
		ZEnable = TRUE;
		ZFunc = GREATER;
		ZWriteEnable = FALSE;
		CullMode = NONE;
		FillMode = SOLID;

		VertexShader = compile vs_3_0 Debug_Frustum_VS();
		PixelShader = compile ps_3_0 Debug_Frustum_PS(0.025);
	}

	pass p1
	{
		AlphaBlendEnable = FALSE;
		ZEnable = TRUE;
		ZFunc = LESSEQUAL;
		ZWriteEnable = FALSE;
		CullMode = NONE;
		FillMode = SOLID;

		VertexShader = compile vs_3_0 Debug_Frustum_VS();
		PixelShader = compile ps_3_0 Debug_Frustum_PS(1.0);
	}
}

technique solidfrustum
{
	pass p0
	{
		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = ONE;
		ZEnable = TRUE;
		ZFunc = GREATER;
		ZWriteEnable = FALSE;
		CullMode = NONE;
		FillMode = SOLID;

		VertexShader = compile vs_3_0 Debug_Frustum_VS();
		PixelShader = compile ps_3_0 Debug_Frustum_PS(0.25);
	}

	pass p1
	{
		AlphaBlendEnable = FALSE;
		ZEnable = TRUE;
		ZFunc = LESSEQUAL;
		ZWriteEnable = FALSE;
		CullMode = NONE;
		FillMode = SOLID;

		VertexShader = compile vs_3_0 Debug_Frustum_VS();
		PixelShader = compile ps_3_0 Debug_Frustum_PS(1.0);
	}
}

technique projectorfrustum
{
	pass p0
	{
		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = ONE;

		ZEnable = TRUE;
		ZFunc = LESSEQUAL;
		ZWriteEnable = FALSE;

		VertexShader = compile vs_3_0 Debug_Frustum_VS();
		PixelShader = compile ps_3_0 Debug_Frustum_PS(1.0);
	}
}
