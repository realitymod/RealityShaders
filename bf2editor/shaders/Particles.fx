#line 2 "Particles.fx"

/*
	Include header files
*/

#include "shaders/RealityGraphics.fxh"
#include "shaders/shared/RealityDepth.fxh"
#include "shaders/shared/RealityDirectXTK.fxh"
#include "shaders/shared/RealityPixel.fxh"
#include "shaders/RaCommon.fxh"
#include "shaders/FXCommon.fxh"
#if !defined(_HEADERS_)
	#include "RealityGraphics.fxh"
	#include "shared/RealityDepth.fxh"
	#include "shared/RealityDirectXTK.fxh"
	#include "shared/RealityPixel.fxh"
	#include "RaCommon.fxh"
	#include "FXCommon.fxh"
#endif

/*
	Description: Renders 2D particles
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
	float2 DisplaceCoords : TEXCOORD2;
	float2 IntensityAndRandomIntensity : TEXCOORD3;
	float2 Rotation : TEXCOORD4;
	float4 UVOffsets : TEXCOORD5;
	float2 TexCoords : TEXCOORD6;
};

struct VS2PS
{
	float4 HPos : POSITION;
	float4 ViewPos : TEXCOORD0;
	float4 Tex0 : TEXCOORD1; // .xy = Diffuse1; .zw = Diffuse2
	float2 HemiTex : TEXCOORD2;
	float3 Color : TEXCOORD3;
	float4 Maps : TEXCOORD4; // [LightMapBlend, Alpha, IntensityBlend, LightMapOffset]
};

struct PS2FB
{
	float4 Color : COLOR0;
};

/*
	[Vertex Shaders]
*/

VS2PS VS_Particle(APP2VS Input)
{
	VS2PS Output = (VS2PS)0.0;

	// Unpack vertex attributes
	float AgeFactor = Input.AgeFactorAndGraphIndex[0];
	float ID = Input.AgeFactorAndGraphIndex[1];
	float Intensity = Input.IntensityAndRandomIntensity[0];
	float RandomIntensity = Input.IntensityAndRandomIntensity[1];
	float RandomSize = Input.RandomSizeAlphaAndIntensityBlendFactor[0];
	float Alpha = Input.RandomSizeAlphaAndIntensityBlendFactor[1];
	float IntensityBlendFactor = Input.RandomSizeAlphaAndIntensityBlendFactor[2];

	float2 TexCoords = DECODE_SHORT(Input.TexCoords.xy);
	float2 Rotation = DECODE_SHORT(Input.Rotation);
	float4 UVOffsets = DECODE_SHORT(Input.UVOffsets);

	// Compute cubic polynomial factors.
	float4 CubicPolynomial = float4(pow(AgeFactor, float3(3.0, 2.0, 1.0)), 1.0);
	float ColorBlendFactor = min(dot(Template[ID].m_colorBlendGraph, CubicPolynomial), 1.0);
	float AlphaBlendFactor = min(dot(Template[ID].m_transparencyGraph, CubicPolynomial), 1.0);
	float SizeFactor = min(dot(Template[ID].m_sizeGraph, CubicPolynomial), 1.0);

	float3 Color = lerp(Template[ID].m_color1AndLightFactor.rgb, Template[ID].m_color2.rgb, ColorBlendFactor);
	Output.Color.rgb = (Color * Intensity) + RandomIntensity;

	// Displace vertex
	float3 WorldPos = Input.Pos.xyz;
	float4 ViewPos = mul(float4(WorldPos, 1.0), _ViewMat);
	float Size = (SizeFactor * Template[ID].m_uvRangeLMapIntensiyAndParticleMaxSize.w) + RandomSize;
	ViewPos.xy += (Input.DisplaceCoords.xy * Size);

	Output.HPos = mul(ViewPos, _ProjMat);
	Output.ViewPos = float4(ViewPos.xyz, Output.HPos.w);

	// Output vertex factors
	Output.Maps[0] = Template[ID].m_color1AndLightFactor.a;
	Output.Maps[1] = AlphaBlendFactor * Alpha;
	Output.Maps[2] = IntensityBlendFactor;
	Output.Maps[3] = GetAltitude(WorldPos, Template[ID].m_uvRangeLMapIntensiyAndParticleMaxSize.z);
	Output.Maps = saturate(Output.Maps);

	// Compute texcoords
	// Rotate and scale to correct u,v space and zoom in.
	float2x2 RotationMat = { Rotation.y, Rotation.x, -Rotation.x, Rotation.y };
	float2 RotatedTexCoords = mul(TexCoords.xy, RotationMat);
	RotatedTexCoords *= Template[ID].m_uvRangeLMapIntensiyAndParticleMaxSize.xy * _UVScale;

	// Bias texcoords
	RotatedTexCoords.y = -RotatedTexCoords.y;
	RotatedTexCoords = RotatedTexCoords + Template[ID].m_uvRangeLMapIntensiyAndParticleMaxSize.xy;
	RotatedTexCoords *= 0.5;

	// Offset texcoords
	Output.Tex0 = RotatedTexCoords.xyxy + UVOffsets.xyzw;
	Output.HemiTex = RPixel_GetHemiTex(WorldPos, 0.0, _HemiMapInfo.xyz, true);

	// Output Depth
	#if defined(LOG_DEPTH)
		Output.HPos.z = RDepth_ApplyLogarithmicDepth(Output.HPos.w + 1.0) * Output.HPos.w;
	#endif

	return Output;
}

