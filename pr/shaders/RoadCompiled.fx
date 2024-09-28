
/*
	Include header files
*/

#include "shaders/RealityGraphics.fxh"
#include "shaders/shared/RealityDepth.fxh"
#include "shaders/shared/RealityDirectXTK.fxh"
#include "shaders/RaCommon.fxh"
#if !defined(_HEADERS_)
	#include "RealityGraphics.fxh"
	#include "shared/RealityDepth.fxh"
	#include "shared/RealityDirectXTK.fxh"
	#include "RaCommon.fxh"
#endif

/*
	Description: Renders lighting for road
*/

float4x4 _WorldViewProj : WorldViewProjection;
float _TexBlendFactor : TexBlendFactor;
float2 _FadeoutValues : FadeOut;
float4 _LocalEyePos : LocalEye;
float4 _CameraPos : CAMERAPOS;
float _ScaleY : SCALEY;
float4 _SunColor : SUNCOLOR;
float4 _GIColor : GICOLOR;

float4 _TexProjOffset : TEXPROJOFFSET;
float4 _TexProjScale : TEXPROJSCALE;

#define CREATE_SAMPLER(SAMPLER_NAME, TEXTURE, ADDRESS_U, ADDRESS_V) \
	sampler SAMPLER_NAME = sampler_state \
	{ \
		Texture = (TEXTURE); \
		MinFilter = FILTER_ROAD_DIFF_MIN; \
		MagFilter = FILTER_ROAD_DIFF_MAG; \
		MipFilter = LINEAR; \
		MaxAnisotropy = PR_MAX_ANISOTROPY; \
		AddressU = ADDRESS_U; \
		AddressV = ADDRESS_V; \
	}; \

texture DetailMap0 : TEXLAYER3;
CREATE_SAMPLER(SampleDetailMap0, DetailMap0, CLAMP, WRAP)

texture DetailMap1 : TEXLAYER4;
CREATE_SAMPLER(SampleDetailMap1, DetailMap1, WRAP, WRAP)

// .rgb = Colors; .a = Lighting;
texture LightMap : TEXLAYER2;
CREATE_SAMPLER(SampleAccumLightMap, LightMap, CLAMP, CLAMP)

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

	float4 Tex0 : TEXCOORD1; // .xy = Tex0; .zw = Tex1
	float4 LightTex : TEXCOORD2;
	float Alpha : TEXCOORD3;
};

struct PS2FB
{
	float4 Color : COLOR0;
	#if defined(LOG_DEPTH)
		float Depth : DEPTH;
	#endif
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

VS2PS VS_RoadCompiled(APP2VS Input)
{
	VS2PS Output = (VS2PS)0.0;

	float4 WorldPos = Input.Pos;
	WorldPos.y += 0.01;

	Output.HPos = mul(WorldPos, _WorldViewProj);
	Output.Pos.xyz = Input.Pos.xyz;

	// Output Depth
	#if defined(LOG_DEPTH)
		Output.Pos.w = Output.HPos.w + 1.0;
	#endif

	Output.Tex0 = float4(Input.Tex0, Input.Tex1);
	Output.LightTex = ProjToLighting(Output.HPos);

	Output.Alpha = Input.Alpha;

	return Output;
}

PS2FB PS_RoadCompiled(VS2PS Input)
{
	PS2FB Output = (PS2FB)0.0;

	float3 LocalPos = Input.Pos.xyz;
	float ZFade = GetRoadZFade(LocalPos.xyz, _LocalEyePos.xyz, _FadeoutValues);

	float4 AccumLights = tex2Dproj(SampleAccumLightMap, Input.LightTex);
	float3 TerrainSunColor = _SunColor.rgb * 2.0;
	float3 TerrainLights = ((TerrainSunColor * AccumLights.w) + AccumLights.rgb) * 2.0;

	float4 Detail0 = SRGBToLinearEst(tex2D(SampleDetailMap0, Input.Tex0.xy));
	float4 Detail1 = SRGBToLinearEst(tex2D(SampleDetailMap1, Input.Tex0.zw * 0.1));

	float4 OutputColor = 0.0;
	OutputColor.rgb = lerp(Detail1, Detail0, _TexBlendFactor);
	OutputColor.a = Detail0.a * saturate(ZFade * Input.Alpha);

	// On thermals no shadows
	if (IsTisActive())
	{
		TerrainLights = (TerrainSunColor + AccumLights.rgb) * 2.0;
		OutputColor.rgb *= TerrainLights;
		OutputColor.g = clamp(OutputColor.g, 0.0, 0.5);
	}
	else
	{
		OutputColor.rgb *= TerrainLights;
	}

	Output.Color = OutputColor;
	ApplyFog(Output.Color.rgb, GetFogValue(LocalPos, _LocalEyePos.xyz));
	TonemapAndLinearToSRGBEst(Output.Color);

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);
	#endif

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
		ZEnable = TRUE;
		ZFunc = PR_ZFUNC_WITHEQUAL;
		ZWriteEnable = FALSE;

		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		VertexShader = compile vs_3_0 VS_RoadCompiled();
		PixelShader = compile ps_3_0 PS_RoadCompiled();
	}

	pass DirectX9
	{
		ZEnable = FALSE;
		ZFunc = PR_ZFUNC_WITHEQUAL;

		#if PR_IS_REVERSED_Z
			DepthBias = 0.0001;
			SlopeScaleDepthBias = 0.00001;
		#else
			DepthBias = -0.0001;
			SlopeScaleDepthBias = -0.00001;
		#endif

		AlphaBlendEnable = FALSE;

		VertexShader = compile vs_3_0 VS_RoadCompiled();
		PixelShader = compile ps_3_0 PS_RoadCompiled();
	}
}
