
/*
	Include header files
*/

#include "shaders/RealityGraphics.fxh"
#include "shaders/shared/RealityDirectXTK.fxh"
#include "shaders/shared/RealityFidelityFX.fxh"
#include "shaders/shared/RealityPixel.fxh"
#if !defined(_HEADERS_)
	#include "RealityGraphics.fxh"
	#include "shared/RealityDirectXTK.fxh"
	#include "shared/RealityFidelityFX.fxh"
	#include "shared/RealityPixel.fxh"
#endif

/*
	Description: Controls the following post-production shaders
		1. Tinnitus
		2. Glow
		3. Thermal vision
		4. Wave distortion
		5. Flashbang
	Note: Some TV shaders write to the same render target as optic shaders
*/

#define VIGNETTE_RADIUS 1.0
#define TINNITUS_BLUR_RADIUS 1.0
#define THERMAL_SIZE 720.0

/*
	[Attributes from app]
*/

float _BackBufferLerpBias : BACKBUFFERLERPBIAS;
float2 _SampleOffset : SAMPLEOFFSET;
float2 _FogStartAndEnd : FOGSTARTANDEND;
float3 _FogColor : FOGCOLOR;
float _GlowStrength : GLOWSTRENGTH;

float _NightFilter_Noise_Strength : NIGHTFILTER_NOISE_STRENGTH;
float _NightFilter_Noise : NIGHTFILTER_NOISE;
float _NightFilter_Blur : NIGHTFILTER_BLUR;
float _NightFilter_Mono : NIGHTFILTER_MONO;

float2 _Displacement : DISPLACEMENT; // Random <x, y> jitter

float _NPixels : NPIXLES = 1.0;
float2 _ScreenSize : VIEWPORTSIZE = { 800, 600 };
float _Glowness : GLOWNESS = 3.0;
float _Cutoff : cutoff = 0.8;

// One pixel in screen texture units
float _DeltaU : DELTAU;
float _DeltaV : DELTAV;

/*
	[Textures and samplers]
*/

#define CREATE_SAMPLER(SAMPLER_NAME, TEXTURE, FILTER, ADDRESS) \
	sampler SAMPLER_NAME = sampler_state \
	{ \
		Texture = (TEXTURE); \
		MinFilter = FILTER; \
		MagFilter = FILTER; \
		MipFilter = FILTER; \
		AddressU = ADDRESS; \
		AddressV = ADDRESS; \
	}; \

// Unused?
texture Texture4 : TEXLAYER4;
texture Texture5 : TEXLAYER5;
texture Texture6 : TEXLAYER6;

texture Tex0 : TEXLAYER0;
CREATE_SAMPLER(SampleTex0, Tex0, LINEAR, CLAMP)
CREATE_SAMPLER(SampleTex0_Point, Tex0, POINT, CLAMP)
CREATE_SAMPLER(SampleTex0_Mirror, Tex0, LINEAR, MIRROR)

texture Tex1 : TEXLAYER1;
CREATE_SAMPLER(SampleTex1, Tex1, LINEAR, CLAMP)
CREATE_SAMPLER(SampleTex1_Wrap, Tex1, LINEAR, WRAP)

texture Tex2 : TEXLAYER2;
CREATE_SAMPLER(SampleTex2, Tex2, LINEAR, CLAMP)
CREATE_SAMPLER(SampleTex2_Wrap, Tex2, LINEAR, WRAP)

texture Tex3 : TEXLAYER3;
CREATE_SAMPLER(SampleTex3, Tex3, LINEAR, CLAMP)

/*
	Transform fullscreen quad into a fullscreen triangle with its texcoords
	NOTE: We transform the texture in PS
*/

struct FSTriangle
{
	float2 Tex;
	float2 Pos;
};

void GetFSTriangle(in float2 Tex, out FSTriangle Output)
{
	Output.Tex = float2(int2(Tex * 2.0));
	Output.Pos = (Output.Tex * float2(2.0, -2.0)) + float2(-1.0, 1.0);
}

struct APP2VS_Quad
{
	float2 Pos : POSITION0;
	float2 Tex0 : TEXCOORD0;
};

struct VS2PS_Quad
{
	float4 HPos : POSITION;
	float2 Tex0 : TEXCOORD0;
};

