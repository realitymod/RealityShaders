#include "shaders/RealityGraphics.fxh"
#include "shaders/FXCommon.fxh"
#line 4 "NonScreenAlignedParticles.fx"

/*
	Description: Renders non-flat particles
*/

// Constant array
struct TemplateParameters
{
	float4 m_uvRangeLMapIntensiyAndParticleMaxSize;
	float4 m_lightColorAndRandomIntensity;
	float4 m_color1AndLightFactor;
	float4 m_color2;
	float4 m_colorBlendGraph;
	float4 m_transparencyGraph;
	float4 m_sizeGraph;
};

// TODO: change the value 10 to the approprite max value for the current hardware, need to make this a variable
TemplateParameters Template[10] : TemplateParameters;

struct APP2VS
{
	float3 Pos : POSITION;
	float2 AgeFactorAndGraphIndex : TEXCOORD0;
	float3 RandomSizeAlphaAndIntensityBlendFactor : TEXCOORD1;
	float3 DisplaceCoords : TEXCOORD2;
	float2 IntensityAndRandomIntensity : TEXCOORD3;
	float4 RotationAndWaterSurfaceOffset : TEXCOORD4;
	float4 UVOffsets : TEXCOORD5;
	float2 TexCoords : TEXCOORD6;
};

struct VS2PS
{
	float4 HPos : POSITION;
	float4 Pos : TEXCOORD0;
	float4 Tex0 : TEXCOORD1; // .xy = Diffuse1; .zw = Diffuse2
	float3 Color : TEXCOORD2;
	float4 Maps : TEXCOORD3; // [LightFactor, Alpha, BlendFactor, LMOffset]
};

struct PS2FB
{
	float4 Color : COLOR;
	#if defined(LOG_DEPTH)
		float Depth : DEPTH;
	#endif
};

VS2PS Particle_VS(APP2VS Input)
{
	VS2PS Output = (VS2PS)0;

	// Unpack vertex attributes
	float AgeFactor = Input.AgeFactorAndGraphIndex[0];
	float ID = Input.AgeFactorAndGraphIndex[1];
	float Intensity = Input.IntensityAndRandomIntensity[0];
	float RandomIntensity = Input.IntensityAndRandomIntensity[1];
	float RandomSize = Input.RandomSizeAlphaAndIntensityBlendFactor[0];
	float Alpha = Input.RandomSizeAlphaAndIntensityBlendFactor[1];
	float IntensityBlendFactor = Input.RandomSizeAlphaAndIntensityBlendFactor[2];

	float4 Rotation = Input.RotationAndWaterSurfaceOffset * _OneOverShort;
	float2 TexCoords = Input.TexCoords * _OneOverShort;
	float4 UVOffsets = Input.UVOffsets * _OneOverShort;

	// Compute cubic polynomial factors.
	float4 CubicPolynomial = float4(pow(Input.AgeFactorAndGraphIndex[0], float3(3.0, 2.0, 1.0)), 1.0);
	float ColorBlendFactor = min(dot(Template[ID].m_colorBlendGraph, CubicPolynomial), 1.0);
	float AlphaBlendFactor = min(dot(Template[ID].m_transparencyGraph, CubicPolynomial), 1.0);
	float SizeFactor = min(dot(Template[ID].m_sizeGraph, CubicPolynomial), 1.0);

	float3 Color = lerp(Template[ID].m_color1AndLightFactor.rgb, Template[ID].m_color2.rgb, ColorBlendFactor);
	Output.Color.rgb = (Color * Intensity) + RandomIntensity;

	Output.Maps[0] = Template[ID].m_color1AndLightFactor.a;
	Output.Maps[1] = AlphaBlendFactor * Alpha;
	Output.Maps[2] = IntensityBlendFactor;
	Output.Maps[3] = saturate((Input.Pos.y - _HemiShadowAltitude) / 10.0) + Template[ID].m_uvRangeLMapIntensiyAndParticleMaxSize.z;
	Output.Maps = saturate(Output.Maps);

	// Displace vertex
	float Size = (SizeFactor * Template[ID].m_uvRangeLMapIntensiyAndParticleMaxSize.w) + RandomSize;
	float3 ScaledPos = (Input.DisplaceCoords * Size) + Input.Pos.xyz;
	ScaledPos.y += Rotation.w;

	float4 Pos = mul(float4(ScaledPos, 1.0), _ViewMat);
	Output.HPos = mul(Pos, _ProjMat);
	Output.Pos.xyz = Pos.xyz;
	#if defined(LOG_DEPTH)
		Output.Pos.w = Output.HPos.w + 1.0; // Output depth
	#endif

	// Compute texcoords
	// Rotate and scale to correct u,v space and zoom in.
	float2x2 RotationMat = { Rotation.y, Rotation.x, -Rotation.x, Rotation.y };
	float2 RotatedTexCoords = mul(TexCoords.xy, RotationMat);
	RotatedTexCoords *= Template[ID].m_uvRangeLMapIntensiyAndParticleMaxSize.xy * _UVScale;

	// Bias texcoords
	RotatedTexCoords.y = -RotatedTexCoords.y;
	RotatedTexCoords = RotatedTexCoords + Template[ID].m_uvRangeLMapIntensiyAndParticleMaxSize.xy;
	RotatedTexCoords *= 0.5;

	// Offset texcoords for particle diffuse
	Output.Tex0 = RotatedTexCoords.xyxy + UVOffsets.xyzw;

	return Output;
}

