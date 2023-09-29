
/*
	Include header files
*/

#include "shaders/shared/RealityPixel.fxh"
#if !defined(INCLUDED_HEADERS)
	#include "shared/RealityPixel.fxh"
#endif

/*
	Description: Renders sky and skybox
	NOTE: We use normal depth calculation for this one because the geometry's far away from the scene
*/

uniform float4x4 _ViewProjMatrix : WorldViewProjection;
uniform float4 _TexOffset : TEXOFFSET;
uniform float4 _TexOffset2 : TEXOFFSET2;

uniform float4 _FlareParams : FLAREPARAMS;
uniform float4 _UnderwaterFog : FogColor;

uniform float2 _FadeOutDist : CLOUDSFADEOUTDIST;
uniform float2 _CloudLerpFactors : CLOUDLERPFACTORS;

uniform float _LightingBlend : LIGHTINGBLEND;
uniform float3 _LightingColor : LIGHTINGCOLOR;

#define CREATE_SAMPLER(SAMPLER_NAME, TEXTURE, ADDRESS) \
	sampler SAMPLER_NAME = sampler_state \
	{ \
		Texture = (TEXTURE); \
		MinFilter = LINEAR; \
		MagFilter = LINEAR; \
		MipFilter = LINEAR; \
		AddressU = ADDRESS; \
		AddressV = ADDRESS; \
	}; \

uniform texture Tex0 : TEXLAYER0;
CREATE_SAMPLER(SampleTex0, Tex0, CLAMP)

uniform texture Tex1 : TEXLAYER1;
CREATE_SAMPLER(SampleTex1, Tex1, WRAP)

uniform texture Tex2 : TEXLAYER2;
CREATE_SAMPLER(SampleTex2, Tex2, WRAP)

struct APP2VS
{
	float4 Pos : POSITION;
	float4 BlendIndices : BLENDINDICES;
	float2 Tex0 : TEXCOORD0;
	float2 Tex1 : TEXCOORD1;
};

struct APP2VS_NoClouds
{
	float4 Pos : POSITION;
	float4 BlendIndices : BLENDINDICES;
	float2 Tex0 : TEXCOORD0;
};

struct PS2FB
{
	float4 Color : COLOR;
};

float GetFadeOut(float3 Pos)
{
	float Dist = length(Pos);
	float FadeOut = 1.0 - saturate((Dist - _FadeOutDist.x) / _FadeOutDist.y);
	return saturate(FadeOut * (Pos.y > 0.0));
}

bool IsTisActive()
{
	return _UnderwaterFog.r == 0;
}

float4 ApplyTis(in out float4 color)
{
	// TIS uses Green + Red channel to determine heat
	color.r = 0;
	// Green = 1 means cold, Green = 0 hot. Invert channel so clouds (high green) become hot
	// Add constant to make everything colder
	color.g = (1 - color.g) + 0.5;
	return color;
}

/*
	General SkyDome shaders
*/

struct VS2PS_SkyDome
{
	float4 HPos : POSITION;
	float4 Pos : TEXCOORD0;
	float4 Tex0 : TEXCOORD1; // .xy = SkyTex; .zw = CloudTex
};

VS2PS_SkyDome VS_SkyDome(APP2VS Input)
{
	VS2PS_SkyDome Output;

	Output.HPos = mul(float4(Input.Pos.xyz, 1.0), _ViewProjMatrix);
	Output.Pos = Input.Pos;

	Output.Tex0.xy = Input.Tex0; // Sky coords
	Output.Tex0.zw = Input.Tex1.xy + _TexOffset.xy; // Cloud1 coords

	return Output;
}

PS2FB PS_SkyDome_UnderWater(VS2PS_SkyDome Input)
{
	PS2FB Output = (PS2FB)0;

	if (IsTisActive())
	{
		Output.Color = 0;
	}
	else
	{
		Output.Color = _UnderwaterFog;
	}

	return Output;
}

PS2FB PS_SkyDome(VS2PS_SkyDome Input)
{
	PS2FB Output = (PS2FB)0;

	float FadeOut = GetFadeOut(Input.Pos.xyz);
	float4 SkyDome = tex2D(SampleTex0, Input.Tex0.xy);
	float4 Cloud1 = GetProceduralTiles(SampleTex1, Input.Tex0.zw) * FadeOut;

	Output.Color = float4(lerp(SkyDome.rgb, Cloud1.rgb, Cloud1.a), 1.0);

	// If thermals make it dark
	if (IsTisActive())
	{
		Output.Color = ApplyTis(Output.Color);
	}

	return Output;
}

