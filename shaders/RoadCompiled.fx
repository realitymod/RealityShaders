
/*
	Description: Renders lighting for road
*/

#include "shaders/RealityGraphics.fxh"
#include "shaders/RaCommon.fxh"

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

#define CREATE_DYNAMIC_SAMPLER(SAMPLER_NAME, TEXTURE, ADDRESS, IS_SRGB) \
	sampler SAMPLER_NAME = sampler_state \
	{ \
		Texture = (TEXTURE); \
		MinFilter = FILTER_ROAD_DIFF_MIN; \
		MagFilter = FILTER_ROAD_DIFF_MAG; \
		MipFilter = LINEAR; \
		MaxAnisotropy = 16; \
		AddressU = ADDRESS; \
		AddressV = ADDRESS; \
		SRGBTexture = IS_SRGB; \
	}; \

uniform texture LightMap : TEXLAYER2;
CREATE_DYNAMIC_SAMPLER(SampleLightMap, LightMap, CLAMP, FALSE)

uniform texture DetailMap0 : TEXLAYER3;
CREATE_DYNAMIC_SAMPLER(SampleDetailMap0, DetailMap0, WRAP, FALSE)

uniform texture DetailMap1 : TEXLAYER4;
CREATE_DYNAMIC_SAMPLER(SampleDetailMap1, DetailMap1, WRAP, FALSE)

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
	float4 Pos : TEXCOORD0; // .xyz = VertexPos; .w = Alpha;

	float4 TexA : TEXCOORD1; // .xy = Tex0; .zw = Tex1
	float4 LightTex : TEXCOORD2;
	float Alpha : COLOR0;
};

struct PS2FB
{
	float4 Color : COLOR;
	float Depth : DEPTH;
};

float4 ProjToLighting(float4 HPos)
{
	// tl: This has been rearranged optimally (I believe) into 1 MUL and 1 MAD,
	//     don't change this without thinking twice.
	//     ProjOffset now includes screen-> texture bias as well as half-texel offset
	//     ProjScale is screen-> texture scale/invert operation
	// Tex = (HPos.x * 0.5 + 0.5 + HTexel, HPos.y * -0.5 + 0.5 + HTexel, HPos.z, HPos.w)
	return HPos * _TexProjScale + (_TexProjOffset * HPos.w);
}

VS2PS RoadCompiled_VS(APP2VS Input)
{
	VS2PS Output;

	float4 WorldPos = Input.Pos;
	WorldPos.y += 0.01;

	Output.HPos = mul(WorldPos, _WorldViewProj);
	Output.Pos.xyz = Input.Pos.xyz;
	Output.Pos.w = Output.HPos.w + 1.0; // Output depth

	Output.TexA = float4(Input.Tex0, Input.Tex1);
	Output.LightTex = ProjToLighting(Output.HPos);

	Output.Alpha = Input.Alpha;

	return Output;
}

PS2FB RoadCompiled_PS(VS2PS Input)
{
	PS2FB Output;

	float3 LocalPos = Input.Pos.xyz;

	float ZFade = GetRoadZFade(LocalPos.xyz, _LocalEyePos.xyz, _FadeoutValues);
	float4 Detail0 = tex2D(SampleDetailMap0, Input.TexA.xy);
	float4 Detail1 = tex2D(SampleDetailMap1, Input.TexA.zw * 0.1);

	float4 OutputColor = 0.0;
	OutputColor.rgb = lerp(Detail1, Detail0, _TexBlendFactor);
	OutputColor.a = Detail0.a * saturate(ZFade * Input.Alpha);

	float4 AccumLights = tex2Dproj(SampleLightMap, Input.LightTex);
	float3 TerrainSunColor = _SunColor.rgb * 2.0;
	float3 Light = ((TerrainSunColor * AccumLights.w) + AccumLights.rgb) * 2.0;

	// On thermals no shadows
	if (FogColor.r < 0.01)
	{
		Light = (TerrainSunColor + AccumLights.rgb) * 2.0;
		OutputColor.rgb *= Light;
		OutputColor.g = clamp(OutputColor.g, 0.0, 0.5);
	}
	else
	{
		OutputColor.rgb *= Light;
	}

	ApplyFog(OutputColor.rgb, GetFogValue(LocalPos, _LocalEyePos));

	Output.Color = OutputColor;
	Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);

	return Output;
}

struct VS2PS_Dx9
{
	float4 HPos : POSITION;
	float4 Pos : TEXCOORD0;

	float4 TexA : TEXCOORD1; // .xy = Tex0; .zw = Tex1
};

VS2PS_Dx9 RoadCompiled_Dx9_VS(APP2VS Input)
{
	VS2PS_Dx9 Output;

	Output.HPos = mul(Input.Pos, _WorldViewProj);
	Output.Pos.xyz = Input.Pos.xyz;
	Output.Pos.w = Output.HPos.w + 1.0; // Output depth

	Output.TexA = float4(Input.Tex0, Input.Tex1);

	return Output;
}

PS2FB RoadCompiled_Dx9_PS(VS2PS_Dx9 Input)
{
	PS2FB Output;

	float3 LocalPos = Input.Pos.xyz;

	float ZFade = GetRoadZFade(LocalPos.xyz, _LocalEyePos.xyz, _FadeoutValues);
	float4 Detail0 = tex2D(SampleDetailMap0, Input.TexA.xy);
	float4 Detail1 = tex2D(SampleDetailMap1, Input.TexA.zw);

	float4 OutputColor = 0.0;
	OutputColor.rgb = lerp(Detail1, Detail0, _TexBlendFactor);
	OutputColor.a = Detail0.a * ZFade;

	Output.Color = OutputColor;
	Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);

	return Output;
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
	pass NV3X
	{
		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		ZEnable = TRUE;
		ZWriteEnable = FALSE;

		SRGBWriteEnable = FALSE;

		VertexShader = compile vs_3_0 RoadCompiled_VS();
		PixelShader = compile ps_3_0 RoadCompiled_PS();
	}

	pass DirectX9
	{
		DepthBias = -0.0001f;
		SlopeScaleDepthBias = -0.00001f;
		ZEnable = FALSE;

		SRGBWriteEnable = FALSE;

		VertexShader = compile vs_3_0 RoadCompiled_Dx9_VS();
		PixelShader = compile ps_3_0 RoadCompiled_Dx9_PS();
	}
}
