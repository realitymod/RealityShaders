#include "shaders/datatypes.fx"

texture texture0 : TEXLAYER0;
texture texture1 : TEXLAYER1;
// texture texture2 : TEXLAYER2;
// texture texture3 : TEXLAYER3;

sampler sampler0point = sampler_state { Texture = (texture0); AddressU = CLAMP; AddressV = CLAMP; MinFilter = POINT; MagFilter = POINT; };
sampler sampler1point = sampler_state { Texture = (texture1); AddressU = CLAMP; AddressV = CLAMP; MinFilter = POINT; MagFilter = POINT; };
// sampler sampler2 = sampler_state { Texture = (texture2); AddressU = CLAMP; AddressV = CLAMP; MinFilter = POINT; MagFilter = POINT; };
// sampler sampler3 = sampler_state { Texture = (texture3); AddressU = CLAMP; AddressV = CLAMP; MinFilter = POINT; MagFilter = POINT; };
sampler sampler0bilin = sampler_state { Texture = (texture0); AddressU = CLAMP; AddressV = CLAMP; MinFilter = LINEAR; MagFilter = LINEAR; };
// sampler sampler0aniso = sampler_state { Texture = (texture0); AddressU = CLAMP; AddressV = CLAMP; MinFilter = ANISOTROPIC; MagFilter = ANISOTROPIC; MaxAnisotropy = 8; };

dword dwStencilRef : STENCILREF = 0;
dword dwStencilPass : STENCILPASS = 1; // KEEP

float4x4 convertPosTo8BitMat : CONVERTPOSTO8BITMAT;

float4 scaleDown2x2SampleOffsets[4] : SCALEDOWN2X2SAMPLEOFFSETS;
float4 scaleDown4x4SampleOffsets[16] : SCALEDOWN4X4SAMPLEOFFSETS;
float4 scaleDown4x4LinearSampleOffsets[4] : SCALEDOWN4X4LINEARSAMPLEOFFSETS;
float4 gaussianBlur5x5CheapSampleOffsets[13] : GAUSSIANBLUR5X5CHEAPSAMPLEOFFSETS;
float gaussianBlur5x5CheapSampleWeights[13] : GAUSSIANBLUR5X5CHEAPSAMPLEWEIGHTS;
float4 gaussianBlur15x15HorizontalSampleOffsets[15] : GAUSSIANBLUR15X15HORIZONTALSAMPLEOFFSETS;
float gaussianBlur15x15HorizontalSampleWeights[15] : GAUSSIANBLUR15X15HORIZONTALSAMPLEWEIGHTS;
float4 gaussianBlur15x15VerticalSampleOffsets[15] : GAUSSIANBLUR15X15VERTICALSAMPLEOFFSETS;
float gaussianBlur15x15VerticalSampleWeights[15] : GAUSSIANBLUR15X15VERTICALSAMPLEWEIGHTS;
float4 growablePoisson13SampleOffsets[12] : GROWABLEPOISSON13SAMPLEOFFSETS;

float2 texelSize : TEXELSIZE;

struct APP2VS_blit
{
    float2 Pos : POSITION0;
    float2 TexCoord0 : TEXCOORD0;
};

struct VS2PS_blit
{
    float4 Pos : POSITION;
    float2 TexCoord0 : TEXCOORD0;
};

VS2PS_blit vsDx9_blit(APP2VS_blit indata)
{
	VS2PS_blit outdata;	
 	outdata.Pos = float4(indata.Pos.x, indata.Pos.y, 0, 1);
 	outdata.TexCoord0 = indata.TexCoord0;
	return outdata;
}

float4 psDx9_FSBMPassThrough(VS2PS_blit indata) : COLOR
{
	return tex2D(sampler0point, indata.TexCoord0);
}

float4 psDx9_FSBMPassThroughSaturateAlpha(VS2PS_blit indata) : COLOR
{
	float4 color =  tex2D(sampler0point, indata.TexCoord0);
	color.a = 1.f;
	return color;
}


