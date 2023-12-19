
#include "Shaders/StaticMesh_Data.fxh"
#if !defined(INCLUDED_HEADERS)
	#include "StaticMesh_Data.fxh"
#endif

/*
	[STRUCTS]
*/

struct APP2VS_GBuffBase
{
	float4 Pos : POSITION;
	float2 DiffuseTex : TEXCOORD0;
	float3 Tan : TANGENT;
	float3 Normal : NORMAL;
};

struct APP2VS_GBuffBaseLM
{
	float4 Pos : POSITION;
	float2 DiffuseTex : TEXCOORD0;
	float2 LightMapTex : TEXCOORD1;
	float3 Tan : TANGENT;
	float3 Normal : NORMAL;
};

struct APP2VS_GBuffBaseDetail
{
	float4 Pos : POSITION;
	float2 DetailTex : TEXCOORD0;
	float3 Tan : TANGENT;
	float3 Normal : NORMAL;
};

struct APP2VS_GBuffBaseDetailLM
{
	float4 Pos : POSITION;
	float2 DetailTex : TEXCOORD0;
	float2 LightMapTex : TEXCOORD1;
	float3 Tan : TANGENT;
	float3 Normal : NORMAL;
};

struct APP2VS_GBuffBaseDetailDirt
{
	float4 Pos : POSITION;
	float2 DetailTex : TEXCOORD0;
	float3 Tan : TANGENT;
	float3 Normal : NORMAL;
};

struct APP2VS_GBuffBaseDetailDirtLM
{
	float4 Pos : POSITION;
	float2 DetailTex : TEXCOORD0;
	float2 LightMapTex : TEXCOORD1;
	float3 Tan : TANGENT;
	float3 Normal : NORMAL;
};

struct APP2VS_GBuffBaseDetailCrack
{
	float4 Pos : POSITION;
	float2 DetailTex : TEXCOORD0;
	float2 CrackTex : TEXCOORD1;
	float3 Tan : TANGENT;
	float3 Normal : NORMAL;
};

struct APP2VS_GBuffBaseDetailCrackLM
{
	float4 Pos : POSITION;
	float2 DetailTex : TEXCOORD0;
	float2 CrackTex : TEXCOORD1;
	float2 LightMapTex : TEXCOORD2;
	float3 Tan : TANGENT;
	float3 Normal : NORMAL;
};

struct APP2VS_GBuffBaseDetailDirtCrack
{
	float4 Pos : POSITION;
	float2 DetailTex : TEXCOORD0;
	float2 CrackTex : TEXCOORD1;
	float3 Tan : TANGENT;
	float3 Normal : NORMAL;
};

struct APP2VS_GBuffBaseDetailDirtCrackLM
{
	float4 Pos : POSITION;
	float2 DetailTex : TEXCOORD0;
	float2 CrackTex : TEXCOORD1;
	float2 LightMapTex : TEXCOORD2;
	float3 Tan : TANGENT;
	float3 Normal : NORMAL;
};

struct VS2PS_GBuffBase
{
	float4 HPos : POSITION;
	float2 DiffuseTex : TEXCOORD0;
	float4 WorldPos : TEXCOORD1;
	float3 Mat1 : TEXCOORD2;
	float3 Mat2 : TEXCOORD3;
	float3 Mat3 : TEXCOORD4;
};

struct VS2PS_GBuffBaseLM
{
	float4 HPos : POSITION;
	float2 DiffuseTex : TEXCOORD0;
	float2 LightMapTex : TEXCOORD1;
	float4 WorldPos : TEXCOORD2;
	float3 Mat1 : TEXCOORD3;
	float3 Mat2 : TEXCOORD4;
	float3 Mat3 : TEXCOORD5;
};

struct VS2PS_GBuffBaseLMAT
{
	float4 HPos : POSITION;
	float2 DiffuseTex : TEXCOORD0;
	float2 LightMapTex : TEXCOORD1;
	float4 WorldPos : TEXCOORD2;
	float3 Mat1 : TEXCOORD3;
	float3 Mat2 : TEXCOORD4;
	float3 Mat3 : TEXCOORD5;
	float4 OtherTex : TEXCOORD6;
};

struct VS2PS_GBuffBaseLMAT1
{
	float4 Pos : POSITION;
	float4 TexCoord0 : TEXCOORD0;
};

struct VS2PS_GBuffBaseDetail
{
	float4 HPos : POSITION;
	float2 DetailTex : TEXCOORD0;
	float4 WorldPos : TEXCOORD1;
	float3 Mat1 : TEXCOORD2;
	float3 Mat2 : TEXCOORD3;
	float3 Mat3 : TEXCOORD4;
};

struct VS2PS_GBuffBaseDetailParallax
{
	float4 HPos : POSITION;
	float2 DetailTex : TEXCOORD0;
	float4 WorldPos : TEXCOORD1;
	float3 Mat1 : TEXCOORD2;
	float3 Mat2 : TEXCOORD3;
	float3 Mat3 : TEXCOORD4;
	float3 TanEyeVec : TEXCOORD5;
};

struct VS2PS_GBuffBaseDetailLM
{
	float4 HPos : POSITION;
	float2 DetailTex : TEXCOORD0;
	float2 LightMapTex : TEXCOORD1;
	float4 WorldPos : TEXCOORD2;
	float3 Mat1 : TEXCOORD3;
	float3 Mat2 : TEXCOORD4;
	float3 Mat3 : TEXCOORD5;
};

struct VS2PS_GBuffBaseDetailLMParallax
{
	float4 HPos : POSITION;
	float2 DetailTex : TEXCOORD0;
	float2 LightMapTex : TEXCOORD1;
	float4 WorldPos : TEXCOORD2;
	float3 Mat1 : TEXCOORD3;
	float3 Mat2 : TEXCOORD4;
	float3 Mat3 : TEXCOORD5;
	float3 TanEyeVec : TEXCOORD6;
};

struct VS2PS_GBuffBaseDetailDirt
{
	float4 HPos : POSITION;
	float2 DetailTex : TEXCOORD0;
	float4 WorldPos : TEXCOORD1;
	float3 Mat1 : TEXCOORD2;
	float3 Mat2 : TEXCOORD3;
	float3 Mat3 : TEXCOORD4;
};

