
/*
	Description: Renders shapes to debug collision mesh, culling, etc.
*/

#include "shaders/RealityGraphics.fxh"

float4x4 _WorldViewProj : WorldViewProjection;
float4x4 _World : World;

string Category = "Effects\\Lighting";

uniform texture Tex0 : TEXLAYER0;
sampler SampleTex0 = sampler_state
{
	Texture = (Tex0);
	MinFilter = ANISOTROPIC;
	MagFilter = ANISOTROPIC;
	MipFilter = LINEAR;
	AddressU = WRAP;
	AddressV = WRAP;
};

float _TextureScale : TEXTURESCALE;

float4 _LightDir = { 1.0, 0.0, 0.0, 1.0 }; // Light Direction
float4 _MaterialAmbient : MATERIALAMBIENT = {0.5, 0.5, 0.5, 1.0};
float4 _MaterialDiffuse : MATERIALDIFFUSE = {1.0, 1.0, 1.0, 1.0};

// float4 _Alpha : BLENDALPHA = { 1.0, 1.0, 1.0, 1.0 };

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
	Output.HPos = mul(float4(Pos.xyz, 1.0), _WorldViewProj);

	// Lighting. Shade (Ambient + etc.)
	Output.Diffuse.xyz = _MaterialAmbient.rgb + Diffuse(Input.Normal, _LightDir) * _MaterialDiffuse.xyz;
	Output.Diffuse.w = _MaterialAmbient.a;
	return Output;
}

VS2PS Debug_Basic_2_VS(APP2VS Input)
{
	VS2PS Output;

 	float3 Pos = mul(Input.Pos, _World);
	Output.HPos = mul(float4(Pos.xyz, 1.0), _WorldViewProj);

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
	pass Pass0
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
	pass Pass0
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
	TempPos.z += 0.5;

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
	pass Pass0
	{
		CullMode = NONE;
		ShadeMode = FLAT;
		FillMode = SOLID;

		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		ZWriteEnable = 1;
		ZEnable = TRUE;
		ZFunc = LESSEQUAL;

		VertexShader = compile vs_3_0 Debug_Editor_VS();
		PixelShader = compile ps_3_0 Debug_Basic_PS();
	}

	pass Pass1
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
	Output.HPos = mul(float4(Pos.xyz, 1.0), _WorldViewProj);

	Output.Diffuse.xyz = (_MaterialAmbient.rgb * MaterialFactor) + 0.1 * Diffuse(Input.Normal,float4(-1.0, -1.0, 1.0, 0.0)) * (_MaterialDiffuse.rgb * MaterialFactor);
	Output.Diffuse.w = 0.8f;

	return Output;
}

technique collisionMesh
<
	int DetailLevel = DLHigh+DLNormal+DLLow+DLAbysmal;
	int Compatibility = CMPR300+CMPNV2X;
>
{
	pass Pass0
	{
		CullMode = NONE;
		ShadeMode = FLAT;
		DepthBias = -0.00001;

		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		ZWriteEnable = 1;
		ZEnable = TRUE;
		ZFunc = LESSEQUAL;

		VertexShader = compile vs_3_0 Debug_CollisionMesh_VS();
		PixelShader = compile ps_3_0 Debug_Basic_PS();
	}

	pass Pass1
	{
		DepthBias = -0.000018;
		FillMode = WIREFRAME;

		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		ZEnable = TRUE;
		ZWriteEnable = 1;

		VertexShader = compile vs_3_0 Debug_CollisionMesh_VS(0.5);
		PixelShader = compile ps_3_0 Debug_Basic_PS();
	}

	pass Pass2
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
	pass Pass0
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
	pass Pass0
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
	pass Pass0
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
	Output.HPos = mul(float4(Pos.xyz, 1.0), _WorldViewProj);

	// Lighting. Shade (Ambient + etc.)
	Output.Diffuse.xyz = _MaterialAmbient.rgb + Diffuse(Input.Normal, _LightDir) * _MaterialDiffuse.xyz;
	Output.Diffuse.w = _MaterialAmbient.a;

	Output.Tex = (Input.Pos.xz * 0.5) + 0.5;
	Output.Tex *= _TextureScale;

	return Output;
}

float4 Debug_Grid_PS(VS2PS_Grid Input) : COLOR
{
	float4 Tex = tex2D(SampleTex0, Input.Tex);
	float4 OutputColor = 0.0;
	OutputColor.rgb = Tex * Input.Diffuse;
	OutputColor.a = (1.0 - Tex.b);// * Input.Diffuse.a;
	return OutputColor;
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
	pass Pass0
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
	pass Pass0
	{
		CullMode = NONE;
		ColorWriteEnable = 0;
		AlphaBlendEnable = FALSE;
		ZFunc = LESSEQUAL;
		ZWriteEnable = TRUE;

		VertexShader = compile vs_3_0 Debug_SpotLight_VS();
		PixelShader = compile ps_3_0 Debug_SpotLight_PS();
	}

	pass Pass1
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
	pass Pass0
	{
		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		ZWriteEnable = 0;
		ZEnable = FALSE;

		VertexShader = compile vs_3_0 Debug_PivotBox_VS();
		PixelShader = compile ps_3_0 Debug_SpotLight_PS();
	}
	pass Pass1
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
	pass Pass0
	{
		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		ZWriteEnable = 0;
		ZEnable = FALSE;

		VertexShader = compile vs_3_0 Debug_Pivot_VS();
		PixelShader = compile ps_3_0 Debug_SpotLight_PS();
	}
	pass Pass1
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
	float4 Color : COLOR;
};

struct VS2PS_Frustum
{
	float4 HPos : POSITION;
	float4 Color : COLOR;
};

VS2PS_Frustum Debug_Frustum_VS(APP2VS_Frustum Input)
{
	VS2PS_Frustum Output;
	Output.HPos = mul(Input.Pos, _WorldViewProj);
	Output.Color = Input.Color;
	return Output;
}

float4 Debug_Frustum_PS(VS2PS_Frustum Input, uniform float AlphaValue) : COLOR
{
	return float4(Input.Color.rgb, Input.Color.a * AlphaValue);
}

technique wirefrustum
{
	pass Pass0
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

	pass Pass1
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
	pass Pass0
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

	pass Pass1
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
	pass Pass0
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