VS2PS_Quad VS_Quad(APP2VS_Quad Input)
{
	VS2PS_Quad Output = (VS2PS_Quad)0.0;
	Output.HPos = float4(Input.Pos.xy, 0.0, 1.0);
	Output.Tex0 = Input.Tex0;
	return Output;
}

float4 GetTex(float2 Tex, float4 Offset)
{
	return (Tex.xyyy * float4(1.0, 1.0, 0.0, 0.0)) + Offset;
}

/*
	Tinnitus using Ronja Böhringer's signed distance fields
*/

VS2PS_Quad VS_Tinnitus(APP2VS_Quad Input)
{
	VS2PS_Quad Output = (VS2PS_Quad)0.0;
	FSTriangle FST;
	GetFSTriangle(Input.Tex0, FST);
	Output.HPos = float4(FST.Pos, 0.0, 1.0);
	Output.Tex0 = FST.Tex;
	return Output;
}

float4 PS_Tinnitus(VS2PS_Quad Input) : COLOR0
{
	// Modify uniform data
	float SatLerpBias = saturate(_BackBufferLerpBias);
	float LerpBias = saturate(smoothstep(0.0, 0.5, SatLerpBias));

	// Create tex for use in vignette effects
	float2 VignetteTex = Input.Tex0 - 0.5;

	// Spread the blur as you go lower on the screen
	float3 SpreadFactor = 1.0;
	FFX_Lens_ApplyVignette(VignetteTex * 2.0, float2(0.0, 1.0), SpreadFactor, LerpBias);

	SpreadFactor = 1.0 - saturate(SpreadFactor);
	SpreadFactor *= TINNITUS_BLUR_RADIUS;
	float4 BlurColor = GetSpiralBlur(SampleTex0_Mirror, Input.Tex0, SpreadFactor.r, true);

	// Vignette BlurColor
	float VignetteRadius = min(VIGNETTE_RADIUS, 2.0) * LerpBias;
	FFX_Lens_ApplyVignette(VignetteTex * float2(2.0, 1.0), float2(0.0, 0.5), BlurColor.rgb, VignetteRadius);

	return float4(BlurColor.rgb, LerpBias);
}

technique Tinnitus
{
	pass p0
	{
		ZEnable = FALSE;
		StencilEnable = FALSE;

		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		VertexShader = compile vs_3_0 VS_Tinnitus();
		PixelShader = compile ps_3_0 PS_Tinnitus();
	}
}

/*
	Glow shaders
*/

float4 PS_Glow(VS2PS_Quad Input) : COLOR0
{
	return tex2D(SampleTex0, Input.Tex0);
}

float4 PS_Glow_Material(VS2PS_Quad Input) : COLOR0
{
	float4 Diffuse = tex2D(SampleTex0, Input.Tex0);
	// return (1.0 - Diffuse.a);
	// temporary test, should be removed
	return _GlowStrength * /* Diffuse + */ float4(Diffuse.rgb * (1.0 - Diffuse.a), 1.0);
}

technique Glow
{
	pass p0
	{
		ZEnable = FALSE;

		AlphaBlendEnable = TRUE;
		SrcBlend = SRCCOLOR;
		DestBlend = ONE;

		VertexShader = compile vs_3_0 VS_Quad();
		PixelShader = compile ps_3_0 PS_Glow();
	}
}

technique GlowMaterial
{
	pass p0
	{
		ZEnable = FALSE;

		StencilEnable = TRUE;
		StencilFunc = NOTEQUAL;
		StencilRef = 0x80;
		StencilMask = 0xFF;
		StencilFail = KEEP;
		StencilZFail = KEEP;
		StencilPass = KEEP;

		AlphaBlendEnable = FALSE;
		SrcBlend = SRCCOLOR;
		DestBlend = ONE;

		VertexShader = compile vs_3_0 VS_Quad();
		PixelShader = compile ps_3_0 PS_Glow_Material();
	}
}

/* TVEffect specific attributes */
float _FracTime : FRACTIME;
float _FracTime256 : FRACTIME256;
float _SinFracTime : FRACSINE;

