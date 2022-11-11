
/*
	Description: Controls the following post-production shaders
		1. Tinnitus
		2. Glow
		3. Thermal vision
		4. Wave distortion
		5. Flashbang
	Note: Some TV shaders write to the same render target as optic shaders
*/

#include "shaders/RealityGraphics.fxh"

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

#define CREATE_SAMPLER(SAMPLER_NAME, TEXTURE, ADDRESS, IS_SRGB) \
	sampler SAMPLER_NAME = sampler_state \
	{ \
		Texture = (TEXTURE); \
		MinFilter = LINEAR; \
		MagFilter = LINEAR; \
		MipFilter = LINEAR; \
		AddressU = ADDRESS; \
		AddressV = ADDRESS; \
		SRGBTexture = IS_SRGB; \
	}; \


/*
	Unused?
	uniform texture Texture4 : TEXLAYER4;
	uniform texture Texture5 : TEXLAYER5;
	uniform texture Texture6 : TEXLAYER6;
*/

uniform texture Tex0 : TEXLAYER0;
CREATE_SAMPLER(SampleTex0, Tex0, CLAMP, FALSE)

uniform texture Tex1 : TEXLAYER1;
CREATE_SAMPLER(SampleTex1, Tex1, CLAMP, FALSE)
CREATE_SAMPLER(SampleTex1_Wrap, Tex1, WRAP, FALSE)

uniform texture Tex2 : TEXLAYER2;
CREATE_SAMPLER(SampleTex2, Tex2, CLAMP, FALSE)
CREATE_SAMPLER(SampleTex2_Wrap, Tex2, WRAP, FALSE)

uniform texture Tex3 : TEXLAYER3;
CREATE_SAMPLER(SampleTex3, Tex3, CLAMP, FALSE)

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

struct PS2FB_Combine
{
	float4 Col0 : COLOR0;
};

VS2PS_Quad Basic_VS(APP2VS_Quad Input)
{
	VS2PS_Quad Output;
	Output.HPos = float4(Input.Pos.xy, 0.0, 1.0);
	Output.TexCoord0 = Input.TexCoord0;
	return Output;
}

float4 Tinnitus_PS(VS2PS_Quad Input) : COLOR
{
	const int BlurTaps = 9;

	// 0 3 6
	// 1 4 7
	// 2 5 8
	float4 Tex[BlurTaps];
	Tex[0] = tex2D(SampleTex0, Input.TexCoord0 + (float2(-1.0, 1.0) / _ScreenSize));
	Tex[1] = tex2D(SampleTex0, Input.TexCoord0 + (float2(-1.0, 0.0) / _ScreenSize));
	Tex[2] = tex2D(SampleTex0, Input.TexCoord0 + (float2(-1.0, -1.0) / _ScreenSize));
	Tex[3] = tex2D(SampleTex0, Input.TexCoord0 + (float2(0.0, 1.0) / _ScreenSize));
	Tex[4] = tex2D(SampleTex0, Input.TexCoord0 + (float2(0.0, 0.0) / _ScreenSize));
	Tex[5] = tex2D(SampleTex0, Input.TexCoord0 + (float2(0.0, -1.0) / _ScreenSize));
	Tex[6] = tex2D(SampleTex0, Input.TexCoord0 + (float2(1.0, 1.0) / _ScreenSize));
	Tex[7] = tex2D(SampleTex0, Input.TexCoord0 + (float2(1.0, 0.0) / _ScreenSize));
	Tex[8] = tex2D(SampleTex0, Input.TexCoord0 + (float2(1.0, -1.0) / _ScreenSize));

	float4 Blur = 0.0;
	for(int i = 0; i < BlurTaps; i++)
	{
		Blur += (Tex[i] * (1.0 / float(BlurTaps)));
	}

	float4 Color = Tex[4];
	float2 UV = Input.TexCoord0;

	// Parabolic function for x opacity to darken the edges, exponential function for opacity to darken the lower part of the screen
	float Darkness = max(4.0 * UV.x * UV.x - 4.0 * UV.x + 1.0, saturate((pow(2.5, UV.y) - UV.y / 2.0 - 1.0)));

	// Weight the blurred version more heavily as you go lower on the screen
	float4 OutputColor = lerp(Color, Blur, saturate(2.0 * (pow(4.0, UV.y) - UV.y - 1.0)));

	// Darken the left, right, and bottom edges of the final product
	OutputColor = lerp(OutputColor, float4(0.0, 0.0, 0.0, 1.0), Darkness);
	return float4(OutputColor.rgb, saturate(2.0 * _BackBufferLerpBias));
}

