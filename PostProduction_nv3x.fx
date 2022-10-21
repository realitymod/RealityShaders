
/*
	Description: Controls the following post-production shaders
		1. Tinnitus
		2. Glow
		3. Thermal vision
		4. Wave distortion
		5. Flashbang
	Note: Some TV shaders write to the same render target as optic shaders
*/

#include "shaders/RealityGraphics.fx"

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

// One pixel in screen texture units
uniform float _DeltaU : DELTAU;
uniform float _DeltaV : DELTAV;

/*
	[Textures and samplers]
*/

#define CREATE_SAMPLER(NAME, TEXTURE, ADDRESS, FILTER) \
	sampler NAME = sampler_state \
	{ \
		Texture = (TEXTURE); \
		AddressU = ADDRESS; \
		AddressV = ADDRESS; \
		MinFilter = FILTER; \
		MagFilter = FILTER; \
	};

uniform texture Texture_0 : TEXLAYER0;
uniform texture Texture_1 : TEXLAYER1;
uniform texture Texture_2 : TEXLAYER2;
uniform texture Texture_3 : TEXLAYER3;

/*
	Unused?
	texture Texture4 : TEXLAYER4;
	texture Texture5 : TEXLAYER5;
	texture Texture6 : TEXLAYER6;
*/

CREATE_SAMPLER(Sampler_0_Bilinear, Texture_0, CLAMP, LINEAR)

CREATE_SAMPLER(Sampler_1_Bilinear, Texture_1, CLAMP, LINEAR)
CREATE_SAMPLER(Sampler_1_Bilinear_Wrap, Texture_1, WRAP, LINEAR)

CREATE_SAMPLER(Sampler_2_Bilinear, Texture_2, CLAMP, LINEAR)
CREATE_SAMPLER(Sampler_2_Bilinear_Wrap, Texture_2, WRAP, LINEAR)

CREATE_SAMPLER(Sampler_3_Bilinear, Texture_3, CLAMP, LINEAR)

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

struct VS2PS_Quad_2
{
	float4 HPos : POSITION;
	float2 TexCoord0 : TEXCOORD0;
	float2 TexCoord1 : TEXCOORD1;
};

struct VS2PS_Quad_3
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

static const float4 FilterKernel[8] =
{
	-1.0, 1.0, 0, 0.125,
	0.0, 1.0, 0, 0.125,
	1.0, 1.0, 0, 0.125,
	-1.0, 0.0, 0, 0.125,
	1.0, 0.0, 0, 0.125,
	-1.0, -1.0, 0, 0.125,
	0.0, -1.0, 0, 0.125,
	1.0, -1.0, 0, 0.125,
};

float4 Tinnitus_PS(VS2PS_Quad Input) : COLOR
{
	float4 Blur = 0.0;

	for(int i = 0; i < 8; i++)
	{
		Blur += FilterKernel[i].w * tex2D(Sampler_0_Bilinear, Input.TexCoord0.xy + 0.02 * FilterKernel[i].xy);
	}

	float4 Color = tex2D(Sampler_0_Bilinear, Input.TexCoord0);
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
	pass p0
	{
		ZEnable = TRUE;
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
	return tex2D(Sampler_0_Bilinear, Input.TexCoord0);
}

float4 Glow_Material_PS(VS2PS_Quad Input) : COLOR
{
	float4 Diffuse = tex2D(Sampler_0_Bilinear, Input.TexCoord0);
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

		VertexShader = compile vs_3_0 Basic_VS();
		PixelShader = compile ps_3_0 Glow_PS();
	}
}

