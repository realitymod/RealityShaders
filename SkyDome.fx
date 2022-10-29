
/*
	Description: Renders sky and skybox
*/

#include "shaders/RealityGraphics.fx"

uniform float4x4 _ViewProjMatrix : WorldViewProjection;
uniform float4 _TexOffset : TEXOFFSET;
uniform float4 _TexOffset2 : TEXOFFSET2;

uniform float4 _FlareParams : FLAREPARAMS;
uniform float4 _UnderwaterFog : FogColor;

uniform float2 _FadeOutDist : CLOUDSFADEOUTDIST;
uniform float2 _CloudLerpFactors : CLOUDLERPFACTORS;

uniform float _LightingBlend : LIGHTINGBLEND;
uniform float3 _LightingColor : LIGHTINGCOLOR;

uniform texture Tex0 : TEXLAYER0;
sampler SampleTex0 = sampler_state
{
	Texture = (Tex0);
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = LINEAR;
	AddressU = CLAMP;
	AddressV = CLAMP;
};

uniform texture Tex1 : TEXLAYER1;
sampler SampleTex1 = sampler_state
{
	Texture = (Tex1);
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = LINEAR;
	AddressU = WRAP;
	AddressV = WRAP;
};

uniform texture Tex2 : TEXLAYER2;
sampler SampleTex2 = sampler_state
{
	Texture = (Tex2);
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = LINEAR;
	AddressU = WRAP;
	AddressV = WRAP;
};

struct APP2VS
{
	float4 Pos : POSITION;
	float4 BlendIndices : BLENDINDICES;
	float2 TexCoord : TEXCOORD0;
	float2 TexCoord1 : TEXCOORD1;
};

struct APP2VS_NoClouds
{
	float4 Pos : POSITION;
	float4 BlendIndices : BLENDINDICES;
	float2 TexCoord : TEXCOORD0;
};

struct VS2PS_NoClouds
{
	float4 HPos : POSITION;
	float2 Tex0 : TEXCOORD0;
};

struct VS2PS_SkyDome
{
	float4 HPos : POSITION;
	float4 UV_Sky_Cloud : TEXCOORD0; // .xy = SkyCoord; .zw = CloudCoord
	float4 FadeOut : COLOR0;
};

struct VS2PS_DualClouds
{
	float4 HPos : POSITION;
	float2 SkyCoord : TEXCOORD0;
	float4 CloudCoords : TEXCOORD1; // .xy = CloudCoord0; .zw = CloudCoord1
	float4 FadeOut : COLOR0;
};

/*
	General SkyDome shaders
*/

VS2PS_SkyDome SkyDome_VS(APP2VS Input)
{
	VS2PS_SkyDome Output;
	Output.HPos = mul(float4(Input.Pos.xyz, 1.0), _ViewProjMatrix);
	Output.UV_Sky_Cloud.xy = Input.TexCoord; // Sky coords
	Output.UV_Sky_Cloud.zw = Input.TexCoord1.xy + _TexOffset.xy; // Cloud1 coords
	float Dist = length(Input.Pos.xyz);
	Output.FadeOut = 1.0 - saturate((Dist - _FadeOutDist.x) / _FadeOutDist.y);
	Output.FadeOut *= Input.Pos.y > 0.0;
	Output.FadeOut = saturate(Output.FadeOut);
	return Output;
}

float4 SkyDome_UnderWater_PS(VS2PS_SkyDome Input) : COLOR
{
	return _UnderwaterFog;
}

float4 SkyDome_PS(VS2PS_SkyDome Input) : COLOR
{
	float4 Sky = tex2D(SampleTex0, Input.UV_Sky_Cloud.xy);
	float4 Cloud1 = tex2D(SampleTex1, Input.UV_Sky_Cloud.zw) * Input.FadeOut;
	return float4(lerp(Sky.rgb, Cloud1.rgb, Cloud1.a), 1.0);
}

float4 SkyDome_Lit_PS(VS2PS_SkyDome Input) : COLOR
{
	float4 Sky = tex2D(SampleTex0, Input.UV_Sky_Cloud.xy);
	Sky.rgb += _LightingColor.rgb * (Sky.a * _LightingBlend);
	float4 Cloud1 = tex2D(SampleTex1, Input.UV_Sky_Cloud.zw) * Input.FadeOut;
	return float4(lerp(Sky.rgb, Cloud1.rgb, Cloud1.a), 1.0);
}

technique SkyDomeUnderWater
{
	pass Sky
	{
		AlphaBlendEnable = FALSE;
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;
		VertexShader = compile vs_3_0 SkyDome_VS();
		PixelShader = compile ps_3_0 SkyDome_UnderWater_PS();
	}
}

technique SkyDomeNV3x
{
	pass Sky
	{
		AlphaBlendEnable = FALSE;
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;
		VertexShader = compile vs_3_0 SkyDome_VS();
		PixelShader = compile ps_3_0 SkyDome_PS();
	}
}

technique SkyDomeNV3xLit
{
	pass Sky
	{
		AlphaBlendEnable = FALSE;
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;
		VertexShader = compile vs_3_0 SkyDome_VS();
		PixelShader = compile ps_3_0 SkyDome_Lit_PS();
	}
}

/*
	SkyDome with two clouds shaders
*/

VS2PS_DualClouds SkyDome_DualClouds_VS(APP2VS Input)
{
	VS2PS_DualClouds Output;
	Output.HPos = mul(float4(Input.Pos.xyz, 1.0), _ViewProjMatrix);
	Output.SkyCoord = Input.TexCoord;
	Output.CloudCoords.xy = (Input.TexCoord1.xy + _TexOffset.xy);
	Output.CloudCoords.zw = (Input.TexCoord1.xy + _TexOffset2.xy);
	float Dist = length(Input.Pos.xyz);
	Output.FadeOut = 1.0 - saturate((Dist - _FadeOutDist.x) / _FadeOutDist.y);
	Output.FadeOut *= Input.Pos.y > 0.0;
	Output.FadeOut = saturate(Output.FadeOut);
	return Output;
}

