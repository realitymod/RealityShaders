#line 2 "Staticmesh_DX9Z.fxh"

#include "Shaders/StaticMesh_Data.fxh"
#include "Shaders/RealityGraphics.fxh"
#if !defined(_HEADERS_)
	#include "StaticMesh_Data.fxh"
	#include "RealityGraphics.fxh"
#endif

/*
	ZAndDiffuse
*/

/*
	[STRUCTS]
*/

struct APP2VS_ZAndDiffusebase
{
	float4 Pos : POSITION;
	float2 DiffuseTex : TEXCOORD0;
};

struct APP2VS_ZAndDiffusebasedetail
{
	float4 Pos : POSITION;
	float2 DiffuseTex : TEXCOORD0;
	float2 DetailTex : TEXCOORD1;
};

struct APP2VS_ZAndDiffusebasedetailparallax
{
	float4 Pos : POSITION;
	float2 DiffuseTex : TEXCOORD0;
	float2 DetailTex : TEXCOORD1;
	float3 Tan : TANGENT;
	float3 Normal : NORMAL;
};

struct APP2VS_ZAndDiffusebasedetaildirt
{
	float4 Pos : POSITION;
	float2 DiffuseTex : TEXCOORD0;
	float2 DetailTex : TEXCOORD1;
	float2 DirtTex : TEXCOORD2;
};

struct APP2VS_ZAndDiffusebasedetaildirtparallax
{
	float4 Pos : POSITION;
	float2 DiffuseTex : TEXCOORD0;
	float2 DetailTex : TEXCOORD1;
	float2 DirtTex : TEXCOORD2;
	float3 Tan : TANGENT;
	float3 Normal : NORMAL;
};

struct APP2VS_ZAndDiffusebasedetailcrack
{
	float4 Pos : POSITION;
	float2 DiffuseTex : TEXCOORD0;
	float2 DetailTex : TEXCOORD1;
	float2 CrackTex : TEXCOORD2;
};

struct APP2VS_ZAndDiffusebasedetailcrackparallax
{
	float4 Pos : POSITION;
	float2 DiffuseTex : TEXCOORD0;
	float2 DetailTex : TEXCOORD1;
	float2 CrackTex : TEXCOORD2;
	float3 Tan : TANGENT;
	float3 Normal : NORMAL;
};

struct APP2VS_ZAndDiffusebasedetaildirtcrack
{
	float4 Pos : POSITION;
	float2 DiffuseTex : TEXCOORD0;
	float2 DetailTex : TEXCOORD1;
	float2 DirtTex : TEXCOORD2;
	float2 CrackTex : TEXCOORD3;
};

struct APP2VS_ZAndDiffusebasedetaildirtcrackparallax
{
	float4 Pos : POSITION;
	float2 DiffuseTex : TEXCOORD0;
	float2 DetailTex : TEXCOORD1;
	float2 DirtTex : TEXCOORD2;
	float2 CrackTex : TEXCOORD3;
	float3 Tan : TANGENT;
	float3 Normal : NORMAL;
};

struct VS2PS_ZAndDiffusebase
{
	float4 HPos : POSITION;
	float2 DiffuseTex : TEXCOORD0;
};

struct VS2PS_ZAndDiffusebasedetail
{
	float4 HPos : POSITION;
	float2 DiffuseTex : TEXCOORD0;
	float2 DetailTex : TEXCOORD1;
};

struct VS2PS_ZAndDiffusebasedetailparallax
{
	float4 HPos : POSITION;
	float2 DiffuseTex : TEXCOORD0;
	float2 DetailTex : TEXCOORD1;
   	float3 TanEyeVec : TEXCOORD2;
};

struct VS2PS_ZAndDiffusebasedetaildirt
{
	float4 HPos : POSITION;
	float2 DiffuseTex : TEXCOORD0;
	float2 DetailTex : TEXCOORD1;
	float2 DirtTex : TEXCOORD2;
};

struct VS2PS_ZAndDiffusebasedetaildirtparallax
{
	float4 HPos : POSITION;
	float2 DiffuseTex : TEXCOORD0;
	float2 DetailTex : TEXCOORD1;
	float2 DirtTex : TEXCOORD2;
   	float3 TanEyeVec : TEXCOORD3;
};

struct VS2PS_ZAndDiffusebasedetailcrack
{
	float4 HPos : POSITION;
	float2 DiffuseTex : TEXCOORD0;
	float2 DetailTex : TEXCOORD1;
	float2 CrackTex : TEXCOORD2;
};

struct VS2PS_ZAndDiffusebasedetailcrackparallax
{
	float4 HPos : POSITION;
	float2 DiffuseTex : TEXCOORD0;
	float2 DetailTex : TEXCOORD1;
	float2 CrackTex : TEXCOORD2;
	float3 TanEyeVec : TEXCOORD3;
};