PS2FB Particle_ShowFill_PS(VS2PS Input)
{
	PS2FB Output = (PS2FB)0;

	Output.Color = _EffectSunColor.rrrr;

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);
	#endif

	return Output;
}

PS2FB Particle_Low_PS(VS2PS Input)
{
	PS2FB Output = (PS2FB)0;

	float4 OutputColor = tex2D(SampleDiffuseMap, Input.Tex0.xy);
	OutputColor.rgb *= Input.Color.rgb;
	OutputColor.a *= Input.Maps[1];

	Output.Color = OutputColor;

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);
	#endif

	ApplyFog(Output.Color.rgb, GetFogValue(Input.Pos, 0.0));

	return Output;
}

PS2FB Particle_Medium_PS(VS2PS Input)
{
	PS2FB Output = (PS2FB)0;

	float4 TDiffuse1 = tex2D(SampleDiffuseMap, Input.Tex0.xy);
	float4 TDiffuse2 = tex2D(SampleDiffuseMap, Input.Tex0.zw);

	float4 OutputColor = lerp(TDiffuse1, TDiffuse2, Input.Maps[2]);
	OutputColor.rgb *= GetParticleLighting(1.0, Input.Maps[3], Input.Maps[0]);
	OutputColor.rgb *= Input.Color.rgb;
	OutputColor.a *= Input.Maps[1];

	Output.Color = OutputColor;

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);
	#endif

	ApplyFog(Output.Color.rgb, GetFogValue(Input.Pos, 0.0));

	return Output;
}

PS2FB Particle_High_PS(VS2PS Input)
{
	PS2FB Output = (PS2FB)0;

	// Hemi lookup table coords
	float3 Pos = Input.Pos.xyz;
	float2 HemiTex = ((Pos + (_HemiMapInfo.z * 0.5)).xz - _HemiMapInfo.xy) / _HemiMapInfo.z;
	HemiTex.y = 1.0 - HemiTex.y;

	float4 TDiffuse1 = tex2D(SampleDiffuseMap, Input.Tex0.xy);
	float4 TDiffuse2 = tex2D(SampleDiffuseMap, Input.Tex0.zw);
	float4 TLut = tex2D(SampleLUT, HemiTex);

	float4 OutputColor = lerp(TDiffuse1, TDiffuse2, Input.Maps[2]);
	OutputColor.rgb *= GetParticleLighting(TLut.a, Input.Maps[3], Input.Maps[0]);
	OutputColor.rgb *= Input.Color.rgb;
	OutputColor.a *= Input.Maps[1];

	Output.Color = OutputColor;

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);
	#endif

	ApplyFog(Output.Color.rgb, GetFogValue(Input.Pos, 0.0));

	return Output;
}

// Ordinary technique

/*	int Declaration[] =
	{
		// StreamNo, DataType, Usage, UsageIdx
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_POSITION, 0 },
		{ 0, D3DDECLTYPE_FLOAT2, D3DDECLUSAGE_TEXCOORD, 0 },
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_TEXCOORD, 1 },
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_TEXCOORD, 2 },
		{ 0, D3DDECLTYPE_FLOAT2, D3DDECLUSAGE_TEXCOORD, 3 },
		{ 0, D3DDECLTYPE_SHORT4, D3DDECLUSAGE_TEXCOORD, 4 },
		{ 0, D3DDECLTYPE_SHORT4, D3DDECLUSAGE_TEXCOORD, 5 },
		{ 0, D3DDECLTYPE_SHORT2, D3DDECLUSAGE_TEXCOORD, 6 },
		DECLARATION_END	// End macro
	};
*/

#define GET_RENDERSTATES_NSAP(SRCBLEND, DESTBLEND) \
	CullMode = NONE; \
	ZEnable = TRUE; \
	ZFunc = LESSEQUAL; \
	ZWriteEnable = FALSE; \
	StencilEnable = FALSE; \
	StencilFunc = ALWAYS; \
	StencilPass = ZERO; \
	AlphaTestEnable = TRUE; \
	AlphaRef = (_AlphaPixelTestRef); \
	AlphaBlendEnable = TRUE; \
	SrcBlend = SRCBLEND; \
	DestBlend = DESTBLEND; \

technique NSAParticleShowFill
<
>
{
	pass Pass0
	{
		GET_RENDERSTATES_NSAP(ONE, ONE)
		VertexShader = compile vs_3_0 Particle_VS();
		PixelShader = compile ps_3_0 Particle_ShowFill_PS();
	}
}

technique NSAParticleLow
<
>
{
	pass Pass0
	{
		GET_RENDERSTATES_NSAP(SRCALPHA, INVSRCALPHA)
		VertexShader = compile vs_3_0 Particle_VS();
		PixelShader = compile ps_3_0 Particle_Low_PS();
	}
}

technique NSAParticleMedium
<
>
{
	pass Pass0
	{
		GET_RENDERSTATES_NSAP(SRCALPHA, INVSRCALPHA)
		VertexShader = compile vs_3_0 Particle_VS();
		PixelShader = compile ps_3_0 Particle_Medium_PS();
	}
}

technique NSAParticleHigh
<
>
{
	pass Pass0
	{
		GET_RENDERSTATES_NSAP(SRCALPHA, INVSRCALPHA)
		VertexShader = compile vs_3_0 Particle_VS();
		PixelShader = compile ps_3_0 Particle_High_PS();
	}
}