float4 SkyDome_DualClouds_PS(VS2PS_DualClouds Input) : COLOR
{
	float4 Sky = tex2D(SampleTex0, Input.SkyCoord);
	float4 Cloud1 = tex2D(SampleTex1, Input.CloudCoords.xy);
	float4 Cloud2 = tex2D(SampleTex2, Input.CloudCoords.zw);
	float4 Temp = Cloud1 * _CloudLerpFactors.x + Cloud2 * _CloudLerpFactors.y;
	Temp *= Input.FadeOut;
	return lerp(Sky, Temp, Temp.a);
}

technique SkyDomeNV3xDualClouds
{
	pass Sky
	{
		AlphaBlendEnable = FALSE;
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;
		VertexShader = compile vs_3_0 SkyDome_DualClouds_VS();
		PixelShader = compile ps_3_0 SkyDome_DualClouds_PS();
	}
}

/*
	SkyDome with not cloud shaders
*/

VS2PS_NoClouds SkyDome_NoClouds_VS(APP2VS_NoClouds Input)
{
	VS2PS_NoClouds Output;
	float4 ScaledPos = float4(Input.Pos.xyz, 10.0); // plo: fix for artifacts on BFO.
	Output.HPos = mul(ScaledPos, _ViewProjMatrix);
	Output.Tex0 = Input.TexCoord;
	return Output;
}

float4 SkyDome_NoClouds_PS(VS2PS_SkyDome Input) : COLOR
{
	return tex2D(SampleTex0, Input.UV_Sky_Cloud.xy);
}

float4 SkyDome_NoClouds_Lit_PS(VS2PS_SkyDome Input) : COLOR
{
	float4 Sky = tex2D(SampleTex0, Input.UV_Sky_Cloud.xy);
	Sky.rgb += _LightingColor.rgb * (Sky.a * _LightingBlend);
	return Sky;
}

technique SkyDomeNV3xNoClouds
{
	pass Sky
	{
		AlphaBlendEnable = FALSE;
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;
		VertexShader = compile vs_3_0 SkyDome_NoClouds_VS();
		PixelShader = compile ps_3_0 SkyDome_NoClouds_PS();
	}
}

technique SkyDomeNV3xNoCloudsLit
{
	pass Sky
	{
		AlphaBlendEnable = FALSE;
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;
		VertexShader = compile vs_3_0 SkyDome_NoClouds_VS();
		PixelShader = compile ps_3_0 SkyDome_NoClouds_Lit_PS();
	}
}

/*
	SkyDome with flare shaders
*/

VS2PS_NoClouds SkyDome_SunFlare_VS(APP2VS_NoClouds Input)
{
	VS2PS_NoClouds Output;
	// Output.HPos = Input.Pos * 10000.0;
	Output.HPos = mul(float4(Input.Pos.xyz, 1.0), _ViewProjMatrix);
	Output.Tex0 = Input.TexCoord;
	return Output;
}

float4 SkyDome_SunFlare_PS(VS2PS_SkyDome Input) : COLOR
{
	// return 1.0;
	// return float4(_FlareParams[0], 0.0, 0.0, 1.0);
	float3 OutputColor = tex2D(SampleTex0, Input.UV_Sky_Cloud.xy).rgb * _FlareParams[0];
	return float4(OutputColor, 1.0);
}

float4 SkyDome_Flare_Occlude_PS(VS2PS_SkyDome Input) : COLOR
{
	float4 Value = tex2D(SampleTex0, Input.UV_Sky_Cloud.xy);
	return float4(0.0, 1.0, 0.0, Value.a);
}

technique SkyDomeSunFlare
{
	pass Sky
	{
		Zenable = FALSE;
		ZWriteEnable = FALSE;
		ZFunc = ALWAYS;
		CullMode = NONE;
		AlphaBlendEnable = TRUE;
		SrcBlend = ONE;
		DestBlend = ONE;
		// ColorWriteEnable = 0;
		VertexShader = compile vs_3_0 SkyDome_SunFlare_VS();
		PixelShader = compile ps_3_0 SkyDome_SunFlare_PS();
	}
}

technique SkyDomeFlareOccludeCheck
{
	pass Sky
	{
		ZEnable = TRUE;
		ZWriteEnable = FALSE;
		ZFunc = ALWAYS;
		CullMode = NONE;
		ColorWriteEnable = 0;

		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;
		AlphaTestEnable = TRUE;
		AlphaRef = 50;
		AlphaFunc = GREATER;
		// AlphaRef = 255;
		// AlphaFunc = LESS;
		VertexShader = compile vs_3_0 SkyDome_SunFlare_VS();
		PixelShader = compile ps_3_0 SkyDome_Flare_Occlude_PS();
	}
}

technique SkyDomeFlareOcclude
{
	pass Sky
	{
		ZEnable = TRUE;
		ZWriteEnable = FALSE;
		ZFunc = LESS;
		CullMode = NONE;
		ColorWriteEnable = 0;

		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		AlphaTestEnable = TRUE;
		AlphaRef = 50;
		AlphaFunc = GREATER;
		// AlphaRef = 255;
		// AlphaFunc = LESS;
		VertexShader = compile vs_3_0 SkyDome_SunFlare_VS();
		PixelShader = compile ps_3_0 SkyDome_Flare_Occlude_PS();
	}
}
