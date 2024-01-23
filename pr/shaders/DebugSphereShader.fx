
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
	Description: Renders debug lightsource spheres
*/

float4x4 _WorldViewProj : WorldViewProjection;
float4x4 _World : World;

string Category = "Effects\\Lighting";

float4 _LightDir = { 1.0, 0.0, 0.0, 1.0 };
float4 _LightDiffuse = { 1.0, 1.0, 1.0, 1.0 };
float4 _MaterialAmbient : MATERIALAMBIENT = { 0.5, 0.5, 0.5, 1.0 };
float4 _MaterialDiffuse : MATERIALDIFFUSE = { 1.0, 1.0, 1.0, 1.0 };

uniform texture BaseTex : TEXLAYER0
<
	string File = "aniso2.dds";
	string TextureType = "2D";
>;

sampler2D SampleBaseTex = sampler_state
{
	Texture = (BaseTex);
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = LINEAR;
};

struct APP2VS
{
	float4 Pos : POSITION;
	float3 Normal : NORMAL;
	float2 TexCoord0 : TEXCOORD0;
};

struct VS2PS
{
	float4 HPos : POSITION;
	float3 Tex0 : TEXCOORD0;
	float4 Diffuse : TEXCOORD1;
};

struct PS2FB
{
	float4 Color : COLOR0;
	#if defined(LOG_DEPTH)
		float Depth : DEPTH;
	#endif
};

/*
	Debug basic shaders
*/

float3 Diffuse(float3 Normal)
{
	// Clamped N.L
	return saturate(dot(Normal, _LightDir.xyz));
}

VS2PS VS_Debug_Basic(APP2VS Input)
{
	VS2PS Output = (VS2PS)0.0;

	float3 Pos = mul(Input.Pos, _World);
	Output.HPos = mul(float4(Pos.xyz, 1.0), _WorldViewProj);

	Output.Tex0.xy = Input.TexCoord0;

	// Output Depth
	#if defined(LOG_DEPTH)
		Output.Tex0.z = Output.HPos.w + 1.0;
	#endif

	// Lighting. Shade (Ambient + etc.)
	Output.Diffuse.xyz = _MaterialAmbient.xyz + Diffuse(Input.Normal) * _MaterialDiffuse.xyz;
	Output.Diffuse.w = 1.0;

	return Output;
}

PS2FB PS_Debug_Basic(VS2PS Input)
{
	PS2FB Output = (PS2FB)0.0;

	Output.Color = tex2D(SampleBaseTex, Input.Tex0.xy) * Input.Diffuse;

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Tex0.z);
	#endif

	return Output;
}

PS2FB PS_Debug_Marked(VS2PS Input)
{
	PS2FB Output = (PS2FB)0.0;

	Output.Color = (tex2D(SampleBaseTex, Input.Tex0.xy) * Input.Diffuse) + float4(1.0, 0.0, 0.0, 0.0);

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Tex0.z);
	#endif

	return Output;
}

technique t0_States < bool Restore = false; >
{
	pass BeginStates
	{
		CullMode = NONE;
	}

	pass EndStates
	{
		CullMode = CCW;
	}
}

technique t0
<
	int Declaration[] =
	{
		// StreamNo, DataType, Usage, UsageIdx
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_POSITION, 0 },
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_NORMAL, 0 },
		{ 0, D3DDECLTYPE_FLOAT2, D3DDECLUSAGE_TEXCOORD, 0 },
		DECLARATION_END	// End macro
	};

>
{
	pass p0
	{
		VertexShader = compile vs_3_0 VS_Debug_Basic();
		PixelShader = compile ps_3_0 PS_Debug_Basic();
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
		{ 0, D3DDECLTYPE_FLOAT2, D3DDECLUSAGE_TEXCOORD, 0 },
		DECLARATION_END	// End macro
	};
>
{
	pass p0
	{
		CullMode = NONE;
		AlphaBlendEnable = FALSE;

		VertexShader = compile vs_3_0 VS_Debug_Basic();
		PixelShader = compile ps_3_0 PS_Debug_Marked();
	}
}

/*
	Debug lightsource shaders
*/

VS2PS VS_Debug_LightSource(APP2VS Input)
{
	VS2PS Output = (VS2PS)0.0;

	float4 Pos;
	Pos.xyz = mul(Input.Pos, _World);
	Pos.w = 1.0;
	Output.HPos = mul(Pos, _WorldViewProj);

	Output.Tex0 = 0.0;

	// Output Depth
	#if defined(LOG_DEPTH)
		Output.Tex0.z = Output.HPos.w + 1.0;
	#endif

	// Lighting. Shade (Ambient + etc.)
	Output.Diffuse.rgb = _MaterialDiffuse.xyz;
	Output.Diffuse.a = _MaterialDiffuse.w;

	return Output;
}

PS2FB PS_Debug_LightSource(VS2PS Input)
{
	PS2FB Output = (PS2FB)0.0;

	Output.Color = Input.Diffuse;

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Tex0.z);
	#endif

	return Output;
}

technique lightsource
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

		VertexShader = compile vs_3_0 VS_Debug_LightSource();
		PixelShader = compile ps_3_0 PS_Debug_LightSource();
	}

	pass p1
	{
		ColorWriteEnable = Red|Blue|Green|Alpha;

		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		ZFunc = EQUAL;
		ZWriteEnable = FALSE;

		VertexShader = compile vs_3_0 VS_Debug_LightSource();
		PixelShader = compile ps_3_0 PS_Debug_LightSource();
	}
}

technique editor
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

		VertexShader = compile vs_3_0 VS_Debug_LightSource();
		PixelShader = compile ps_3_0 PS_Debug_LightSource();
	}

	pass p1
	{
		ColorWriteEnable = Red|Blue|Green|Alpha;

		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		ZFunc = EQUAL;
		ZWriteEnable = FALSE;

		VertexShader = compile vs_3_0 VS_Debug_LightSource();
		PixelShader = compile ps_3_0 PS_Debug_LightSource();
	}
}

technique EditorDebug
{
	pass p0
	{
		CullMode = NONE;

		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		ZEnable = TRUE;
		ZFunc = LESSEQUAL;
		ZWriteEnable = TRUE;

		ShadeMode = FLAT;
		FillMode = SOLID;

		VertexShader = compile vs_3_0 VS_Debug_LightSource();
		PixelShader = compile ps_3_0 PS_Debug_LightSource();
	}
}
