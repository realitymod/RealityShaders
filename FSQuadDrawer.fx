
/*
	Description:

	Shader that handles most of the screen-space post processing and texture conversions in the game.
	The shader includes the following
	1. Blurs (glow, blur, downsample, upsample, etc.)
	2. Texture conversions to 8-bit

	Changes:
	1. Removed Shader Model 1.4 shaders (these were done because arbitrary texture coordinate swizzling wasn't a thing in Shader Model 1.x)
	2. Many shaders now use bilinear filtering instead of point filtering (linear filtering was more expensive for certain cards back then)
	3. Updated shaders to Shader Model 3.0 for access to ddx, ddy, and non-gradient texture instructions
	4. Redid coding conventions
*/

#include "shaders/RealityGraphics.fxh"

/*
	[Attributes from app]
*/

uniform dword _dwordStencilRef : STENCILREF = 0;
uniform dword _dwordStencilPass : STENCILPASS = 1; // KEEP

uniform float4x4 _ConvertPosTo8BitMat : CONVERTPOSTO8BITMAT;
uniform float4x4 _CustomMtx : CUSTOMMTX;

// Convolution attributes passed from the app
uniform float4 _ScaleDown2x2SampleOffsets[4] : SCALEDOWN2X2SAMPLEOFFSETS;
uniform float4 _ScaleDown4x4SampleOffsets[16] : SCALEDOWN4X4SAMPLEOFFSETS;
uniform float4 _ScaleDown4x4LinearSampleOffsets[4] : SCALEDOWN4X4LINEARSAMPLEOFFSETS;
uniform float4 _GaussianBlur5x5CheapSampleOffsets[13] : GAUSSIANBLUR5X5CHEAPSAMPLEOFFSETS;
uniform float _GaussianBlur5x5CheapSampleWeights[13] : GAUSSIANBLUR5X5CHEAPSAMPLEWEIGHTS;
uniform float4 _GaussianBlur15x15HorizontalSampleOffsets[15] : GAUSSIANBLUR15X15HORIZONTALSAMPLEOFFSETS;
uniform float _GaussianBlur15x15HorizontalSampleWeights[15] : GAUSSIANBLUR15X15HORIZONTALSAMPLEWEIGHTS;
uniform float4 _GaussianBlur15x15VerticalSampleOffsets[15] : GAUSSIANBLUR15X15VERTICALSAMPLEOFFSETS;
uniform float _GaussianBlur15x15VerticalSampleWeights[15] : GAUSSIANBLUR15X15VERTICALSAMPLEWEIGHTS;
uniform float4 _GrowablePoisson13SampleOffsets[12] : GROWABLEPOISSON13SAMPLEOFFSETS;

// Glow attributes passed from the app
uniform float _GlowHorizOffsets[5] : GLOWHORIZOFFSETS;
uniform float _GlowHorizWeights[5] : GLOWHORIZWEIGHTS;
uniform float _GlowVertOffsets[5] : GLOWVERTOFFSETS;
uniform float _GlowVertWeights[5] : GLOWVERTWEIGHTS;

// Glow attributes passed from the app
uniform float _BloomHorizOffsets[5] : BLOOMHORIZOFFSETS;
uniform float _BloomVertOffsets[5] : BLOOMVERTOFFSETS;

// Other attributes passed from the app (render.)
uniform float _HighPassGate : HIGHPASSGATE;
uniform float _BlurStrength : BLURSTRENGTH; // 3d optics blur; xxxx.yyyy; x - inner radius, y - outer radius

uniform float2 _TexelSize : TEXELSIZE;

/*
	[Textures and samplers]
*/

uniform texture Tex0 : TEXLAYER0;
uniform texture Tex1 : TEXLAYER1;

// uniform texture Tex2 : TEXLAYER2;
// uniform texture Tex3 : TEXLAYER3;

/*
	sampler SampleTex2 = sampler_state
	{
		Texture = (Tex2);
		AddressU = CLAMP;
		AddressV = CLAMP;
		MinFilter = POINT;
		MagFilter = POINT;
	};

	sampler SampleTex3 = sampler_state
	{
		Texture = (Tex3);
		AddressU = CLAMP;
		AddressV = CLAMP;
		MinFilter = POINT;
		MagFilter = POINT;
	};
*/

