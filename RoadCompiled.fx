
/*
	Description: Renders lighting for road
*/

#include "shaders/RealityGraphics.fx"

#include "shaders/RaCommon.fx"

uniform float4x4 _WorldViewProj : WorldViewProjection;
uniform float _TexBlendFactor : TexBlendFactor;
uniform float2 _FadeoutValues : FadeOut;
uniform float4 _LocalEyePos : LocalEye;
uniform float4 _CameraPos : CAMERAPOS;
uniform float _ScaleY : SCALEY;
uniform float4 _SunColor : SUNCOLOR;
uniform float4 _GIColor : GICOLOR;

uniform float4 _TexProjOffset : TEXPROJOFFSET;
uniform float4 _TexProjScale : TEXPROJSCALE;

uniform texture Lighting : TEXLAYER2;
sampler Lighting_Sampler = sampler_state
{
	Texture = (Lighting);
	AddressU = CLAMP;
	AddressV = CLAMP;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = LINEAR;
};

uniform texture Detail_0 : TEXLAYER3;
sampler Detail_0_Sampler = sampler_state
{
	Texture = (Detail_0);
	AddressU = CLAMP;
	AddressV = WRAP;
	MipFilter = LINEAR;
	MinFilter = FILTER_ROAD_DIFF_MIN;
	MagFilter = FILTER_ROAD_DIFF_MAG;
	MaxAnisotropy = 16;
};

uniform texture Detail_1 : TEXLAYER4;
sampler Detail_1_Sampler = sampler_state
{
	Texture = (Detail_1);
	AddressU = WRAP;
	AddressV = WRAP;
	MipFilter = LINEAR;
	MinFilter = FILTER_ROAD_DIFF_MIN;
	MagFilter = FILTER_ROAD_DIFF_MAG;
	MaxAnisotropy = 16;
};

struct APP2VS
{
	float4 Pos : POSITION;
	float2 Tex0 : TEXCOORD0;
	float2 Tex1 : TEXCOORD1;
	// float4 MorphDelta: POSITION1;
	float Alpha : TEXCOORD2;
};

struct VS2PS
{
	float4 HPos : POSITION;
	float4 Tex_0_1 : TEXCOORD0; // .xy = Tex0; .zw = Tex1
	float4 PosTex : TEXCOORD1;
	float4 P_VertexPos_Alpha : TEXCOORD2; // .xyz = VertexPos; .w = Alpha;
};

float4 ProjToLighting(float4 HPos)
{
	float4 Tex;
	// tl: This has been rearranged optimally (I believe) into 1 MUL and 1 MAD,
	//     don't change this without thinking twice.
	//     ProjOffset now includes screen-> texture bias as well as half-texel offset
	//     ProjScale is screen-> texture scale/invert operation
	// Tex = (HPos.x * 0.5 + 0.5 + HTexel, HPos.y * -0.5 + 0.5 + HTexel, HPos.z, HPos.w)
 	Tex = HPos * _TexProjScale + (_TexProjOffset * HPos.w);
	return Tex;
}

VS2PS RoadCompiled_VS(APP2VS Input)
{
	VS2PS Output;

	float4 WorldPos = Input.Pos;
	WorldPos.y += 0.01;
	Output.HPos = mul(WorldPos, _WorldViewProj);
	Output.PosTex = ProjToLighting(Output.HPos);
	Output.Tex_0_1 = float4(Input.Tex0, Input.Tex1);
	Output.P_VertexPos_Alpha = float4(Input.Pos.xyz, Input.Alpha);

	return Output;
}

float4 RoadCompiled_PS(VS2PS Input) : COLOR
{
	float ZFade = GetRoadZFade(Input.P_VertexPos_Alpha.xyz, _LocalEyePos.xyz, _FadeoutValues);
	float4 Detail0 = tex2D(Detail_0_Sampler, Input.Tex_0_1.xy);
	float4 Detail1 = tex2D(Detail_1_Sampler, Input.Tex_0_1.zw * 0.1);

	float4 Color = 0.0;
	Color.rgb = lerp(Detail1, Detail0, _TexBlendFactor);
	Color.a = Detail0.a * saturate(ZFade * Input.P_VertexPos_Alpha.w);

	float4 AccumLights = tex2Dproj(Lighting_Sampler, Input.PosTex);
	float4 Light = 0.0;

	if (FogColor.r < 0.01)
	{
		// On thermals no shadows
		Light = (_SunColor * 2.0 + AccumLights) * 2.0;
		Color.rgb *= Light.xyz;
		Color.g = clamp(Color.g, 0.0, 0.5);
	}
	else
	{
		Light = ((AccumLights.w * _SunColor * 2.0) + AccumLights) * 2.0;
		Color.rgb *= Light.xyz;
	}

	Color.rgb = ApplyFog(Color.rgb, GetFogValue(Input.P_VertexPos_Alpha.xyz, _LocalEyePos.xyz));
	return Color;
}

struct VS2PS_Dx9
{
	float4 HPos : POSITION;
	float4 Tex_0_1 : TEXCOORD0; // .xy = Tex0; .zw = Tex1
	float3 VertexPos : TEXCOORD1;
};

VS2PS_Dx9 RoadCompiled_Dx9_VS(APP2VS Input)
{
	VS2PS_Dx9 Output;
	Output.HPos = mul(Input.Pos, _WorldViewProj);
	Output.Tex_0_1 = float4(Input.Tex0, Input.Tex1);
	Output.VertexPos = Input.Pos.xyz;
	return Output;
}

float4 RoadCompiled_Dx9_PS(VS2PS_Dx9 Input) : COLOR
{
	float ZFade = GetRoadZFade(Input.VertexPos.xyz, _LocalEyePos.xyz, _FadeoutValues);
	float4 Detail0 = tex2D(Detail_0_Sampler, Input.Tex_0_1.xy);
	float4 Detail1 = tex2D(Detail_1_Sampler, Input.Tex_0_1.zw);

	float4 Final = 0.0;
	Final.rgb = lerp(Detail1, Detail0, _TexBlendFactor);
	Final.a = Detail0.a * ZFade;
	return Final;
}

technique roadcompiledFull
<
	int DetailLevel = DLHigh+DLNormal+DLLow+DLAbysmal;
	int Compatibility = CMPR300+CMPNV2X;
	int Declaration[] =
	{
		// StreamNo, DataType, Usage, UsageIdx
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_POSITION, 0 },
		{ 0, D3DDECLTYPE_FLOAT2, D3DDECLUSAGE_TEXCOORD, 0 },
		{ 0, D3DDECLTYPE_FLOAT2, D3DDECLUSAGE_TEXCOORD, 1 },
		// { 0, D3DDECLTYPE_FLOAT4, D3DDECLUSAGE_POSITION, 1 },
		{ 0, D3DDECLTYPE_FLOAT1, D3DDECLUSAGE_TEXCOORD, 2 },
		DECLARATION_END	// End macro
	};
	int TechniqueStates = D3DXFX_DONOTSAVESHADERSTATE;
>
{
	pass NV3x
	{
		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;
		ZEnable = TRUE;
		ZWriteEnable = FALSE;
		VertexShader = compile vs_3_0 RoadCompiled_VS();
		PixelShader = compile ps_3_0 RoadCompiled_PS();
	}

	pass DirectX9
	{
		DepthBias = -0.0001f;
		SlopeScaleDepthBias = -0.00001f;
		ZEnable = FALSE;
		VertexShader = compile vs_3_0 RoadCompiled_Dx9_VS();
		PixelShader = compile ps_3_0 RoadCompiled_Dx9_PS();
	}
}