float4 psDx9_FSBMCopyOtherRGBToAlpha(VS2PS_blit indata) : COLOR
{
	float4 color = tex2D(sampler0point, indata.TexCoord0);
	
	float3 avg = 1.0/3;
	
	color.a = dot(avg, color);
	
	return color;
}


float4 psDx9_FSBMConvertPosTo8Bit(VS2PS_blit indata) : COLOR
{
	float4 viewPos = tex2D(sampler0point, indata.TexCoord0);
	viewPos /= 50;
	viewPos = viewPos * 0.5 + 0.5;
	return viewPos;
}

float4 psDx9_FSBMConvertNormalTo8Bit(VS2PS_blit indata) : COLOR
{
	return normalize(tex2D(sampler0point, indata.TexCoord0)) / 2 + 0.5;
	// return tex2D(sampler0point, indata.TexCoord0).a;
}

float4 psDx9_FSBMConvertShadowMapFrontTo8Bit(VS2PS_blit indata) : COLOR
{
	float4 depths = tex2D(sampler0point, indata.TexCoord0);
	return depths;
}

float4 psDx9_FSBMConvertShadowMapBackTo8Bit(VS2PS_blit indata) : COLOR
{
	return -tex2D(sampler0point, indata.TexCoord0);
}

float4 psDx9_FSBMScaleUp4x4LinearFilter(VS2PS_blit indata) : COLOR
{
	return tex2D(sampler0bilin, indata.TexCoord0);
}

float4 psDx9_FSBMScaleDown2x2Filter(VS2PS_blit indata) : COLOR
{
	float4 accum;
	accum = tex2D(sampler0point, indata.TexCoord0 + scaleDown2x2SampleOffsets[0]);
	accum += tex2D(sampler0point, indata.TexCoord0 + scaleDown2x2SampleOffsets[1]);
	accum += tex2D(sampler0point, indata.TexCoord0 + scaleDown2x2SampleOffsets[2]);
	accum += tex2D(sampler0point, indata.TexCoord0 + scaleDown2x2SampleOffsets[3]);

	return accum * 0.25; // div 4
}

float4 psDx9_FSBMScaleDown4x4Filter(VS2PS_blit indata) : COLOR
{
	float4 accum = 0;

	for(int tap = 0; tap < 16; ++tap)
		accum += tex2D(sampler0point, indata.TexCoord0 + scaleDown4x4SampleOffsets[tap]);

	return accum * 0.0625; // div 16
}

float4 psDx9_FSBMScaleDown4x4LinearFilter(VS2PS_blit indata) : COLOR
{
	float4 accum;
	accum = tex2D(sampler0bilin, indata.TexCoord0 + scaleDown4x4LinearSampleOffsets[0]);
	accum += tex2D(sampler0bilin, indata.TexCoord0 + scaleDown4x4LinearSampleOffsets[1]);
	accum += tex2D(sampler0bilin, indata.TexCoord0 + scaleDown4x4LinearSampleOffsets[2]);
	accum += tex2D(sampler0bilin, indata.TexCoord0 + scaleDown4x4LinearSampleOffsets[3]);

	return accum * 0.25; // div 4
}

float4 psDx9_FSBMGaussianBlur5x5CheapFilter(VS2PS_blit indata) : COLOR
{
	float4 accum = 0;

	for(int tap = 0; tap < 13; ++tap)
		accum += tex2D(sampler0point, indata.TexCoord0 + gaussianBlur5x5CheapSampleOffsets[tap]) * gaussianBlur5x5CheapSampleWeights[tap];

	return accum;
}

float4 psDx9_FSBMGaussianBlur15x15HorizontalFilter(VS2PS_blit indata) : COLOR
{
	float4 accum = 0;

	for(int tap = 0; tap < 15; ++tap)
		accum += tex2D(sampler0point, indata.TexCoord0 + gaussianBlur15x15HorizontalSampleOffsets[tap]) * gaussianBlur15x15HorizontalSampleWeights[tap];

	return accum;
}