sampler SampleTex0_Clamp = sampler_state
{
	Texture = (Tex0);
	AddressU = CLAMP;
	AddressV = CLAMP;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
};

sampler SampleTex0_Mirror = sampler_state
{
	Texture = (Tex0);
	AddressU = MIRROR;
	AddressV = MIRROR;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
};

sampler SampleTex0_Aniso = sampler_state
{
	Texture = (Tex0);
	AddressU = CLAMP;
	AddressV = CLAMP;
	MinFilter = ANISOTROPIC;
	MagFilter = ANISOTROPIC;
	MaxAnisotropy = 16;
};

sampler SampleTex1 = sampler_state
{
	Texture = (Tex1);
	AddressU = CLAMP;
	AddressV = CLAMP;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
};

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

VS2PS_Blit Blit_VS(APP2VS_Blit Input)
{
	VS2PS_Blit Output;
	Output.HPos = float4(Input.Pos.xy, 0.0, 1.0);
	Output.TexCoord0 = Input.TexCoord0;
	return Output;
}

VS2PS_Blit Blit_Custom_VS(APP2VS_Blit Input)
{
	VS2PS_Blit Output;
	Output.HPos = mul(float4(Input.Pos.xy, 0.0, 1.0), _CustomMtx);
	Output.TexCoord0 = Input.TexCoord0;
	return Output;
}

static const float2 Offsets[5] =
{
	float2(0.0, 0.0),
	float2(0.0, 1.4584295167832),
	float2(0.0, 3.4039848066734835),
	float2(0.0, 5.351805780136256),
	float2(0.0, 7.302940716034593)
};

static const float Weights[5] =
{
	0.1329807601338109,
	0.2322770777384485,
	0.13532693306504567,
	0.05115603510197893,
	0.012539291705835646
};

float4 LinearGaussianBlur(sampler2D Source, float2 TexCoord, bool IsHorizontal)
{
	float4 OutputColor = 0.0;
	float4 TotalWeights = 0.0;
	float2 PixelSize = float2(ddx(TexCoord.x), ddy(TexCoord.y));

	OutputColor += tex2D(Source, TexCoord + (Offsets[0].xy * PixelSize)) * Weights[0];
	TotalWeights += Weights[0];

	for(int i = 1; i < 5; i++)
	{
		float2 Offset = (IsHorizontal) ? Offsets[i].yx : Offsets[i].xy;
		OutputColor += tex2D(Source, TexCoord + (Offset * PixelSize)) * Weights[i];
		OutputColor += tex2D(Source, TexCoord - (Offset * PixelSize)) * Weights[i];
		TotalWeights += (Weights[i] * 2.0);
	}

	return OutputColor / TotalWeights;
}

float4 TR_OpticsBlurH_PS(VS2PS_Blit Input) : COLOR
{
	return LinearGaussianBlur(SampleTex0_Mirror, Input.TexCoord0, true);
}

float4 TR_OpticsBlurV_PS(VS2PS_Blit Input) : COLOR
{
	return LinearGaussianBlur(SampleTex0_Mirror, Input.TexCoord0, false);
}

float4 TR_OpticsMask_PS(VS2PS_Blit Input) : COLOR
{
	float2 ScreenSize = 0.0;
	ScreenSize.x = int(1.0 / abs(ddx(Input.TexCoord0.x)));
	ScreenSize.y = int(1.0 / abs(ddy(Input.TexCoord0.y)));
	float AspectRatio = ScreenSize.x / ScreenSize.y;

	float Radius1 = _BlurStrength / 1000.0; // 0.2 by default (floor() isn't used for perfomance reasons)
	float Radius2 = frac(_BlurStrength); // 0.25 by default
	float Distance = length((Input.TexCoord0 - 0.5) * float2(AspectRatio, 1.0)); // get distance from the Center of the screen

	float BlurAmount = saturate((Distance - Radius1) / (Radius2 - Radius1));
	float4 OutputColor = tex2D(SampleTex0_Aniso, Input.TexCoord0);
	return float4(OutputColor.rgb, BlurAmount); // Alpha (.a) is the mask to be composited in the pixel shader's blend operation
}

float4 TR_PassthroughBilinear_PS(VS2PS_Blit Input) : COLOR
{
	return tex2D(SampleTex0_Clamp, Input.TexCoord0);
}

