
/*
	Include header files
*/

#include "shaders/RealityGraphics.fxh"
#include "shaders/shared/RealityPixel.fxh"
#if !defined(INCLUDED_HEADERS)
	#include "RealityGraphics.fxh"
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

#define BLUR_RADIUS 1.0
#define THERMAL_SIZE 500

/*
	[Attributes from app]
*/

uniform float _BackBufferLerpBias : BACKBUFFERLERPBIAS;
uniform float2 _SampleOffset : SAMPLEOFFSET;
uniform float2 _FogStartAndEnd : FOGSTARTANDEND;
uniform float3 _FogColor : FOGCOLOR;
uniform float _GlowStrength : GLOWSTRENGTH;

uniform float _NightFilter_Noise_Strength : NIGHTFILTER_NOISE_STRENGTH;
uniform float _NightFilter_Noise : NIGHTFILTER_NOISE;
uniform float _NightFilter_Blur : NIGHTFILTER_BLUR;
uniform float _NightFilter_Mono : NIGHTFILTER_MONO;

uniform float2 _Displacement : DISPLACEMENT; // Random <x, y> jitter

float _NPixels : NPIXLES = 1.0;
float2 _ScreenSize : VIEWPORTSIZE = { 800, 600 };
float _Glowness : GLOWNESS = 3.0;
float _Cutoff : cutoff = 0.8;

// One pixel in screen texture units
uniform float _DeltaU : DELTAU;
uniform float _DeltaV : DELTAV;

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

/*
	Unused?
	uniform texture Texture4 : TEXLAYER4;
	uniform texture Texture5 : TEXLAYER5;
	uniform texture Texture6 : TEXLAYER6;
*/

uniform texture Tex0 : TEXLAYER0;
CREATE_SAMPLER(SampleTex0, Tex0, LINEAR, CLAMP)
CREATE_SAMPLER(SampleTex0_Point, Tex0, POINT, CLAMP)
CREATE_SAMPLER(SampleTex0_Mirror, Tex0, LINEAR, MIRROR)

uniform texture Tex1 : TEXLAYER1;
CREATE_SAMPLER(SampleTex1, Tex1, LINEAR, CLAMP)
CREATE_SAMPLER(SampleTex1_Wrap, Tex1, LINEAR, WRAP)

uniform texture Tex2 : TEXLAYER2;
CREATE_SAMPLER(SampleTex2, Tex2, LINEAR, CLAMP)
CREATE_SAMPLER(SampleTex2_Wrap, Tex2, LINEAR, WRAP)

uniform texture Tex3 : TEXLAYER3;
CREATE_SAMPLER(SampleTex3, Tex3, LINEAR, CLAMP)

struct APP2VS_Quad
{
	float2 Pos : POSITION0;
	float2 Tex0 : TEXCOORD0;
};

/*
	Custom datatypes and their respective constructors
*/

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
	Output.Tex = trunc(Tex * 2.0);
	Output.Pos = (Output.Tex * float2(2.0, -2.0)) + float2(-1.0, 1.0);
}

struct VS2PS_Quad
{
	float4 HPos : POSITION;
	float2 Tex0 : TEXCOORD0;
};

VS2PS_Quad VS_Quad(APP2VS_Quad Input)
{
	VS2PS_Quad Output;
	Output.HPos = float4(Input.Pos, 0.0, 1.0);
	Output.Tex0 = Input.Tex0;
	return Output;
}

struct ScreenSpace
{
	float2 Pos;
	float2 Tex;
	float2 Size;
};

struct VS2PS_PP
{
	float4 Pos : VPOS;
	float2 Tex0 : TEXCOORD0;
};

ScreenSpace GetScreenSpace(VS2PS_PP Input)
{
	ScreenSpace Output;
	Output.Pos = Input.Pos.xy;
	Output.Tex = Input.Tex0;
	Output.Size = GetScreenSize(Input.Tex0);
	return Output;
}

/*
	Main shaders
*/

/*
	Tinnitus using Ronja Böhringer's signed distance fields
	---
	https://github.com/ronja-tutorials/ShaderTutorials
*/

VS2PS_Quad VS_Tinnitus(APP2VS_Quad Input)
{
	VS2PS_Quad Output;
	FSTriangle FST;
	GetFSTriangle(Input.Tex0, FST);
	Output.HPos = float4(FST.Pos, 0.0, 1.0);
	Output.Tex0 = FST.Tex;
	return Output;
}