PS2FB PS_SkyDome_Lit(VS2PS_SkyDome Input)
{
	PS2FB Output = (PS2FB)0;

	float FadeOut = GetFadeOut(Input.Pos.xyz);
	float4 SkyDome = tex2D(SampleTex0, Input.Tex0.xy);
	float4 Cloud1 = GetProceduralTiles(SampleTex1, Input.Tex0.zw) * FadeOut;
	SkyDome.rgb += _LightingColor.rgb * (SkyDome.a * _LightingBlend);

	Output.Color = float4(lerp(SkyDome.rgb, Cloud1.rgb, Cloud1.a), 1.0);

	// If thermals make it dark
	if (IsTisActive())
	{
		Output.Color = ApplyTis(Output.Color);
	}

	return Output;
}

/*
	SkyDome with two clouds shaders
*/

struct VS2PS_DualClouds
{
	float4 HPos : POSITION;
	float4 Pos : TEXCOORD0;
	float2 SkyTex : TEXCOORD1;
	float4 CloudTex : TEXCOORD2; // .xy = CloudTex0; .zw = CloudTex1
};

VS2PS_DualClouds VS_SkyDome_DualClouds(APP2VS Input)
{
	VS2PS_DualClouds Output;

	Output.HPos = mul(float4(Input.Pos.xyz, 1.0), _ViewProjMatrix);
	Output.Pos = Input.Pos;

	Output.SkyTex = Input.Tex0;
	Output.CloudTex.xy = (Input.Tex1.xy + _TexOffset.xy);
	Output.CloudTex.zw = (Input.Tex1.xy + _TexOffset2.xy);

	return Output;
}

PS2FB PS_SkyDome_DualClouds(VS2PS_DualClouds Input)
{
	PS2FB Output = (PS2FB)0;

	float FadeOut = GetFadeOut(Input.Pos.xyz);
	float4 SkyDome = tex2D(SampleTex0, Input.SkyTex);
	float4 Cloud1 = GetProceduralTiles(SampleTex1, Input.CloudTex.xy) * _CloudLerpFactors.x;
	float4 Cloud2 = GetProceduralTiles(SampleTex2, Input.CloudTex.zw) * _CloudLerpFactors.y;
	float4 Temp = (Cloud1 + Cloud2) * FadeOut;

	Output.Color = lerp(SkyDome, Temp, Temp.a);

	// If thermals make it dark
	if (IsTisActive())
	{
		Output.Color = ApplyTis(Output.Color);
	}

	return Output;
}

/*
	SkyDome with no cloud shaders
*/

struct VS2PS_NoClouds
{
	float4 HPos : POSITION;
	float4 Pos : TEXCOORD0;
	float2 Tex0 : TEXCOORD1;
};

VS2PS_NoClouds VS_SkyDome_NoClouds(APP2VS_NoClouds Input)
{
	VS2PS_NoClouds Output;

	float4 ScaledPos = float4(Input.Pos.xyz, 10.0); // plo: fix for artifacts on BFO.
	Output.HPos = mul(ScaledPos, _ViewProjMatrix);
	Output.Pos = Input.Pos;

	Output.Tex0 = Input.Tex0;

	return Output;
}

PS2FB PS_SkyDome_NoClouds(VS2PS_NoClouds Input)
{
	PS2FB Output = (PS2FB)0;

	Output.Color = tex2D(SampleTex0, Input.Tex0);

	// If thermals make it dark
	if (IsTisActive())
	{
		Output.Color = ApplyTis(Output.Color);
	}

	return Output;
}

PS2FB PS_SkyDome_NoClouds_Lit(VS2PS_NoClouds Input)
{
	PS2FB Output = (PS2FB)0;

	float4 SkyDome = tex2D(SampleTex0, Input.Tex0);
	SkyDome.rgb += _LightingColor.rgb * (SkyDome.a * _LightingBlend);

	Output.Color = SkyDome;

	// If thermals make it dark
	if (IsTisActive())
	{
		Output.Color = ApplyTis(Output.Color);
	}

	return Output;
}

/*
	SkyDome with Sun flare shaders
*/