float4 TR_PassthroughAnisotropy_PS(VS2PS_Blit Input) : COLOR
{
	return tex2D(SampleTex0_Aniso, Input.TexCoord0);
}

float4 Dummy_PS() : COLOR
{
	return 0.0;
}

VS2PS_Blit Blit_Magnified_PS(APP2VS_Blit Input)
{
	VS2PS_Blit Output;
	Output.HPos = float4(Input.Pos.xy * 1.1, 0.0, 1.0);
	Output.TexCoord0 = Input.TexCoord0;
	return Output;
}

VS2PS_4Tap ScaleDown4x4_VS(APP2VS_Blit Input)
{
	VS2PS_4Tap Output;
	Output.HPos = float4(Input.Pos.xy, 0.0, 1.0);
	Output.FilterCoords[0] = Input.TexCoord0 + _ScaleDown4x4LinearSampleOffsets[0].xy;
	Output.FilterCoords[1] = Input.TexCoord0 + _ScaleDown4x4LinearSampleOffsets[1].xy;
	Output.FilterCoords[2] = Input.TexCoord0 + _ScaleDown4x4LinearSampleOffsets[2].xy;
	Output.FilterCoords[3] = Input.TexCoord0 + _ScaleDown4x4LinearSampleOffsets[3].xy;
	return Output;
}

