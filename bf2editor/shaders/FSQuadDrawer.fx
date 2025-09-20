#line 2 "FSQuadDrawer.fx"

/*
	Include header files
*/

#include "shaders/RealityGraphics.fxh"
#include "shaders/shared/RealityDirectXTK.fxh"
#include "shaders/shared/RealityEffects.fxh"
#include "shaders/shared/RealityPixel.fxh"
#if !defined(_HEADERS_)
	#include "RealityGraphics.fxh"
	#include "shared/RealityDirectXTK.fxh"
	#include "shared/RealityEffects.fxh"
	#include "shared/RealityPixel.fxh"
#endif

/*
	Description: This shader handles screen-space post-processing and texture conversions

	The shader includes the following effects:
		- Blurs (glow, blur, downsample, upsample, etc.)
		- Texture conversions to 8-bit
*/

/*
	[Attributes from app]
*/

dword _dwordStencilRef : STENCILREF = 0;
dword _dwordStencilPass : STENCILPASS = 1; // KEEP

float4x4 _ConvertPosTo8BitMat : CONVERTPOSTO8BITMAT;
float4x4 _CustomMtx : CUSTOMMTX;

// Convolution attributes passed from the app
float4 _ScaleDown2x2SampleOffsets[4] : SCALEDOWN2X2SAMPLEOFFSETS;
float4 _ScaleDown4x4SampleOffsets[16] : SCALEDOWN4X4SAMPLEOFFSETS;
float4 _ScaleDown4x4LinearSampleOffsets[4] : SCALEDOWN4X4LINEARSAMPLEOFFSETS;
float4 _GaussianBlur5x5CheapSampleOffsets[13] : GAUSSIANBLUR5X5CHEAPSAMPLEOFFSETS;
float _GaussianBlur5x5CheapSampleWeights[13] : GAUSSIANBLUR5X5CHEAPSAMPLEWEIGHTS;
float4 _GaussianBlur15x15HorizontalSampleOffsets[15] : GAUSSIANBLUR15X15HORIZONTALSAMPLEOFFSETS;
float _GaussianBlur15x15HorizontalSampleWeights[15] : GAUSSIANBLUR15X15HORIZONTALSAMPLEWEIGHTS;
float4 _GaussianBlur15x15VerticalSampleOffsets[15] : GAUSSIANBLUR15X15VERTICALSAMPLEOFFSETS;
float _GaussianBlur15x15VerticalSampleWeights[15] : GAUSSIANBLUR15X15VERTICALSAMPLEWEIGHTS;
float4 _GrowablePoisson13SampleOffsets[12] : GROWABLEPOISSON13SAMPLEOFFSETS;

// Glow attributes passed from the app
float _GlowHorizOffsets[5] : GLOWHORIZOFFSETS;
float _GlowHorizWeights[5] : GLOWHORIZWEIGHTS;
float _GlowVertOffsets[5] : GLOWVERTOFFSETS;
float _GlowVertWeights[5] : GLOWVERTWEIGHTS;

// Glow attributes passed from the app
float _BloomHorizOffsets[5] : BLOOMHORIZOFFSETS;
float _BloomVertOffsets[5] : BLOOMVERTOFFSETS;

// Other attributes passed from the app (render.)
float _HighPassGate : HIGHPASSGATE;
float _BlurStrength : BLURSTRENGTH; // 3d optics blur; xxxx.yyyy; x - inner radius, y - outer radius

float2 _TexelSize : TEXELSIZE;

/*
	[Textures and samplers]
*/

#define CREATE_SAMPLER(SAMPLER_NAME, TEXTURE, FILTER, ADDRESS) \
sampler SAMPLER_NAME = sampler_state \
{ \
	Texture = (TEXTURE); \
	MinFilter = FILTER; \
	MagFilter = FILTER; \
	MipFilter = LINEAR; \
	MaxAnisotropy = PR_MAX_ANISOTROPY; \
	AddressU = ADDRESS; \
	AddressV = ADDRESS; \
}; \

