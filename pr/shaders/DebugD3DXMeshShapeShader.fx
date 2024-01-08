
/*
	Include header files
*/

#include "shaders/RealityGraphics.fxh"
#include "shaders/shared/RealityDirectXTK.fxh"
#include "shaders/shared/RealityDepth.fxh"
#if !defined(INCLUDED_HEADERS)
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

void VS_Debug_Basic(in APP2VS Input, out VS2PS_Basic Output)
{
	Output = (VS2PS_Basic)0.0;

	float3 Pos = mul(Input.Pos, _World);
	Output.HPos = mul(float4(Pos.xyz, 1.0), _WorldViewProj);
	Output.Pos = Output.HPos;
	#if defined(LOG_DEPTH)
		Output.Pos.w = Output.HPos.w + 1.0; // Output depth
	#endif

	Output.Normal = Input.Normal;
}

void VS_Debug_Cone(in APP2VS Input, out VS2PS Output)
{
	Output = (VS2PS)0.0;

	float2 RadScale = lerp(_ConeSkinValues.x, _ConeSkinValues.y, Input.Pos.z + 0.5);
	float4 WorldPos = mul(Input.Pos * float4(RadScale, 1.0, 1.0), _World);

	Output.HPos = mul(WorldPos, _WorldViewProj);
	Output.Pos = Output.HPos;
	#if defined(LOG_DEPTH)
		Output.Pos.w = Output.HPos.w + 1.0; // Output depth
	#endif
}

void PS_Debug_Basic_1(in VS2PS_Basic Input, out PS2FB Output)
{
	float3 Normal = normalize(Input.Normal);

	float4 Ambient = _MaterialAmbient;
	float HalfNL = GetHalfNL(Normal, _LightDir.xyz);
	float3 OutputColor = Ambient.rgb + (HalfNL * _MaterialDiffuse.rgb);

	Output.Color = float4(OutputColor, Ambient.a);

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);
	#endif
}

void PS_Debug_Basic_2(in VS2PS_Basic Input, out PS2FB Output)
{
	Output.Color = float4(_MaterialAmbient.rgb, 0.3);

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);
	#endif
}

void PS_Debug_Object(in VS2PS Input, out PS2FB Output)
{
	Output.Color = _MaterialAmbient;

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);
	#endif
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

void VS_Debug_Occluder(in APP2VS Input, out VS2PS Output)
{
	Output = (VS2PS)0.0;

	float4 WorldPos = mul(Input.Pos, _World);
	Output.HPos = mul(WorldPos, _WorldViewProj);
	Output.Pos = Output.HPos;
	#if defined(LOG_DEPTH)
		Output.Pos.w = Output.HPos.w + 1.0; // Output depth
	#endif
}

void PS_Debug_Occluder(in VS2PS Input, out PS2FB Output)
{
	Output.Color = float4(1.0, 0.5, 0.5, 0.5);

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);
	#endif
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

		VertexShader = compile vs_3_0 VS_Debug_Occluder();
		PixelShader = compile ps_3_0 PS_Debug_Occluder();
	}
}

/*
	Debug editor shaders
*/