struct VS2PS_ZAndDiffusebasedetaildirtcrack
{
	float4 HPos : POSITION;
	float2 DiffuseTex : TEXCOORD0;
	float2 DetailTex : TEXCOORD1;
	float2 DirtTex : TEXCOORD2;
	float2 CrackTex : TEXCOORD3;
};

struct VS2PS_ZAndDiffusebasedetaildirtcrackparallax
{
	float4 HPos : POSITION;
	float2 DiffuseTex : TEXCOORD0;
	float2 DetailTex : TEXCOORD1;
	float2 DirtTex : TEXCOORD2;
	float2 CrackTex : TEXCOORD3;
   	float3 TanEyeVec : TEXCOORD4;
};

/*
	[VERTEX SHADERS]
*/

VS2PS_ZAndDiffusebase VS_ZAndDiffusebase(APP2VS_ZAndDiffusebase Input)
{
	VS2PS_ZAndDiffusebase Output;

	Output.HPos = mul(Input.Pos, _ViewProjMatrix);

	Output.DiffuseTex = Input.DiffuseTex;

	return Output;
}

VS2PS_ZAndDiffusebasedetail VS_ZAndDiffusebasedetail(APP2VS_ZAndDiffusebasedetail Input)
{
	VS2PS_ZAndDiffusebasedetail Output;

	Output.HPos = mul(Input.Pos, _ViewProjMatrix);

	Output.DiffuseTex = Input.DiffuseTex;
	Output.DetailTex = Input.DetailTex;

	return Output;
}

VS2PS_ZAndDiffusebasedetailparallax VS_ZAndDiffusebasedetailparallax(APP2VS_ZAndDiffusebasedetailparallax Input)
{
	VS2PS_ZAndDiffusebasedetailparallax Output;

	Output.HPos = mul(Input.Pos, _ViewProjMatrix);

	float3x3 TangentBasis = RVertex_GetTangentBasis(Input.Tan, Input.Normal, 1.0);
	Output.TanEyeVec = mul(_EyePosObjectSpace.xyz - Input.Pos.xyz, TangentBasis);
	Output.DiffuseTex = Input.DiffuseTex;
	Output.DetailTex = Input.DetailTex;

	return Output;
}

VS2PS_ZAndDiffusebasedetaildirt VS_ZAndDiffusebasedetaildirt(APP2VS_ZAndDiffusebasedetaildirt Input)
{
	VS2PS_ZAndDiffusebasedetaildirt Output;

 	Output.HPos = mul(Input.Pos, _ViewProjMatrix);

	Output.DiffuseTex = Input.DiffuseTex;
	Output.DetailTex = Input.DetailTex;
	Output.DirtTex = Input.DirtTex;

	return Output;
}

VS2PS_ZAndDiffusebasedetaildirtparallax VS_ZAndDiffusebasedetaildirtparallax(APP2VS_ZAndDiffusebasedetaildirtparallax Input)
{
	VS2PS_ZAndDiffusebasedetaildirtparallax Output;

	Output.HPos = mul(Input.Pos, _ViewProjMatrix);

	float3x3 TangentBasis = RVertex_GetTangentBasis(Input.Tan, Input.Normal, 1.0);
	Output.TanEyeVec = mul(_EyePosObjectSpace.xyz - Input.Pos.xyz, TangentBasis);

	Output.DiffuseTex = Input.DiffuseTex;
	Output.DetailTex = Input.DetailTex;
	Output.DirtTex = Input.DirtTex;

	return Output;
}

VS2PS_ZAndDiffusebasedetailcrack VS_ZAndDiffusebasedetailcrack(APP2VS_ZAndDiffusebasedetailcrack Input)
{
	VS2PS_ZAndDiffusebasedetailcrack Output;

	Output.HPos = mul(Input.Pos, _ViewProjMatrix);

	Output.DiffuseTex = Input.DiffuseTex;
	Output.DetailTex = Input.DetailTex;
	Output.CrackTex = Input.CrackTex;

	return Output;
}

VS2PS_ZAndDiffusebasedetailcrackparallax VS_ZAndDiffusebasedetailcrackparallax(APP2VS_ZAndDiffusebasedetailcrackparallax Input)
{
	VS2PS_ZAndDiffusebasedetailcrackparallax Output;

	Output.HPos = mul(Input.Pos, _ViewProjMatrix);

	float3x3 TangentBasis = RVertex_GetTangentBasis(Input.Tan, Input.Normal, 1.0);
	Output.TanEyeVec = mul(_EyePosObjectSpace.xyz - Input.Pos.xyz, TangentBasis);

	Output.DiffuseTex = Input.DiffuseTex;
	Output.DetailTex = Input.DetailTex;
	Output.CrackTex = Input.CrackTex;

	return Output;
}