struct VS2PS_GBuffBaseDetailDirtParallax
{
	float4 HPos : POSITION;
	float2 DetailTex : TEXCOORD0;
	float4 WorldPos : TEXCOORD1;
	float3 Mat1 : TEXCOORD2;
	float3 Mat2 : TEXCOORD3;
	float3 Mat3 : TEXCOORD4;
	float3 TanEyeVec : TEXCOORD5;
};

struct VS2PS_GBuffBaseDetailDirtLM
{
	float4 HPos : POSITION;
	float2 DetailTex : TEXCOORD0;
	float2 LightMapTex : TEXCOORD1;
	float4 WorldPos : TEXCOORD2;
	float3 Mat1 : TEXCOORD3;
	float3 Mat2 : TEXCOORD4;
	float3 Mat3 : TEXCOORD5;
};

struct VS2PS_GBuffBaseDetailDirtLMParallax
{
	float4 HPos : POSITION;
	float2 DetailTex : TEXCOORD0;
	float2 LightMapTex : TEXCOORD1;
	float4 WorldPos : TEXCOORD2;
	float3 Mat1 : TEXCOORD3;
	float3 Mat2 : TEXCOORD4;
	float3 Mat3 : TEXCOORD5;
	float3 TanEyeVec : TEXCOORD6;
};

struct VS2PS_GBuffBaseDetailCrack
{
	float4 HPos : POSITION;
	float2 DetailTex : TEXCOORD0;
	float2 CrackTex : TEXCOORD1;
	float4 WorldPos : TEXCOORD2;
	float3 Mat1 : TEXCOORD3;
	float3 Mat2 : TEXCOORD4;
	float3 Mat3 : TEXCOORD5;
};

struct VS2PS_GBuffBaseDetailCrackParallax
{
	float4 HPos : POSITION;
	float2 DetailTex : TEXCOORD0;
	float2 CrackTex : TEXCOORD1;
	float4 WorldPos : TEXCOORD2;
	float3 Mat1 : TEXCOORD3;
	float3 Mat2 : TEXCOORD4;
	float3 Mat3 : TEXCOORD5;
	float3 TanEyeVec : TEXCOORD6;
};

struct VS2PS_GBuffBaseDetailCrackLM
{
	float4 HPos : POSITION;
	float2 DetailTex : TEXCOORD0;
	float2 CrackTex : TEXCOORD1;
	float2 LightMapTex : TEXCOORD2;
	float4 WorldPos : TEXCOORD3;
	float3 Mat1 : TEXCOORD4;
	float3 Mat2 : TEXCOORD5;
	float3 Mat3 : TEXCOORD6;
};

struct VS2PS_GBuffBaseDetailCrackLMParallax
{
	float4 HPos : POSITION;
	float2 DetailTex : TEXCOORD0;
	float2 CrackTex : TEXCOORD1;
	float2 LightMapTex : TEXCOORD2;
	float4 WorldPos : TEXCOORD3;
	float3 Mat1 : TEXCOORD4;
	float3 Mat2 : TEXCOORD5;
	float3 Mat3 : TEXCOORD6;
	float3 TanEyeVec : TEXCOORD7;
};

struct VS2PS_GBuffBaseDetailDirtCrack
{
	float4 HPos : POSITION;
	float2 DetailTex : TEXCOORD0;
	float2 CrackTex : TEXCOORD1;
	float4 WorldPos : TEXCOORD2;
	float3 Mat1 : TEXCOORD3;
	float3 Mat2 : TEXCOORD4;
	float3 Mat3 : TEXCOORD5;
};

struct VS2PS_GBuffBaseDetailDirtCrackParallax
{
	float4 HPos : POSITION;
	float2 DetailTex : TEXCOORD0;
	float2 CrackTex : TEXCOORD1;
	float4 WorldPos : TEXCOORD2;
	float3 Mat1 : TEXCOORD3;
	float3 Mat2 : TEXCOORD4;
	float3 Mat3 : TEXCOORD5;
	float3 TanEyeVec : TEXCOORD6;
};

struct VS2PS_GBuffBaseDetailDirtCrackLM
{
	float4 HPos : POSITION;
	float2 DetailTex : TEXCOORD0;
	float4 CrackAndLightMapTex : TEXCOORD1;
	float4 WorldPos : TEXCOORD2;
	float3 Mat1 : TEXCOORD3;
	float3 Mat2 : TEXCOORD4;
	float3 Mat3 : TEXCOORD5;
};

struct VS2PS_GBuffBaseDetailDirtCrackLMParallax
{
	float4 HPos : POSITION;
	float2 DetailTex : TEXCOORD0;
	float4 CrackAndLightMapTex : TEXCOORD1;
	float4 WorldPos : TEXCOORD2;
	float3 Mat1 : TEXCOORD3;
	float3 Mat2 : TEXCOORD4;
	float3 Mat3 : TEXCOORD5;
	float3 TanEyeVec : TEXCOORD6;
};

struct PS2FB_MRT
{
	float4 LightmapBuffer : COLOR0;
	float4 WorldPosBuffer : COLOR1;
	float4 NormalBuffer : COLOR2;
};

struct PS2FB_MRT4
{
	float4 Color0 : COLOR0;
	float4 Color1 : COLOR1;
	float4 Color2 : COLOR2;
	float4 Color3 : COLOR3;
};

/*
	[VERTEX SHADERS]
*/

VS2PS_GBuffBase VS_GBuffBase(APP2VS_GBuffBase Input)
{
	VS2PS_GBuffBase Output;

	Output.HPos = mul(Input.Pos, _ViewProjMatrix);
	Output.WorldPos = mul(Input.Pos, _WorldViewMatrix);

	float3x3 TangentBasis = GetTangentBasis(Input.Tan, Input.Normal, 1.0);
	GetViewTangentBasis(TangentBasis, Output.Mat1, Output.Mat2, Output.Mat3);

	// Pass-through texcoords
	Output.DiffuseTex = Input.DiffuseTex;
	return Output;
}

VS2PS_GBuffBaseLM VS_GBuffBaseLM(APP2VS_GBuffBaseLM Input)
{
	VS2PS_GBuffBaseLM Output;

	Output.HPos = mul(Input.Pos, _ViewProjMatrix);
	Output.WorldPos = mul(Input.Pos, _WorldViewMatrix);

	float3x3 TangentBasis = GetTangentBasis(Input.Tan, Input.Normal, 1.0);
	GetViewTangentBasis(TangentBasis, Output.Mat1, Output.Mat2, Output.Mat3);

	// Pass-through texcoords
	Output.DiffuseTex = Input.DiffuseTex;
	Output.LightMapTex = (Input.LightMapTex * _LightmapOffset.xy) + _LightmapOffset.zw;

	return Output;
}

