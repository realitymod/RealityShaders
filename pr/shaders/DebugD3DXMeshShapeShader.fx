
/*
	Include header files
*/

#include "shaders/RealityGraphics.fxh"
#include "shaders/shared/RealityDirectXTK.fxh"
#include "shaders/shared/RealityDepth.fxh"
#if !defined(_HEADERS_)
	#include "RealityGraphics.fxh"
	#include "shared/RealityDirectXTK.fxh"
	#include "shared/RealityDepth.fxh"
#endif

/*
	Description: Renders shapes to debug collision mesh, culling, etc.
*/

float4x4 _WorldViewProj : WorldViewProjection;
float4x4 _World : World;

string Category = "Effects\\Lighting";

texture Tex0 : TEXLAYER0;
sampler SampleTex0 = sampler_state
{
	Texture = (Tex0);
	MinFilter = ANISOTROPIC;
	MagFilter = ANISOTROPIC;
	MipFilter = LINEAR;
	AddressU = WRAP;
	AddressV = WRAP;
	MaxAnisotropy = PR_MAX_ANISOTROPY;
};

float _TextureScale : TEXTURESCALE;

float4 _LightDir = { 1.0, 0.0, 0.0, 1.0 }; // Light Direction
float4 _MaterialAmbient : MATERIALAMBIENT = { 0.5, 0.5, 0.5, 1.0 };
float4 _MaterialDiffuse : MATERIALDIFFUSE = { 1.0, 1.0, 1.0, 1.0 };

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
	float4 Pos : TEXCOORD0;
};

struct PS2FB
{
	float4 Color : COLOR0;
	#if defined(LOG_DEPTH)
		float Depth : DEPTH;
	#endif
};

/*
	Basic debug shaders
*/

struct VS2PS_Basic
{
	float4 HPos : POSITION;
	float4 Pos : TEXCOORD0;
	float3 Normal : TEXCOORD1;
};

VS2PS_Basic VS_Debug_Basic(APP2VS Input)
{
	VS2PS_Basic Output = (VS2PS_Basic)0.0;

	float3 Pos = mul(Input.Pos, _World);
	Output.HPos = mul(float4(Pos.xyz, 1.0), _WorldViewProj);
	Output.Pos = Output.HPos;

	// Output Depth
	#if defined(LOG_DEPTH)
		Output.Pos.w = Output.HPos.w + 1.0;
	#endif

	Output.Normal = Input.Normal;

	return Output;
}

VS2PS VS_Debug_Cone(APP2VS Input)
{
	VS2PS Output = (VS2PS)0.0;

	float2 RadScale = lerp(_ConeSkinValues.x, _ConeSkinValues.y, Input.Pos.z + 0.5);
	float4 WorldPos = mul(Input.Pos * float4(RadScale, 1.0, 1.0), _World);

	Output.HPos = mul(WorldPos, _WorldViewProj);
	Output.Pos = Output.HPos;

	// Output Depth
	#if defined(LOG_DEPTH)
		Output.Pos.w = Output.HPos.w + 1.0;
	#endif

	return Output;
}

PS2FB PS_Debug_Basic_1(VS2PS_Basic Input)
{
	PS2FB Output = (PS2FB)0.0;

	float3 Normal = normalize(Input.Normal);

	float4 Ambient = _MaterialAmbient;
	float HalfNL = GetHalfNL(Normal, _LightDir.xyz);
	float3 OutputColor = Ambient.rgb + (HalfNL * _MaterialDiffuse.rgb);

	Output.Color = float4(OutputColor, Ambient.a);
	TonemapAndLinearToSRGBEst(Output.Color);

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);
	#endif

	return Output;
}

PS2FB PS_Debug_Basic_2(VS2PS_Basic Input)
{
	PS2FB Output = (PS2FB)0.0;

	Output.Color = float4(_MaterialAmbient.rgb, 0.3);
	TonemapAndLinearToSRGBEst(Output.Color);

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);
	#endif

	return Output;
}

PS2FB PS_Debug_Object(VS2PS Input)
{
	PS2FB Output = (PS2FB)0.0;

	Output.Color = _MaterialAmbient;
	TonemapAndLinearToSRGBEst(Output.Color);

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);
	#endif

	return Output;
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

		VertexShader = compile vs_3_0 VS_Debug_Basic();
		PixelShader = compile ps_3_0 PS_Debug_Basic_1();
	}
}