/*
	[Pixel Shaders]
*/

struct VFactors
{
	float LightMapBlend;
	float AlphaBlend;
	float IntensityBlend;
	float LightMapOffset;
};

VFactors GetVFactors(VS2PS Input)
{
	VFactors Output = (VFactors)0.0;
	Output.LightMapBlend = Input.Maps[0];
	Output.AlphaBlend = Input.Maps[1];
	Output.IntensityBlend = Input.Maps[2];
	Output.LightMapOffset = Input.Maps[3];
	return Output;
}

PS2FB PS_Particle_ShowFill(VS2PS Input)
{
	PS2FB Output = (PS2FB)0.0;
	Output.Color = _EffectSunColor.rrrr;
	return Output;
}

PS2FB PS_Particle_Low(VS2PS Input)
{
	PS2FB Output = (PS2FB)0.0;

	// Get vertex attributes
	VFactors VF = GetVFactors(Input);

	// Get diffuse map
	float4 DiffuseMap = RDirectXTK_SRGBToLinearEst(tex2D(SampleDiffuseMap, Input.Tex0.xy));

	// Apply lighting
	float4 LightColor = float4(Input.Color.rgb * _EffectSunColor.rgb, VF.AlphaBlend);
	float4 OutputColor = DiffuseMap * LightColor;

	Output.Color = OutputColor;
	ApplyFog(Output.Color.rgb, GetFogValue(Input.ViewPos, 0.0));
	RDirectXTK_TonemapAndLinearToSRGBEst(Output.Color);

	return Output;
}

PS2FB PS_Particle_Medium(VS2PS Input)
{
	PS2FB Output = (PS2FB)0.0;

	// Get vertex attributes
	VFactors VF = GetVFactors(Input);

	// Get diffuse map
	float4 TDiffuse1 = RDirectXTK_SRGBToLinearEst(tex2D(SampleDiffuseMap, Input.Tex0.xy));
	float4 TDiffuse2 = RDirectXTK_SRGBToLinearEst(tex2D(SampleDiffuseMap, Input.Tex0.zw));
	float4 DiffuseMap = lerp(TDiffuse1, TDiffuse2, VF.IntensityBlend);

	// Apply lighting
	float3 Lighting = GetParticleLighting(1.0, VF.LightMapOffset, VF.LightMapBlend);
	float4 LightColor = float4(Input.Color.rgb * Lighting, VF.AlphaBlend);
	float4 OutputColor = DiffuseMap * LightColor;

	Output.Color = OutputColor;
	ApplyFog(Output.Color.rgb, GetFogValue(Input.ViewPos, 0.0));
	RDirectXTK_TonemapAndLinearToSRGBEst(Output.Color);

	return Output;
}

PS2FB PS_Particle_High(VS2PS Input)
{
	PS2FB Output = (PS2FB)0.0;

	// Get vertex attributes
	VFactors VF = GetVFactors(Input);

	// Get diffuse map
	float4 TDiffuse1 = RDirectXTK_SRGBToLinearEst(tex2D(SampleDiffuseMap, Input.Tex0.xy));
	float4 TDiffuse2 = RDirectXTK_SRGBToLinearEst(tex2D(SampleDiffuseMap, Input.Tex0.zw));
	float4 DiffuseMap = lerp(TDiffuse1, TDiffuse2, VF.IntensityBlend);

	// Get hemi map
	float4 HemiMap = RDirectXTK_SRGBToLinearEst(tex2D(SampleLUT, Input.HemiTex));

	// Apply lighting
	float3 Lighting = GetParticleLighting(HemiMap.a, VF.LightMapOffset, VF.LightMapBlend);
	float4 LightColor = float4(Input.Color.rgb * Lighting, VF.AlphaBlend);
	float4 OutputColor = DiffuseMap * LightColor;

	Output.Color = OutputColor;
	ApplyFog(Output.Color.rgb, GetFogValue(Input.ViewPos, 0.0));
	RDirectXTK_TonemapAndLinearToSRGBEst(Output.Color);

	return Output;
}