float4 psDx9_FSBMGaussianBlur15x15VerticalFilter(VS2PS_blit indata) : COLOR
{
	float4 accum = 0;

	for(int tap = 0; tap < 15; ++tap)
		accum += tex2D(sampler0point, indata.TexCoord0 + gaussianBlur15x15VerticalSampleOffsets[tap]) * gaussianBlur15x15VerticalSampleWeights[tap];

	return accum;
}

float4 psDx9_FSBMGaussianBlur15x15HorizontalFilter2(VS2PS_blit indata) : COLOR
{
	float4 accum = 0;

	for(int tap = 0; tap < 15; ++tap)
		accum += tex2D(sampler0point, indata.TexCoord0 + 2*gaussianBlur15x15HorizontalSampleOffsets[tap]) * gaussianBlur15x15HorizontalSampleWeights[tap];

	return accum;
}

float4 psDx9_FSBMGaussianBlur15x15VerticalFilter2(VS2PS_blit indata) : COLOR
{
	float4 accum = 0;

	for(int tap = 0; tap < 15; ++tap)
		accum += tex2D(sampler0point, indata.TexCoord0 + 2*gaussianBlur15x15VerticalSampleOffsets[tap]) * gaussianBlur15x15VerticalSampleWeights[tap];

	return accum;
}

float4 psDx9_FSBMGrowablePoisson13Filter(VS2PS_blit indata) : COLOR
{
	float4 accum = 0;
	float samples = 1;

	accum = tex2D(sampler0point, indata.TexCoord0);
	for(int tap = 0; tap < 11; ++tap)
	{
// float4 v = tex2D(sampler0point, indata.TexCoord0 + growablePoisson13SampleOffsets[tap]*1);
		float4 v = tex2D(sampler0point, indata.TexCoord0 + growablePoisson13SampleOffsets[tap]*0.1*accum.a);
		if(v.a > 0)
		{
			accum.rgb += v;
			samples += 1;
		}
	}

// return tex2D(sampler0point, indata.TexCoord0);
	return accum / samples;
}

float4 psDx9_FSBMGrowablePoisson13AndDilationFilter(VS2PS_blit indata) : COLOR
{
	float4 center = tex2D(sampler0point, indata.TexCoord0);
	
	float4 accum = 0;
	if(center.a > 0)
	{
		accum.rgb = center;
		accum.a = 1;
	}

	for(int tap = 0; tap < 11; ++tap)
	{
		float scale = 3*(center.a);
		if(scale == 0)
			scale = 1.5;
		float4 v = tex2D(sampler0point, indata.TexCoord0 + growablePoisson13SampleOffsets[tap]*scale);
		if(v.a > 0)
		{
			accum.rgb += v;
			accum.a += 1;
		}
	}

// if(center.a == 0)
// {
// accum.gb = center.gb;
// accum.r / accum.a;
// return accum;
// }
// else
		return accum / accum.a;
}

float4 psDx9_FSBMScaleUpBloomFilter(VS2PS_blit indata) : COLOR
{
	float offSet = 0.01;

	float4 close = tex2D(sampler0point, indata.TexCoord0);
/*	
	close += tex2D(sampler0bilin, float2((indata.TexCoord0.x - offSet*4.5), indata.TexCoord0.y));
	close += tex2D(sampler0bilin, float2((indata.TexCoord0.x - offSet*3.5), indata.TexCoord0.y));
	close += tex2D(sampler0bilin, float2((indata.TexCoord0.x - offSet*2.5), indata.TexCoord0.y));
	close += tex2D(sampler0bilin, float2((indata.TexCoord0.x - offSet*1.5), indata.TexCoord0.y));
	close += tex2D(sampler0bilin, float2((indata.TexCoord0.x + offSet*1.5), indata.TexCoord0.y));
	close += tex2D(sampler0bilin, float2((indata.TexCoord0.x + offSet*2.5), indata.TexCoord0.y));
	close += tex2D(sampler0bilin, float2((indata.TexCoord0.x + offSet*3.5), indata.TexCoord0.y));
	close += tex2D(sampler0bilin, float2((indata.TexCoord0.x + offSet*4.5), indata.TexCoord0.y));

	close += tex2D(sampler0bilin, float2(indata.TexCoord0.x, indata.TexCoord0.y - offSet*4.5));
	close += tex2D(sampler0bilin, float2(indata.TexCoord0.x, indata.TexCoord0.y - offSet*3.5));
	close += tex2D(sampler0bilin, float2(indata.TexCoord0.x, indata.TexCoord0.y - offSet*2.5));
	close += tex2D(sampler0bilin, float2(indata.TexCoord0.x, indata.TexCoord0.y - offSet*1.5));
	close += tex2D(sampler0bilin, float2(indata.TexCoord0.x, indata.TexCoord0.y + offSet*1.5));
	close += tex2D(sampler0bilin, float2(indata.TexCoord0.x, indata.TexCoord0.y + offSet*2.5));
	close += tex2D(sampler0bilin, float2(indata.TexCoord0.x, indata.TexCoord0.y + offSet*3.5));
	// close += tex2D(sampler0bilin, float2(indata.TexCoord0.x, indata.TexCoord0.y + offSet*4.5));

	return close / 16;
*/
	return close;
}

