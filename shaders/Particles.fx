
/*
	Description: Renders 2D particles
*/

#include "shaders/RealityGraphics.fxh"
#include "shaders/FXCommon.fxh"

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
	float4 Pos : TEXCOORD0;
	float4 Tex0 : TEXCOORD1; // .xy = Diffuse1; .zw = Diffuse2
	float2 HemiTex : TEXCOORD2;
	float3 Color : TEXCOORD3;
	float4 Maps : TEXCOORD4; // [LightFactor, Alpha, BlendFactor, LMOffset]
};

struct PS2FB
{
	float4 Color : COLOR;
	float Depth : DEPTH;
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

	float2 TexCoords = Input.TexCoords.xy * _OneOverShort;
	float2 Rotation = Input.Rotation * _OneOverShort;
	float4 UVOffsets = Input.UVOffsets * _OneOverShort;

	// Compute cubic polynomial factors.
	float4 CubicPolynomial = float4(pow(AgeFactor, float3(3.0, 2.0, 1.0)), 1.0);
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
	float4 Pos = mul(float4(Input.Pos.xyz, 1.0), _ViewMat);
	float Size = (SizeFactor * Template[ID].m_uvRangeLMapIntensiyAndParticleMaxSize.w) + RandomSize;
	Pos.xy = (Input.DisplaceCoords.xy * Size) + Pos.xy;

	Output.HPos = mul(Pos, _ProjMat);
	Output.Pos.xyz = Pos.xyz;
	Output.Pos.w = Output.HPos.w + 1.0; // Output depth

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

	// Hemi lookup coords
	Output.HemiTex = ((Input.Pos + (_HemiMapInfo.z * 0.5)).xz - _HemiMapInfo.xy) / _HemiMapInfo.z;	
 	Output.HemiTex.y = 1.0 - Output.HemiTex.y;

	return Output;
}

/*
	Ordinary techniques
*/

PS2FB Particle_ShowFill_PS(VS2PS Input)
{
	PS2FB Output;

	Output.Color = _EffectSunColor.rrrr;
	Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);

	return Output;
}

PS2FB Particle_Low_PS(VS2PS Input)
{
	PS2FB Output;

	float4 OutputColor = tex2D(SampleDiffuseMap, Input.Tex0.xy);
	OutputColor.rgb *= Input.Color.rgb * _EffectSunColor; // M
	OutputColor.a *= Input.Maps[1];

	ApplyFog(OutputColor.rgb, GetFogValue(Input.Pos, 0.0));

	Output.Color = OutputColor;
	Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);

	return Output;
}

PS2FB Particle_Medium_PS(VS2PS Input)
{
	PS2FB Output;

	float4 TDiffuse1 = tex2D(SampleDiffuseMap, Input.Tex0.xy);
	float4 TDiffuse2 = tex2D(SampleDiffuseMap, Input.Tex0.zw);

	float4 OutputColor = lerp(TDiffuse1, TDiffuse2, Input.Maps[2]);
	OutputColor.rgb *= GetParticleLighting(1.0, Input.Maps[3], Input.Maps[0]);
	OutputColor.rgb *= Input.Color.rgb;
	OutputColor.a *= Input.Maps[1];

	ApplyFog(OutputColor.rgb, GetFogValue(Input.Pos, 0.0));

	Output.Color = OutputColor;
	Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);

	return Output;
}

PS2FB Particle_High_PS(VS2PS Input)
{
	PS2FB Output;

	float4 TDiffuse1 = tex2D(SampleDiffuseMap, Input.Tex0.xy);
	float4 TDiffuse2 = tex2D(SampleDiffuseMap, Input.Tex0.zw);
	float4 TLUT = tex2D(SampleLUT, Input.HemiTex);

	float4 OutputColor = lerp(TDiffuse1, TDiffuse2, Input.Maps[2]);
	OutputColor.rgb *= GetParticleLighting(TLUT.a, Input.Maps[3], Input.Maps[0]);
	OutputColor.rgb *= Input.Color.rgb;
	OutputColor.a *= Input.Maps[1];

	ApplyFog(OutputColor.rgb, GetFogValue(Input.Pos, 0.0));

	Output.Color = OutputColor;
	Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);

	return Output;
}

PS2FB Particle_Low_Additive_PS(VS2PS Input)
{
	PS2FB Output;

	// Mask with alpha since were doing an add
	float4 OutputColor = tex2D(SampleDiffuseMap, Input.Tex0.xy);
	OutputColor.rgb *= Input.Color.rgb;
	OutputColor.rgb *= OutputColor.a * Input.Maps[1];

	OutputColor.rgb *= GetFogValue(Input.Pos, 0.0);

	Output.Color = OutputColor;
	Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);

	return Output;
}

PS2FB Particle_High_Additive_PS(VS2PS Input)
{
	PS2FB Output;

	float4 TDiffuse1 = tex2D(SampleDiffuseMap, Input.Tex0.xy);
	float4 TDiffuse2 = tex2D(SampleDiffuseMap, Input.Tex0.zw);

	// Mask with alpha since were doing an add
	float4 OutputColor = lerp(TDiffuse1, TDiffuse2, Input.Maps[2]);
	OutputColor.rgb *= Input.Color.rgb;
	OutputColor.rgb *= OutputColor.a * Input.Maps[1];

	OutputColor.rgb *= GetFogValue(Input.Pos, 0.0);

	Output.Color = OutputColor;
	Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);

	return Output;
}

#define GET_RENDERSTATES_PARTICLES(SRCBLEND, DESTBLEND) \
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
	SRGBWriteEnable = FALSE; \

technique ParticleShowFill
{
	pass Pass0
	{
		GET_RENDERSTATES_PARTICLES(ONE, ONE)
		VertexShader = compile vs_3_0 Particle_VS();
		PixelShader = compile ps_3_0 Particle_ShowFill_PS();
	}
}

technique ParticleLow
{
	pass Pass0
	{
		GET_RENDERSTATES_PARTICLES(SRCALPHA, INVSRCALPHA)
		VertexShader = compile vs_3_0 Particle_VS();
		PixelShader = compile ps_3_0 Particle_Low_PS();
	}
}

technique ParticleMedium
{
	pass Pass0
	{
		GET_RENDERSTATES_PARTICLES(SRCALPHA, INVSRCALPHA)
		VertexShader = compile vs_3_0 Particle_VS();
		PixelShader = compile ps_3_0 Particle_Medium_PS();
	}
}

technique ParticleHigh
{
	pass Pass0
	{
		GET_RENDERSTATES_PARTICLES(SRCALPHA, INVSRCALPHA)
		VertexShader = compile vs_3_0 Particle_VS();
		PixelShader = compile ps_3_0 Particle_High_PS();
	}
}

technique AdditiveLow
{
	pass Pass0
	{
		GET_RENDERSTATES_PARTICLES(ONE, ONE)
		VertexShader = compile vs_3_0 Particle_VS();
		PixelShader = compile ps_3_0 Particle_Low_Additive_PS();
	}
}

technique AdditiveHigh
{
	pass Pass0
	{
		GET_RENDERSTATES_PARTICLES(ONE, ONE)
		VertexShader = compile vs_3_0 Particle_VS();
		PixelShader = compile ps_3_0 Particle_High_Additive_PS();
	}
}