/*
	Debug occluder shaders
*/

VS2PS VS_Debug_Occluder(APP2VS Input)
{
	VS2PS Output = (VS2PS)0.0;

	float4 WorldPos = mul(Input.Pos, _World);
	Output.HPos = mul(WorldPos, _WorldViewProj);
	Output.Pos = Output.HPos;

	// Output Depth
	#if defined(LOG_DEPTH)
		Output.Pos.w = Output.HPos.w + 1.0;
	#endif

	return Output;
}

PS2FB PS_Debug_Occluder(VS2PS Input)
{
	PS2FB Output = (PS2FB)0.0;

	Output.Color = float4(1.0, 0.5, 0.5, 0.5);
	TonemapAndLinearToSRGBEst(Output.Color);

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);
	#endif

	return Output;
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
		ZFunc = PR_ZFUNC_WITHEQUAL;

		VertexShader = compile vs_3_0 VS_Debug_Occluder();
		PixelShader = compile ps_3_0 PS_Debug_Occluder();
	}
}

/*
	Debug editor shaders
*/

PS2FB PS_Debug_Editor(VS2PS Input, uniform float AmbientColorFactor = 1.0)
{
	PS2FB Output = (PS2FB)0.0;

	Output.Color = float4(_MaterialAmbient.rgb * AmbientColorFactor, _MaterialAmbient.a);
	TonemapAndLinearToSRGBEst(Output.Color);

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);
	#endif

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
		ShadeMode = FLAT;
		FillMode = SOLID;

		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		ZWriteEnable = 1;
		ZEnable = TRUE;
		ZFunc = PR_ZFUNC_WITHEQUAL;

		VertexShader = compile vs_3_0 VS_Debug_Cone();
		PixelShader = compile ps_3_0 PS_Debug_Editor();
	}

	pass p1
	{
		CullMode = CW;

		ZEnable = TRUE;
		ZFunc = PR_ZFUNC_WITHEQUAL;
		FillMode = WIREFRAME;

		VertexShader = compile vs_3_0 VS_Debug_Cone();
		PixelShader = compile ps_3_0 PS_Debug_Editor(0.5);
	}
}

/*
	Debug occluder shaders
*/

struct VS2PS_CollisionMesh
{
	float4 HPos : POSITION;
	float4 Pos : TEXCOORD0;
	float3 Normal : TEXCOORD1;
};

VS2PS_CollisionMesh VS_Debug_CollisionMesh(APP2VS Input)
{
	VS2PS_CollisionMesh Output = (VS2PS_CollisionMesh)0.0;

	float3 Pos = mul(Input.Pos, _World);
	Output.HPos = mul(float4(Pos.xyz, 1.0), _WorldViewProj);
	Output.Pos = Output.HPos;

	// Output Depth
	#if defined(LOG_DEPTH)
		Output.Pos.w = Output.HPos.w + 1.0;
	#endif

	Output.Normal = Input.Normal;

	return Output;
}

PS2FB PS_Debug_CollisionMesh(VS2PS_CollisionMesh Input, uniform float MaterialFactor = 1.0)
{
	PS2FB Output = (PS2FB)0.0;

	float3 Normal = normalize(Input.Normal);
	float3 LightDir = normalize(float3(-1.0, -1.0, 1.0));

	float HalfNL = GetHalfNL(Normal, LightDir);
	float3 Ambient = (_MaterialAmbient.rgb * MaterialFactor) + 0.1;
	float3 Diffuse = HalfNL * (_MaterialDiffuse.rgb * MaterialFactor);

	Output.Color = float4(Ambient + Diffuse, 0.8);
	TonemapAndLinearToSRGBEst(Output.Color);

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);
	#endif

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
		ShadeMode = FLAT;

		#if PR_IS_REVERSED_Z
			DepthBias = 0.00001;
		#else
			DepthBias = -0.00001;
		#endif

		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		ZWriteEnable = TRUE;
		ZEnable = TRUE;
		ZFunc = PR_ZFUNC_WITHEQUAL;

		VertexShader = compile vs_3_0 VS_Debug_CollisionMesh();
		PixelShader = compile ps_3_0 PS_Debug_CollisionMesh();
	}

	pass p1
	{
		#if PR_IS_REVERSED_Z
			DepthBias = 0.000018;
		#else
			DepthBias = -0.000018;
		#endif

		FillMode = WIREFRAME;

		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		ZEnable = TRUE;
		ZFunc = PR_ZFUNC_WITHEQUAL;
		ZWriteEnable = TRUE;

		VertexShader = compile vs_3_0 VS_Debug_CollisionMesh();
		PixelShader = compile ps_3_0 PS_Debug_CollisionMesh(0.5);
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

		ZFunc = PR_ZFUNC_WITHEQUAL;

		VertexShader = compile vs_3_0 VS_Debug_Basic();
		PixelShader = compile ps_3_0 PS_Debug_Basic_1();
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
		ZFunc = PR_ZFUNC_WITHEQUAL;

		VertexShader = compile vs_3_0 VS_Debug_Basic();
		PixelShader = compile ps_3_0 PS_Debug_Basic_2();
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

		VertexShader = compile vs_3_0 VS_Debug_Basic();
		PixelShader = compile ps_3_0 PS_Debug_Basic_2();
	}
}