technique Blit
{
	pass FSBMPassThrough
	{
		ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		StencilEnable = FALSE;
		AlphaTestEnable = FALSE;
		VertexShader = compile vs_1_1 vsDx9_blit();
		PixelShader = compile PS2_EXT psDx9_FSBMPassThrough();
	}

	pass FSBMBlend
	{
		ZEnable = FALSE;
		AlphaBlendEnable = TRUE;
		StencilEnable = FALSE;
		AlphaTestEnable = FALSE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		VertexShader = compile vs_1_1 vsDx9_blit();
		PixelShader = compile ps_1_1 psDx9_FSBMPassThrough();
	}

	pass FSBMConvertPosTo8Bit
	{
		ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_1_1 vsDx9_blit();
		PixelShader = compile PS2_EXT psDx9_FSBMConvertPosTo8Bit();
	}

	pass FSBMConvertNormalTo8Bit
	{
		ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_1_1 vsDx9_blit();
		PixelShader = compile PS2_EXT psDx9_FSBMConvertNormalTo8Bit();
	}

	pass FSBMConvertShadowMapFrontTo8Bit
	{
		ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_1_1 vsDx9_blit();
		PixelShader = compile PS2_EXT psDx9_FSBMConvertShadowMapFrontTo8Bit();
	}

	pass FSBMConvertShadowMapBackTo8Bit
	{
		ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_1_1 vsDx9_blit();
		PixelShader = compile PS2_EXT psDx9_FSBMConvertShadowMapBackTo8Bit();
	}

	pass FSBMScaleUp4x4LinearFilter
	{
		ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_1_1 vsDx9_blit();
		PixelShader = compile PS2_EXT psDx9_FSBMScaleUp4x4LinearFilter();
	}

	pass FSBMScaleDown2x2Filter
	{
		ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_1_1 vsDx9_blit();
		PixelShader = compile PS2_EXT psDx9_FSBMScaleDown2x2Filter();
	}

	pass FSBMScaleDown4x4Filter
	{
		ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_1_1 vsDx9_blit();
		PixelShader = compile PS2_EXT psDx9_FSBMScaleDown4x4Filter();
	}

	pass FSBMScaleDown4x4LinearFilter
	{
		ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_1_1 vsDx9_blit();
		PixelShader = compile PS2_EXT psDx9_FSBMScaleDown4x4LinearFilter();
	}

	pass FSBMGaussianBlur5x5CheapFilter
	{
		ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_1_1 vsDx9_blit();
		PixelShader = compile PS2_EXT psDx9_FSBMGaussianBlur5x5CheapFilter();
	}

	pass FSBMGaussianBlur15x15HorizontalFilter
	{
		ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_1_1 vsDx9_blit();
		PixelShader = compile PS2_EXT psDx9_FSBMGaussianBlur15x15HorizontalFilter();// psDx9_FSBMGaussianBlur15x15HorizontalFilter2();
	}

	pass FSBMGaussianBlur15x15VerticalFilter
	{
		ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_1_1 vsDx9_blit();
		PixelShader = compile PS2_EXT psDx9_FSBMGaussianBlur15x15VerticalFilter();// psDx9_FSBMGaussianBlur15x15VerticalFilter2();
	}

	pass FSBMGrowablePoisson13Filter
	{
		ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_1_1 vsDx9_blit();
		PixelShader = compile PS2_EXT psDx9_FSBMGrowablePoisson13Filter();
	}

	pass FSBMGrowablePoisson13AndDilationFilter
	{
		ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_1_1 vsDx9_blit();
		PixelShader = compile PS2_EXT psDx9_FSBMGrowablePoisson13AndDilationFilter();
	}

	pass FSBMScaleUpBloomFilter
	{
		ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_1_1 vsDx9_blit();
		PixelShader = compile PS2_EXT psDx9_FSBMScaleUpBloomFilter();
	}
	
	pass FSBMPassThroughSaturateAlpha
	{
		ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		StencilEnable = FALSE;
		AlphaTestEnable = FALSE;
		VertexShader = compile vs_1_1 vsDx9_blit();
		PixelShader = compile PS2_EXT psDx9_FSBMPassThroughSaturateAlpha();
	}
	
	pass FSBMCopyOtherRGBToAlpha
	{
		ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		StencilEnable = FALSE;
		AlphaTestEnable = FALSE;
		ColorWriteEnable = ALPHA;
		
		VertexShader = compile vs_1_1 vsDx9_blit();
		PixelShader = compile PS2_EXT psDx9_FSBMCopyOtherRGBToAlpha();
		
	}
}

