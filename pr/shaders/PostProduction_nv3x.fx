#include "shaders/RealityGraphics.fxh"

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

#define CREATE_SAMPLER(SAMPLER_NAME, TEXTURE, ADDRESS) \
	sampler SAMPLER_NAME = sampler_state \
	{ \
		Texture = (TEXTURE); \
		MinFilter = LINEAR; \
		MagFilter = LINEAR; \
		MipFilter = LINEAR; \
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
CREATE_SAMPLER(SampleTex0, Tex0, CLAMP)
CREATE_SAMPLER(SampleTex0_Mirror, Tex0, MIRROR)

uniform texture Tex1 : TEXLAYER1;
CREATE_SAMPLER(SampleTex1, Tex1, CLAMP)
CREATE_SAMPLER(SampleTex1_Wrap, Tex1, WRAP)

uniform texture Tex2 : TEXLAYER2;
CREATE_SAMPLER(SampleTex2, Tex2, CLAMP)
CREATE_SAMPLER(SampleTex2_Wrap, Tex2, WRAP)

uniform texture Tex3 : TEXLAYER3;
CREATE_SAMPLER(SampleTex3, Tex3, CLAMP)

struct APP2VS_Quad
{
	float2 Pos : POSITION0;
	float2 TexCoord0 : TEXCOORD0;
};

struct VS2PS_Quad
{
	float4 HPos : POSITION;
	float2 TexCoord0 : TEXCOORD0;
};

struct VS2PS_ThermalVision
{
	float4 HPos : POSITION;
	float2 TexCoord0 : TEXCOORD0;
	float2 TexCoord1 : TEXCOORD1;
	float2 TexCoord2 : TEXCOORD2;
};

VS2PS_Quad VS_Basic(APP2VS_Quad Input)
{
	VS2PS_Quad Output;
	Output.HPos = float4(Input.Pos.xy, 0.0, 1.0);
	Output.TexCoord0 = Input.TexCoord0;
	return Output;
}

float4 GetBlur(sampler Source, float2 Tex, float2 Pos, float SpreadFactor)
{
	float4 OutputColor = 0.0;
	float4 Weight = 0.0;

	const float Pi2 = acos(-1.0) * 2.0;
	float Noise = Pi2 * GetGradientNoise(Pos.xy);

	float2 Rotation = 0.0;
	sincos(Noise, Rotation.y, Rotation.x);
	float2x2 RotationMatrix = float2x2(Rotation.x, Rotation.y, -Rotation.y, Rotation.x);

	[unroll] for(int i = 1; i < 4; ++i)
	{
		[unroll] for(int j = 0; j < 4 * i; ++j)
		{
			const float Shift = (Pi2 / (4.0 * float(i))) * float(j);
			float2 AngleShift = 0.0;
			sincos(Shift, AngleShift.x, AngleShift.y);
			AngleShift *= float(i);

			float2 Offset = mul((AngleShift * SpreadFactor) * BLUR_RADIUS, RotationMatrix);
			OutputColor += tex2D(Source, Tex + (Offset * 0.01));
			Weight++;
		}
	}

	return OutputColor / Weight;
}

/*
	Tinnitus using Ronja Böhringer's signed distance fields
	---
	Changes:
		- Scaled the edge math to output [-1, 1] range instead of [-0.5, 0.5]
		- Used squared Euclidean distance
	---
	https://github.com/ronja-tutorials/ShaderTutorials
*/

float4 PS_Tinnitus(VS2PS_Quad Input, float2 ScreenPos : VPOS) : COLOR
{
	// Get texture coordinates
	float2 Tex1 = Input.TexCoord0;

	// Spread the blur as you go lower on the screen
	float SpreadFactor = saturate((Tex1.y * Tex1.y) * 4.0);
	float4 Color = GetBlur(SampleTex0_Mirror, Input.TexCoord0, ScreenPos, SpreadFactor);

	// Get SDF mask that darkens the left, right, and bottom edges
	float2 Tex2 = float2((Tex1.x * 2.0) - 1.0, Tex1.y);
	float2 Edge = max((abs(Tex2) * 2.0) - 1.0, 0.0);
	float Mask = saturate(dot(Edge, Edge));

	// Composite final product
	float4 OutputColor = lerp(Color, float4(0.0, 0.0, 0.0, 1.0), Mask);
	return float4(OutputColor.rgb, saturate(2.0 * _BackBufferLerpBias));
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

		VertexShader = compile vs_3_0 VS_Basic();
		PixelShader = compile ps_3_0 PS_Tinnitus();
	}
}

/*
	Glow shaders
*/

float4 PS_Glow(VS2PS_Quad Input) : COLOR
{
	return tex2D(SampleTex0, Input.TexCoord0);
}