VS2PS_NoClouds VS_SkyDome_SunFlare(APP2VS_NoClouds Input)
{
	VS2PS_NoClouds Output = (VS2PS_NoClouds)0;

	Output.HPos = mul(float4(Input.Pos.xyz, 1.0), _ViewProjMatrix);
	Output.Pos = Input.Pos;

	Output.Tex0 = Input.Tex0;

	return Output;
}

PS2FB PS_SkyDome_SunFlare(VS2PS_NoClouds Input)
{
	PS2FB Output = (PS2FB)0;

	float4 SkyDome = tex2D(SampleTex0, Input.Tex0);
	Output.Color = float4(SkyDome.rgb * _FlareParams[0], 1.0);

	return Output;
}

PS2FB PS_SkyDome_Flare_Occlude(VS2PS_NoClouds Input)
{
	PS2FB Output = (PS2FB)0;

	float4 Value = tex2D(SampleTex0, Input.Tex0);

	Output.Color = float4(0.0, 1.0, 0.0, Value.a);

	return Output;
}

#define GET_RENDERSTATES_SKY \
	ZEnable = TRUE; \
	ZFunc = LESSEQUAL; \
	ZWriteEnable = TRUE; \
	AlphaBlendEnable = FALSE; \

technique SkyDomeUnderWater
{
	pass Sky
	{
		GET_RENDERSTATES_SKY
		VertexShader = compile vs_3_0 VS_SkyDome();
		PixelShader = compile ps_3_0 PS_SkyDome_UnderWater();
	}
}

technique SkyDomeNV3x
{
	pass Sky
	{
		GET_RENDERSTATES_SKY
		VertexShader = compile vs_3_0 VS_SkyDome();
		PixelShader = compile ps_3_0 PS_SkyDome();
	}
}

technique SkyDomeNV3xLit
{
	pass Sky
	{
		GET_RENDERSTATES_SKY
		VertexShader = compile vs_3_0 VS_SkyDome();
		PixelShader = compile ps_3_0 PS_SkyDome_Lit();
	}
}

technique SkyDomeNV3xDualClouds
{
	pass Sky
	{
		GET_RENDERSTATES_SKY
		VertexShader = compile vs_3_0 VS_SkyDome_DualClouds();
		PixelShader = compile ps_3_0 PS_SkyDome_DualClouds();
	}
}

technique SkyDomeNV3xNoClouds
{
	pass Sky
	{
		GET_RENDERSTATES_SKY
		VertexShader = compile vs_3_0 VS_SkyDome_NoClouds();
		PixelShader = compile ps_3_0 PS_SkyDome_NoClouds();
	}
}

technique SkyDomeNV3xNoCloudsLit
{
	pass Sky
	{
		GET_RENDERSTATES_SKY
		VertexShader = compile vs_3_0 VS_SkyDome_NoClouds();
		PixelShader = compile ps_3_0 PS_SkyDome_NoClouds_Lit();
	}
}

technique SkyDomeSunFlare
{
	pass Sky
	{
		CullMode = NONE;
		// ColorWriteEnable = 0;

		ZEnable = FALSE;
		ZFunc = ALWAYS;
		ZWriteEnable = FALSE;

		AlphaBlendEnable = TRUE;
		SrcBlend = ONE;
		DestBlend = ONE;

		VertexShader = compile vs_3_0 VS_SkyDome_SunFlare();
		PixelShader = compile ps_3_0 PS_SkyDome_SunFlare();
	}
}

technique SkyDomeFlareOccludeCheck
{
	pass Sky
	{
		ZEnable = TRUE;
		ZFunc = ALWAYS;
		ZWriteEnable = FALSE;

		CullMode = NONE;
		ColorWriteEnable = 0;

		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		AlphaTestEnable = TRUE;
		AlphaRef = 50; // 255
		AlphaFunc = GREATER; // LESS

		VertexShader = compile vs_3_0 VS_SkyDome_SunFlare();
		PixelShader = compile ps_3_0 PS_SkyDome_Flare_Occlude();
	}
}

technique SkyDomeFlareOcclude
{
	pass Sky
	{
		ZEnable = TRUE;
		ZFunc = LESS;
		ZWriteEnable = FALSE;

		CullMode = NONE;
		ColorWriteEnable = 0;

		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		AlphaTestEnable = TRUE;
		AlphaRef = 50; // 255
		AlphaFunc = GREATER; // LESS

		VertexShader = compile vs_3_0 VS_SkyDome_SunFlare();
		PixelShader = compile ps_3_0 PS_SkyDome_Flare_Occlude();
	}
}