/*
	Debug grid shaders
*/

struct VS2PS_Grid
{
	float4 HPos : POSITION;
	float3 Tex0 : TEXCOORD0;
	float3 Normal : TEXCOORD1;
};

VS2PS_Grid VS_Debug_Grid(APP2VS Input)
{
	VS2PS_Grid Output = (VS2PS_Grid)0.0;

	float3 Pos = mul(Input.Pos, _World);
	Output.HPos = mul(float4(Pos.xyz, 1.0), _WorldViewProj);
	Output.Tex0.xy = (Input.Pos.xz * 0.5) + 0.5;
	Output.Tex0.xy *= _TextureScale;

	// Output Depth
	#if defined(LOG_DEPTH)
		Output.Tex0.z = Output.HPos.w + 1.0;
	#endif

	Output.Normal = Input.Normal;

	return Output;
}

PS2FB PS_Debug_Grid(VS2PS_Grid Input)
{
	PS2FB Output = (PS2FB)0.0;

	float3 Normal = normalize(Input.Normal);

	float HalfNL = GetHalfNL(Normal, _LightDir.xyz);
	float3 Lighting = _MaterialAmbient.rgb + (HalfNL * _MaterialDiffuse.rgb);

	float4 Tex = SRGBToLinearEst(tex2D(SampleTex0, Input.Tex0.xy));
	// float4 OutputColor = float4(Tex.rgb * Lighting, _MaterialDiffuse.a);
	float4 OutputColor = float4(Tex.rgb * Lighting, 1.0 - Tex.b);

	Output.Color = OutputColor;
	TonemapAndLinearToSRGBEst(Output.Color);

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Tex0.z);
	#endif

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

		ZFunc = PR_ZFUNC_WITHEQUAL;

		VertexShader = compile vs_3_0 VS_Debug_Grid();
		PixelShader = compile ps_3_0 PS_Debug_Grid();
	}
}

/*
	Debug SpotLight shaders
*/

VS2PS VS_Debug_SpotLight(APP2VS Input)
{
	VS2PS Output = (VS2PS)0.0;

	float4 Pos = Input.Pos;
	Pos.z += 0.5;
	float2 RadScale = lerp(_ConeSkinValues.x, _ConeSkinValues.y, Pos.z);
	Pos.xy *= RadScale;
	Pos = mul(Pos, _World);

	Output.HPos = mul(Pos, _WorldViewProj);
	Output.Pos = Output.HPos;

	// Output Depth
	#if defined(LOG_DEPTH)
		Output.Pos.w = Output.HPos.w + 1.0;
	#endif

	return Output;
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

		ZFunc = PR_ZFUNC_WITHEQUAL;
		ZWriteEnable = TRUE;

		VertexShader = compile vs_3_0 VS_Debug_SpotLight();
		PixelShader = compile ps_3_0 PS_Debug_Object();
	}

	pass p1
	{
		ColorWriteEnable = Red|Blue|Green|Alpha;

		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		ZFunc = EQUAL;
		ZWriteEnable = FALSE;

		VertexShader = compile vs_3_0 VS_Debug_SpotLight();
		PixelShader = compile ps_3_0 PS_Debug_Object();
	}
}