VS2PS_ZAndDiffusebasedetaildirtcrack VS_ZAndDiffusebasedetaildirtcrack(APP2VS_ZAndDiffusebasedetaildirtcrack Input)
{
	VS2PS_ZAndDiffusebasedetaildirtcrack Output;

	Output.HPos = mul(Input.Pos, _ViewProjMatrix);

	Output.DiffuseTex = Input.DiffuseTex;
	Output.DetailTex = Input.DetailTex;
	Output.DirtTex = Input.DirtTex;
	Output.CrackTex = Input.CrackTex;

	return Output;
}

VS2PS_ZAndDiffusebasedetaildirtcrackparallax VS_ZAndDiffusebasedetaildirtcrackparallax(APP2VS_ZAndDiffusebasedetaildirtcrackparallax Input)
{
	VS2PS_ZAndDiffusebasedetaildirtcrackparallax Output;

	Output.HPos = mul(Input.Pos, _ViewProjMatrix);

	float3x3 TangentBasis = RVertex_GetTangentBasis(Input.Tan, Input.Normal, 1.0);
	Output.TanEyeVec = mul(_EyePosObjectSpace.xyz - Input.Pos.xyz, TangentBasis);

	Output.DiffuseTex = Input.DiffuseTex;
	Output.DetailTex = Input.DetailTex;
	Output.DirtTex = Input.DirtTex;
	Output.CrackTex = Input.CrackTex;

	return Output;
}

/*
	[PIXEL SHADERS]
*/

float4 PS_ZAndDiffusebase(VS2PS_ZAndDiffusebase Input) : COLOR0
{
	return tex2D(SamplerWrap0, Input.DiffuseTex);
}

float4 PS_ZAndDiffusebasedetail(VS2PS_ZAndDiffusebasedetail Input) : COLOR0
{
	float4 Detail = tex2D(SamplerWrapAniso1, Input.DetailTex);
	float4 Base = tex2D(SamplerWrapAniso0, Input.DiffuseTex);

	return Base * Detail;
}

float4 PS_ZAndDiffusebasedetailparallax(VS2PS_ZAndDiffusebasedetailparallax Input) : COLOR0
{
	float2 ParallaxOffset = GetOffsetsFromAlpha(Input.DetailTex.xy, SamplerWrapAniso1, _ParallaxScaleBias, Input.TanEyeVec);
	float4 Base = tex2D(SamplerWrapAniso0, Input.DiffuseTex + ParallaxOffset);
	float4 Detail = tex2D(SamplerWrapAniso1, Input.DetailTex + ParallaxOffset);

	return Base * Detail;
}

float4 PS_ZAndDiffusebasedetaildirt(VS2PS_ZAndDiffusebasedetaildirt Input) : COLOR0
{
	float4 Detail = tex2D(SamplerWrapAniso1, Input.DetailTex);
	float4 Base = tex2D(SamplerWrapAniso0, Input.DiffuseTex);
	float4 Dirt = tex2D(SamplerWrapAniso2, Input.DirtTex);

	return Base * Detail * Dirt;
}

float4 PS_ZAndDiffusebasedetaildirtparallax(VS2PS_ZAndDiffusebasedetaildirtparallax Input) : COLOR0
{
	float2 ParallaxOffset = GetOffsetsFromAlpha(Input.DetailTex.xy, SamplerWrapAniso1, _ParallaxScaleBias, Input.TanEyeVec);
	float4 Base = tex2D(SamplerWrapAniso0, Input.DiffuseTex + ParallaxOffset);
	float4 Detail = tex2D(SamplerWrapAniso1, Input.DetailTex + ParallaxOffset);
	float4 Dirt = tex2D(SamplerWrapAniso2, Input.DirtTex + ParallaxOffset);

	return Base * Detail * Dirt;
}

float4 PS_ZAndDiffusebasedetailcrack(VS2PS_ZAndDiffusebasedetailcrack Input) : COLOR0
{
	float4 Detail = tex2D(SamplerWrapAniso1, Input.DetailTex);
	float4 Base = tex2D(SamplerWrapAniso0, Input.DiffuseTex);
	float4 Crack = tex2D(SamplerWrapAniso2, Input.CrackTex);

	float3 Color = lerp(Base.rgb * Detail.rgb, Crack.rgb, Crack.a);
	return float4(Color, Detail.a);
}