VS2PS_GBuffBaseLMAT VS_GBuffBaseLMAT(APP2VS_GBuffBaseLM Input)
{
	VS2PS_GBuffBaseLMAT Output;

	Output.HPos = mul(Input.Pos, _ViewProjMatrix);
	Output.WorldPos = mul(Input.Pos, _WorldViewMatrix);

	float3x3 TangentBasis = GetTangentBasis(Input.Tan, Input.Normal, 1.0);
	GetViewTangentBasis(TangentBasis, Output.Mat1, Output.Mat2, Output.Mat3);

	// Pass-through texcoords
	Output.DiffuseTex = Input.DiffuseTex;
	Output.LightMapTex = (Input.LightMapTex * _LightmapOffset.xy) + _LightmapOffset.zw;

	// Hacked to only support 800/600
	Output.OtherTex.xy = Output.HPos.xy/Output.HPos.w;
	Output.OtherTex.xy = (Output.OtherTex.xy * 0.5) + 0.5;
	Output.OtherTex.y = 1-Output.OtherTex.y;
	Output.OtherTex.x += 0.000625;
	Output.OtherTex.y += 0.000833;
	Output.OtherTex.xy = Output.OtherTex.xy * Output.HPos.w;
	Output.OtherTex.zw = Output.HPos.zw;

	return Output;
}

VS2PS_GBuffBaseLMAT1 VS_GBuffBaseLMAT1(APP2VS_GBuffBaseLM Input)
{
	VS2PS_GBuffBaseLMAT1 Output;

  	Output.Pos = mul(Input.Pos, _ViewProjMatrix);

	Output.TexCoord0.xy = Output.Pos.xy/Output.Pos.w;
	Output.TexCoord0.xy = (Output.TexCoord0.xy * 0.5) + 0.5;
	Output.TexCoord0.y = 1-Output.TexCoord0.y;
	Output.TexCoord0.x += 0.000625;
	Output.TexCoord0.y += 0.000833;
	Output.TexCoord0.xy = Output.TexCoord0.xy * Output.Pos.w;
	Output.TexCoord0.zw = Output.Pos.zw;

	return Output;
}

VS2PS_GBuffBaseDetail VS_GBuffBaseDetail(APP2VS_GBuffBaseDetail Input)
{
	VS2PS_GBuffBaseDetail Output;

	Output.HPos = mul(Input.Pos, _ViewProjMatrix);
	Output.WorldPos = mul(Input.Pos, _WorldViewMatrix);

	float3x3 TangentBasis = GetTangentBasis(Input.Tan, Input.Normal, 1.0);
	GetViewTangentBasis(TangentBasis, Output.Mat1, Output.Mat2, Output.Mat3);

	// Pass-through texcoords
	Output.DetailTex = Input.DetailTex;

	return Output;
}

VS2PS_GBuffBaseDetailParallax VS_GBuffBaseDetailParallax(APP2VS_GBuffBaseDetail Input)
{
	VS2PS_GBuffBaseDetailParallax Output;

	Output.HPos = mul(Input.Pos, _ViewProjMatrix);
	Output.WorldPos = mul(Input.Pos, _WorldViewMatrix);

	float3x3 TangentBasis = GetTangentBasis(Input.Tan, Input.Normal, 1.0);
	GetViewTangentBasis(TangentBasis, Output.Mat1, Output.Mat2, Output.Mat3);
	Output.TanEyeVec = mul(_EyePosObjectSpace.xyz - Input.Pos.xyz, TangentBasis);

	// Pass-through texcoords
	Output.DetailTex = Input.DetailTex;

	return Output;
}

VS2PS_GBuffBaseDetailLM VS_GBuffBaseDetailLM(APP2VS_GBuffBaseDetailLM Input)
{
	VS2PS_GBuffBaseDetailLM Output;

  	Output.HPos = mul(Input.Pos, _ViewProjMatrix);
	Output.WorldPos = mul(Input.Pos, _WorldViewMatrix);

	float3x3 TangentBasis = GetTangentBasis(Input.Tan, Input.Normal, 1.0);
	GetViewTangentBasis(TangentBasis, Output.Mat1, Output.Mat2, Output.Mat3);

	// Pass-through texcoords
	Output.DetailTex = Input.DetailTex;
	Output.LightMapTex = (Input.LightMapTex * _LightmapOffset.xy) + _LightmapOffset.zw;
	return Output;
}

VS2PS_GBuffBaseDetailLMParallax VS_GBuffBaseDetailLMParallax(APP2VS_GBuffBaseDetailLM Input)
{
	VS2PS_GBuffBaseDetailLMParallax Output;

  	Output.HPos = mul(Input.Pos, _ViewProjMatrix);
	Output.WorldPos = mul(Input.Pos, _WorldViewMatrix);

	float3x3 TangentBasis = GetTangentBasis(Input.Tan, Input.Normal, 1.0);
	GetViewTangentBasis(TangentBasis, Output.Mat1, Output.Mat2, Output.Mat3);

	Output.TanEyeVec = mul((_EyePosObjectSpace.xyz - Input.Pos.xyz), TangentBasis);

	// Pass-through texcoords
	Output.DetailTex = Input.DetailTex;
	Output.LightMapTex = (Input.LightMapTex * _LightmapOffset.xy) + _LightmapOffset.zw;

	return Output;
}

VS2PS_GBuffBaseDetailDirt VS_GBuffBaseDetailDirt(APP2VS_GBuffBaseDetailDirt Input)
{
	VS2PS_GBuffBaseDetailDirt Output;

	Output.HPos = mul(Input.Pos, _ViewProjMatrix);
	Output.WorldPos = mul(Input.Pos, _WorldViewMatrix);

	float3x3 TangentBasis = GetTangentBasis(Input.Tan, Input.Normal, 1.0);
	GetViewTangentBasis(TangentBasis, Output.Mat1, Output.Mat2, Output.Mat3);

	// Pass-through texcoords
	Output.DetailTex = Input.DetailTex;

	return Output;
}