PS2FB PS_Particle_Low_Additive(VS2PS Input)
{
	PS2FB Output = (PS2FB)0.0;

	// Get vertex attributes
	VFactors VF = GetVFactors(Input);

	// Textures
	float4 DiffuseMap = RDirectXTK_SRGBToLinearEst(tex2D(SampleDiffuseMap, Input.Tex0.xy));

	// Lighting | Mask with alpha since were doing an add
	float4 OutputColor = DiffuseMap * float4(Input.Color.rgb, VF.AlphaBlend);

	Output.Color = OutputColor;
	RDirectXTK_TonemapAndLinearToSRGBEst(Output.Color);
	Output.Color.a *= GetFogValue(Input.ViewPos, 0.0);

	return Output;
}

PS2FB PS_Particle_High_Additive(VS2PS Input)
{
	PS2FB Output = (PS2FB)0.0;

	// Get vertex attributes
	VFactors VF = GetVFactors(Input);

	// Textures
	float4 TDiffuse1 = RDirectXTK_SRGBToLinearEst(tex2D(SampleDiffuseMap, Input.Tex0.xy));
	float4 TDiffuse2 = RDirectXTK_SRGBToLinearEst(tex2D(SampleDiffuseMap, Input.Tex0.zw));
	float4 DiffuseMap = lerp(TDiffuse1, TDiffuse2, VF.IntensityBlend);

	// Lighting | Mask with alpha since were doing an add
	float4 OutputColor = DiffuseMap * float4(Input.Color.rgb, VF.AlphaBlend);

	Output.Color = OutputColor;
	RDirectXTK_TonemapAndLinearToSRGBEst(Output.Color);
	Output.Color.a *= GetFogValue(Input.ViewPos, 0.0);

	return Output;
}

#define GET_RENDERSTATES_PARTICLES(SRCBLEND, DESTBLEND) \
	CullMode = NONE; \
	ZEnable = TRUE; \
	ZFunc = PR_ZFUNC_WITHEQUAL; \
	ZWriteEnable = FALSE; \
	StencilEnable = FALSE; \
	StencilFunc = ALWAYS; \
	StencilPass = ZERO; \
	AlphaBlendEnable = TRUE; \
	SrcBlend = SRCBLEND; \
	DestBlend = DESTBLEND; \

technique ParticleShowFill
{
	pass p0
	{
		GET_RENDERSTATES_PARTICLES(ONE, ONE)
		VertexShader = compile vs_3_0 VS_Particle();
		PixelShader = compile ps_3_0 PS_Particle_ShowFill();
	}
}

technique ParticleLow
{
	pass p0
	{
		GET_RENDERSTATES_PARTICLES(SRCALPHA, INVSRCALPHA)
		VertexShader = compile vs_3_0 VS_Particle();
		PixelShader = compile ps_3_0 PS_Particle_Low();
	}
}

technique ParticleMedium
{
	pass p0
	{
		GET_RENDERSTATES_PARTICLES(SRCALPHA, INVSRCALPHA)
		VertexShader = compile vs_3_0 VS_Particle();
		PixelShader = compile ps_3_0 PS_Particle_Medium();
	}
}

technique ParticleHigh
{
	pass p0
	{
		GET_RENDERSTATES_PARTICLES(SRCALPHA, INVSRCALPHA)
		VertexShader = compile vs_3_0 VS_Particle();
		PixelShader = compile ps_3_0 PS_Particle_High();
	}
}

technique AdditiveLow
{
	pass p0
	{
		GET_RENDERSTATES_PARTICLES(SRCALPHA, ONE)
		VertexShader = compile vs_3_0 VS_Particle();
		PixelShader = compile ps_3_0 PS_Particle_Low_Additive();
	}
}

technique AdditiveHigh
{
	pass p0
	{
		GET_RENDERSTATES_PARTICLES(SRCALPHA, ONE)
		VertexShader = compile vs_3_0 VS_Particle();
		PixelShader = compile ps_3_0 PS_Particle_High_Additive();
	}
}