texture Tex0 : TEXLAYER0;
CREATE_SAMPLER(SampleTex0_Clamp, Tex0, LINEAR, CLAMP)
CREATE_SAMPLER(SampleTex0_Mirror, Tex0, LINEAR, MIRROR)
CREATE_SAMPLER(SampleTex0_Aniso, Tex0, ANISOTROPIC, CLAMP)

texture Tex1 : TEXLAYER1;
CREATE_SAMPLER(SampleTex1, Tex1, LINEAR, CLAMP)

// texture Tex2 : TEXLAYER2;
// CREATE_SAMPLER(SampleTex2, Tex2, LINEAR, CLAMP)

// texture Tex3 : TEXLAYER3;
// CREATE_SAMPLER(SampleTex3, Tex3, LINEAR, CLAMP)

struct APP2VS_Blit
{
	float2 Pos : POSITION0;
	float2 TexCoord0 : TEXCOORD0;
};

struct VS2PS_4Tap
{
	float4 HPos : POSITION;
	float2 FilterCoords[4] : TEXCOORD0;
};

struct VS2PS_5Tap
{
	float4 HPos : POSITION;
	float2 TexCoord0 : TEXCOORD0;
	float4 FilterCoords[2] : TEXCOORD1;
};

struct VS2PS_Blit
{
	float4 HPos : POSITION;
	float2 TexCoord0 : TEXCOORD0;
};

VS2PS_Blit VS_Blit(APP2VS_Blit Input)
{
	VS2PS_Blit Output = (VS2PS_Blit)0.0;
	Output.HPos = float4(Input.Pos.xy, 0.0, 1.0);
	Output.TexCoord0 = Input.TexCoord0;
	return Output;
}

VS2PS_Blit VS_Blit_Custom(APP2VS_Blit Input)
{
	VS2PS_Blit Output = (VS2PS_Blit)0.0;
	Output.HPos = mul(float4(Input.Pos.xy, 0.0, 1.0), _CustomMtx);
	Output.TexCoord0 = Input.TexCoord0;
	return Output;
}

float4 PS_TR_OpticsSpiralBlur(VS2PS_Blit Input) : COLOR0
{
	return GetSpiralBlur(SampleTex0_Mirror, Input.TexCoord0, 1.0, true);
}

float4 PS_TR_OpticsMask(VS2PS_Blit Input) : COLOR0
{
	// Get distance from the Center of the screen
	float AspectRatio = GetAspectRatio(GetScreenSize(Input.TexCoord0).yx);

	// Get blur mask
	float2 BlendTex = Input.TexCoord0 - 0.5;
	float Distance = length(BlendTex * float2(AspectRatio, 1.0));
	float EdgeAA = fwidth(Distance);
	float Edge1 = _BlurStrength / 1000.0; // default: 0.2
	float Edge2 = frac(_BlurStrength); // default: 0.25
	float BlendMask = saturate(smoothstep(Edge1 - EdgeAA, Edge2, Distance));

	// Composite
	float3 Color = tex2D(SampleTex0_Aniso, Input.TexCoord0).rgb;

	// Alpha (.a) is the mask to be composited in the pixel shader's blend operation
	return float4(Color, BlendMask);
}

float4 PS_TR_PassthroughBilinear(VS2PS_Blit Input) : COLOR0
{
	return tex2D(SampleTex0_Clamp, Input.TexCoord0);
}

float4 PS_TR_PassthroughAnisotropy(VS2PS_Blit Input) : COLOR0
{
	return tex2D(SampleTex0_Aniso, Input.TexCoord0);
}

float4 PS_Dummy() : COLOR0
{
	return 0.0;
}

VS2PS_Blit PS_Blit_Magnified(APP2VS_Blit Input)
{
	VS2PS_Blit Output = (VS2PS_Blit)0.0;
	Output.HPos = float4(Input.Pos.xy * 1.1, 0.0, 1.0);
	Output.TexCoord0 = Input.TexCoord0;
	return Output;
}

