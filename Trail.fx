
/*
	Description: Renders lighting for particles that trail
*/

#include "shaders/RealityGraphics.fxh"

#include "shaders/FXCommon.fxh"

// UNIFORM INPUTS

uniform float3 _EyePos : EyePos;
uniform float _FresnelOffset : FresnelOffset = 0;

// constant array
struct TemplateParameters
{
	float4 m_uvRangeLMapIntensiyAndParticleMaxSize;
	float4 m_fadeInOutTileFactorAndUVOffsetVelocity;
	float4 m_color1AndLightFactor;
	float4 m_color2;
	float4 m_colorBlendGraph;
	float4 m_transparencyGraph;
	float4 m_sizeGraph;
};

TemplateParameters TParameters : TemplateParameters;

struct APP2VS
{
	float3 Pos : POSITION;
	float3 LocalCoords : NORMAL0;
	float3 Tangent : NORMAL1;
	float4 IntensityAgeAnimBlendFactorAndAlpha : TEXCOORD0;
	float4 UVOffsets : TEXCOORD1;
	float2 TexCoords : TEXCOORD2;
};

struct VS2PS_Trail
{
	float4 HPos : POSITION;
	float4 Color : TEXCOORD0;
	float4 DiffuseCoords : TEXCOORD1; // .xy = Diffuse1; .zw = Diffuse2
	float2 HemiLUTCoord : TEXCOORD2;
	float3 VertexPos : TEXCOORD3;

	float3 AnimBFactorAndLMapIntOffset : COLOR0;
	float4 LightFactorAndAlpha : COLOR1;
};

VS2PS_Trail Trail_VS(APP2VS Input)
{
	VS2PS_Trail Output = (VS2PS_Trail)0;

	// Compute Cubic polynomial factors.
	float Age = Input.IntensityAgeAnimBlendFactorAndAlpha[1];

	// FADE values
	float FadeIn = saturate(Age/TParameters.m_fadeInOutTileFactorAndUVOffsetVelocity.x);
	float FadeOut = saturate((1.0f - Age) / TParameters.m_fadeInOutTileFactorAndUVOffsetVelocity.y);
	float3 ViewVec = _EyePos.xyz - Input.Pos.xyz;

	// Project eyevec to Tangent vector to get position on axis
	float TanPos = dot(ViewVec, Input.Tangent);

	// Closest point to camera
	float3 AxisVec = ViewVec - (Input.Tangent * TanPos);
	AxisVec = normalize(AxisVec);

	// Find rotation around axis
	float3 Normal = cross(Input.Tangent, -Input.LocalCoords);
	float FadeFactor = dot(AxisVec, Normal);
	FadeFactor *= FadeFactor;
	FadeFactor += _FresnelOffset;
	FadeFactor *= FadeIn * FadeOut;

	// Age factor polynomials
	float4 PC = float4(pow(Age, float3(3.0, 2.0, 1.0)), 1.0);

	// Compute size of particle using the constants of the Template[Input.ageFactorAndGraphIndex.y]ate (mSizeGraph)
	float Size = min(dot(TParameters.m_sizeGraph, PC), 1.0) * TParameters.m_uvRangeLMapIntensiyAndParticleMaxSize.w;

	// Displace vertex
	float4 Pos = mul(float4(Input.Pos.xyz + Size * (Input.LocalCoords.xyz * Input.TexCoords.y), 1.0), _ViewMat);
	Output.HPos = mul(Pos, _ProjMat);

	float ColorBlendFactor = min(dot(TParameters.m_colorBlendGraph, PC), 1.0);
	float3 Color = ColorBlendFactor * TParameters.m_color2.rgb;
	Color += (1.0 - ColorBlendFactor) * TParameters.m_color1AndLightFactor.rgb;

	float AlphaBlendFactor = min(dot(TParameters.m_transparencyGraph, PC), 1.0) * Input.IntensityAgeAnimBlendFactorAndAlpha[3];
	AlphaBlendFactor *= FadeFactor;

	Output.Color.rgb = Color;
	Output.LightFactorAndAlpha.b = AlphaBlendFactor;
 	Output.LightFactorAndAlpha.a = TParameters.m_color1AndLightFactor.a;
	Output.LightFactorAndAlpha = saturate(Output.LightFactorAndAlpha);

	Output.AnimBFactorAndLMapIntOffset.x = Input.IntensityAgeAnimBlendFactorAndAlpha[2];
	float LightMapIntensity = saturate(saturate((Input.Pos.y - _HemiShadowAltitude) / 10.0f) + TParameters.m_uvRangeLMapIntensiyAndParticleMaxSize.z);
	Output.AnimBFactorAndLMapIntOffset.yz = LightMapIntensity;
	Output.AnimBFactorAndLMapIntOffset = saturate(Output.AnimBFactorAndLMapIntOffset);

	// Compute texcoords for trail
	float2 RotatedTexCoords = Input.TexCoords;

	RotatedTexCoords.x -= Age * TParameters.m_fadeInOutTileFactorAndUVOffsetVelocity.w;
	RotatedTexCoords *= TParameters.m_uvRangeLMapIntensiyAndParticleMaxSize.xy;
	RotatedTexCoords.x *= TParameters.m_fadeInOutTileFactorAndUVOffsetVelocity.z / TParameters.m_uvRangeLMapIntensiyAndParticleMaxSize.w;

	// Bias texcoords
	RotatedTexCoords.x += TParameters.m_uvRangeLMapIntensiyAndParticleMaxSize.x;
	RotatedTexCoords.y = TParameters.m_uvRangeLMapIntensiyAndParticleMaxSize.y - RotatedTexCoords.y;
	RotatedTexCoords.y *= 0.5f;

	// Offset texcoords
	float4 UVOffsets = Input.UVOffsets * _OneOverShort;
	Output.DiffuseCoords = RotatedTexCoords.xyxy + UVOffsets.xyzw;

	// Hemi lookup coords
 	Output.HemiLUTCoord.xy = ((Input.Pos + (_HemiMapInfo.z / 2.0)).xz - _HemiMapInfo.xy) / _HemiMapInfo.z;
 	Output.HemiLUTCoord.y = 1.0 - Output.HemiLUTCoord.y;

	Output.VertexPos = Input.Pos.xyz;

	return Output;
}