VS2PS_5Tap Sample5_VS(APP2VS_Blit Input, uniform float Offsets[5], uniform bool Horizontal)
{
	VS2PS_5Tap Output;
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

float4 Passthrough_PS(VS2PS_Blit Input) : COLOR
{
	return tex2D(SampleTex0_Clamp, Input.TexCoord0);
}

float4 PassthroughSaturateAlpha_PS(VS2PS_Blit Input) : COLOR
{
	float4 OutputColor = tex2D(SampleTex0_Clamp, Input.TexCoord0);
	OutputColor.a = 1.0f;
	return OutputColor;
}

float4 CopyRGBToAlpha_PS(VS2PS_Blit Input) : COLOR
{
	float4 OutputColor = tex2D(SampleTex0_Clamp, Input.TexCoord0);
	OutputColor.a = dot(OutputColor.rgb, 1.0 / 3.0);
	return OutputColor;
}

float4 PosTo8Bit_PS(VS2PS_Blit Input) : COLOR
{
	float4 ViewPosition = tex2D(SampleTex0_Clamp, Input.TexCoord0);
	ViewPosition /= 50.0;
	ViewPosition = (ViewPosition * 0.5) + 0.5;
	return ViewPosition;
}

float4 NormalTo8Bit_PS(VS2PS_Blit Input) : COLOR
{
	return (normalize(tex2D(SampleTex0_Clamp, Input.TexCoord0)) * 0.5) + 0.5;
	// return tex2D(SampleTex0_Clamp, Input.TexCoord0).a;
}

float4 ShadowMapFrontTo8Bit_PS(VS2PS_Blit Input) : COLOR
{
	return tex2D(SampleTex0_Clamp, Input.TexCoord0);
}

float4 ShadowMapBackTo8Bit_PS(VS2PS_Blit Input) : COLOR
{
	return -tex2D(SampleTex0_Clamp, Input.TexCoord0);
}

float4 ScaleUp4x4_PS(VS2PS_Blit Input) : COLOR
{
	return tex2D(SampleTex0_Clamp, Input.TexCoord0);
}

float4 ScaleDown2x2_PS(VS2PS_Blit Input) : COLOR
{
	float4 OutputColor = 0.0;
	OutputColor += tex2D(SampleTex0_Clamp, Input.TexCoord0 + _ScaleDown2x2SampleOffsets[0].xy);
	OutputColor += tex2D(SampleTex0_Clamp, Input.TexCoord0 + _ScaleDown2x2SampleOffsets[1].xy);
	OutputColor += tex2D(SampleTex0_Clamp, Input.TexCoord0 + _ScaleDown2x2SampleOffsets[2].xy);
	OutputColor += tex2D(SampleTex0_Clamp, Input.TexCoord0 + _ScaleDown2x2SampleOffsets[3].xy);
	return OutputColor * 0.25;
}

void ScaleDown4x4_PS(in VS2PS_Blit Input, out float4 OutputColor : COLOR)
{
	OutputColor = 0.0;
	for(int i = 0; i < 16; i++)
	{
		OutputColor += tex2D(SampleTex0_Clamp, Input.TexCoord0 + _ScaleDown4x4SampleOffsets[i].xy) * 0.0625;
	}
}

float4 ScaleDown4x4Linear_PS(VS2PS_4Tap Input) : COLOR
{
	float4 OutputColor = 0.0;
	OutputColor += tex2D(SampleTex0_Clamp, Input.FilterCoords[0].xy);
	OutputColor += tex2D(SampleTex0_Clamp, Input.FilterCoords[1].xy);
	OutputColor += tex2D(SampleTex0_Clamp, Input.FilterCoords[2].xy);
	OutputColor += tex2D(SampleTex0_Clamp, Input.FilterCoords[3].xy);
	return OutputColor * 0.25;
}

void CheapGaussianBlur5x5_PS(in VS2PS_Blit Input, out float4 OutputColor : COLOR)
{
	OutputColor = 0.0;
	for(int i = 0; i < 13; i++)
	{
		OutputColor += tex2D(SampleTex0_Clamp, Input.TexCoord0 + _GaussianBlur5x5CheapSampleOffsets[i].xy) * _GaussianBlur5x5CheapSampleWeights[i];
	}
}

void _Gaussian_Blur_5x5_Cheap_Filter_Blend_PS(VS2PS_Blit Input, out float4 OutputColor : COLOR)
{
	OutputColor = 0.0;
	for(int i = 0; i < 13; i++)
	{
		OutputColor += tex2D(SampleTex0_Clamp, Input.TexCoord0 + _GaussianBlur5x5CheapSampleOffsets[i].xy) * _GaussianBlur5x5CheapSampleWeights[i];
	}
	OutputColor.a = _BlurStrength;
}

void GaussianBlur15x15H_PS(VS2PS_Blit Input, out float4 OutputColor : COLOR)
{
	OutputColor = 0.0;
	for(int i = 0; i < 15; i++)
	{
		OutputColor += tex2D(SampleTex0_Clamp, Input.TexCoord0 + _GaussianBlur15x15HorizontalSampleOffsets[i].xy) * _GaussianBlur15x15HorizontalSampleWeights[i];
	}
}

void GaussianBlur15x15V_PS(VS2PS_Blit Input, out float4 OutputColor : COLOR)
{
	OutputColor = 0.0;
	for(int i = 0; i < 15; i++)
	{
		OutputColor += tex2D(SampleTex0_Clamp, Input.TexCoord0 + _GaussianBlur15x15VerticalSampleOffsets[i].xy) * _GaussianBlur15x15VerticalSampleWeights[i];
	}
}

float4 Poisson13Blur_PS(VS2PS_Blit Input) : COLOR
{
	float4 OutputColor = 0.0;
	float Samples = 1.0;

	OutputColor = tex2D(SampleTex0_Clamp, Input.TexCoord0);

	for(int i = 0; i < 11; i++)
	{
		// float4 V = tex2D(SampleTex0_Clamp, Input.TexCoord0 + _GrowablePoisson13SampleOffsets[i]);
		float4 V = tex2D(SampleTex0_Clamp, Input.TexCoord0 + _GrowablePoisson13SampleOffsets[i].xy * 0.1 * OutputColor.a);
		if(V.a > 0)
		{
			OutputColor.rgb += V;
			Samples += 1.0;
		}
	}

	return OutputColor / Samples;
}

float4 Poisson13AndDilation_PS(VS2PS_Blit Input) : COLOR
{
	float4 Center = tex2D(SampleTex0_Clamp, Input.TexCoord0);

	float4 OutputColor = 0.0;
	OutputColor = (Center.a > 0) ? float4(Center.rgb, 1.0) : OutputColor;

	for(int i = 0; i < 11; i++)
	{
		float Scale = Center.a * 3.0;

		if(Scale == 0)
		{
			Scale = 1.5;
		}

		float4 V = tex2D(SampleTex0_Clamp, Input.TexCoord0 + _GrowablePoisson13SampleOffsets[i].xy*Scale);

		if(V.a > 0)
		{
			OutputColor.rgb += V.rgb;
			OutputColor.a += 1.0;
		}
	}

	return OutputColor / OutputColor.a;
}

float4 GlowFilter_PS(VS2PS_5Tap Input, uniform float Weights[5], uniform bool Horizontal) : COLOR
{
	float4 OutputColor = Weights[0] * tex2D(SampleTex0_Clamp, Input.FilterCoords[0].xy);
	OutputColor += Weights[1] * tex2D(SampleTex0_Clamp, Input.FilterCoords[0].zw);
	OutputColor += Weights[2] * tex2D(SampleTex0_Clamp, Input.FilterCoords[1].xy);
	OutputColor += Weights[3] * tex2D(SampleTex0_Clamp, Input.FilterCoords[1].zw);
	OutputColor += Weights[4] * tex2D(SampleTex0_Clamp, Input.TexCoord0);
	return OutputColor;
}

float4 HighPassFilter_PS(VS2PS_Blit Input) : COLOR
{
	float4 OutputColor = tex2D(SampleTex0_Clamp, Input.TexCoord0);
	OutputColor -= _HighPassGate;
	return max(OutputColor, 0.0);
}

float4 HighPassFilterFade_PS(VS2PS_Blit Input) : COLOR
{
	float4 OutputColor = tex2D(SampleTex0_Clamp, Input.TexCoord0);
	OutputColor.rgb = saturate(OutputColor.rgb - _HighPassGate);
	OutputColor.a = _BlurStrength;
	return OutputColor;
}

float4 Clear_PS(VS2PS_Blit Input) : COLOR
{
	return 0.0;
}

float4 ExtractGlowFilter_PS(VS2PS_Blit Input) : COLOR
{
	float4 OutputColor = tex2D(SampleTex0_Clamp, Input.TexCoord0);
	OutputColor.rgb = OutputColor.a;
	OutputColor.a = 1.0;
	return OutputColor;
}

float4 ExtractHDRFilterFade_PS(VS2PS_Blit Input) : COLOR
{
	float4 OutputColor = tex2D(SampleTex0_Clamp, Input.TexCoord0);
	OutputColor.rgb = saturate(OutputColor.a - _HighPassGate);
	OutputColor.a = _BlurStrength;
	return OutputColor;
}

float4 LumaAndBrightPass_PS(VS2PS_Blit Input) : COLOR
{
	float4 OutputColor = tex2D(SampleTex0_Clamp, Input.TexCoord0) * _HighPassGate;
	// float luminance = dot(OutputColor, float3(0.299f, 0.587f, 0.114f));
	return OutputColor;
}

float4 BloomFilter_PS(VS2PS_5Tap Input, uniform bool Is_Blur) : COLOR
{
	float4 OutputColor = 0.0;
	OutputColor.a = (Is_Blur) ? _BlurStrength : OutputColor.a;

	OutputColor.rgb += tex2D(SampleTex0_Clamp, Input.TexCoord0.xy);

	for(int i = 0; i < 2; i++)
	{
		OutputColor.rgb += tex2D(SampleTex0_Clamp, Input.FilterCoords[i].xy);
		OutputColor.rgb += tex2D(SampleTex0_Clamp, Input.FilterCoords[i].zw);
	}

	OutputColor.rgb /= 5.0;
	return OutputColor;
}

float4 ScaleUpBloomFilter_PS(VS2PS_Blit Input) : COLOR
{
	float Offset = 0.01;
	// We can use a blur for this
	float4 Close = tex2D(SampleTex0_Clamp, Input.TexCoord0);
	return Close;
}

float4 Blur_PS(VS2PS_Blit Input) : COLOR
{
	return float4(tex2D(SampleTex0_Clamp, Input.TexCoord0).rgb, _BlurStrength);
}

//
//	Techniques
//

technique Blit
{
	pass PassThrough
	{
		ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		StencilEnable = FALSE;
		AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 Blit_VS();
		PixelShader = compile ps_3_0 Passthrough_PS();
	}

	pass Blend
	{
		ZEnable = FALSE;
		AlphaBlendEnable = TRUE;
		StencilEnable = FALSE;
		AlphaTestEnable = FALSE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		VertexShader = compile vs_3_0 Blit_VS();
		PixelShader = compile ps_3_0 Passthrough_PS();
	}

	pass PosTo8Bit
	{
		ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_3_0 Blit_VS();
		PixelShader = compile ps_3_0 PosTo8Bit_PS();
	}

	pass NormalTo8Bit
	{
		ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_3_0 Blit_VS();
		PixelShader = compile ps_3_0 NormalTo8Bit_PS();
	}

	pass ShadowMapFrontTo8Bit
	{
		ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_3_0 Blit_VS();
		PixelShader = compile ps_3_0 ShadowMapFrontTo8Bit_PS();
	}

	pass ShadowMapBackTo8Bit
	{
		ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_3_0 Blit_VS();
		PixelShader = compile ps_3_0 ShadowMapBackTo8Bit_PS();
	}

	pass ScaleUp4x4
	{
		ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_3_0 Blit_VS();
		PixelShader = compile ps_3_0 ScaleUp4x4_PS();
	}

	pass ScaleDown2x2
	{
		ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_3_0 Blit_VS();
		PixelShader = compile ps_3_0 ScaleDown2x2_PS();
	}

	pass ScaleDown4x4
	{
		ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_3_0 Blit_VS();
		PixelShader = compile ps_3_0 ScaleDown4x4_PS();
	}

	pass ScaleDown4x4Linear // pass 9, tinnitus
	{
		ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_3_0 ScaleDown4x4_VS();
		PixelShader = compile ps_3_0 ScaleDown4x4Linear_PS();
	}

	pass CheapGaussianBlur5x5
	{
		ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_3_0 Blit_VS();
		PixelShader = compile ps_3_0 CheapGaussianBlur5x5_PS();
	}

	pass GaussianBlur15x15H
	{
		ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_3_0 Blit_VS();
		PixelShader = compile ps_3_0 GaussianBlur15x15H_PS();
	}

	pass GaussianBlur15x15V
	{
		ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_3_0 Blit_VS();
		PixelShader = compile ps_3_0 GaussianBlur15x15V_PS();
	}

	pass Poisson13Blur
	{
		ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_3_0 Blit_VS();
		PixelShader = compile ps_3_0 Poisson13Blur_PS();
	}

	pass Poisson13AndDilation
	{
		ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_3_0 Blit_VS();
		PixelShader = compile ps_3_0 Poisson13AndDilation_PS();
	}

	pass ScaleUpBloomFilter
	{
		ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_3_0 Blit_VS();
		PixelShader = compile ps_3_0 ScaleUpBloomFilter_PS();
	}

	pass PassThroughSaturateAlpha
	{
		ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		StencilEnable = FALSE;
		AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 Blit_VS();
		PixelShader = compile ps_3_0 PassthroughSaturateAlpha_PS();
	}

	pass CopyRGBToAlpha
	{
		ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		StencilEnable = FALSE;
		AlphaTestEnable = FALSE;
		ColorWriteEnable = ALPHA;

		VertexShader = compile vs_3_0 Blit_VS();
		PixelShader = compile ps_3_0 CopyRGBToAlpha_PS();
	}

	// X-Pack additions
	pass PassThroughBilinear
	{
		ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		StencilEnable = FALSE;
		AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 Blit_VS();
		PixelShader = compile ps_3_0 TR_PassthroughBilinear_PS();
	}

	pass PassThroughBilinearAdditive
	{
		/*
			ZEnable = FALSE;
			AlphaBlendEnable = TRUE;
			SrcBlend = ONE;
			DestBlend = ONE;
			StencilEnable = FALSE;
			AlphaTestEnable = FALSE;
		*/

		// VertexShader = compile vs_3_0 Blit_VS();
		// PixelShader = compile ps_3_0 Passthrough_PS();

		/*
			ZEnable = FALSE;
			AlphaBlendEnable = FALSE;
			StencilEnable = FALSE;
			AlphaTestEnable = FALSE;
		*/

		ZEnable = FALSE;
		AlphaBlendEnable = TRUE;
		SrcBlend = ZERO;
		DestBlend = ONE;
		StencilEnable = FALSE;
		AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 Blit_VS();
		PixelShader = compile ps_3_0 TR_PassthroughBilinear_PS();
	}

	pass Blur
	{
		VertexShader = NULL;
		PixelShader = NULL;
	}

	pass ScaleUp4x4Additive
	{
		VertexShader = NULL;
		PixelShader = NULL;
	}

	pass CheapGaussianBlur5x5Blend
	{
		VertexShader = NULL;
		PixelShader = NULL;
	}

	pass CheapGaussianBlur5x5Additive
	{
		VertexShader = NULL;
		PixelShader = NULL;
	}

	pass ScaleUpBloomFilterAdditive
	{
		VertexShader = NULL;
		PixelShader = NULL;
	}

	pass GlowHorizontalFilter // pass 25
	{
		ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_3_0 Blit_VS();
		PixelShader = compile ps_3_0 TR_OpticsBlurH_PS();
	}

	pass GlowVerticalFilter // pass 26
	{
		ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_3_0 Blit_VS();
		PixelShader = compile ps_3_0 TR_OpticsBlurV_PS();
	}

	pass GlowVerticalFilterAdditive
	{
		VertexShader = NULL;
		PixelShader = NULL;
	}

	pass HighPassFilter
	{
		VertexShader = NULL;
		PixelShader = NULL;
	}

	pass HighPassFilterFade  // pass 29
	{
		ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_3_0 Blit_VS();
		PixelShader = compile ps_3_0 TR_PassthroughBilinear_PS();
	}

	pass ExtractGlowFilter
	{
		VertexShader = NULL;
		PixelShader = NULL;
	}

	pass ExtractHDRFilterFade
	{
		VertexShader = NULL;
		PixelShader = NULL;
	}

	pass ClearAlpha
	{
		ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		StencilEnable = FALSE;
		AlphaTestEnable = FALSE;
		ColorWriteEnable = ALPHA;

		VertexShader = compile vs_3_0 Blit_Magnified_PS(); // is this needed? -mosq
		PixelShader = compile ps_3_0 Clear_PS();
	}

	pass Additive
	{
		VertexShader = NULL;
		PixelShader = NULL;
	}

	pass AdditiveBilinear  // pass 34
	{
		ZEnable = FALSE;
		AlphaBlendEnable = TRUE;
		StencilEnable = FALSE;
		AlphaTestEnable = FALSE;
		BlendOp = ADD;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;
		VertexShader = compile vs_3_0 Blit_VS();
		PixelShader = compile ps_3_0 TR_OpticsMask_PS();
	}

	pass BloomHorizFilter // pass 35
	{
		ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_3_0 Blit_VS();
		PixelShader = compile ps_3_0 TR_PassthroughBilinear_PS();
	}

	pass BloomHorizFilterAdditive
	{
		VertexShader = NULL;
		PixelShader = NULL;
	}

	pass BloomVertFilter // pass 37
	{
		ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_3_0 Blit_VS();
		PixelShader = compile ps_3_0 TR_PassthroughBilinear_PS();
	}

	pass BloomVAdditive
	{
		VertexShader = NULL;
		PixelShader = NULL;
	}

	pass BloomVBlur
	{
		VertexShader = NULL;
		PixelShader = NULL;
	}

	pass BloomVAdditiveBlur
	{
		VertexShader = NULL;
		PixelShader = NULL;
	}

	pass LumaAndBrightPass
	{
		VertexShader = NULL;
		PixelShader = NULL;
	}

	pass ScaleDown4x4H // pass 42
	{
		ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_3_0 Blit_VS();
		PixelShader = compile ps_3_0 TR_PassthroughAnisotropy_PS();
	}

	pass ScaleDown4x4V // pass 43
	{
		ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_3_0 Blit_VS();
		PixelShader = compile ps_3_0 TR_PassthroughAnisotropy_PS();
	}

	pass Clear
	{
		ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_3_0 Blit_VS();
		PixelShader = compile ps_3_0 Clear_PS();
	}

	pass BlendCustom
	{
		ZEnable = FALSE;
		AlphaBlendEnable = TRUE;
		StencilEnable = FALSE;
		AlphaTestEnable = FALSE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		VertexShader = compile vs_3_0 Blit_Custom_VS();
		PixelShader = compile ps_3_0 Passthrough_PS();
	}

}

float4 StencilGather_PS(VS2PS_Blit Input) : COLOR
{
	return _dwordStencilRef / 255.0;
}

float4 StencilMap_PS(VS2PS_Blit Input) : COLOR
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

		VertexShader = compile vs_3_0 Blit_VS();
		PixelShader = compile ps_3_0 StencilGather_PS();
	}

	pass StencilMap
	{
		ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		AlphaTestEnable = FALSE;
		StencilEnable = FALSE;

		VertexShader = compile vs_3_0 Blit_VS();
		PixelShader = compile ps_3_0 StencilMap_PS();
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

		VertexShader = compile vs_3_0 Blit_VS();
		PixelShader = compile ps_3_0 Dummy_PS();
	}
}