float _Interference : INTERFERENCE; // = 0.050000 || -0.015;
float _DistortionRoll : DISTORTIONROLL; // = 0.100000;
float _DistortionScale : DISTORTIONSCALE; // = 0.500000 || 0.2;
float _DistortionFreq : DISTORTIONFREQ; //= 0.500000;
float _Granularity : TVGRANULARITY; // = 3.5;
float _TVAmbient : TVAMBIENT; // = 0.15
float3 _TVColor : TVCOLOR;
/* TVEffect specific attributes */

struct TV
{
	float2 Random;
	float2 Noise;
};

TV GetTV(float2 Tex)
{
	TV Output;
	Tex = (Tex * 2.0) - 1.0;
	Output.Random = (Tex * _Granularity) + _Displacement;
	Output.Noise = (Tex * 0.25) - (0.35 * _SinFracTime);
	return Output;
}

VS2PS_Quad VS_ThermalVision(APP2VS_Quad Input)
{
	VS2PS_Quad Output = (VS2PS_Quad)0.0;
	if (_Interference < 0) // Use fullscreen triangle for thermals
	{
		FSTriangle FST;
		GetFSTriangle(Input.Tex0.xy, FST);
		Output.HPos = float4(FST.Pos, 0.0, 1.0);
		Output.Tex0 = FST.Tex;
	}
	else // Use default fullscreen quad for passthrough
	{
		Output.HPos = float4(Input.Pos.xy, 0.0, 1.0);
		Output.Tex0 = Input.Tex0.xy;
	}
	return Output;
}

float2 GetPixelation(float2 Tex)
{
	return floor(Tex * THERMAL_SIZE) / THERMAL_SIZE;
}

float4 PS_ThermalVision(VS2PS_Quad Input) : COLOR0
{
	float4 OutputColor = 0.0;

	// Get texture data
	float2 ImageTex = Input.Tex0;
	TV Tex = GetTV(Input.Tex0);

	// Fetch textures
	float4 Color = tex2D(SampleTex0, ImageTex);
	float Random = tex2D(SampleTex2_Wrap, Tex.Random) - 0.2;
	float Noise = tex2D(SampleTex1_Wrap, Tex.Random) - 0.5;

	if (_Interference < 0) // Thermals
	{
		// Calculate thermal image
		float4 Image = SRGBToLinearEst(tex2Dlod(SampleTex0_Point, float4(GetPixelation(Input.Tex0), 0.0, 0.0)));

		// OutputColor.r = lerp(lerp(lerp(0.43, 0.17, Image.g), lerp(0.75, 0.50, Image.b), Image.b), Image.r, Image.r); // M
		OutputColor.r = lerp(0.43, 0.0, Image.g) + Image.r; // Terrain max light mod should be 0.608
		OutputColor.r = saturate(OutputColor.r - (_Interference * Random)); // Add -_Interference
		OutputColor = float4(QuantizeRGB(_TVColor * OutputColor.r, 32.0), Image.a);

		LinearToSRGBEst(OutputColor);
	}
	else if (_Interference > 0 && _Interference <= 1) // BF2 TV
	{
		Color = SRGBToLinearEst(Color);
		float Gray = Desaturate(Color.rgb);

		// Distort texture coordinates
		float Distort = frac(Tex.Random.y * _DistortionFreq + _DistortionRoll * _SinFracTime);
		Distort *= (1.0 - Distort);
		Distort /= 1.0 + _DistortionScale * abs(Tex.Random.y);
		ImageTex.x += _DistortionScale * Noise * Distort;

		// Fetch image
		float TVFactor = lerp(Gray, 1.0, _TVAmbient) + (_Interference * Random);
		OutputColor = float4(QuantizeRGB(_TVColor, 32.0), 1.0) * TVFactor;

		LinearToSRGBEst(OutputColor);
	}
	else // Passthrough
	{
		OutputColor = Color;
	}

	return OutputColor;
}

technique TVEffect
{
	pass p0
	{
		ZEnable = FALSE;
		StencilEnable = FALSE;
		AlphaBlendEnable = FALSE;

		VertexShader = compile vs_3_0 VS_Quad();
		PixelShader = compile ps_3_0 PS_ThermalVision();
	}
}

/*
	TV Effect with usage of gradient texture
*/

