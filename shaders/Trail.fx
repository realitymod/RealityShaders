
/*
	Description: Renders lighting for particles emit smoke trails
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

TemplateParameters Template : TemplateParameters;

struct APP2VS
{
	float3 Pos : POSITION;
	float3 LocalCoords : NORMAL0;
	float3 Tangent : NORMAL1;
	float4 IntensityAgeAnimBlendFactorAndAlpha : TEXCOORD0;
	float4 UVOffsets : TEXCOORD1;
	float2 TexCoords : TEXCOORD2;
};

struct VS2PS
{
	float4 HPos : POSITION;
	float4 Pos : TEXCOORD0;

	float4 Tex0 : TEXCOORD1; // .xy = Diffuse1; .zw = Diffuse2
	float3 Color : TEXCOORD2;
	float3 Maps : TEXCOORD3; // [AlphaBlend, AnimBlend, LMOffset]
};

struct PS2FB
{
	float4 Color : COLOR;
	float Depth : DEPTH;
};

VS2PS Trail_VS(APP2VS Input)
{
	VS2PS Output = (VS2PS)0;

	// Unpack vertex attributes
	float Intensity = Input.IntensityAgeAnimBlendFactorAndAlpha[0];
	float Age = Input.IntensityAgeAnimBlendFactorAndAlpha[1];
	float AnimBlendFactor = Input.IntensityAgeAnimBlendFactorAndAlpha[2];
	float Alpha = Input.IntensityAgeAnimBlendFactorAndAlpha[3];

	float4 UVOffsets = Input.UVOffsets * _OneOverShort;

	// Compute and age cubic polynomial factors
	float4 CubicPolynomial = float4(pow(Age, float3(3.0, 2.0, 1.0)), 1.0);
	float Size = min(dot(Template.m_sizeGraph, CubicPolynomial), 1.0) * Template.m_uvRangeLMapIntensiyAndParticleMaxSize.w;
	float ColorBlendFactor = min(dot(Template.m_colorBlendGraph, CubicPolynomial), 1.0);
	float AlphaBlendFactor = min(dot(Template.m_transparencyGraph, CubicPolynomial), 1.0) * Alpha;

	// Project eyevec to Tangent vector to get position on axis
	float3 ViewVec = _EyePos.xyz - Input.Pos.xyz;
	float TanPos = dot(ViewVec, Input.Tangent);

	// Closest point to camera
	float3 AxisVec = ViewVec - (Input.Tangent * TanPos);
	AxisVec = normalize(AxisVec);

	// Find rotation around axis
	float3 Normal = cross(Input.Tangent, -Input.LocalCoords);

	// Fade values
	float FadeIn = saturate(Age / Template.m_fadeInOutTileFactorAndUVOffsetVelocity.x);
	float FadeOut = saturate((1.0 - Age) / Template.m_fadeInOutTileFactorAndUVOffsetVelocity.y);
	float FadeFactor = dot(AxisVec, Normal);
	FadeFactor *= FadeFactor;
	FadeFactor += _FresnelOffset;
	FadeFactor *= FadeIn * FadeOut;

	// Displace vertex
	float4 Pos = mul(float4(Input.Pos.xyz + Size * (Input.LocalCoords.xyz * Input.TexCoords.y), 1.0), _ViewMat);
	Output.HPos = mul(Pos, _ProjMat);
	Output.Pos.xyz = Input.Pos.xyz;
	Output.Pos.w = Output.HPos.w; // Output depth

	Output.Color = lerp(Template.m_color1AndLightFactor.rgb, Template.m_color2.rgb, ColorBlendFactor);

	Output.Maps[0] = AlphaBlendFactor * FadeFactor;
	Output.Maps[1] = AnimBlendFactor;
	Output.Maps[2] = saturate((Input.Pos.y - _HemiShadowAltitude) / 10.0) + Template.m_uvRangeLMapIntensiyAndParticleMaxSize.z;

	// Compute texcoords for trail
	float2 RotatedTexCoords = Input.TexCoords;
	RotatedTexCoords.x -= Age * Template.m_fadeInOutTileFactorAndUVOffsetVelocity.w;
	RotatedTexCoords.xy *= Template.m_uvRangeLMapIntensiyAndParticleMaxSize.xy;
	RotatedTexCoords.x *= Template.m_fadeInOutTileFactorAndUVOffsetVelocity.z / Template.m_uvRangeLMapIntensiyAndParticleMaxSize.w;

	// Bias texcoords
	RotatedTexCoords.y = -RotatedTexCoords.y;
	RotatedTexCoords.xy += Template.m_uvRangeLMapIntensiyAndParticleMaxSize.xy;
	RotatedTexCoords.y *= 0.5;

	// Offset texcoords
	Output.Tex0 = RotatedTexCoords.xyxy + UVOffsets.xyzw;

	return Output;
}

PS2FB Trail_ShowFill_PS(VS2PS Input)
{
	PS2FB Output;

	Output.Color = _EffectSunColor.rrrr;
	Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);

	return Output;
}

PS2FB Trail_Low_PS(VS2PS Input)
{
	PS2FB Output;

	float3 LocalPos = Input.Pos.xyz;

	float4 OutputColor = tex2D(SampleDiffuseMap, Input.Tex0.xy);
	OutputColor.rgb *= Input.Color.rgb;
	OutputColor.a *= Input.Maps[0];

	ApplyFog(OutputColor.rgb, GetFogValue(LocalPos, _EyePos));

	Output.Color = OutputColor;
	Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);

	return Output;
}

PS2FB Trail_Medium_PS(VS2PS Input)
{
	PS2FB Output;

	float3 LocalPos = Input.Pos.xyz;

	float4 TDiffuse1 = tex2D(SampleDiffuseMap, Input.Tex0.xy);
	float4 TDiffuse2 = tex2D(SampleDiffuseMap, Input.Tex0.zw);

	float4 OutputColor = lerp(TDiffuse1, TDiffuse2, Input.Maps[1]);
	OutputColor.rgb *= Input.Color.rgb;
	OutputColor.rgb *= GetParticleLighting(1.0, Input.Maps[2], saturate(Template.m_color1AndLightFactor.a));
	OutputColor.a *= Input.Maps[0];

	ApplyFog(OutputColor.rgb, GetFogValue(LocalPos, _EyePos));

	Output.Color = OutputColor;
	Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);

	return Output;
}

PS2FB Trail_High_PS(VS2PS Input)
{
	PS2FB Output;

	// Hemi lookup coords
	float3 LocalPos = Input.Pos.xyz;
 	float2 HemiTex = ((LocalPos + (_HemiMapInfo.z * 0.5)).xz - _HemiMapInfo.xy) / _HemiMapInfo.z;
 	HemiTex.y = 1.0 - HemiTex.y;

	float4 TDiffuse1 = tex2D(SampleDiffuseMap, Input.Tex0.xy);
	float4 TDiffuse2 = tex2D(SampleDiffuseMap, Input.Tex0.zw);
	float4 TLUT = tex2D(SampleLUT, HemiTex);

	float4 OutputColor = lerp(TDiffuse1, TDiffuse2, Input.Maps[1]);
	OutputColor.rgb *= Input.Color.rgb;
	OutputColor.rgb *= GetParticleLighting(TLUT.a, Input.Maps[2], saturate(Template.m_color1AndLightFactor.a));
	OutputColor.a *= Input.Maps[0];

	ApplyFog(OutputColor.rgb, GetFogValue(LocalPos, _EyePos));

	Output.Color = OutputColor;
	Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);

	return Output;
}

// Ordinary technique

#define GET_RENDERSTATES_TRAIL(SRCBLEND, DESTBLEND) \
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

technique TrailShowFill
<
>
{
	pass Pass0
	{
		GET_RENDERSTATES_TRAIL(ONE, ONE)
		VertexShader = compile vs_3_0 Trail_VS();
		PixelShader = compile ps_3_0 Trail_ShowFill_PS();
	}
}

technique TrailLow
<
>
{
	pass Pass0
	{
		GET_RENDERSTATES_TRAIL(SRCALPHA, INVSRCALPHA)
		VertexShader = compile vs_3_0 Trail_VS();
		PixelShader = compile ps_3_0 Trail_Low_PS();
	}
}

technique TrailMedium
<
>
{
	pass Pass0
	{
		GET_RENDERSTATES_TRAIL(SRCALPHA, INVSRCALPHA)
		VertexShader = compile vs_3_0 Trail_VS();
		PixelShader = compile ps_3_0 Trail_Medium_PS();
	}
}

technique TrailHigh
<
>
{
	pass Pass0
	{
		GET_RENDERSTATES_TRAIL(SRCALPHA, INVSRCALPHA)
		VertexShader = compile vs_3_0 Trail_VS();
		PixelShader = compile ps_3_0 Trail_High_PS();
	}
}