technique Tinnitus
{
	pass Pass0
	{
		ZEnable = FALSE;
		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;
		StencilEnable = FALSE;

		VertexShader = compile vs_3_0 Basic_VS();
		PixelShader = compile ps_3_0 Tinnitus_PS();
	}
}

/*
	Glow shaders
*/

float4 Glow_PS(VS2PS_Quad Input) : COLOR
{
	return tex2D(SampleTex0, Input.TexCoord0);
}

float4 Glow_Material_PS(VS2PS_Quad Input) : COLOR
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

		VertexShader = compile vs_3_0 Basic_VS();
		PixelShader = compile ps_3_0 Glow_PS();
	}
}

technique GlowMaterial
{
	pass Pass0
	{
		ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		SrcBlend = SRCCOLOR;
		DestBlend = ONE;

		StencilEnable = TRUE;
		StencilFunc = NOTEQUAL;
		StencilRef = 0x80;
		StencilMask = 0xFF;
		StencilFail = KEEP;
		StencilZFail = KEEP;
		StencilPass = KEEP;

		VertexShader = compile vs_3_0 Basic_VS();
		PixelShader = compile ps_3_0 Glow_Material_PS();
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

VS2PS_ThermalVision ThermalVision_VS(APP2VS_Quad Input)
{
	VS2PS_ThermalVision Output;
	Input.Pos.xy = sign(Input.Pos.xy);
	Output.HPos = float4(Input.Pos.xy, 0, 1);
	Output.TexCoord0 = Input.Pos.xy * _Granularity + _Displacement; // Outputs random jitter movement at [-x, x] range
	Output.TexCoord1 = Input.Pos.xy * 0.25 - 0.35 * _SinFracTime;
	Output.TexCoord2 = Input.TexCoord0;
	return Output;
}

PS2FB_Combine ThermalVision_PS(VS2PS_ThermalVision Input)
{
	PS2FB_Combine Output;
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
		// Output.Col0.r = lerp(lerp(lerp(0.43, 0.17, Image.g), lerp(0.75f, 0.50f, Image.b), Image.b), Image.r, Image.r); // M
		Output.Col0.r = lerp(0.43, 0.0, Image.g) + Image.r; // Terrain max light mod should be 0.608
		Output.Col0.r -= _Interference * Random; // Add -_Interference
		Output.Col0 = float4(_TVColor * Output.Col0.rrr, Image.a);
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
		Output.Col0 = float4(_TVColor, 1.0) * (_Interference * Random + Image * (1.0 - _TVAmbient) + _TVAmbient);
	}
	else // Passthrough
	{
		Output.Col0 = Image;
	}
	return Output;
}

/*
	TV Effect with usage of gradient texture
*/

PS2FB_Combine ThermalVision_Gradient_PS(VS2PS_ThermalVision Input)
{
	PS2FB_Combine Output;

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
		float4 GradientColor = tex2D(SampleTex3, float2(Intensity.r, 0.0f));
		Output.Col0 = float4( GradientColor.rgb, Intensity.a );
	}
	else
	{
		Output.Col0 = tex2D(SampleTex0, Input.TexCoord2);
	}

	return Output;
}

technique TVEffect
{
	pass Pass0
	{
		ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		StencilEnable = FALSE;

		VertexShader = compile vs_3_0 ThermalVision_VS();
		PixelShader = compile ps_3_0 ThermalVision_PS();
	}
}

technique TVEffect_Gradient_Tex
{
	pass Pass0
	{
		ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		StencilEnable = FALSE;

		VertexShader = compile vs_3_0 ThermalVision_VS();
		PixelShader = compile ps_3_0 ThermalVision_Gradient_PS();
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

VS2PS_Distortion WaveDistortion_VS(APP2VS_Quad Input)
{
	VS2PS_Distortion Output;
	Output.HPos = float4(Input.Pos.xy, 0.0, 1.0);
	Output.TexCoord0 = Input.TexCoord0;
	Output.TexCoord1 = Input.Pos.xy;
	return Output;
}

float4 WaveDistortion_PS(VS2PS_Distortion Input) : COLOR
{
	return 0.0;
}

technique WaveDistortion
{
	pass Pass0
	{
		ZEnable = FALSE;
		AlphaBlendEnable = TRUE;
		AlphaTestEnable = FALSE;
		StencilEnable = FALSE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		VertexShader = compile vs_3_0 WaveDistortion_VS();
		PixelShader = compile ps_3_0 WaveDistortion_PS();
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

float4 Flashbang_PS(VS2PS_Quad Input) : COLOR
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
		AlphaBlendEnable = TRUE;

		BlendOp = ADD;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;
		StencilEnable = FALSE;

		VertexShader = compile vs_3_0 Basic_VS();
		PixelShader = compile ps_3_0 Flashbang_PS();
	}
}