VS2PS_4Tap VS_ScaleDown4x4(APP2VS_Blit Input)
{
	VS2PS_4Tap Output = (VS2PS_4Tap)0.0;
	Output.HPos = float4(Input.Pos.xy, 0.0, 1.0);
	Output.FilterCoords[0] = Input.TexCoord0 + _ScaleDown4x4LinearSampleOffsets[0].xy;
	Output.FilterCoords[1] = Input.TexCoord0 + _ScaleDown4x4LinearSampleOffsets[1].xy;
	Output.FilterCoords[2] = Input.TexCoord0 + _ScaleDown4x4LinearSampleOffsets[2].xy;
	Output.FilterCoords[3] = Input.TexCoord0 + _ScaleDown4x4LinearSampleOffsets[3].xy;
	return Output;
}

VS2PS_5Tap VS_Sample5(APP2VS_Blit Input, uniform float Offsets[5], uniform bool Horizontal)
{
	VS2PS_5Tap Output = (VS2PS_5Tap)0.0;
	Output.HPos = float4(Input.Pos.xy, 0.0, 1.0);

	float2 VSOffset = (Horizontal) ? float2(Offsets[4], 0.0) : float2(0.0, Offsets[4]);
	Output.TexCoord0 = Input.TexCoord0 + VSOffset;

	for(int i = 0; i < 2; i++)
	{
		float2 VSOffsetA = (Horizontal) ? float2(Offsets[i * 2], 0.0) : float2(0.0, Offsets[i * 2]);
		float2 VSOffsetB = (Horizontal) ? float2(Offsets[i * 2 + 1], 0.0) : float2(0.0, Offsets[i * 2 + 1]);
		Output.FilterCoords[i].xy = Input.TexCoord0.xy + VSOffsetA;
		Output.FilterCoords[i].zw = Input.TexCoord0.xy + VSOffsetB;
	}

	return Output;
}

float4 PS_Passthrough(VS2PS_Blit Input) : COLOR0
{
	return tex2D(SampleTex0_Clamp, Input.TexCoord0);
}

float4 PS_PassthroughSaturateAlpha(VS2PS_Blit Input) : COLOR0
{
	float4 OutputColor = tex2D(SampleTex0_Clamp, Input.TexCoord0);
	OutputColor.a = 1.0;
	return OutputColor;
}

float4 PS_CopyRGBToAlpha(VS2PS_Blit Input) : COLOR0
{
	float4 OutputColor = tex2D(SampleTex0_Clamp, Input.TexCoord0);
	OutputColor.a = dot(OutputColor.rgb, 1.0 / 3.0);
	return OutputColor;
}

float4 PS_PosTo8Bit(VS2PS_Blit Input) : COLOR0
{
	float4 ViewPosition = tex2D(SampleTex0_Clamp, Input.TexCoord0);
	ViewPosition /= 50.0;
	ViewPosition = (ViewPosition * 0.5) + 0.5;
	return ViewPosition;
}

float4 PS_NormalTo8Bit(VS2PS_Blit Input) : COLOR0
{
	return (normalize(tex2D(SampleTex0_Clamp, Input.TexCoord0)) * 0.5) + 0.5;
	// return tex2D(SampleTex0_Clamp, Input.TexCoord0).a;
}

float4 PS_ShadowMapFrontTo8Bit(VS2PS_Blit Input) : COLOR0
{
	return tex2D(SampleTex0_Clamp, Input.TexCoord0);
}

float4 PS_ShadowMapBackTo8Bit(VS2PS_Blit Input) : COLOR0
{
	return -tex2D(SampleTex0_Clamp, Input.TexCoord0);
}

float4 PS_ScaleUp4x4(VS2PS_Blit Input) : COLOR0
{
	return tex2D(SampleTex0_Clamp, Input.TexCoord0);
}