VS2PS_GBuffBaseDetailDirtParallax VS_GBuffBaseDetailDirtParallax(APP2VS_GBuffBaseDetailDirt Input)
{
	VS2PS_GBuffBaseDetailDirtParallax Output;

	Output.HPos = mul(Input.Pos, _ViewProjMatrix);
	Output.WorldPos = mul(Input.Pos, _WorldViewMatrix);

	float3x3 TangentBasis = GetTangentBasis(Input.Tan, Input.Normal, 1.0);
	GetViewTangentBasis(TangentBasis, Output.Mat1, Output.Mat2, Output.Mat3);
	Output.TanEyeVec = mul(_EyePosObjectSpace.xyz - Input.Pos.xyz, TangentBasis);

	// Pass-through texcoords
	Output.DetailTex = Input.DetailTex;

	return Output;
}

VS2PS_GBuffBaseDetailDirtLM VS_GBuffBaseDetailDirtLM(APP2VS_GBuffBaseDetailDirtLM Input)
{
	VS2PS_GBuffBaseDetailDirtLM Output;

	Output.HPos = mul(Input.Pos, _ViewProjMatrix);
	Output.WorldPos = mul(Input.Pos, _WorldViewMatrix);

	float3x3 TangentBasis = GetTangentBasis(Input.Tan, Input.Normal, 1.0);
	GetViewTangentBasis(TangentBasis, Output.Mat1, Output.Mat2, Output.Mat3);

	// Pass-through texcoords
	Output.DetailTex = Input.DetailTex;
	Output.LightMapTex = (Input.LightMapTex * _LightmapOffset.xy) + _LightmapOffset.zw;

	return Output;
}

VS2PS_GBuffBaseDetailDirtLMParallax VS_GBuffBaseDetailDirtLMParallax(APP2VS_GBuffBaseDetailDirtLM Input)
{
	VS2PS_GBuffBaseDetailDirtLMParallax Output;

	Output.HPos = mul(Input.Pos, _ViewProjMatrix);
	Output.WorldPos = mul(Input.Pos, _WorldViewMatrix);

	float3x3 TangentBasis = GetTangentBasis(Input.Tan, Input.Normal, 1.0);
	GetViewTangentBasis(TangentBasis, Output.Mat1, Output.Mat2, Output.Mat3);
	Output.TanEyeVec = mul(_EyePosObjectSpace.xyz - Input.Pos.xyz, TangentBasis);

	// Pass-through texcoords
	Output.DetailTex = Input.DetailTex;
	Output.LightMapTex = (Input.LightMapTex * _LightmapOffset.xy) + _LightmapOffset.zw;

	return Output;
}

VS2PS_GBuffBaseDetailCrack VS_GBuffBaseDetailCrack(APP2VS_GBuffBaseDetailCrack Input)
{
	VS2PS_GBuffBaseDetailCrack Output;

	Output.HPos = mul(Input.Pos, _ViewProjMatrix);
	Output.WorldPos = mul(Input.Pos, _WorldViewMatrix);

	float3x3 TangentBasis = GetTangentBasis(Input.Tan, Input.Normal, 1.0);
	GetViewTangentBasis(TangentBasis, Output.Mat1, Output.Mat2, Output.Mat3);

	// Pass-through texcoords
	Output.DetailTex = Input.DetailTex;
	Output.CrackTex = Input.CrackTex;

	return Output;
}

VS2PS_GBuffBaseDetailCrackParallax VS_GBuffBaseDetailCrackParallax(APP2VS_GBuffBaseDetailCrack Input)
{
	VS2PS_GBuffBaseDetailCrackParallax Output;

	Output.HPos = mul(Input.Pos, _ViewProjMatrix);
	Output.WorldPos = mul(Input.Pos, _WorldViewMatrix);

	float3x3 TangentBasis = GetTangentBasis(Input.Tan, Input.Normal, 1.0);
	GetViewTangentBasis(TangentBasis, Output.Mat1, Output.Mat2, Output.Mat3);
	Output.TanEyeVec = mul(_EyePosObjectSpace.xyz - Input.Pos.xyz, TangentBasis);

	// Pass-through texcoords
	Output.DetailTex = Input.DetailTex;
	Output.CrackTex = Input.CrackTex;

	return Output;
}

VS2PS_GBuffBaseDetailCrackLM VS_GBuffBaseDetailCrackLM(APP2VS_GBuffBaseDetailCrackLM Input)
{
	VS2PS_GBuffBaseDetailCrackLM Output;

	Output.HPos = mul(Input.Pos, _ViewProjMatrix);
	Output.WorldPos = mul(Input.Pos, _WorldViewMatrix);

	float3x3 TangentBasis = GetTangentBasis(Input.Tan, Input.Normal, 1.0);
	GetViewTangentBasis(TangentBasis, Output.Mat1, Output.Mat2, Output.Mat3);

	// Pass-through texcoords
	Output.DetailTex = Input.DetailTex;
	Output.CrackTex = Input.CrackTex;
	Output.LightMapTex = (Input.LightMapTex * _LightmapOffset.xy) + _LightmapOffset.zw;

	return Output;
}

VS2PS_GBuffBaseDetailCrackLMParallax VS_GBuffBaseDetailCrackLMParallax(APP2VS_GBuffBaseDetailCrackLM Input)
{
	VS2PS_GBuffBaseDetailCrackLMParallax Output;

	Output.HPos = mul(Input.Pos, _ViewProjMatrix);
	Output.WorldPos = mul(Input.Pos, _WorldViewMatrix);

	float3x3 TangentBasis = GetTangentBasis(Input.Tan, Input.Normal, 1.0);
	GetViewTangentBasis(TangentBasis, Output.Mat1, Output.Mat2, Output.Mat3);
	Output.TanEyeVec = mul(_EyePosObjectSpace.xyz - Input.Pos.xyz, TangentBasis);

	// Pass-through texcoords
	Output.DetailTex = Input.DetailTex;
	Output.CrackTex = Input.CrackTex;
	Output.LightMapTex = (Input.LightMapTex * _LightmapOffset.xy) + _LightmapOffset.zw;

	return Output;
}