// Ordinary technique

/*	int Declaration[] =
	{
		// StreamNo, DataType, Usage, UsageIdx
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_POSITION, 0 },
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_NORMAL, 0 },
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_NORMAL, 1 },
		{ 0, D3DDECLTYPE_FLOAT4, D3DDECLUSAGE_TEXCOORD, 0 },
		{ 0, D3DDECLTYPE_SHORT4, D3DDECLUSAGE_TEXCOORD, 1 },
		{ 0, D3DDECLTYPE_FLOAT2, D3DDECLUSAGE_TEXCOORD, 2 },
		DECLARATION_END	// End macro
	};
*/

float4 Trail_Low_PS(VS2PS_Trail Input) : COLOR
{
	float4 OutputColor = tex2D(SampleDiffuseMap, Input.DiffuseCoords.xy);
	OutputColor.rgb *= Input.Color.rgb;
	OutputColor.a *= Input.LightFactorAndAlpha.b;

	ApplyFog(OutputColor.rgb, GetFogValue(Input.VertexPos.xyz, _EyePos.xyz));
	return OutputColor;
}

technique TrailLow
<
>
{
	pass Pass0
	{
		CullMode = NONE;

		ZEnable = TRUE;
		ZFunc = LESSEQUAL;
		ZWriteEnable = FALSE;

		StencilEnable = FALSE;
		StencilFunc = ALWAYS;
		StencilPass = ZERO;

		AlphaTestEnable = TRUE;
		AlphaRef = <_AlphaPixelTestRef>;

		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		SRGBWriteEnable = FALSE;

		VertexShader = compile vs_3_0 Trail_VS();
		PixelShader = compile ps_3_0 Trail_Low_PS();
	}
}