/*
	Debug PivotBox shaders
*/

VS2PS VS_Debug_PivotBox(APP2VS Input)
{
	VS2PS Output = (VS2PS)0.0;

	float4 Pos = mul(Input.Pos, _World);
	Output.HPos = mul(Pos, _WorldViewProj);
	Output.Pos = Output.HPos;

	// Output Depth
	#if defined(LOG_DEPTH)
		Output.Pos.w = Output.HPos.w + 1.0;
	#endif

	return Output;
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

		ZEnable = FALSE;
		ZWriteEnable = FALSE;

		VertexShader = compile vs_3_0 VS_Debug_PivotBox();
		PixelShader = compile ps_3_0 PS_Debug_Object();
	}

	pass p1
	{
		ColorWriteEnable = Red|Blue|Green|Alpha;

		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		ZFunc = EQUAL;
		ZWriteEnable = FALSE;

		VertexShader = compile vs_3_0 VS_Debug_PivotBox();
		PixelShader = compile ps_3_0 PS_Debug_Object();
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

		ZEnable = FALSE;
		ZWriteEnable = FALSE;

		VertexShader = compile vs_3_0 VS_Debug_Cone();
		PixelShader = compile ps_3_0 PS_Debug_Object();
	}

	pass p1
	{
		ColorWriteEnable = Red|Blue|Green|Alpha;

		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		ZFunc = EQUAL;
		ZWriteEnable = FALSE;

		VertexShader = compile vs_3_0 VS_Debug_Cone();
		PixelShader = compile ps_3_0 PS_Debug_Object();
	}
}

/*
	Debug frustum shaders
*/

struct APP2VS_Frustum
{
	float4 Pos : POSITION;
	float4 Color : COLOR;
};

struct VS2PS_Frustum
{
	float4 HPos : POSITION;
	float4 Pos : TEXCOORD0;
	float4 Color : TEXCOORD1;
};

VS2PS_Frustum VS_Debug_Frustum(APP2VS_Frustum Input)
{
	VS2PS_Frustum Output = (VS2PS_Frustum)0.0;

	Output.HPos = mul(Input.Pos, _WorldViewProj);
	Output.Pos = Output.HPos;

	// Output Depth
	#if defined(LOG_DEPTH)
		Output.Pos.w = Output.HPos.w + 1.0;
	#endif

	Output.Color = Input.Color;

	return Output;
}

PS2FB PS_Debug_Frustum(VS2PS_Frustum Input, uniform float AlphaValue)
{
	PS2FB Output = (PS2FB)0.0;

	Output.Color = float4(Input.Color.rgb, Input.Color.a * AlphaValue);
	TonemapAndLinearToSRGBEst(Output.Color);

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);
	#endif

	return Output;
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

		VertexShader = compile vs_3_0 VS_Debug_Frustum();
		PixelShader = compile ps_3_0 PS_Debug_Frustum(0.025);
	}

	pass p1
	{
		AlphaBlendEnable = FALSE;

		ZEnable = TRUE;
		ZFunc = PR_ZFUNC_WITHEQUAL;
		ZWriteEnable = FALSE;

		CullMode = NONE;
		FillMode = SOLID;

		VertexShader = compile vs_3_0 VS_Debug_Frustum();
		PixelShader = compile ps_3_0 PS_Debug_Frustum(1.0);
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

		VertexShader = compile vs_3_0 VS_Debug_Frustum();
		PixelShader = compile ps_3_0 PS_Debug_Frustum(0.25);
	}

	pass p1
	{
		AlphaBlendEnable = FALSE;

		ZEnable = TRUE;
		ZFunc = PR_ZFUNC_WITHEQUAL;
		ZWriteEnable = FALSE;

		CullMode = NONE;
		FillMode = SOLID;

		VertexShader = compile vs_3_0 VS_Debug_Frustum();
		PixelShader = compile ps_3_0 PS_Debug_Frustum(1.0);
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
		ZFunc = PR_ZFUNC_WITHEQUAL;
		ZWriteEnable = FALSE;

		VertexShader = compile vs_3_0 VS_Debug_Frustum();
		PixelShader = compile ps_3_0 PS_Debug_Frustum(1.0);
	}
}