float4 PS_ScaleDown2x2(VS2PS_Blit Input) : COLOR0
{
	float4 OutputColor = 0.0;
	OutputColor += SRGBToLinearEst(tex2D(SampleTex0_Clamp, Input.TexCoord0 + _ScaleDown2x2SampleOffsets[0].xy)) * 0.25;
	OutputColor += SRGBToLinearEst(tex2D(SampleTex0_Clamp, Input.TexCoord0 + _ScaleDown2x2SampleOffsets[1].xy)) * 0.25;
	OutputColor += SRGBToLinearEst(tex2D(SampleTex0_Clamp, Input.TexCoord0 + _ScaleDown2x2SampleOffsets[2].xy)) * 0.25;
	OutputColor += SRGBToLinearEst(tex2D(SampleTex0_Clamp, Input.TexCoord0 + _ScaleDown2x2SampleOffsets[3].xy)) * 0.25;

	LinearToSRGBEst(OutputColor);
	return OutputColor;
}

float4 PS_ScaleDown4x4(in VS2PS_Blit Input) : COLOR0
{
	float4 OutputColor = 0.0;

	for(int i = 0; i < 16; i++)
	{
		float2 Offset = _ScaleDown4x4SampleOffsets[i].xy;
		OutputColor += SRGBToLinearEst(tex2D(SampleTex0_Clamp, Input.TexCoord0 + Offset)) * 0.0625;
	}

	LinearToSRGBEst(OutputColor);
	return OutputColor;
}

float4 PS_ScaleDown4x4Linear(VS2PS_4Tap Input) : COLOR0
{
	float4 OutputColor = 0.0;
	OutputColor += SRGBToLinearEst(tex2D(SampleTex0_Clamp, Input.FilterCoords[0].xy)) * 0.25;
	OutputColor += SRGBToLinearEst(tex2D(SampleTex0_Clamp, Input.FilterCoords[1].xy)) * 0.25;
	OutputColor += SRGBToLinearEst(tex2D(SampleTex0_Clamp, Input.FilterCoords[2].xy)) * 0.25;
	OutputColor += SRGBToLinearEst(tex2D(SampleTex0_Clamp, Input.FilterCoords[3].xy)) * 0.25;

	LinearToSRGBEst(OutputColor);
	return OutputColor;
}

float4 PS_CheapGaussianBlur5x5(in VS2PS_Blit Input) : COLOR0
{
	float4 OutputColor = 0.0;
	for(int i = 0; i < 13; i++)
	{
		float2 Offset = _GaussianBlur5x5CheapSampleOffsets[i].xy;
		float Weight = _GaussianBlur5x5CheapSampleWeights[i];
		OutputColor += tex2D(SampleTex0_Clamp, Input.TexCoord0 + Offset) * Weight;
	}

	LinearToSRGBEst(OutputColor);
	return OutputColor;
}

float4 PS_Gaussian_Blur_5x5_Cheap_Filter_Blend(VS2PS_Blit Input) : COLOR0
{
	float4 OutputColor = 0.0;

	for(int i = 0; i < 13; i++)
	{
		float2 Offset = _GaussianBlur5x5CheapSampleOffsets[i].xy;
		float Weight = _GaussianBlur5x5CheapSampleWeights[i];
		OutputColor += tex2D(SampleTex0_Clamp, Input.TexCoord0 + Offset) * Weight;
	}

	OutputColor.a = _BlurStrength;

	LinearToSRGBEst(OutputColor);
	return OutputColor;
}

float4 PS_GaussianBlur15x15H(VS2PS_Blit Input) : COLOR0
{
	float4 OutputColor = 0.0;

	for(int i = 0; i < 15; i++)
	{
		float2 Offset = _GaussianBlur15x15HorizontalSampleOffsets[i].xy;
		float Weight = _GaussianBlur15x15HorizontalSampleWeights[i];
		OutputColor += SRGBToLinearEst(tex2D(SampleTex0_Clamp, Input.TexCoord0 + Offset)) * Weight;
	}

	LinearToSRGBEst(OutputColor);
	return OutputColor;
}