technique Blit_1_4
{
	pass FSBMPassThrough
	{
		ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		StencilEnable = FALSE;
		AlphaTestEnable = FALSE;
		VertexShader = compile vs_1_1 vsDx9_blit();
		PixelShader = compile ps_1_1 psDx9_FSBMPassThrough();
	}

	pass FSBMBlend
	{
		ZEnable = FALSE;
		AlphaBlendEnable = TRUE;
		StencilEnable = FALSE;
		AlphaTestEnable = FALSE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		VertexShader = compile vs_1_1 vsDx9_blit();
		PixelShader = compile ps_1_1 psDx9_FSBMPassThrough();
	}

	pass FSBMConvertPosTo8Bit
	{
		ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_1_1 vsDx9_blit();
		// PixelShader = compile PS2_EXT psDx9_FSBMConvertPosTo8Bit();
		PixelShader = compile ps_1_1 psDx9_FSBMConvertPosTo8Bit();
	}

	pass FSBMConvertNormalTo8Bit
	{
/*		ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_1_1 vsDx9_blit();
		PixelShader = compile ps_1_4 psDx9_FSBMConvertNormalTo8Bit();
		*/
	}

	pass FSBMConvertShadowMapFrontTo8Bit
	{
		ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_1_1 vsDx9_blit();
		PixelShader = compile ps_1_4 psDx9_FSBMConvertShadowMapFrontTo8Bit();
	}

	pass FSBMConvertShadowMapBackTo8Bit
	{
		ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_1_1 vsDx9_blit();
		PixelShader = compile ps_1_4 psDx9_FSBMConvertShadowMapBackTo8Bit();
	}

	pass FSBMScaleUp4x4LinearFilter
	{
		ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_1_1 vsDx9_blit();
		PixelShader = compile ps_1_4 psDx9_FSBMScaleUp4x4LinearFilter();
	}

	pass FSBMScaleDown2x2Filter
	{
		ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_1_1 vsDx9_blit();
		PixelShader = compile ps_1_4 psDx9_FSBMScaleDown2x2Filter();
	}

	pass FSBMScaleDown4x4Filter
	{
/*		ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_1_1 vsDx9_blit();
		PixelShader = compile ps_1_4 psDx9_FSBMScaleDown4x4Filter();
		*/
		// actually the FSBMScaleDown4x4LinearFilter
		ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_1_1 vsDx9_blit();
		PixelShader = compile ps_1_4 psDx9_FSBMScaleDown4x4LinearFilter();
		
	}

	pass FSBMScaleDown4x4LinearFilter
	{
		ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_1_1 vsDx9_blit();
		PixelShader = compile ps_1_4 psDx9_FSBMScaleDown4x4LinearFilter();
	}

	pass FSBMGaussianBlur5x5CheapFilter
	{
		/*ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_1_1 vsDx9_blit();
		PixelShader = compile ps_1_4 psDx9_FSBMGaussianBlur5x5CheapFilter();
		*/
	}

	pass FSBMGaussianBlur15x15HorizontalFilter
	{
	/*	ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_1_1 vsDx9_blit();
		PixelShader = compile ps_1_4 psDx9_FSBMGaussianBlur15x15HorizontalFilter();// psDx9_FSBMGaussianBlur15x15HorizontalFilter2();
		*/
	}

	pass FSBMGaussianBlur15x15VerticalFilter
	{
		/*ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_1_1 vsDx9_blit();
		PixelShader = compile ps_1_4 psDx9_FSBMGaussianBlur15x15VerticalFilter();// psDx9_FSBMGaussianBlur15x15VerticalFilter2();
		*/
	}

	pass FSBMGrowablePoisson13Filter
	{
		/*ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_1_1 vsDx9_blit();
		PixelShader = compile ps_1_4 psDx9_FSBMGrowablePoisson13Filter();
		*/
	}

	pass FSBMGrowablePoisson13AndDilationFilter
	{
		/*ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_1_1 vsDx9_blit();
		PixelShader = compile PS2_EXT psDx9_FSBMGrowablePoisson13AndDilationFilter();
		*/
	}

	pass FSBMScaleUpBloomFilter
	{
		ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_1_1 vsDx9_blit();
		PixelShader = compile ps_1_4 psDx9_FSBMScaleUpBloomFilter();
	}
	
	pass FSBMPassThroughSaturateAlpha
	{
		ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		StencilEnable = FALSE;
		AlphaTestEnable = FALSE;
		VertexShader = compile vs_1_1 vsDx9_blit();
		PixelShader = compile ps_1_4 psDx9_FSBMPassThroughSaturateAlpha();
	}
	
	pass FSBMCopyOtherRGBToAlpha
	{
		ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		StencilEnable = FALSE;
		AlphaTestEnable = FALSE;
		ColorWriteEnable = ALPHA;
		
		VertexShader = compile vs_1_1 vsDx9_blit();
		PixelShader = compile ps_1_1 psDx9_FSBMCopyOtherRGBToAlpha();
		
	}
}