VS2PS_GBuffBaseDetailDirtCrack VS_GBuffBaseDetailDirtCrack(APP2VS_GBuffBaseDetailDirtCrack Input)
{
	VS2PS_GBuffBaseDetailDirtCrack Output;

	Output.HPos = mul(Input.Pos, _ViewProjMatrix);
	Output.WorldPos = mul(Input.Pos, _WorldViewMatrix);

	float3x3 TangentBasis = GetTangentBasis(Input.Tan, Input.Normal, 1.0);
	GetViewTangentBasis(TangentBasis, Output.Mat1, Output.Mat2, Output.Mat3);

	// Pass-through texcoords
	Output.DetailTex = Input.DetailTex;
	Output.CrackTex = Input.CrackTex;

	return Output;
}

VS2PS_GBuffBaseDetailDirtCrackParallax VS_GBuffBaseDetailDirtCrackParallax(APP2VS_GBuffBaseDetailDirtCrack Input)
{
	VS2PS_GBuffBaseDetailDirtCrackParallax Output;

	Output.HPos = mul(Input.Pos, _ViewProjMatrix);
	Output.WorldPos = mul(Input.Pos, _WorldViewMatrix);

	float3x3 TangentBasis = GetTangentBasis(Input.Tan, Input.Normal, 1.0);
	GetViewTangentBasis(TangentBasis, Output.Mat1, Output.Mat2, Output.Mat3);
	Output.TanEyeVec = mul(_EyePosObjectSpace.xyz - Input.Pos.xyz, TangentBasis);

	// Pass-through texcoords
	Output.DetailTex = Input.DetailTex;
	Output.CrackTex = Input.CrackTex;

	return Output;
}

VS2PS_GBuffBaseDetailDirtCrackLM VS_GBuffBaseDetailDirtCrackLM(APP2VS_GBuffBaseDetailDirtCrackLM Input)
{
	VS2PS_GBuffBaseDetailDirtCrackLM Output;

	Output.HPos = mul(Input.Pos, _ViewProjMatrix);
	Output.WorldPos = mul(Input.Pos, _WorldViewMatrix);

	float3x3 TangentBasis = GetTangentBasis(Input.Tan, Input.Normal, 1.0);
	GetViewTangentBasis(TangentBasis, Output.Mat1, Output.Mat2, Output.Mat3);

	// Pass-through texcoords
	Output.DetailTex = Input.DetailTex;
	Output.CrackAndLightMapTex.xy = Input.CrackTex;
	Output.CrackAndLightMapTex.zw = (Input.LightMapTex * _LightmapOffset.xy) + _LightmapOffset.zw;

	return Output;
}

VS2PS_GBuffBaseDetailDirtCrackLMParallax VS_GBuffBaseDetailDirtCrackLMParallax(APP2VS_GBuffBaseDetailDirtCrackLM Input)
{
	VS2PS_GBuffBaseDetailDirtCrackLMParallax Output;

	Output.HPos = mul(Input.Pos, _ViewProjMatrix);
	Output.WorldPos = mul(Input.Pos, _WorldViewMatrix);

	float3x3 TangentBasis = GetTangentBasis(Input.Tan, Input.Normal, 1.0);
	GetViewTangentBasis(TangentBasis, Output.Mat1, Output.Mat2, Output.Mat3);
	Output.TanEyeVec = mul(_EyePosObjectSpace.xyz - Input.Pos.xyz, TangentBasis);

	// Pass-through texcoords
	Output.DetailTex = Input.DetailTex;
	Output.CrackAndLightMapTex.xy = Input.CrackTex;
	Output.CrackAndLightMapTex.zw = (Input.LightMapTex * _LightmapOffset.xy) + _LightmapOffset.zw;

	return Output;
}

/*
	[PIXEL SHADERS]
*/

PS2FB_MRT PS_GBuffBase(VS2PS_GBuffBase Input)
{
	PS2FB_MRT Output;

	float4 NormalMap = tex2D(SamplerWrap1, Input.DiffuseTex);

	Output.LightmapBuffer = 1.0;
	Output.WorldPosBuffer = Input.WorldPos;
	Output.NormalBuffer = UnpackNormal(NormalMap, float3x3(Input.Mat1, Input.Mat2, Input.Mat3));

	return Output;
}

PS2FB_MRT PS_GBuffBaseLM(VS2PS_GBuffBaseLM Input)
{
	PS2FB_MRT Output;

	float4 NormalMap = tex2D(SamplerWrap1, Input.DiffuseTex);

	Output.LightmapBuffer = tex2D(SamplerWrap2, Input.LightMapTex);
	Output.WorldPosBuffer = Input.WorldPos;
	Output.NormalBuffer = UnpackNormal(NormalMap, float3x3(Input.Mat1, Input.Mat2, Input.Mat3));

	return Output;
}

PS2FB_MRT4 PS_GBuffBaseLMAT0(VS2PS_GBuffBaseLMAT Input)
{
	PS2FB_MRT4 Output;

	float4 diffTex = tex2D(SamplerWrapAniso0, Input.DiffuseTex);
	// float newDepth = Input.WorldPos.w + (1-diffTex.a);
	// Output.Depth = newDepth;
	// clip(diffTex.a-0.1);

	float4 rtlightmap = tex2Dproj(SamplerClamp3, Input.OtherTex);
	float4 rtposmap = tex2Dproj(SamplerClamp4, Input.OtherTex);
	float4 rtnormalmap = tex2Dproj(SamplerClamp5, Input.OtherTex);
	float4 rtdiffmap = tex2Dproj(SamplerClamp6, Input.OtherTex);

	float4 LMap = tex2D(SamplerWrap2, Input.LightMapTex);
	Output.Color0 = (diffTex.a >= 50.0/255.0) ? LMap : rtlightmap;
	Output.Color1 = (diffTex.a >= 50.0/255.0) ? float4(Input.WorldPos.rgb, 0): rtposmap;
	float4 ExpandedNormal = tex2D(SamplerWrap1, Input.DiffuseTex);
	ExpandedNormal.xyz = (ExpandedNormal.xyz * 2) - 1.0;
	float4 rotatedNormal;
	rotatedNormal.x = dot(ExpandedNormal, Input.Mat1);
	rotatedNormal.y = dot(ExpandedNormal, Input.Mat2);
	rotatedNormal.z = dot(ExpandedNormal, Input.Mat3);
	rotatedNormal.w = 0;
	Output.Color2 = (diffTex.a >= 50.0/255.0) ? rotatedNormal : rtnormalmap;
	Output.Color3 = (diffTex.a >= 50.0/255.0) ? diffTex : rtdiffmap;

	return Output;
}