float4 Trail_Medium_PS(VS2PS_Trail Input) : COLOR
{
	float4 TDiffuse1 = tex2D(SampleDiffuseMap, Input.DiffuseCoords.xy);
	float4 TDiffuse2 = tex2D(SampleDiffuseMap, Input.DiffuseCoords.zw);

	float4 OutputColor = lerp(TDiffuse1, TDiffuse2, Input.AnimBFactorAndLMapIntOffset.x);
	OutputColor.rgb *= Input.Color.rgb;
	OutputColor.rgb *= GetParticleLighting(1, Input.AnimBFactorAndLMapIntOffset.z, Input.LightFactorAndAlpha.a);
	OutputColor.a *= Input.LightFactorAndAlpha.b;

	ApplyFog(OutputColor.rgb, GetFogValue(Input.VertexPos.xyz, _EyePos.xyz));
	return OutputColor;
}

technique TrailMedium
<
>
{
	pass Pass0
	{
		CullMode = NONE;

		ZEnable = TRUE;
		ZFunc = LESSEQUAL;
		ZWriteEnable = FALSE;

		StencilEnable = FALSE;
		StencilFunc = ALWAYS;
		StencilPass = ZERO;

		AlphaTestEnable = TRUE;
		AlphaRef = <_AlphaPixelTestRef>;

		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		SRGBWriteEnable = FALSE;

		VertexShader = compile vs_3_0 Trail_VS();
		PixelShader = compile ps_3_0 Trail_Medium_PS();
	}
}

float4 Trail_High_PS(VS2PS_Trail Input) : COLOR
{
	float4 TDiffuse1 = tex2D(SampleDiffuseMap, Input.DiffuseCoords.xy);
	float4 TDiffuse2 = tex2D(SampleDiffuseMap, Input.DiffuseCoords.zw);
	float4 TLUT = tex2D(SampleLUT, Input.HemiLUTCoord.xy);

	float4 OutputColor = lerp(TDiffuse1, TDiffuse2, Input.AnimBFactorAndLMapIntOffset.x);
	OutputColor.rgb *= Input.Color.rgb;
	OutputColor.rgb *= GetParticleLighting(TLUT.a, Input.AnimBFactorAndLMapIntOffset.z, Input.LightFactorAndAlpha.a);
	OutputColor.a *= Input.LightFactorAndAlpha.b;

	ApplyFog(OutputColor.rgb, GetFogValue(Input.VertexPos.xyz, _EyePos.xyz));
	return OutputColor;
}

technique TrailHigh
<
>
{
	pass Pass0
	{
		CullMode = NONE;

		ZEnable = TRUE;
		ZFunc = LESSEQUAL;
		ZWriteEnable = FALSE;

		StencilEnable = FALSE;
		StencilFunc = ALWAYS;
		StencilPass = ZERO;

		AlphaTestEnable = TRUE;
		AlphaRef = <_AlphaPixelTestRef>;

		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		SRGBWriteEnable = FALSE;

		VertexShader = compile vs_3_0 Trail_VS();
		PixelShader = compile ps_3_0 Trail_High_PS();
	}
}

float4 Trail_Show_Fill_PS(VS2PS_Trail Input) : COLOR
{
	float4 OutputColor = _EffectSunColor.rrrr;
	ApplyFog(OutputColor.rgb, GetFogValue(Input.VertexPos.xyz, _EyePos.xyz));
	return OutputColor;
}

technique TrailShowFill
<
>
{
	pass Pass0
	{
		CullMode = NONE;

		ZEnable = TRUE;
		ZFunc = LESSEQUAL;
		ZWriteEnable = FALSE;

		StencilEnable = FALSE;
		StencilFunc = ALWAYS;
		StencilPass = ZERO;

		AlphaTestEnable = TRUE;
		AlphaRef = <_AlphaPixelTestRef>;

		AlphaBlendEnable = TRUE;
		SrcBlend = ONE;
		DestBlend = ONE;

		VertexShader = compile vs_3_0 Trail_VS();
		PixelShader = compile ps_3_0 Trail_Show_Fill_PS();
	}
}