float4 PS_GaussianBlur15x15V(VS2PS_Blit Input) : COLOR0
{
	float4 OutputColor = 0.0;

	for(int i = 0; i < 15; i++)
	{
		float2 Offset = _GaussianBlur15x15VerticalSampleOffsets[i].xy;
		float Weight = _GaussianBlur15x15VerticalSampleWeights[i];
		OutputColor += SRGBToLinearEst(tex2D(SampleTex0_Clamp, Input.TexCoord0 + Offset)) * Weight; 
	}

	LinearToSRGBEst(OutputColor);
	return OutputColor;
}

float4 PS_Poisson13Blur(VS2PS_Blit Input) : COLOR0
{
	float4 OutputColor = 0.0;
	float Samples = 1.0;

	OutputColor = SRGBToLinearEst(tex2D(SampleTex0_Clamp, Input.TexCoord0));

	for(int i = 0; i < 11; i++)
	{
		// float4 V = tex2D(SampleTex0_Clamp, Input.TexCoord0 + _GrowablePoisson13SampleOffsets[i]);
		float2 TexOffset = _GrowablePoisson13SampleOffsets[i].xy * 0.1 * OutputColor.a;
		float4 V = SRGBToLinearEst(tex2D(SampleTex0_Clamp, Input.TexCoord0 + TexOffset));

		if(V.a > 0)
		{
			OutputColor.rgb += V.rgb;
			Samples += 1.0;
		}
	}

	OutputColor /= Samples;

	LinearToSRGBEst(OutputColor);
	return OutputColor;
}

float4 PS_Poisson13AndDilation(VS2PS_Blit Input) : COLOR0
{
	float4 OutputColor = 0.0;

	float4 Center = SRGBToLinearEst(tex2D(SampleTex0_Clamp, Input.TexCoord0));
	OutputColor = (Center.a > 0) ? float4(Center.rgb, 1.0) : OutputColor;

	for(int i = 0; i < 11; i++)
	{
		float Scale = Center.a * 3.0;
		Scale = (Scale == 0) ? 1.5 : Scale;

		float2 TexOffset = _GrowablePoisson13SampleOffsets[i].xy * Scale;
		float4 V = SRGBToLinearEst(tex2D(SampleTex0_Clamp, Input.TexCoord0 + TexOffset));

		if(V.a > 0)
		{
			OutputColor.rgb += V.rgb;
			OutputColor.a += 1.0;
		}
	}

	OutputColor /= OutputColor.a;

	LinearToSRGBEst(OutputColor);
	return OutputColor;
}

float4 PS_GlowFilter(VS2PS_5Tap Input, uniform float Weights[5], uniform bool Horizontal) : COLOR0
{
	float4 OutputColor = Weights[0] * SRGBToLinearEst(tex2D(SampleTex0_Clamp, Input.FilterCoords[0].xy));
	OutputColor += Weights[1] * SRGBToLinearEst(tex2D(SampleTex0_Clamp, Input.FilterCoords[0].zw));
	OutputColor += Weights[2] * SRGBToLinearEst(tex2D(SampleTex0_Clamp, Input.FilterCoords[1].xy));
	OutputColor += Weights[3] * SRGBToLinearEst(tex2D(SampleTex0_Clamp, Input.FilterCoords[1].zw));
	OutputColor += Weights[4] * SRGBToLinearEst(tex2D(SampleTex0_Clamp, Input.TexCoord0));

	LinearToSRGBEst(OutputColor);
	return OutputColor;
}

float4 PS_HighPassFilter(VS2PS_Blit Input) : COLOR0
{
	float4 OutputColor = SRGBToLinearEst(tex2D(SampleTex0_Clamp, Input.TexCoord0));
	OutputColor -= _HighPassGate;
	OutputColor = max(0.0, OutputColor);

	LinearToSRGBEst(OutputColor);
	return OutputColor;
}

float4 PS_HighPassFilterFade(VS2PS_Blit Input) : COLOR0
{
	float4 OutputColor = SRGBToLinearEst(tex2D(SampleTex0_Clamp, Input.TexCoord0));
	OutputColor.rgb = saturate(OutputColor.rgb - _HighPassGate);
	OutputColor.a = _BlurStrength;

	LinearToSRGBEst(OutputColor);
	return OutputColor;
}

