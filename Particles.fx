
/*
	Description: Renders static particles
*/

#include "shaders/RealityGraphics.fxh"

#include "shaders/FXCommon.fxh"

// UNIFORM INPUTS
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
TemplateParameters _Temps[10] : TemplateParameters;

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

struct VS2PS_Particle
{
	float4 HPos : POSITION;
	float4 Color : TEXCOORD0;
	float4 DiffuseCoords : TEXCOORD1; // .xy = Diffuse1; .zw = Diffuse2
	float2 HemiLUTCoord : TEXCOORD2;
	float3 VertexPos : TEXCOORD3;

	float4 LightFactorAndAlphaBlend	: COLOR0;
	float4 AnimBFactorAndLMapIntOffset : COLOR1;
};

VS2PS_Particle Particle_VS(APP2VS Input)
{
	VS2PS_Particle Output = (VS2PS_Particle)0;

	float4 Pos = mul(float4(Input.Pos.xyz, 1.0), _ViewMat);

	// Compute Cubic polynomial factors.
	float4 PC = float4(pow(Input.AgeFactorAndGraphIndex[0], float3(3.0, 2.0, 1.0)), 1.0);

	float ColorBlendFactor = min(dot(_Temps[Input.AgeFactorAndGraphIndex.y].m_colorBlendGraph, PC), 1.0);
	float3 Color = ColorBlendFactor * _Temps[Input.AgeFactorAndGraphIndex.y].m_color2.rgb;
	Color += (1.0 - ColorBlendFactor) * _Temps[Input.AgeFactorAndGraphIndex.y].m_color1AndLightFactor.rgb;
	Output.Color.rgb = (Color * Input.IntensityAndRandomIntensity[0]) + Input.IntensityAndRandomIntensity[1];

	float AlphaBlendFactor = min(dot(_Temps[Input.AgeFactorAndGraphIndex.y].m_transparencyGraph, PC), 1);
	Output.LightFactorAndAlphaBlend.a = _Temps[Input.AgeFactorAndGraphIndex.y].m_color1AndLightFactor.a;
	Output.LightFactorAndAlphaBlend.b = AlphaBlendFactor * Input.RandomSizeAlphaAndIntensityBlendFactor[1];
	Output.LightFactorAndAlphaBlend = saturate(Output.LightFactorAndAlphaBlend);

	Output.AnimBFactorAndLMapIntOffset.a = Input.RandomSizeAlphaAndIntensityBlendFactor[2];
	Output.AnimBFactorAndLMapIntOffset.b = saturate(saturate((Input.Pos.y - _HemiShadowAltitude) / 10.0f) + _Temps[Input.AgeFactorAndGraphIndex.y].m_uvRangeLMapIntensiyAndParticleMaxSize.z);
	Output.AnimBFactorAndLMapIntOffset = saturate(Output.AnimBFactorAndLMapIntOffset);

	// Compute size of particle using the constants of the _Temps[Input.AgeFactorAndGraphIndex.y]ate (mSizeGraph)
	float Size = min(dot(_Temps[Input.AgeFactorAndGraphIndex.y].m_sizeGraph, PC), 1.0) * _Temps[Input.AgeFactorAndGraphIndex.y].m_uvRangeLMapIntensiyAndParticleMaxSize.w;
	Size += Input.RandomSizeAlphaAndIntensityBlendFactor.x;

	// Displace vertex
	float2 Rotation = Input.Rotation * _OneOverShort;
	Pos.xy = (Input.DisplaceCoords.xy * Size) + Pos.xy;
	Output.HPos = mul(Pos, _ProjMat);

	// Compute texcoords
	// Rotate and scale to correct u,v space and zoom in.
	float2 TexCoords = Input.TexCoords.xy * _OneOverShort;
	float2 RotatedTexCoords = float2(TexCoords.x * Rotation.y - TexCoords.y * Rotation.x, TexCoords.x * Rotation.x + TexCoords.y * Rotation.y);
	RotatedTexCoords *= _Temps[Input.AgeFactorAndGraphIndex.y].m_uvRangeLMapIntensiyAndParticleMaxSize.xy * _UVScale;

	// Bias texcoords
	RotatedTexCoords.x += _Temps[Input.AgeFactorAndGraphIndex.y].m_uvRangeLMapIntensiyAndParticleMaxSize.x;
	RotatedTexCoords.y = _Temps[Input.AgeFactorAndGraphIndex.y].m_uvRangeLMapIntensiyAndParticleMaxSize.y - RotatedTexCoords.y;
	RotatedTexCoords *= 0.5f;

	// Offset texcoords
	float4 UVOffsets = Input.UVOffsets * _OneOverShort;
	Output.DiffuseCoords = RotatedTexCoords.xyxy + UVOffsets.xyzw;

	// Hemi lookup coords
	Output.HemiLUTCoord.xy = ((Input.Pos + (_HemiMapInfo.z / 2.0)).xz - _HemiMapInfo.xy) / _HemiMapInfo.z;
	Output.HemiLUTCoord.y = 1.0 - Output.HemiLUTCoord.y;

	Output.VertexPos = Pos.xyz;

	return Output;
}

