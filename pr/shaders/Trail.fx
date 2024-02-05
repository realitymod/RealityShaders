
/*
	Include header files
*/

#include "shaders/RealityGraphics.fxh"
#include "shaders/shared/RealityDepth.fxh"
#include "shaders/shared/RealityPixel.fxh"
#include "shaders/RaCommon.fxh"
#include "shaders/FXCommon.fxh"
#if !defined(_HEADERS_)
	#include "RealityGraphics.fxh"
	#include "shared/RealityDepth.fxh"
	#include "shared/RealityPixel.fxh"
	#include "RaCommon.fxh"
	#include "FXCommon.fxh"
#endif

/*
	Description: Renders lighting for particles emit smoke trails
*/

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
	float4 WorldPos : TEXCOORD0;
	float3 Color : TEXCOORD1;

	float4 Tex0 : TEXCOORD2; // .xy = Diffuse1; .zw = Diffuse2
	float3 Maps : TEXCOORD3; // [AlphaBlend, AnimBlend, LMOffset]
};

struct PS2FB
{
	float4 Color : COLOR0;
	#if defined(LOG_DEPTH)
		float Depth : DEPTH;
	#endif
};

/*
	[Vertex Shaders]
*/

VS2PS VS_Trail(APP2VS Input)
{
	VS2PS Output = (VS2PS)0.0;

	// Unpack vertex attributes
	float Intensity = Input.IntensityAgeAnimBlendFactorAndAlpha[0];
	float Age = Input.IntensityAgeAnimBlendFactorAndAlpha[1];
	float AnimBlendFactor = Input.IntensityAgeAnimBlendFactorAndAlpha[2];
	float Alpha = Input.IntensityAgeAnimBlendFactorAndAlpha[3];

	// Compute and age cubic polynomial factors
	float4 CubicPolynomial = float4(pow(Age, float3(3.0, 2.0, 1.0)), 1.0);
	float Size = min(dot(Template.m_sizeGraph, CubicPolynomial), 1.0) * Template.m_uvRangeLMapIntensiyAndParticleMaxSize.w;
	float ColorBlendFactor = min(dot(Template.m_colorBlendGraph, CubicPolynomial), 1.0);
	float AlphaBlendFactor = min(dot(Template.m_transparencyGraph, CubicPolynomial), 1.0) * Alpha;

	// Displace vertex
	float4 Pos = mul(float4(Input.Pos.xyz + Size * (Input.LocalCoords.xyz * Input.TexCoords.y), 1.0), _ViewMat);
	Output.HPos = mul(Pos, _ProjMat);
	Output.WorldPos = float4(Input.Pos, 0.0);

	// Output Depth
	#if defined(LOG_DEPTH)
		Output.WorldPos.w = Output.HPos.w + 1.0;
	#endif

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

	Output.Color = lerp(Template.m_color1AndLightFactor.rgb, Template.m_color2.rgb, ColorBlendFactor);
	Output.Maps[0] = AlphaBlendFactor * FadeFactor;
	Output.Maps[1] = AnimBlendFactor;
	Output.Maps[2] = Template.m_uvRangeLMapIntensiyAndParticleMaxSize.z;

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
	float4 UVOffsets = Input.UVOffsets * _OneOverShort;
	Output.Tex0 = RotatedTexCoords.xyxy + UVOffsets.xyzw;

	return Output;
}

/*
	[Pixel Shaders]
*/

struct VFactors
{
	float AlphaBlend;
	float AnimationBlend;
	float LightMapOffset;
};

VFactors GetVFactors(VS2PS Input)
{
	VFactors Output = (VFactors)0.0;
	Output.AlphaBlend = Input.Maps[0];
	Output.AnimationBlend = Input.Maps[1];
	Output.LightMapOffset = GetAltitude(Input.WorldPos.xyz, Input.Maps[2]);
	return Output;
}

PS2FB PS_Trail_ShowFill(VS2PS Input)
{
	PS2FB Output = (PS2FB)0.0;
	Output.Color = _EffectSunColor.rrrr;
	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.WorldPos.w);
	#endif
	return Output;
}