float4 PS_ZAndDiffusebasedetailcrackparallax(VS2PS_ZAndDiffusebasedetailcrackparallax Input) : COLOR0
{
	float2 ParallaxOffset = GetOffsetsFromAlpha(Input.DetailTex.xy, SamplerWrapAniso1, _ParallaxScaleBias, Input.TanEyeVec);
	float4 Detail = tex2D(SamplerWrapAniso1, Input.DetailTex + ParallaxOffset);
	float4 Base = tex2D(SamplerWrapAniso0, Input.DiffuseTex + ParallaxOffset);
	float4 Crack = tex2D(SamplerWrapAniso2, Input.CrackTex);

	float3 Color = lerp(Base.rgb * Detail.rgb, Crack.rgb, Crack.a);
	return float4(Color, Detail.a);
}

float4 PS_ZAndDiffusebasedetaildirtcrack(VS2PS_ZAndDiffusebasedetaildirtcrack Input) : COLOR0
{
	float4 Detail = tex2D(SamplerWrapAniso1, Input.DetailTex);
	float4 Base = tex2D(SamplerWrapAniso0, Input.DiffuseTex);
	float4 Dirt = tex2D(SamplerWrapAniso2, Input.DirtTex);
	float4 Crack = tex2D(SamplerWrapAniso3, Input.CrackTex);

	float3 Color = lerp(Base.rgb * Detail.rgb * Dirt.rgb, Crack.rgb, Crack.a);
	return float4(Color, Detail.a);
}

float4 PS_ZAndDiffusebasedetaildirtcrackparallax(VS2PS_ZAndDiffusebasedetaildirtcrackparallax Input) : COLOR0
{
	float2 ParallaxOffset = GetOffsetsFromAlpha(Input.DetailTex.xy, SamplerWrapAniso1, _ParallaxScaleBias, Input.TanEyeVec);
	float4 Detail = tex2D(SamplerWrapAniso1, Input.DetailTex + ParallaxOffset);
	float4 Base = tex2D(SamplerWrapAniso0, Input.DiffuseTex + ParallaxOffset);
	float4 Dirt = tex2D(SamplerWrapAniso2, Input.DirtTex + ParallaxOffset);
	float4 Crack = tex2D(SamplerWrapAniso3, Input.CrackTex);

	float3 Color = lerp(Base.rgb * Detail.rgb * Dirt.rgb, Crack.rgb, Crack.a);
	return float4(Color, Detail.a);
}

/*
	[TECHNIQUES]
*/

#define CREATE_TECHNIQUE_DX9Z(TECHNIQUE_NAME, VERTEX_SHADER, PIXEL_SHADER) \
	technique TECHNIQUE_NAME \
	{ \
		pass p0 \
		{ \
			ZEnable = TRUE; \
			ZWriteEnable = TRUE; \
			ZFunc = PR_ZFUNC_WITHEQUAL; \
			StencilEnable = TRUE; \
			StencilRef = 0x40; \
			StencilFunc = ALWAYS; \
			StencilZFail = KEEP; \
			StencilPass = REPLACE; \
			VertexShader = compile vs_3_0 VERTEX_SHADER; \
			PixelShader = compile ps_3_0 PIXEL_SHADER; \
		} \
	}

CREATE_TECHNIQUE_DX9Z(DX9ZAndDiffusebase, VS_ZAndDiffusebase(), PS_ZAndDiffusebase())
CREATE_TECHNIQUE_DX9Z(DX9ZAndDiffusebasedetail, VS_ZAndDiffusebasedetail(), PS_ZAndDiffusebasedetail())
CREATE_TECHNIQUE_DX9Z(DX9ZAndDiffusebasedetailparallax, VS_ZAndDiffusebasedetailparallax(), PS_ZAndDiffusebasedetailparallax())
CREATE_TECHNIQUE_DX9Z(DX9ZAndDiffusebasedetaildirt, VS_ZAndDiffusebasedetaildirt(), PS_ZAndDiffusebasedetaildirt())
CREATE_TECHNIQUE_DX9Z(DX9ZAndDiffusebasedetaildirtparallax, VS_ZAndDiffusebasedetaildirtparallax(), PS_ZAndDiffusebasedetaildirtparallax())
CREATE_TECHNIQUE_DX9Z(DX9ZAndDiffusebasedetailcrack, VS_ZAndDiffusebasedetailcrack(), PS_ZAndDiffusebasedetailcrack())
CREATE_TECHNIQUE_DX9Z(DX9ZAndDiffusebasedetailcrackparallax, VS_ZAndDiffusebasedetailcrackparallax(), PS_ZAndDiffusebasedetailcrackparallax())
CREATE_TECHNIQUE_DX9Z(DX9ZAndDiffusebasedetaildirtcrack, VS_ZAndDiffusebasedetaildirtcrack(), PS_ZAndDiffusebasedetaildirtcrack())
CREATE_TECHNIQUE_DX9Z(DX9ZAndDiffusebasedetaildirtcrackparallax, VS_ZAndDiffusebasedetaildirtcrackparallax(), PS_ZAndDiffusebasedetaildirtcrackparallax())