/*
	Ordinary techniques
*/

float4 Particle_Low_PS(VS2PS_Particle Input) : COLOR
{
	float4 Color = tex2D(SampleDiffuseMap, Input.DiffuseCoords.xy);
	Color.rgb *= Input.Color.rgb * _EffectSunColor; // M
	Color.a *= Input.LightFactorAndAlphaBlend.b;

	ApplyFog(Color.rgb, GetFogValue(Input.VertexPos, 0.0));
	return Color;
}

float4 Particle_Medium_PS(VS2PS_Particle Input) : COLOR
{
	float4 TDiffuse1 = tex2D(SampleDiffuseMap, Input.DiffuseCoords.xy);
	float4 TDiffuse2 = tex2D(SampleDiffuseMap, Input.DiffuseCoords.zw);
	float4 OutputColor = lerp(TDiffuse1, TDiffuse2, Input.AnimBFactorAndLMapIntOffset.a);
	OutputColor.rgb *= GetParticleLighting(1.0, Input.AnimBFactorAndLMapIntOffset.b, Input.LightFactorAndAlphaBlend.a);
	OutputColor.rgb *= Input.Color.rgb;
	OutputColor.a *= Input.LightFactorAndAlphaBlend.b;

	ApplyFog(OutputColor.rgb, GetFogValue(Input.VertexPos, 0.0));
	return OutputColor;
}

float4 Particle_High_PS(VS2PS_Particle Input) : COLOR
{
	float4 TDiffuse1 = tex2D(SampleDiffuseMap, Input.DiffuseCoords.xy);
	float4 TDiffuse2 = tex2D(SampleDiffuseMap, Input.DiffuseCoords.zw);
	float4 TLUT = tex2D(SampleLUT, Input.HemiLUTCoord.xy);
	float4 Color = lerp(TDiffuse1, TDiffuse2, Input.AnimBFactorAndLMapIntOffset.a);
	Color.rgb *= GetParticleLighting(TLUT.a, Input.AnimBFactorAndLMapIntOffset.b, Input.LightFactorAndAlphaBlend.a);
	Color.rgb *= Input.Color.rgb;
	Color.a *= Input.LightFactorAndAlphaBlend.b;

	ApplyFog(Color.rgb, GetFogValue(Input.VertexPos, 0.0));
	return Color;
}

#define COMMON_RENDERSTATES_PARTICLE \
	CullMode = NONE; \
	ZEnable = TRUE; \
	ZFunc = LESSEQUAL; \
	ZWriteEnable = FALSE; \
	StencilEnable = FALSE; \
	StencilFunc = ALWAYS; \
	StencilPass = ZERO; \
	AlphaTestEnable = TRUE; \
	AlphaRef = <_AlphaPixelTestRef>; \
	AlphaBlendEnable = TRUE; \
	SrcBlend = SRCALPHA; \
	DestBlend = INVSRCALPHA; \
	SRGBWriteEnable = FALSE; \