float4 PS_GBuffBaseLMAT1_Diffuse(VS2PS_GBuffBaseLMAT1 Input) : COLOR0
{
	return tex2Dproj(SamplerClamp3, Input.TexCoord0);
}

PS2FB_MRT PS_GBuffBaseLMAT1_MRT(VS2PS_GBuffBaseLMAT1 Input)
{
	PS2FB_MRT Output;

	Output.LightmapBuffer = tex2Dproj(SamplerClamp0, Input.TexCoord0);
	Output.WorldPosBuffer = tex2Dproj(SamplerClamp1, Input.TexCoord0);
	Output.NormalBuffer = tex2Dproj(SamplerClamp2, Input.TexCoord0);

	return Output;
}

PS2FB_MRT PS_GBuffBaseDetail(VS2PS_GBuffBaseDetail Input)
{
	PS2FB_MRT Output;

	float4 NormalMap = tex2D(SamplerWrap2, Input.DetailTex);

	Output.LightmapBuffer = 1.0;
	Output.WorldPosBuffer = Input.WorldPos;
	Output.NormalBuffer = UnpackNormal(NormalMap, float3x3(Input.Mat1, Input.Mat2, Input.Mat3));

	return Output;
}

PS2FB_MRT PS_GBuffBaseDetailParallax(VS2PS_GBuffBaseDetailParallax Input)
{
	PS2FB_MRT Output;

	float2 ParallaxOffset = GetOffsetsFromAlpha(Input.DetailTex.xy, SamplerWrap1, _ParallaxScaleBias, Input.TanEyeVec);
	float4 NormalMap = tex2D(SamplerWrap2, Input.DetailTex + ParallaxOffset);

	Output.LightmapBuffer = 1.0;
	Output.WorldPosBuffer = Input.WorldPos;
	Output.NormalBuffer = UnpackNormal(NormalMap, float3x3(Input.Mat1, Input.Mat2, Input.Mat3));

	return Output;
}

PS2FB_MRT PS_GBuffBaseDetailLM(VS2PS_GBuffBaseDetailLM Input)
{
	PS2FB_MRT Output;

	float4 LightMap = tex2D(SamplerWrap3, Input.LightMapTex);
	float4 NormalMap = tex2D(SamplerWrap2, Input.DetailTex);

	Output.LightmapBuffer = LightMap;
	Output.WorldPosBuffer = Input.WorldPos;
	Output.NormalBuffer = UnpackNormal(NormalMap, float3x3(Input.Mat1, Input.Mat2, Input.Mat3));

	return Output;
}

PS2FB_MRT PS_GBuffBaseDetailLMParallax(VS2PS_GBuffBaseDetailLMParallax Input)
{
	PS2FB_MRT Output;

	float2 ParallaxOffset = GetOffsetsFromAlpha(Input.DetailTex.xy, SamplerWrap1, _ParallaxScaleBias, Input.TanEyeVec);
	float4 NormalMap = tex2D(SamplerWrap2, Input.DetailTex + ParallaxOffset);

	Output.NormalBuffer = UnpackNormal(NormalMap, float3x3(Input.Mat1, Input.Mat2, Input.Mat3));
	Output.LightmapBuffer = tex2D(SamplerWrap3, Input.LightMapTex.xy);
	Output.WorldPosBuffer = Input.WorldPos;

	return Output;
}

PS2FB_MRT PS_GBuffBaseDetailDirt(VS2PS_GBuffBaseDetailDirt Input)
{
	PS2FB_MRT Output;

	float4 NormalMap = tex2D(SamplerWrap3, Input.DetailTex);

	Output.LightmapBuffer = 1.0;
	Output.WorldPosBuffer = Input.WorldPos;
	Output.NormalBuffer = UnpackNormal(NormalMap, float3x3(Input.Mat1, Input.Mat2, Input.Mat3));

	return Output;
}

PS2FB_MRT PS_GBuffBaseDetailDirtParallax(VS2PS_GBuffBaseDetailDirtParallax Input)
{
	PS2FB_MRT Output;

	float2 ParallaxOffset = GetOffsetsFromAlpha(Input.DetailTex.xy, SamplerWrap1, _ParallaxScaleBias, Input.TanEyeVec);
	float4 NormalMap = tex2D(SamplerWrap3, Input.DetailTex + ParallaxOffset);

	Output.LightmapBuffer = 1.0;
	Output.WorldPosBuffer = Input.WorldPos;
	Output.NormalBuffer = UnpackNormal(NormalMap, float3x3(Input.Mat1, Input.Mat2, Input.Mat3));

	return Output;
}

PS2FB_MRT PS_GBuffBaseDetailDirtLM(VS2PS_GBuffBaseDetailDirtLM Input)
{
	PS2FB_MRT Output;

	float4 LightMap = tex2D(SamplerWrap4, Input.LightMapTex);
	float4 NormalMap = tex2D(SamplerWrap3, Input.DetailTex);

	Output.LightmapBuffer = LightMap;
	Output.WorldPosBuffer = Input.WorldPos;
	Output.NormalBuffer = UnpackNormal(NormalMap, float3x3(Input.Mat1, Input.Mat2, Input.Mat3));

	return Output;
}

PS2FB_MRT PS_GBuffBaseDetailDirtLMParallax(VS2PS_GBuffBaseDetailDirtLMParallax Input)
{
	PS2FB_MRT Output;

	float2 ParallaxOffset = GetOffsetsFromAlpha(Input.DetailTex.xy, SamplerWrap1, _ParallaxScaleBias, Input.TanEyeVec);
	float4 LightMap = tex2D(SamplerWrap4, Input.LightMapTex.xy);
	float4 NormalMap = tex2D(SamplerWrap3, Input.DetailTex + ParallaxOffset);

	Output.LightmapBuffer = LightMap;
	Output.WorldPosBuffer = Input.WorldPos;
	Output.NormalBuffer = UnpackNormal(NormalMap, float3x3(Input.Mat1, Input.Mat2, Input.Mat3));

	return Output;
}