float4 PS_Tinnitus(VS2PS_PP Input) : COLOR
{
	ScreenSpace SS = GetScreenSpace(Input);

	// Get texture data
	float LerpBias = saturate(smoothstep(0.0, 0.5, _BackBufferLerpBias));

	// Spread the blur as you go lower on the screen
	float SpreadFactor = saturate(1.0 - (Input.Tex0.y * Input.Tex0.y));
	SpreadFactor *= BLUR_RADIUS;
	SpreadFactor *= LerpBias;
	float4 Color = GetSpiralBlur(SampleTex0_Mirror, SS.Pos, SS.Tex, SpreadFactor);

	// Get SDF mask that darkens the left, right, and top edges
	float2 Tex = (SS.Tex * float2(2.0, 1.0)) - 1.0;
	Tex *= LerpBias; // gradually remove mask overtime
	float2 Edge = max(abs(Tex) - (1.0 / 5.0), 0.0);
	float Mask = saturate(length(Edge));

	// Composite final product
	float4 OutputColor = lerp(Color, float4(0.0, 0.0, 0.0, 1.0), Mask);
	return float4(OutputColor.rgb, LerpBias);
}

technique Tinnitus
{
	pass Pass0
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

float4 PS_Glow(VS2PS_PP Input) : COLOR
{
	ScreenSpace SS = GetScreenSpace(Input);

	return tex2D(SampleTex0, SS.Tex);
}

float4 PS_Glow_Material(VS2PS_PP Input) : COLOR
{
	ScreenSpace SS = GetScreenSpace(Input);

	float4 Diffuse = tex2D(SampleTex0, SS.Tex);
	// return (1.0 - Diffuse.a);
	// temporary test, should be removed
	return _GlowStrength * /* Diffuse + */ float4(Diffuse.rgb * (1.0 - Diffuse.a), 1.0);
}

technique Glow
{
	pass Pass0
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
	pass Pass0
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

// TVEffect specific attributes
uniform float _FracTime : FRACTIME;
uniform float _FracTime256 : FRACTIME256;
uniform float _SinFracTime : FRACSINE;

uniform float _Interference : INTERFERENCE; // = 0.050000 || -0.015;
uniform float _DistortionRoll : DISTORTIONROLL; // = 0.100000;
uniform float _DistortionScale : DISTORTIONSCALE; // = 0.500000 || 0.2;
uniform float _DistortionFreq : DISTORTIONFREQ; //= 0.500000;
uniform float _Granularity : TVGRANULARITY; // = 3.5;
uniform float _TVAmbient : TVAMBIENT; // = 0.15
uniform float3 _TVColor : TVCOLOR;

VS2PS_Quad VS_ThermalVision(APP2VS_Quad Input)
{
	VS2PS_Quad Output;
	if (_Interference < 0) // Use fullscreen triangle for thermals
	{
		FSTriangle FST;
		GetFSTriangle(Input.Tex0, FST);
		Output.HPos = float4(FST.Pos, 0.0, 1.0);
		Output.Tex0 = FST.Tex;
	}
	else // Use default fullscreen quad for passthrough
	{
		Output.HPos = float4(Input.Pos, 0.0, 1.0);
		Output.Tex0 = Input.Tex0;
	}
	return Output;
}

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

float2 GetPixelation(float2 Tex)
{
	return round(Tex * THERMAL_SIZE) / THERMAL_SIZE;
}

float4 PS_ThermalVision(VS2PS_PP Input) : COLOR
{
	ScreenSpace SS = GetScreenSpace(Input);

	float4 OutputColor = 0.0;

	// Get texture data
	float2 ImageTex = Input.Tex0;
	TV Tex = GetTV(Input.Tex0);

	// Fetch number textures
	float Random = tex2D(SampleTex2_Wrap, Tex.Random) - 0.2;
	float Noise = tex2D(SampleTex1_Wrap, Tex.Random) - 0.5;

	if (_Interference < 0) // Thermals
	{
		float4 Image = tex2Dlod(SampleTex0_Point, float4(GetPixelation(Input.Tex0), 0.0, 0.0));
		// OutputColor.r = lerp(lerp(lerp(0.43, 0.17, Image.g), lerp(0.75, 0.50, Image.b), Image.b), Image.r, Image.r); // M
		OutputColor.r = lerp(0.43, 0.0, Image.g) + Image.r; // Terrain max light mod should be 0.608
		OutputColor.r -= _Interference * Random; // Add -_Interference
		OutputColor = float4(_TVColor * OutputColor.rrr, Image.a);
	}
	else if (_Interference > 0 && _Interference <= 1) // BF2 TV
	{
		// Distort texture coordinates
		float Distort = frac(Tex.Random.y * _DistortionFreq + _DistortionRoll * _SinFracTime);
		Distort *= (1.0 - Distort);
		Distort /= 1.0 + _DistortionScale * abs(Tex.Random.y);
		ImageTex.x += _DistortionScale * Noise * Distort;

		// Fetch image
		float4 Image = tex2D(SampleTex0, ImageTex);
		Image = dot(Image.rgb, float3(0.3, 0.59, 0.11));
		OutputColor = float4(_TVColor, 1.0) * (_Interference * Random + Image * (1.0 - _TVAmbient) + _TVAmbient);
	}
	else // Passthrough
	{
		OutputColor = tex2D(SampleTex0_Point, ImageTex);
	}

	return OutputColor;
}

technique TVEffect
{
	pass Pass0
	{
		ZEnable = FALSE;
		StencilEnable = FALSE;
		AlphaBlendEnable = FALSE;

		VertexShader = compile vs_3_0 VS_ThermalVision();
		PixelShader = compile ps_3_0 PS_ThermalVision();
	}
}

/*
	TV Effect with usage of gradient texture
*/

float4 PS_GradientThermalVision(VS2PS_PP Input) : COLOR
{
	float4 OutputColor = 0.0;

	// Get texture data
	float2 ImageTex = Input.Tex0;
	TV Tex = GetTV(ImageTex);

	// Fetch number textures
	float Random = tex2D(SampleTex2_Wrap, Tex.Random) - 0.2;
	float Noise = tex2D(SampleTex1_Wrap, Tex.Noise) - 0.5;

	if (_Interference > 0 && _Interference <= 1)
	{
		// Distort texture coordinates
		float Distort = frac(Tex.Random.y * _DistortionFreq + _DistortionRoll * _SinFracTime);
		Distort *= (1.0 - Distort);
		Distort /= 1.0 + _DistortionScale * abs(Tex.Random.y);
		ImageTex.x += _DistortionScale * Noise * Distort;

		// Fetch image
		float4 Image = tex2D(SampleTex0, ImageTex);
		Image = dot(Image.rgb, float3(0.3, 0.59, 0.11));

		float4 Intensity = (_Interference * Random + Image * (1.0 - _TVAmbient) + _TVAmbient);
		float4 GradientColor = tex2D(SampleTex3, float2(Intensity.r, 0.0));
		OutputColor = float4(GradientColor.rgb, Intensity.a);
	}
	else // Passthrough
	{
		OutputColor = tex2D(SampleTex0_Point, ImageTex);
	}

	return OutputColor;
}

technique TVEffect_Gradient_Tex
{
	pass Pass0
	{
		ZEnable = FALSE;
		StencilEnable = FALSE;
		AlphaBlendEnable = FALSE;

		VertexShader = compile vs_3_0 VS_Quad();
		PixelShader = compile ps_3_0 PS_GradientThermalVision();
	}
}

/*
	Wave Distortion Shader
*/

struct VS2PS_Distortion
{
	float4 HPos : POSITION;
	float2 Tex0 : TEXCOORD0;
	float2 Tex1 : TEXCOORD1;
};

VS2PS_Distortion VS_WaveDistortion(APP2VS_Quad Input)
{
	VS2PS_Distortion Output;
	Output.HPos = float4(Input.Pos.xy, 0.0, 1.0);
	Output.Tex0 = Input.Tex0;
	Output.Tex1 = Input.Pos.xy;
	return Output;
}

float4 PS_WaveDistortion(VS2PS_Distortion Input) : COLOR
{
	return 0.0;
}

technique WaveDistortion
{
	pass Pass0
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

float4 PS_Flashbang(VS2PS_PP Input) : COLOR
{
	float4 Sample0 = tex2D(SampleTex0, Input.Tex0);
	float4 Sample1 = tex2D(SampleTex1, Input.Tex0);
	float4 Sample2 = tex2D(SampleTex2, Input.Tex0);
	float4 Sample3 = tex2D(SampleTex3, Input.Tex0);

	float4 OutputColor = Sample0 * 0.5;
	OutputColor += Sample1 * 0.25;
	OutputColor += Sample2 * 0.15;
	OutputColor += Sample3 * 0.10;
	return float4(OutputColor.rgb, _BackBufferLerpBias);
}

technique Flashbang
{
	pass Pass0
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