float4 psDx9_StencilGather(VS2PS_blit indata) : COLOR
{
	return dwStencilRef / 255.0;
}

float4 psDx9_StencilMap(VS2PS_blit indata) : COLOR
{
	float4 stencil = tex2D(sampler0point, indata.TexCoord0);
	return tex1D(sampler1point, stencil.x / 255.0);
}

technique StencilPasses
{
	pass StencilGather
	{
		ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		AlphaTestEnable = FALSE;
		
		StencilEnable = TRUE;
		StencilRef = (dwStencilRef);
		StencilFunc = EQUAL;
		StencilFail = KEEP;
		StencilZFail = KEEP;
		StencilPass = KEEP;
		
		VertexShader = compile vs_1_1 vsDx9_blit();
		PixelShader = compile ps_2_a psDx9_StencilGather();
	}

	pass StencilMap
	{
		ZEnable = FALSE;
		AlphaBlendEnable = FALSE;
		AlphaTestEnable = FALSE;
		StencilEnable = FALSE;
		
		VertexShader = compile vs_1_1 vsDx9_blit();
		PixelShader = compile ps_2_a psDx9_StencilMap();
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
		StencilRef = (dwStencilRef);
		StencilMask = 0xFF;
		StencilWriteMask = 0xFF;
		StencilFunc = EQUAL;
		StencilFail = KEEP;
		StencilZFail = KEEP;
		StencilPass = (dwStencilPass);
		TwoSidedStencilMode = FALSE;
		
		VertexShader = compile vs_1_1 vsDx9_blit();
		PixelShader = asm
		{
			ps.1.1
			def c0, 0, 0, 0, 0
			mov r0, c0
		};
	}
}