PS2FB_MRT PS_GBuffBaseDetailCrack(VS2PS_GBuffBaseDetailCrack Input)
{
	PS2FB_MRT Output;

	float4 Crack = tex2D(SamplerWrap2, Input.CrackTex);
	float4 DetailNormal = tex2D(SamplerWrap3, Input.DetailTex);
	float4 CrackNormal = tex2D(SamplerWrap4, Input.CrackTex);
	float4 NormalMap = lerp(DetailNormal, CrackNormal, Crack.a);

	Output.LightmapBuffer = 1.0;
	Output.WorldPosBuffer = Input.WorldPos;
	Output.NormalBuffer = UnpackNormal(NormalMap, float3x3(Input.Mat1, Input.Mat2, Input.Mat3));

	return Output;
}

PS2FB_MRT PS_GBuffBaseDetailCrackParallax(VS2PS_GBuffBaseDetailCrackParallax Input)
{
	PS2FB_MRT Output;

	float2 ParallaxOffset = GetOffsetsFromAlpha(Input.DetailTex.xy, SamplerWrap1, _ParallaxScaleBias, Input.TanEyeVec);
	float4 Crack = tex2D(SamplerWrap2, Input.CrackTex);
	float4 DetailNormal = tex2D(SamplerWrap3, Input.DetailTex + ParallaxOffset);
	float4 CrackNormal = tex2D(SamplerWrap4, Input.CrackTex);
	float4 NormalMap = lerp(DetailNormal, CrackNormal, Crack.a);

	Output.LightmapBuffer = 1.0;
	Output.WorldPosBuffer = Input.WorldPos;
	Output.NormalBuffer = UnpackNormal(NormalMap, float3x3(Input.Mat1, Input.Mat2, Input.Mat3));

	return Output;
}

PS2FB_MRT PS_GBuffBaseDetailCrackLM(VS2PS_GBuffBaseDetailCrackLM Input)
{
	PS2FB_MRT Output;

	float4 Crack = tex2D(SamplerWrap2, Input.CrackTex);
	float4 DetailNormal = tex2D(SamplerWrap3, Input.DetailTex);
	float4 CrackNormal = tex2D(SamplerWrap4, Input.CrackTex);
	float4 LightMap = tex2D(SamplerWrap5, Input.LightMapTex);
	float4 NormalMap = lerp(DetailNormal, CrackNormal, Crack.a);

	Output.LightmapBuffer = LightMap;
	Output.WorldPosBuffer = Input.WorldPos;
	Output.NormalBuffer = UnpackNormal(NormalMap, float3x3(Input.Mat1, Input.Mat2, Input.Mat3));

	return Output;
}

PS2FB_MRT PS_GBuffBaseDetailCrackLMParallax(VS2PS_GBuffBaseDetailCrackLMParallax Input)
{
	PS2FB_MRT Output;

	float2 ParallaxOffset = GetOffsetsFromAlpha(Input.DetailTex.xy, SamplerWrap1, _ParallaxScaleBias, Input.TanEyeVec);
	float4 Crack = tex2D(SamplerWrap2, Input.CrackTex);
	float4 DetailNormal = tex2D(SamplerWrap3, Input.DetailTex + ParallaxOffset);
	float4 CrackNormal = tex2D(SamplerWrap4, Input.CrackTex);
	float4 LightMap = tex2D(SamplerWrap5, Input.LightMapTex.xy);
	float4 NormalMap = lerp(DetailNormal, CrackNormal, Crack.a);

	Output.LightmapBuffer = LightMap;
	Output.WorldPosBuffer = Input.WorldPos;
	Output.NormalBuffer = UnpackNormal(NormalMap, float3x3(Input.Mat1, Input.Mat2, Input.Mat3));

	return Output;
}

PS2FB_MRT PS_GBuffBaseDetailDirtCrack(VS2PS_GBuffBaseDetailDirtCrack Input)
{
	PS2FB_MRT Output;

	float4 Crack = tex2D(SamplerWrap3, Input.CrackTex);
	float4 DetailNormal = tex2D(SamplerWrap4, Input.DetailTex);
	float4 CrackNormal = tex2D(SamplerWrap5, Input.CrackTex);
	float4 NormalMap = lerp(DetailNormal, CrackNormal, Crack.a);

	Output.LightmapBuffer = 1.0;
	Output.WorldPosBuffer = Input.WorldPos;
	Output.NormalBuffer = UnpackNormal(NormalMap, float3x3(Input.Mat1, Input.Mat2, Input.Mat3));

	return Output;
}

PS2FB_MRT PS_GBuffBaseDetailDirtCrackParallax(VS2PS_GBuffBaseDetailDirtCrackParallax Input)
{
	PS2FB_MRT Output;

	float2 ParallaxOffset = GetOffsetsFromAlpha(Input.DetailTex.xy, SamplerWrap1, _ParallaxScaleBias, Input.TanEyeVec);
	float4 Crack = tex2D(SamplerWrap3, Input.CrackTex);
	float4 DetailNormal = tex2D(SamplerWrap4, Input.DetailTex + ParallaxOffset);
	float4 CrackNormal = tex2D(SamplerWrap5, Input.CrackTex);
	float4 NormalMap = lerp(DetailNormal, CrackNormal, Crack.a);

	Output.LightmapBuffer = 1.0;
	Output.WorldPosBuffer = Input.WorldPos;
	Output.NormalBuffer = UnpackNormal(NormalMap, float3x3(Input.Mat1, Input.Mat2, Input.Mat3));

	return Output;
}

PS2FB_MRT PS_GBuffBaseDetailDirtCrackLM(VS2PS_GBuffBaseDetailDirtCrackLM Input)
{
	PS2FB_MRT Output;

	float4 Crack = tex2D(SamplerWrapAniso3, Input.CrackAndLightMapTex.xy);
	float4 DetailNormal = tex2D(SamplerWrap4, Input.DetailTex);
	float4 CrackNormal = tex2D(SamplerWrap5, Input.CrackAndLightMapTex.xy);
	float4 LightMap = tex2D(SamplerWrap6, Input.CrackAndLightMapTex.zw);
	float4 NormalMap = lerp(DetailNormal, CrackNormal, Crack.a);

	Output.LightmapBuffer = LightMap;
	Output.WorldPosBuffer = Input.WorldPos;
	Output.NormalBuffer = UnpackNormal(NormalMap, float3x3(Input.Mat1, Input.Mat2, Input.Mat3));

	return Output;
}