float4 PS_Clear(VS2PS_Blit Input) : COLOR0
{
	return 0.0;
}

float4 PS_ExtractGlowFilter(VS2PS_Blit Input) : COLOR0
{
	float4 OutputColor = tex2D(SampleTex0_Clamp, Input.TexCoord0);
	OutputColor.rgb = OutputColor.a;
	OutputColor.a = 1.0;
	return OutputColor;
}

float4 PS_ExtractHDRFilterFade(VS2PS_Blit Input) : COLOR0
{
	float4 OutputColor = SRGBToLinearEst(tex2D(SampleTex0_Clamp, Input.TexCoord0));
	OutputColor.rgb = saturate(OutputColor.a - _HighPassGate);
	OutputColor.a = _BlurStrength;

	LinearToSRGBEst(OutputColor);
	return OutputColor;
}

float4 PS_LumaAndBrightPass(VS2PS_Blit Input) : COLOR0
{
	float4 OutputColor = SRGBToLinearEst(tex2D(SampleTex0_Clamp, Input.TexCoord0));
	OutputColor *= _HighPassGate;
	// float luminance = dot(OutputColor, float3(0.299f, 0.587f, 0.114f));
	
	LinearToSRGBEst(OutputColor);
	return OutputColor;
}

float4 PS_BloomFilter(VS2PS_5Tap Input, uniform bool Is_Blur) : COLOR0
{
	float4 OutputColor = 0.0;
	OutputColor.a = (Is_Blur) ? _BlurStrength : OutputColor.a;

	OutputColor.rgb += SRGBToLinearEst(tex2D(SampleTex0_Clamp, Input.TexCoord0.xy));

	for(int i = 0; i < 2; i++)
	{
		OutputColor.rgb += SRGBToLinearEst(tex2D(SampleTex0_Clamp, Input.FilterCoords[i].xy));
		OutputColor.rgb += SRGBToLinearEst(tex2D(SampleTex0_Clamp, Input.FilterCoords[i].zw));
	}

	OutputColor.rgb /= 5.0;
	LinearToSRGBEst(OutputColor);

	return OutputColor;
}

float4 PS_ScaleUpBloomFilter(VS2PS_Blit Input) : COLOR0
{
	float Offset = 0.01;
	// We can use a blur for this
	float4 Close = tex2D(SampleTex0_Clamp, Input.TexCoord0);
	return Close;
}

float4 PS_Blur(VS2PS_Blit Input) : COLOR0
{
	return float4(tex2D(SampleTex0_Clamp, Input.TexCoord0).rgb, _BlurStrength);
}

/*
	Techniques
*/

#define CREATE_PASS(VERTEX_SHADER, PIXEL_SHADER) \
	pass \
	{ \
		ZEnable = FALSE; \
		AlphaBlendEnable = FALSE; \
		StencilEnable = FALSE; \
		AlphaTestEnable = FALSE; \
		VertexShader = compile vs_3_0 VERTEX_SHADER; \
		PixelShader = compile ps_3_0 PIXEL_SHADER; \
	} \

#define CREATE_NULL_PASS \
	pass \
	{ \
		VertexShader = NULL; \
		PixelShader = NULL; \
	} \