PS2FB PS_Trail_Low(VS2PS Input)
{
	PS2FB Output = (PS2FB)0.0;

	// Vertex blend factors
	VFactors VF = GetVFactors(Input);

	// Lighting
	float4 DiffuseMap = tex2D(SampleDiffuseMap, Input.Tex0.xy);
	float4 LightColor = float4(Input.Color.rgb, VF.AlphaBlend);
	float4 OutputColor = DiffuseMap * LightColor;

	Output.Color = OutputColor;
	ApplyFog(Output.Color.rgb, GetFogValue(Input.WorldPos.xyz, _EyePos));

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.WorldPos.w);
	#endif

	return Output;
}

PS2FB PS_Trail_Medium(VS2PS Input)
{
	PS2FB Output = (PS2FB)0.0;

	// Vertex blend factors
	VFactors VF = GetVFactors(Input);

	// Texture data
	float4 TDiffuse1 = tex2D(SampleDiffuseMap, Input.Tex0.xy);
	float4 TDiffuse2 = tex2D(SampleDiffuseMap, Input.Tex0.zw);
	float4 DiffuseMap = lerp(TDiffuse1, TDiffuse2, VF.AnimationBlend);

	// Lighting
	float3 Lighting = GetParticleLighting(1.0, VF.LightMapOffset, saturate(Template.m_color1AndLightFactor.a));
	float4 LightColor = float4(Input.Color.rgb * Lighting, VF.AlphaBlend);
	float4 OutputColor = DiffuseMap * LightColor;

	Output.Color = OutputColor;
	ApplyFog(Output.Color.rgb, GetFogValue(Input.WorldPos.xyz, _EyePos));

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.WorldPos.w);
	#endif

	return Output;
}

PS2FB PS_Trail_High(VS2PS Input)
{
	PS2FB Output = (PS2FB)0.0;

	// Vertex blend factors
	VFactors VF = GetVFactors(Input);

	// Get diffuse map
	float4 TDiffuse1 = tex2D(SampleDiffuseMap, Input.Tex0.xy);
	float4 TDiffuse2 = tex2D(SampleDiffuseMap, Input.Tex0.zw);
	float4 DiffuseMap = lerp(TDiffuse1, TDiffuse2, VF.AnimationBlend);

	// Get hemi map
	float2 HemiTex = GetHemiTex(Input.WorldPos.xyz, 0.0, _HemiMapInfo.xyz, true);
	float4 HemiMap = tex2D(SampleLUT, HemiTex);

	// Apply lighting
	float3 Lighting = GetParticleLighting(HemiMap.a, VF.LightMapOffset, saturate(Template.m_color1AndLightFactor.a));
	float4 LightColor = float4(Input.Color.rgb * Lighting, VF.AlphaBlend);
	float4 OutputColor = DiffuseMap * LightColor;

	Output.Color = OutputColor;
	ApplyFog(Output.Color.rgb, GetFogValue(Input.WorldPos.xyz, _EyePos));

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.WorldPos.w);
	#endif

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
	pass p0
	{
		GET_RENDERSTATES_TRAIL(ONE, ONE)
		VertexShader = compile vs_3_0 VS_Trail();
		PixelShader = compile ps_3_0 PS_Trail_ShowFill();
	}
}

technique TrailLow
<
>
{
	pass p0
	{
		GET_RENDERSTATES_TRAIL(SRCALPHA, INVSRCALPHA)
		VertexShader = compile vs_3_0 VS_Trail();
		PixelShader = compile ps_3_0 PS_Trail_Low();
	}
}

technique TrailMedium
<
>
{
	pass p0
	{
		GET_RENDERSTATES_TRAIL(SRCALPHA, INVSRCALPHA)
		VertexShader = compile vs_3_0 VS_Trail();
		PixelShader = compile ps_3_0 PS_Trail_Medium();
	}
}

technique TrailHigh
<
>
{
	pass p0
	{
		GET_RENDERSTATES_TRAIL(SRCALPHA, INVSRCALPHA)
		VertexShader = compile vs_3_0 VS_Trail();
		PixelShader = compile ps_3_0 PS_Trail_High();
	}
}