PS2FB_MRT PS_GBuffBaseDetailDirtCrackLMParallax(VS2PS_GBuffBaseDetailDirtCrackLMParallax Input)
{
	PS2FB_MRT Output;

	float2 ParallaxOffset = GetOffsetsFromAlpha(Input.DetailTex.xy, SamplerWrap1, _ParallaxScaleBias, Input.TanEyeVec);
	float4 Crack = tex2D(SamplerWrapAniso3, Input.CrackAndLightMapTex.xy);
	float4 DetailNormal = tex2D(SamplerWrap4, Input.DetailTex + ParallaxOffset);
	float4 CrackNormal = tex2D(SamplerWrap5, Input.CrackAndLightMapTex.xy);
	float4 LightMap = tex2D(SamplerWrap6, Input.CrackAndLightMapTex.zw);
	float4 NormalMap = lerp(DetailNormal, CrackNormal, Crack.a);

	Output.LightmapBuffer = LightMap;
	Output.WorldPosBuffer = Input.WorldPos;
	Output.NormalBuffer = UnpackNormal(NormalMap, float3x3(Input.Mat1, Input.Mat2, Input.Mat3));

	return Output;
}

/*
	[TECHNIQUES]
*/

#define CREATE_TECHNIQUE_DX9G(TECHNIQUE_NAME, VERTEX_SHADER, PIXEL_SHADER) \
	technique TECHNIQUE_NAME \
	{ \
		pass p0 \
		{ \
			ZWriteEnable = FALSE; \
			ZFunc = EQUAL; \
			ZEnable = TRUE; \
			StencilEnable = FALSE; \
			VertexShader = compile vs_3_0 VERTEX_SHADER; \
			PixelShader = compile ps_3_0 PIXEL_SHADER; \
		} \
	}

#define CREATE_TECHNIQUE_DX9G_WRITE(TECHNIQUE_NAME, VERTEX_SHADER, PIXEL_SHADER) \
	technique TECHNIQUE_NAME \
	{ \
		pass p0 \
		{ \
			ZEnable = TRUE; \
			ZWriteEnable = FALSE; \
			ZFunc = LESSEQUAL; \
			ColorWriteEnable = RED|BLUE|GREEN|ALPHA; \
			StencilEnable = FALSE; \
			VertexShader = compile vs_3_0 VERTEX_SHADER; \
			PixelShader = compile ps_3_0 PIXEL_SHADER; \
		} \
	}

CREATE_TECHNIQUE_DX9G(DX9GBuffbase, VS_GBuffBase(), PS_GBuffBase())
CREATE_TECHNIQUE_DX9G(DX9GBuffbaseLM, VS_GBuffBaseLM(), PS_GBuffBaseLM())

CREATE_TECHNIQUE_DX9G_WRITE(DX9GBuffbaseLMAT0, VS_GBuffBaseLMAT(), PS_GBuffBaseLMAT0())
CREATE_TECHNIQUE_DX9G_WRITE(DX9GBuffbaseLMAT1, VS_GBuffBaseLMAT1(), PS_GBuffBaseLMAT1_Diffuse())
CREATE_TECHNIQUE_DX9G_WRITE(DX9GBuffbaseLMAT2, VS_GBuffBaseLMAT1(), PS_GBuffBaseLMAT1_MRT())

CREATE_TECHNIQUE_DX9G(DX9GBuffbasedetail, VS_GBuffBaseDetail(), PS_GBuffBaseDetail())
CREATE_TECHNIQUE_DX9G(DX9GBuffbasedetailparallax, VS_GBuffBaseDetailParallax(), PS_GBuffBaseDetailParallax())
CREATE_TECHNIQUE_DX9G(DX9GBuffbasedetailLM, VS_GBuffBaseDetailLM(), PS_GBuffBaseDetailLM())
CREATE_TECHNIQUE_DX9G(DX9GBuffbasedetailLMparallax, VS_GBuffBaseDetailLMParallax(), PS_GBuffBaseDetailLMParallax())
CREATE_TECHNIQUE_DX9G(DX9GBuffbasedetaildirt, VS_GBuffBaseDetailDirt(), PS_GBuffBaseDetailDirt())
CREATE_TECHNIQUE_DX9G(DX9GBuffbasedetaildirtparallax, VS_GBuffBaseDetailDirtParallax(), PS_GBuffBaseDetailDirtParallax())
CREATE_TECHNIQUE_DX9G(DX9GBuffbasedetaildirtLM, VS_GBuffBaseDetailDirtLM(), PS_GBuffBaseDetailDirtLM())
CREATE_TECHNIQUE_DX9G(DX9GBuffbasedetaildirtLMparallax, VS_GBuffBaseDetailDirtLMParallax(), PS_GBuffBaseDetailDirtLMParallax())
CREATE_TECHNIQUE_DX9G(DX9GBuffbasedetailcrack, VS_GBuffBaseDetailCrack(), PS_GBuffBaseDetailCrack())
CREATE_TECHNIQUE_DX9G(DX9GBuffbasedetailcrackparallax, VS_GBuffBaseDetailCrackParallax(), PS_GBuffBaseDetailCrackParallax())
CREATE_TECHNIQUE_DX9G(DX9GBuffbasedetailcrackLM, VS_GBuffBaseDetailCrackLM(), PS_GBuffBaseDetailCrackLM())
CREATE_TECHNIQUE_DX9G(DX9GBuffbasedetailcrackLMparallax, VS_GBuffBaseDetailCrackLMParallax(), PS_GBuffBaseDetailCrackLMParallax())
CREATE_TECHNIQUE_DX9G(DX9GBuffbasedetaildirtcrack, VS_GBuffBaseDetailDirtCrack(), PS_GBuffBaseDetailDirtCrack())
CREATE_TECHNIQUE_DX9G(DX9GBuffbasedetaildirtcrackparallax, VS_GBuffBaseDetailDirtCrackParallax(), PS_GBuffBaseDetailDirtCrackParallax())
CREATE_TECHNIQUE_DX9G(DX9GBuffbasedetaildirtcrackLM, VS_GBuffBaseDetailDirtCrackLM(), PS_GBuffBaseDetailDirtCrackLM())
CREATE_TECHNIQUE_DX9G(DX9GBuffbasedetaildirtcrackLMparallax, VS_GBuffBaseDetailDirtCrackLMParallax(), PS_GBuffBaseDetailDirtCrackLMParallax())