technique Blit
{
	// Pass 0: PassThrough
	CREATE_PASS(VS_Blit(), PS_Passthrough())

	// Pass 1
	pass Blend
	{
		ZEnable = FALSE;
		StencilEnable = FALSE;
		AlphaTestEnable = FALSE;

		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		VertexShader = compile vs_3_0 VS_Blit();
		PixelShader = compile ps_3_0 PS_Passthrough();
	}

	// Pass 2: PosTo8Bit
	CREATE_PASS(VS_Blit(), PS_PosTo8Bit())

	// Pass 3: NormalTo8Bit
	CREATE_PASS(VS_Blit(), PS_NormalTo8Bit())

	// Pass 4: ShadowMapFrontTo8Bit
	CREATE_PASS(VS_Blit(), PS_ShadowMapFrontTo8Bit())

	// Pass 5: ShadowMapBackTo8Bit
	CREATE_PASS(VS_Blit(), PS_ShadowMapBackTo8Bit())

	// Pass 6: ScaleUp4x4
	CREATE_PASS(VS_Blit(), PS_ScaleUp4x4())

	// Pass 7: ScaleDown2x2
	CREATE_PASS(VS_Blit(), PS_ScaleDown2x2())

	// Pass 8: ScaleDown4x4
	CREATE_PASS(VS_Blit(), PS_ScaleDown4x4())

	// Pass 9: ScaleDown4x4Linear (Tinnitus)
	CREATE_PASS(VS_ScaleDown4x4(), PS_ScaleDown4x4Linear())

	// Pass 10: CheapGaussianBlur5x5
	CREATE_PASS(VS_Blit(), PS_CheapGaussianBlur5x5())

	// Pass 11: GaussianBlur15x15H
	CREATE_PASS(VS_Blit(), PS_GaussianBlur15x15H())

	// Pass 12: GaussianBlur15x15V
	CREATE_PASS(VS_Blit(), PS_GaussianBlur15x15V())

	// Pass 13: Poisson13Blur
	CREATE_PASS(VS_Blit(), PS_Poisson13Blur())

	// Pass 14: Poisson13AndDilation
	CREATE_PASS(VS_Blit(), PS_Poisson13AndDilation())

	// Pass 15: ScaleUpBloomFilter
	CREATE_PASS(VS_Blit(), PS_ScaleUpBloomFilter())

	// Pass 16: PassThroughSaturateAlpha
	CREATE_PASS(VS_Blit(), PS_PassthroughSaturateAlpha())

	// Pass 17
	pass CopyRGBToAlpha
	{
		ColorWriteEnable = ALPHA;

		VertexShader = compile vs_3_0 VS_Blit();
		PixelShader = compile ps_3_0 PS_CopyRGBToAlpha();
	}

	/*
		X-Pack additions
	*/

	// Pass 18: PassThroughBilinear
	CREATE_PASS(VS_Blit(), PS_TR_PassthroughBilinear())

	// Pass 19
	pass PassThroughBilinearAdditive
	{
		ZEnable = FALSE;
		StencilEnable = FALSE;
		AlphaTestEnable = FALSE;

		AlphaBlendEnable = TRUE;
		SrcBlend = ZERO;
		DestBlend = ONE;

		VertexShader = compile vs_3_0 VS_Blit();
		PixelShader = compile ps_3_0 PS_TR_PassthroughBilinear();
	}

	// Pass 20: Blur
	CREATE_NULL_PASS

	// Pass 21: ScaleUp4x4Additive
	CREATE_NULL_PASS

	// Pass 22: CheapGaussianBlur5x5Blend
	CREATE_NULL_PASS

	// Pass 23: CheapGaussianBlur5x5Additive
	CREATE_NULL_PASS

	// Pass 24: ScaleUpBloomFilterAdditive
	CREATE_NULL_PASS

	// Pass 25: GlowHorizontalFilter
	CREATE_PASS(VS_Blit(), PS_TR_OpticsSpiralBlur())

	// Pass 26: GlowVerticalFilter
	CREATE_PASS(VS_Blit(), PS_TR_OpticsSpiralBlur())

	// Pass 27: GlowVerticalFilterAdditive
	CREATE_NULL_PASS

	// Pass 28: HighPassFilter
	CREATE_NULL_PASS

	// Pass 29: HighPassFilterFade
	CREATE_PASS(VS_Blit(), PS_TR_PassthroughBilinear())

	// Pass 30: ExtractGlowFilter
	CREATE_NULL_PASS

	// Pass 31: ExtractHDRFilterFade
	CREATE_NULL_PASS

	// Pass 32
	pass ClearAlpha
	{
		ColorWriteEnable = ALPHA;
		VertexShader = compile vs_3_0 PS_Blit_Magnified(); // is this needed? -mosq
		PixelShader = compile ps_3_0 PS_Clear();
	}

	// Pass 33: Additive
	CREATE_NULL_PASS

	// Pass 34
	pass AdditiveBilinear
	{
		ZEnable = FALSE;
		StencilEnable = FALSE;
		AlphaTestEnable = FALSE;

		AlphaBlendEnable = TRUE;
		BlendOp = ADD;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		VertexShader = compile vs_3_0 VS_Blit();
		PixelShader = compile ps_3_0 PS_TR_OpticsMask();
	}

	// Pass 35: BloomHorizFilter
	CREATE_PASS(VS_Blit(), PS_TR_PassthroughBilinear())

	// Pass 36: BloomHorizFilterAdditive
	CREATE_NULL_PASS

	// Pass 37: BloomVertFilter
	CREATE_PASS(VS_Blit(), PS_TR_PassthroughBilinear())

	// Pass 38: BloomVAdditive
	CREATE_NULL_PASS

	// Pass 39: BloomVBlur
	CREATE_NULL_PASS

	// Pass 40: BloomVAdditiveBlur
	CREATE_NULL_PASS

	// Pass 41: LumaAndBrightPass
	CREATE_NULL_PASS

	// Pass 42: ScaleDown4x4H
	CREATE_PASS(VS_Blit(), PS_TR_PassthroughAnisotropy())

	// Pass 43: ScaleDown4x4V
	CREATE_PASS(VS_Blit(), PS_TR_PassthroughAnisotropy())

	// Pass 44: Clear
	CREATE_PASS(VS_Blit(), PS_Clear())

	// Pass 45
	pass BlendCustom
	{
		ZEnable = FALSE;
		StencilEnable = FALSE;
		AlphaTestEnable = FALSE;

		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		VertexShader = compile vs_3_0 VS_Blit_Custom();
		PixelShader = compile ps_3_0 PS_Passthrough();
	}

}

