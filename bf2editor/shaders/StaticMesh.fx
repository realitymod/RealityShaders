#line 2 "StaticMesh.fx"

#include "Shaders/StaticMesh_Data.fxh"
#include "Shaders/StaticMesh_DX9Z.fxh"
#include "Shaders/StaticMesh_DX9Gbuff.fxh"
#include "Shaders/StaticMesh_Debug.fxh"
#include "Shaders/StaticMesh_LightMapGen.fxh"
#if !defined(_HEADERS_)
	#include "StaticMesh_Data.fxh"
	#include "StaticMesh_DX9Z.fxh"
	#include "StaticMesh_DX9Gbuff.fxh"
	#include "StaticMesh_Debug.fxh"
	#include "StaticMesh_LightMapGen.fxh"
#endif

struct APP2VS
{
    float4 Pos : POSITION;
    float3 Normal : NORMAL;
    float2 TexCoord : TEXCOORD0;
    float3 Tan : TANGENT;
    float3 Binorm : BINORMAL;
};

struct VS2PS_SimpleShader
{
    float4 HPos : POSITION;
    float2 Tex0 : TEXCOORD0;
};

VS2PS_SimpleShader VS_SimpleShader(APP2VS Input)
{
	VS2PS_SimpleShader Output = (VS2PS_SimpleShader)0;

	Output.HPos = mul(float4(Input.Pos.xyz, 1.0), _ViewProjMatrix);
	Output.Tex0 = Input.TexCoord;

	return Output;
}

float4 PS_SimpleShader(VS2PS_SimpleShader Input) : COLOR0
{
	float4 Ambient = float4(1.0, 1.0, 1.0, 0.8);
	float4 NormalMap = tex2D(SamplerWrap0, Input.Tex0);
	return NormalMap * Ambient;
}

technique alpha_one
{
	pass p0
	{
		ZEnable = TRUE;
		ZWriteEnable = FALSE;
		CullMode = NONE;
		AlphaBlendEnable = TRUE;

		SrcBlend = SRCALPHA;
		DestBlend = ONE;

		AlphaTestEnable = TRUE;
		AlphaRef = 0;
		AlphaFunc = GREATER;

		VertexShader = compile vs_3_0 VS_SimpleShader();
		PixelShader = compile ps_3_0 PS_SimpleShader();
	}
}

struct APPDATA_ShadowMap
{
    float4 Pos : POSITION;
};

struct VS2PS_ShadowMap
{
	float4 Pos : POSITION;
	float4 PosZW : TEXCOORD0;
};

VS2PS_ShadowMap VS_ShadowMap(APPDATA_ShadowMap Input)
{
	VS2PS_ShadowMap Output;

 	float4 WorldPos = mul(Input.Pos, _WorldMatrix);
 	Output.Pos = mul(Input.Pos, _ViewProjMatrix);
	Output.PosZW.xy = Output.Pos.zw;
	Output.PosZW.zw = WorldPos.y - _DropShadowClipHeight;

	return Output;
}

float4 PS_ShadowMap(VS2PS_ShadowMap Input) : COLOR
{
	clip(Input.PosZW.w);
	return 0.0;
}

VS2PS_ShadowMap VS_ShadowMapPoint(APPDATA_ShadowMap Input)
{
	VS2PS_ShadowMap Output;

  	float4 oPos = Input.Pos;
 	Output.Pos = mul(oPos, _ViewProjMatrix);
	Output.Pos.z *= _ParaboloidValues.x;
	Output.PosZW = Output.Pos.zwww / 10.0 + 0.5;

 	float Dist = length(Output.Pos.xyz);
 	Output.Pos.xyz /= Dist;
	Output.Pos.z += 1.0;
 	Output.Pos.xy /= Output.Pos.z;
	Output.Pos.z = (Dist * _ParaboloidZValues.x) + _ParaboloidZValues.y;
	Output.Pos.w = 1.0;

	return Output;
}

float4 PS_ShadowMapPoint(VS2PS_ShadowMap Input) : COLOR
{
	clip(Input.PosZW.x - 0.5);
	return GetSlopedBasedBias(Input.PosZW.x - 0.5);
}

technique DrawShadowMap
{
	pass DirectionalSpot
	{
		AlphaBlendEnable = FALSE;
		ZEnable = TRUE;
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;
		ScissorTestEnable = TRUE;

		// ClipPlaneEnable = 1;	// Enable clipplane 0

		VertexShader = compile vs_3_0 VS_ShadowMap();
		PixelShader = compile ps_3_0 PS_ShadowMap();
	}

	pass Point
	{
		AlphaBlendEnable = FALSE;
		ZEnable = TRUE;
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;

		ScissorTestEnable = TRUE;

		VertexShader = compile vs_3_0 VS_ShadowMapPoint();
		PixelShader = compile ps_3_0 PS_ShadowMapPoint();
	}
}