technique ParticleLow
<
>
{
	pass Pass0
	{
		COMMON_RENDERSTATES_PARTICLE
		VertexShader = compile vs_3_0 Particle_VS();
		PixelShader = compile ps_3_0 Particle_Low_PS();
	}
}

technique ParticleMedium
<
>
{
	pass Pass0
	{
		COMMON_RENDERSTATES_PARTICLE
		VertexShader = compile vs_3_0 Particle_VS();
		PixelShader = compile ps_3_0 Particle_Medium_PS();
	}
}

technique ParticleHigh
<
>
{
	pass Pass0
	{
		COMMON_RENDERSTATES_PARTICLE
		VertexShader = compile vs_3_0 Particle_VS();
		PixelShader = compile ps_3_0 Particle_High_PS();
	}
}




float4 Particle_Show_Fill_PS(VS2PS_Particle Input) : COLOR
{
	float4 OutputColor = _EffectSunColor.rrrr;
	OutputColor.rgb *= GetFogValue(Input.VertexPos, 0.0);
	return OutputColor;
}

float4 Particle_Additive_Low_PS(VS2PS_Particle Input) : COLOR
{
	float4 Color = tex2D(SampleDiffuseMap, Input.DiffuseCoords.xy);
	Color.rgb *= Input.Color.rgb;

	// Mask with alpha since were doing an add
	Color.rgb *= Color.a * Input.LightFactorAndAlphaBlend.b;

	Color.rgb *= GetFogValue(Input.VertexPos, 0.0);
	return Color;
}

float4 Particle_Additive_High_PS(VS2PS_Particle Input) : COLOR
{
	float4 TDiffuse1 = tex2D(SampleDiffuseMap, Input.DiffuseCoords.xy);
	float4 TDiffuse2 = tex2D(SampleDiffuseMap, Input.DiffuseCoords.zw);
	float4 OutputColor = lerp(TDiffuse1, TDiffuse2, Input.AnimBFactorAndLMapIntOffset.a);
	OutputColor.rgb *= Input.Color.rgb;
	// Mask with alpha since were doing an add
	OutputColor.rgb *= OutputColor.a * Input.LightFactorAndAlphaBlend.b;

	OutputColor.rgb *= GetFogValue(Input.VertexPos, 0.0);
	return OutputColor;
}

#define COMMON_RENDERSTATES_PARTICLE_ADDITIVE \
	CullMode = NONE; \
	ZEnable = TRUE; \
	ZFunc = LESSEQUAL; \
	ZWriteEnable = FALSE; \
	StencilEnable = FALSE; \
	StencilFunc = ALWAYS; \
	StencilPass = ZERO; \
	AlphaTestEnable = TRUE; \
	AlphaRef = <_AlphaPixelTestRef>; \
	AlphaBlendEnable = TRUE; \
	SrcBlend = ONE; \
	DestBlend = ONE; \
	SRGBWriteEnable = FALSE; \

technique ParticleShowFill
<
>
{
	pass Pass0
	{
		COMMON_RENDERSTATES_PARTICLE_ADDITIVE
		VertexShader = compile vs_3_0 Particle_VS();
		PixelShader = compile ps_3_0 Particle_Show_Fill_PS();
	}
}

technique AdditiveLow
<
>
{
	pass Pass0
	{
		COMMON_RENDERSTATES_PARTICLE_ADDITIVE
		VertexShader = compile vs_3_0 Particle_VS();
		PixelShader = compile ps_3_0 Particle_Additive_Low_PS();
	}
}

technique AdditiveHigh
<
>
{
	pass Pass0
	{
		COMMON_RENDERSTATES_PARTICLE_ADDITIVE
		VertexShader = compile vs_3_0 Particle_VS();
		PixelShader = compile ps_3_0 Particle_Additive_High_PS();
	}
}