float4 PS_StencilGather(VS2PS_Blit Input) : COLOR0
{
	return _dwordStencilRef / 255.0;
}

float4 PS_StencilMap(VS2PS_Blit Input) : COLOR0
{
	float4 Stencil = tex2D(SampleTex0_Clamp, Input.TexCoord0);
	return tex1D(SampleTex1, Stencil.x / 255.0);
}

technique StencilPasses
{
	pass StencilGather
	{
		ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		AlphaTestEnable = FALSE;

		StencilEnable = TRUE;
		StencilRef = (_dwordStencilRef);
		StencilFunc = EQUAL;
		StencilFail = KEEP;
		StencilZFail = KEEP;
		StencilPass = KEEP;

		VertexShader = compile vs_3_0 VS_Blit();
		PixelShader = compile ps_3_0 PS_StencilGather();
	}

	pass StencilMap
	{
		ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		AlphaTestEnable = FALSE;
		StencilEnable = FALSE;
		VertexShader = compile vs_3_0 VS_Blit();
		PixelShader = compile ps_3_0 PS_StencilMap();
	}
}

technique ResetStencilCuller
{
	pass NV4X
	{
		ZEnable = TRUE;
		ZWriteEnable = FALSE;
		ZFunc = ALWAYS;

		AlphaBlendEnable = FALSE;
		AlphaTestEnable = FALSE;
		ColorWriteEnable = 0;
		ColorWriteEnable1 = 0;
		ColorWriteEnable2 = 0;
		ColorWriteEnable3 = 0;

		StencilEnable = TRUE;
		StencilRef = (_dwordStencilRef);
		StencilMask = 0xFF;
		StencilWriteMask = 0xFF;
		StencilFunc = EQUAL;
		StencilFail = KEEP;
		StencilZFail = KEEP;
		StencilPass = (_dwordStencilPass);
		TwoSidedStencilMode = FALSE;

		VertexShader = compile vs_3_0 VS_Blit();
		PixelShader = compile ps_3_0 PS_Dummy();
	}
}