technique GlowMaterial
{
	pass p0
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

/*
	float4 Fog_PS(VS2PS_Quad Input) : COLOR
	{
		float3 WorldPosition = tex2D(Sampler_0_Bilinear, Input.TexCoord0).xyz;
		float Coord = saturate((WorldPosition.z - _FogStartAndEnd.r) / _FogStartAndEnd.g); // fogColorandomViewDistance.a);
		return saturate(float4(_FogColor.rgb, Coord));
		// float2 FogCoords = float2(Coord, 0.0);
		return tex2D(Sampler_1_Bilinear, float2(Coord, 0.0)) * _FogColor.rgbb;
	}

	technique Fog
	{
		pass p0
		{
			ZEnable = FALSE;
			AlphaBlendEnable = TRUE;
			//SrcBlend = SRCCOLOR;
			//DestBlend = ZERO;
			SrcBlend = SRCALPHA;
			DestBlend = INVSRCALPHA;
			//StencilEnable = FALSE;

			StencilEnable = TRUE;
			StencilFunc = NOTEQUAL;
			StencilRef = 0x00;
			StencilMask = 0xFF;
			StencilFail = KEEP;
			StencilZFail = KEEP;
			StencilPass = KEEP;

			VertexShader = compile vs_3_0 Basic_VS();
			PixelShader = compile ps_3_0 Fog_PS();
		}
	}
*/

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

VS2PS_Quad_3 Thermal_Vision_VS( APP2VS_Quad Input )
{
	VS2PS_Quad_3 Output;
	Input.Pos.xy = sign(Input.Pos.xy);
	Output.HPos = float4(Input.Pos.xy, 0, 1);
	Output.TexCoord0 = Input.Pos.xy * _Granularity + _Displacement; // Outputs random jitter movement at [-x, x] range
	Output.TexCoord1 = Input.Pos.xy * 0.25 - 0.35 * _SinFracTime;
	Output.TexCoord2 = Input.TexCoord0;
	return Output;
}

PS2FB_Combine Thermal_Vision_PS(VS2PS_Quad_3 Input)
{
	PS2FB_Combine Output;
	float2 ImgCoord = Input.TexCoord2;
	float4 Image = tex2D(Sampler_0_Bilinear, ImgCoord);

	if (_Interference <= 1)
	{
		float2 Pos = Input.TexCoord0;
		float Random = tex2D(Sampler_2_Bilinear_Wrap, Pos) - 0.2;
		if (_Interference < 0) // thermal imaging
		{
			float HOffset = 0.001;
			float VOffset = 0.0015;
			Image *= 0.25;
			Image += tex2D(Sampler_0_Bilinear, ImgCoord + float2( HOffset, VOffset)) * 0.0625;
			Image += tex2D(Sampler_0_Bilinear, ImgCoord - float2( HOffset, VOffset)) * 0.0625;
			Image += tex2D(Sampler_0_Bilinear, ImgCoord + float2(-HOffset, VOffset)) * 0.0625;
			Image += tex2D(Sampler_0_Bilinear, ImgCoord + float2( HOffset, -VOffset)) * 0.0625;
			Image += tex2D(Sampler_0_Bilinear, ImgCoord + float2( HOffset, 0.0)) * 0.125;
			Image += tex2D(Sampler_0_Bilinear, ImgCoord - float2( HOffset, 0.0)) * 0.125;
			Image += tex2D(Sampler_0_Bilinear, ImgCoord + float2( 0.0, VOffset)) * 0.125;
			Image += tex2D(Sampler_0_Bilinear, ImgCoord - float2( 0.0, VOffset)) * 0.125;
			// Output.Col0.r = lerp(lerp(lerp(0.43, 0.17, Image.g), lerp(0.75f, 0.50f, Image.b), Image.b), Image.r, Image.r); // M
			Output.Col0.r = lerp(0.43, 0.0, Image.g) + Image.r; // Terrain max light mod should be 0.608
			Output.Col0.r -= _Interference * Random; // Add -_Interference
			Output.Col0 = float4(_TVColor * Output.Col0.rrr, Image.a);
		}
		else // normal tv effect
		{
			float Noise = tex2D(Sampler_1_Bilinear_Wrap, Input.TexCoord1) - 0.5;
			float Distort = frac(Pos.y * _DistortionFreq + _DistortionRoll * _SinFracTime);
			Distort *= (1.0 - Distort);
			Distort /= 1.0 + _DistortionScale * abs(Pos.y);
			ImgCoord.x += _DistortionScale * Noise * Distort;
			Image = dot(float3(0.3, 0.59, 0.11), Image.rgb);
			Output.Col0 = float4(_TVColor, 1.0) * (_Interference * Random + Image * (1.0 - _TVAmbient) + _TVAmbient);
		}
	}
	else Output.Col0 = Image;
	return Output;
}

/*
	TV Effect with usage of gradient texture
*/

PS2FB_Combine Thermal_Vision_Gradient_PS(VS2PS_Quad_3 Input)
{
	PS2FB_Combine Output;

	if ( _Interference >= 0 && _Interference <= 1 )
	{
		float2 Pos = Input.TexCoord0;
		float2 ImgCoord = Input.TexCoord2;
		float Random = tex2D(Sampler_2_Bilinear_Wrap, Pos) - 0.2;
		float Noise = tex2D(Sampler_1_Bilinear_Wrap, Input.TexCoord1) - 0.5;
		float Distort = frac(Pos.y * _DistortionFreq + _DistortionRoll * _SinFracTime);
		Distort *= (1.0 - Distort);
		Distort /= 1.0 + _DistortionScale * abs(Pos.y);
		ImgCoord.x += _DistortionScale * Noise * Distort;
		float4 Image = dot(float3(0.3, 0.59, 0.11), tex2D(Sampler_0_Bilinear, ImgCoord).rgb);
		float4 Intensity = (_Interference * Random + Image * (1.0 - _TVAmbient) + _TVAmbient);
		float4 GradientColor = tex2D(Sampler_3_Bilinear, float2(Intensity.r, 0.0f));
		Output.Col0 = float4( GradientColor.rgb, Intensity.a );
	}
	else
	{
		Output.Col0 = tex2D(Sampler_0_Bilinear, Input.TexCoord2);
	}

	return Output;
}

technique TVEffect
{
	pass p0
	{
		ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		StencilEnable = FALSE;

		VertexShader = compile vs_3_0 Thermal_Vision_VS();
        PixelShader = compile ps_3_0 Thermal_Vision_PS();
	}
}

technique TVEffect_Gradient_Tex
{
	pass p0
	{
		ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		StencilEnable = FALSE;

		VertexShader = compile vs_3_0 Thermal_Vision_VS();
		PixelShader = compile ps_3_0 Thermal_Vision_Gradient_PS();
	}
}

/*
	Wave Distortion Shader
*/

VS2PS_Quad_2 Wave_Distortion_VS(APP2VS_Quad Input)
{
	VS2PS_Quad_2 Output;
	Output.HPos = float4(Input.Pos.xy, 0.0, 1.0);
	Output.TexCoord0 = Input.TexCoord0;
	Output.TexCoord1 = Input.Pos.xy;
	return Output;
}

float4 Wave_Distortion_PS(VS2PS_Quad_2 Input) : COLOR
{
	return 0.0;
}

technique WaveDistortion
{
	pass p0
	{
		ZEnable = FALSE;
		AlphaBlendEnable = TRUE;
		AlphaTestEnable = FALSE;
		StencilEnable = FALSE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		// PixelShaderConstant2[0] = <_FracTime>;
		// PixelShaderConstant1[1] = <_DeltaU>;
		// PixelShaderConstant1[2] = <_DeltaV>;
		// TextureTransform[2] = <UpScaleTexBy8>;

		VertexShader = compile vs_3_0 Wave_Distortion_VS();
		PixelShader = compile ps_3_0 Wave_Distortion_PS();
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
	float4 Sample0 = tex2D(Sampler_0_Bilinear, Input.TexCoord0);
	float4 Sample1 = tex2D(Sampler_1_Bilinear, Input.TexCoord0);
	float4 Sample2 = tex2D(Sampler_2_Bilinear, Input.TexCoord0);
	float4 Sample3 = tex2D(Sampler_3_Bilinear, Input.TexCoord0);

	float4 OutputColor = Sample0 * 0.5;
	OutputColor += Sample1 * 0.25;
	OutputColor += Sample2 * 0.15;
	OutputColor += Sample3 * 0.10;
	return float4(OutputColor.rgb, _BackBufferLerpBias);
}

technique Flashbang
{
	pass P0
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