float4 PS_Glow_Material(VS2PS_Quad Input) : COLOR
{
	float4 Diffuse = tex2D(SampleTex0, Input.TexCoord0);
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

		VertexShader = compile vs_3_0 VS_Basic();
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

		VertexShader = compile vs_3_0 VS_Basic();
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

VS2PS_ThermalVision VS_ThermalVision(APP2VS_Quad Input)
{
	VS2PS_ThermalVision Output;
	Input.Pos.xy = sign(Input.Pos.xy);
	Output.HPos = float4(Input.Pos.xy, 0, 1);
	Output.TexCoord0 = Input.Pos.xy * _Granularity + _Displacement; // Outputs random jitter movement at [-x, x] range
	Output.TexCoord1 = Input.Pos.xy * 0.25 - 0.35 * _SinFracTime;
	Output.TexCoord2 = Input.TexCoord0;
	return Output;
}

float4 PS_ThermalVision(VS2PS_ThermalVision Input) : COLOR
{
	float4 OutputColor = 0.0;
	float2 ImgCoord = Input.TexCoord2;
	float4 Image = tex2D(SampleTex0, ImgCoord);

	if (_Interference < 0) // Thermals
	{
		float2 Pos = Input.TexCoord0;
		float Random = tex2D(SampleTex2_Wrap, Pos) - 0.2;
		float HOffset = 0.001;
		float VOffset = 0.0015;
		Image *= 0.25;
		Image += tex2D(SampleTex0, ImgCoord + float2( HOffset, VOffset)) * 0.0625;
		Image += tex2D(SampleTex0, ImgCoord - float2( HOffset, VOffset)) * 0.0625;
		Image += tex2D(SampleTex0, ImgCoord + float2(-HOffset, VOffset)) * 0.0625;
		Image += tex2D(SampleTex0, ImgCoord + float2( HOffset, -VOffset)) * 0.0625;
		Image += tex2D(SampleTex0, ImgCoord + float2( HOffset, 0.0)) * 0.125;
		Image += tex2D(SampleTex0, ImgCoord - float2( HOffset, 0.0)) * 0.125;
		Image += tex2D(SampleTex0, ImgCoord + float2( 0.0, VOffset)) * 0.125;
		Image += tex2D(SampleTex0, ImgCoord - float2( 0.0, VOffset)) * 0.125;
		// OutputColor.r = lerp(lerp(lerp(0.43, 0.17, Image.g), lerp(0.75, 0.50, Image.b), Image.b), Image.r, Image.r); // M
		OutputColor.r = lerp(0.43, 0.0, Image.g) + Image.r; // Terrain max light mod should be 0.608
		OutputColor.r -= _Interference * Random; // Add -_Interference
		OutputColor = float4(_TVColor * OutputColor.rrr, Image.a);
	}
	else if (_Interference > 0 && _Interference <= 1) // BF2 TV
	{
		float2 Pos = Input.TexCoord0;
		float Random = tex2D(SampleTex2_Wrap, Pos) - 0.2;
		float Noise = tex2D(SampleTex1_Wrap, Input.TexCoord1) - 0.5;
		float Distort = frac(Pos.y * _DistortionFreq + _DistortionRoll * _SinFracTime);
		Distort *= (1.0 - Distort);
		Distort /= 1.0 + _DistortionScale * abs(Pos.y);
		ImgCoord.x += _DistortionScale * Noise * Distort;
		Image = dot(float3(0.3, 0.59, 0.11), Image.rgb);
		OutputColor = float4(_TVColor, 1.0) * (_Interference * Random + Image * (1.0 - _TVAmbient) + _TVAmbient);
	}
	else // Passthrough
	{
		OutputColor = Image;
	}

	return OutputColor;
}

/*
	TV Effect with usage of gradient texture
*/

float4 PS_ThermalVision_Gradient(VS2PS_ThermalVision Input) : COLOR
{
	float4 OutputColor = 0.0;

	if (_Interference > 0 && _Interference <= 1)
	{
		float2 Pos = Input.TexCoord0;
		float2 ImgCoord = Input.TexCoord2;
		float Random = tex2D(SampleTex2_Wrap, Pos) - 0.2;
		float Noise = tex2D(SampleTex1_Wrap, Input.TexCoord1) - 0.5;
		float Distort = frac(Pos.y * _DistortionFreq + _DistortionRoll * _SinFracTime);
		Distort *= (1.0 - Distort);
		Distort /= 1.0 + _DistortionScale * abs(Pos.y);
		ImgCoord.x += _DistortionScale * Noise * Distort;
		float4 Image = dot(float3(0.3, 0.59, 0.11), tex2D(SampleTex0, ImgCoord).rgb);
		float4 Intensity = (_Interference * Random + Image * (1.0 - _TVAmbient) + _TVAmbient);
		float4 GradientColor = tex2D(SampleTex3, float2(Intensity.r, 0.0));
		OutputColor = float4( GradientColor.rgb, Intensity.a );
	}
	else
	{
		OutputColor = tex2D(SampleTex0, Input.TexCoord2);
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

technique TVEffect_Gradient_Tex
{
	pass Pass0
	{
		ZEnable = FALSE;
		StencilEnable = FALSE;
		AlphaBlendEnable = FALSE;

		VertexShader = compile vs_3_0 VS_ThermalVision();
		PixelShader = compile ps_3_0 PS_ThermalVision_Gradient();
	}
}

/*
	Wave Distortion Shader
*/

struct VS2PS_Distortion
{
	float4 HPos : POSITION;
	float2 TexCoord0 : TEXCOORD0;
	float2 TexCoord1 : TEXCOORD1;
};

VS2PS_Distortion VS_WaveDistortion(APP2VS_Quad Input)
{
	VS2PS_Distortion Output;
	Output.HPos = float4(Input.Pos.xy, 0.0, 1.0);
	Output.TexCoord0 = Input.TexCoord0;
	Output.TexCoord1 = Input.Pos.xy;
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

float4 PS_Flashbang(VS2PS_Quad Input) : COLOR
{
	float4 Sample0 = tex2D(SampleTex0, Input.TexCoord0);
	float4 Sample1 = tex2D(SampleTex1, Input.TexCoord0);
	float4 Sample2 = tex2D(SampleTex2, Input.TexCoord0);
	float4 Sample3 = tex2D(SampleTex3, Input.TexCoord0);

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

		VertexShader = compile vs_3_0 VS_Basic();
		PixelShader = compile ps_3_0 PS_Flashbang();
	}
}