PS2FB PS_Debug_Editor(in VS2PS Input, uniform float AmbientColorFactor = 1.0)
{
	PS2FB Output = (PS2FB)0.0;

	Output.Color = float4(_MaterialAmbient.rgb * AmbientColorFactor, _MaterialAmbient.a);

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
		ZFunc = LESSEQUAL;

		VertexShader = compile vs_3_0 VS_Debug_Cone();
		PixelShader = compile ps_3_0 PS_Debug_Editor();
	}

	pass p1
	{
		CullMode = CW;

		ZEnable = TRUE;
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

void VS_Debug_CollisionMesh(in APP2VS Input, out VS2PS_CollisionMesh Output)
{
	Output = (VS2PS_CollisionMesh)0.0;

	float3 Pos = mul(Input.Pos, _World);
	Output.HPos = mul(float4(Pos.xyz, 1.0), _WorldViewProj);
	Output.Pos = Output.HPos;
	#if defined(LOG_DEPTH)
		Output.Pos.w = Output.HPos.w + 1.0; // Output depth
	#endif

	Output.Normal = Input.Normal;
}

PS2FB PS_Debug_CollisionMesh(in VS2PS_CollisionMesh Input, uniform float MaterialFactor = 1.0)
{
	PS2FB Output = (PS2FB)0.0;

	float3 Normal = normalize(Input.Normal);
	float3 LightDir = normalize(float3(-1.0, -1.0, 1.0));

	float HalfNL = GetHalfNL(Normal, LightDir);
	float3 Ambient = (_MaterialAmbient.rgb * MaterialFactor) + 0.1;
	float3 Diffuse = HalfNL * (_MaterialDiffuse.rgb * MaterialFactor);

	Output.Color = float4(Ambient + Diffuse, 0.8);

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
		DepthBias = -0.00001;

		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		ZWriteEnable = 1;
		ZEnable = TRUE;
		ZFunc = LESSEQUAL;

		VertexShader = compile vs_3_0 VS_Debug_CollisionMesh();
		PixelShader = compile ps_3_0 PS_Debug_CollisionMesh();
	}

	pass p1
	{
		DepthBias = -0.000018;
		FillMode = WIREFRAME;

		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		ZEnable = TRUE;
		ZWriteEnable = 1;

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

void VS_Debug_Grid(in APP2VS Input, out VS2PS_Grid Output)
{
	Output = (VS2PS_Grid)0.0;

	float3 Pos = mul(Input.Pos, _World);
	Output.HPos = mul(float4(Pos.xyz, 1.0), _WorldViewProj);

	Output.Tex0.xy = (Input.Pos.xz * 0.5) + 0.5;
	Output.Tex0.xy *= _TextureScale;
	#if defined(LOG_DEPTH)
		Output.Tex0.z = Output.HPos.w + 1.0; // Output depth
	#endif

	Output.Normal = Input.Normal;
}

void PS_Debug_Grid(in VS2PS_Grid Input, out PS2FB Output)
{
	float3 Normal = normalize(Input.Normal);

	float4 Tex = tex2D(SampleTex0, Input.Tex0.xy);
	float HalfNL = GetHalfNL(Normal, _LightDir.xyz);
	float3 Lighting = _MaterialAmbient.rgb + (HalfNL * _MaterialDiffuse.rgb);

	Output.Color.rgb = Tex.rgb * Lighting;
	Output.Color.a = 1.0 - Tex.b;
	// Output.Color.a = _MaterialDiffuse.a;

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Tex0.z);
	#endif
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

		VertexShader = compile vs_3_0 VS_Debug_Grid();
		PixelShader = compile ps_3_0 PS_Debug_Grid();
	}
}

/*
	Debug SpotLight shaders
*/

void VS_Debug_SpotLight(in APP2VS Input, out VS2PS Output)
{
	Output = (VS2PS)0.0;

	float4 Pos = Input.Pos;
	Pos.z += 0.5;
	float2 RadScale = lerp(_ConeSkinValues.x, _ConeSkinValues.y, Pos.z);
	Pos.xy *= RadScale;
	Pos = mul(Pos, _World);

	Output.HPos = mul(Pos, _WorldViewProj);
	Output.Pos = Output.HPos;
	#if defined(LOG_DEPTH)
		Output.Pos.w = Output.HPos.w + 1.0; // Output depth
	#endif
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

void VS_Debug_PivotBox(in APP2VS Input, out VS2PS Output)
{
	Output = (VS2PS)0.0;

	float4 Pos = mul(Input.Pos, _World);
	Output.HPos = mul(Pos, _WorldViewProj);
	Output.Pos = Output.HPos;
	#if defined(LOG_DEPTH)
		Output.Pos.w = Output.HPos.w + 1.0; // Output depth
	#endif
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

		ZWriteEnable = 0;
		ZEnable = FALSE;

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

void VS_Debug_Frustum(in APP2VS_Frustum Input, out VS2PS_Frustum Output)
{
	Output = (VS2PS_Frustum)0.0;

	Output.HPos = mul(Input.Pos, _WorldViewProj);
	Output.Pos = Output.HPos;
	#if defined(LOG_DEPTH)
		Output.Pos.w = Output.HPos.w + 1.0; // Output depth
	#endif

	Output.Color = Input.Color;
}

PS2FB PS_Debug_Frustum(in VS2PS_Frustum Input, uniform float AlphaValue)
{
	PS2FB Output = (PS2FB)0.0;

	Output.Color = float4(Input.Color.rgb, Input.Color.a * AlphaValue);

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
		ZFunc = LESSEQUAL;
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
		ZFunc = LESSEQUAL;
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
		ZFunc = LESSEQUAL;
		ZWriteEnable = FALSE;

		VertexShader = compile vs_3_0 VS_Debug_Frustum();
		PixelShader = compile ps_3_0 PS_Debug_Frustum(1.0);
	}
}