float4 PS_ThermalVision_Gradient(VS2PS_Quad Input) : COLOR0
{
	float4 OutputColor = 0.0;

	if (_Interference >= 0 && _Interference <= 1)
	{
		// Get texture data
		float2 ImageTex = Input.Tex0;
		TV Tex = GetTV(ImageTex);

		// Fetch textures
		float Random = tex2D(SampleTex2_Wrap, Tex.Random) - 0.2;
		float Noise = tex2D(SampleTex1_Wrap, Tex.Noise) - 0.5;

		// Distort texture coordinates
		float Distort = frac(Tex.Random.y * _DistortionFreq + _DistortionRoll * _SinFracTime);
		Distort *= (1.0 - Distort);
		Distort /= 1.0 + _DistortionScale * abs(Tex.Random.y);
		ImageTex.x += _DistortionScale * Noise * Distort;

		// Fetch image
		float4 Color = SRGBToLinearEst(tex2D(SampleTex0, ImageTex));
		float Gray = Desaturate(Color.rgb);

		float TVFactor = lerp(Gray, 1.0, _TVAmbient) + (_Interference * Random);
		float4 GradientColor = tex2D(SampleTex3, float2(TVFactor, 0.0));
		OutputColor = float4(QuantizeRGB(GradientColor.rgb, 32.0), TVFactor);
		LinearToSRGBEst(OutputColor);
	}
	else
	{
		OutputColor = tex2D(SampleTex0, Input.Tex0);
	}

	return OutputColor;
}

technique TVEffect_Gradient_Tex
{
	pass p0
	{
		ZEnable = FALSE;
		StencilEnable = FALSE;
		AlphaBlendEnable = FALSE;

		VertexShader = compile vs_3_0 VS_Quad();
		PixelShader = compile ps_3_0 PS_ThermalVision_Gradient();
	}
}

/*
	Wave Distortion Shader
*/

struct VS2PS_Distortion
{
	float4 HPos : POSITION;
	float2 Tex0 : TEXCOORD0;
};

VS2PS_Distortion VS_WaveDistortion(APP2VS_Quad Input)
{
	VS2PS_Distortion Output = (VS2PS_Distortion)0.0;
	Output.HPos = float4(Input.Pos.xy, 0.0, 1.0);
	Output.Tex0 = Input.Tex0.xy;
	return Output;
}

float4 PS_WaveDistortion(VS2PS_Distortion Input) : COLOR0
{
	return 0.0;
}

technique WaveDistortion
{
	pass p0
	{
		ZEnable = FALSE;
		AlphaTestEnable = FALSE;
		StencilEnable = FALSE;

		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		SRGBWriteEnable = FALSE;

		VertexShader = compile vs_3_0 VS_WaveDistortion();
		PixelShader = compile ps_3_0 PS_WaveDistortion();
	}
}

/*
	Flashbang frame-blending shader

	Assumption:
	1. sampler 0, 1, 2, and 3 are based on history textures
	2. The shader spatially blends these history buffers in the pixel shader, and temporally blend through blend operation

	TODO: See what the core issue is with this.
	Theory is that the texture getting temporally blended or sampled has been rewritten before the blendop
*/

float4 PS_Flashbang(VS2PS_Quad Input) : COLOR0
{
	float4 Sample0 = SRGBToLinearEst(tex2D(SampleTex0, Input.Tex0));
	float4 Sample1 = SRGBToLinearEst(tex2D(SampleTex1, Input.Tex0));
	float4 Sample2 = SRGBToLinearEst(tex2D(SampleTex2, Input.Tex0));
	float4 Sample3 = SRGBToLinearEst(tex2D(SampleTex3, Input.Tex0));

	float4 OutputColor = Sample0 * 0.5;
	OutputColor += Sample1 * 0.25;
	OutputColor += Sample2 * 0.15;
	OutputColor += Sample3 * 0.10;

	LinearToSRGBEst(OutputColor);
	return float4(OutputColor.rgb, _BackBufferLerpBias);
}

technique Flashbang
{
	pass p0
	{
		ZEnable = FALSE;
		StencilEnable = FALSE;

		AlphaBlendEnable = TRUE;
		BlendOp = ADD;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		VertexShader = compile vs_3_0 VS_Quad();
		PixelShader = compile ps_3_0 PS_Flashbang();
	}
}
