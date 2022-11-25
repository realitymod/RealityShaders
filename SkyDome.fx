
/*
	Description: Renders sky and skybox
*/

#include "shaders/RealityGraphics.fxh"

uniform float4x4 _ViewProjMatrix : WorldViewProjection;
uniform float4 _TexOffset : TEXOFFSET;
uniform float4 _TexOffset2 : TEXOFFSET2;

uniform float4 _FlareParams : FLAREPARAMS;
uniform float4 _UnderwaterFog : FogColor;

uniform float2 _FadeOutDist : CLOUDSFADEOUTDIST;
uniform float2 _CloudLerpFactors : CLOUDLERPFACTORS;

uniform float _LightingBlend : LIGHTINGBLEND;
uniform float3 _LightingColor : LIGHTINGCOLOR;

#define CREATE_SAMPLER(SAMPLER_NAME, TEXTURE, ADDRESS, IS_SRGB) \
	sampler SAMPLER_NAME = sampler_state \
	{ \
		Texture = (TEXTURE); \
		MinFilter = LINEAR; \
		MagFilter = LINEAR; \
		MipFilter = LINEAR; \
		AddressU = ADDRESS; \
		AddressV = ADDRESS; \
		SRGBTexture = IS_SRGB; \
	}; \

uniform texture Tex0 : TEXLAYER0;
CREATE_SAMPLER(SampleTex0, Tex0, CLAMP, FALSE)

uniform texture Tex1 : TEXLAYER1;
CREATE_SAMPLER(SampleTex1, Tex1, WRAP, FALSE)

uniform texture Tex2 : TEXLAYER2;
CREATE_SAMPLER(SampleTex2, Tex2, WRAP, FALSE)

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

struct VS2PS_NoClouds
{
	float4 HPos : POSITION;
	float4 Pos : TEXCOORD0;

	float2 Tex0 : TEXCOORD1;
};

struct VS2PS_SkyDome
{
	float4 HPos : POSITION;
	float4 Pos : TEXCOORD0;

	float4 TexA : TEXCOORD1; // .xy = SkyTex; .zw = CloudTex
	float4 FadeOut : COLOR0;
};

struct VS2PS_DualClouds
{
	float4 HPos : POSITION;
	float4 Pos : TEXCOORD0;

	float2 SkyTex : TEXCOORD1;
	float4 CloudTex : TEXCOORD2; // .xy = CloudTex0; .zw = CloudTex1
	float4 FadeOut : COLOR0;
};

struct PS2FB
{
	float4 Color : COLOR;
	float Depth : DEPTH;
};

/*
	General SkyDome shaders
*/

VS2PS_SkyDome SkyDome_VS(APP2VS Input)
{
	VS2PS_SkyDome Output;

	Output.HPos = mul(float4(Input.Pos.xyz, 1.0), _ViewProjMatrix);
	Output.Pos = Output.HPos;

	Output.TexA.xy = Input.Tex0; // Sky coords
	Output.TexA.zw = Input.Tex1.xy + _TexOffset.xy; // Cloud1 coords

	float Dist = length(Input.Pos.xyz);
	Output.FadeOut = 1.0 - saturate((Dist - _FadeOutDist.x) / _FadeOutDist.y);
	Output.FadeOut *= Input.Pos.y > 0.0;
	Output.FadeOut = saturate(Output.FadeOut);

	return Output;
}

PS2FB SkyDome_UnderWater_PS(VS2PS_SkyDome Input)
{
	PS2FB Output;

	Output.Color = _UnderwaterFog;
	Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);

	return Output;
}

PS2FB SkyDome_PS(VS2PS_SkyDome Input)
{
	PS2FB Output;

	float4 Sky = tex2D(SampleTex0, Input.TexA.xy);
	float4 Cloud1 = tex2D(SampleTex1, Input.TexA.zw) * Input.FadeOut;

	Output.Color = float4(lerp(Sky.rgb, Cloud1.rgb, Cloud1.a), 1.0);
	Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);

	return Output;
}

PS2FB SkyDome_Lit_PS(VS2PS_SkyDome Input)
{
	PS2FB Output;

	float4 Sky = tex2D(SampleTex0, Input.TexA.xy);
	float4 Cloud1 = tex2D(SampleTex1, Input.TexA.zw) * Input.FadeOut;
	Sky.rgb += _LightingColor.rgb * (Sky.a * _LightingBlend);

	Output.Color = float4(lerp(Sky.rgb, Cloud1.rgb, Cloud1.a), 1.0);
	Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);

	return Output;
}

/*
	SkyDome with two clouds shaders
*/

VS2PS_DualClouds SkyDome_DualClouds_VS(APP2VS Input)
{
	VS2PS_DualClouds Output;

	Output.HPos = mul(float4(Input.Pos.xyz, 1.0), _ViewProjMatrix);
	Output.Pos = Output.HPos;

	Output.SkyTex = Input.Tex0;
	Output.CloudTex.xy = (Input.Tex1.xy + _TexOffset.xy);
	Output.CloudTex.zw = (Input.Tex1.xy + _TexOffset2.xy);

	float Dist = length(Input.Pos.xyz);
	Output.FadeOut = 1.0 - saturate((Dist - _FadeOutDist.x) / _FadeOutDist.y);
	Output.FadeOut *= Input.Pos.y > 0.0;
	Output.FadeOut = saturate(Output.FadeOut);

	return Output;
}

PS2FB SkyDome_DualClouds_PS(VS2PS_DualClouds Input)
{
	PS2FB Output;

	float4 Sky = tex2D(SampleTex0, Input.SkyTex);
	float4 Cloud1 = tex2D(SampleTex1, Input.CloudTex.xy) * _CloudLerpFactors.x;
	float4 Cloud2 = tex2D(SampleTex2, Input.CloudTex.zw) * _CloudLerpFactors.y;
	float4 Temp = (Cloud1 + Cloud2) * Input.FadeOut;

	Output.Color = lerp(Sky, Temp, Temp.a);
	Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);

	return Output;
}

/*
	SkyDome with no cloud shaders
*/

VS2PS_NoClouds SkyDome_NoClouds_VS(APP2VS_NoClouds Input)
{
	VS2PS_NoClouds Output;

	float4 ScaledPos = float4(Input.Pos.xyz, 10.0); // plo: fix for artifacts on BFO.
	Output.HPos = mul(ScaledPos, _ViewProjMatrix);
	Output.Pos = Output.HPos;

	Output.Tex0 = Input.Tex0;

	return Output;
}

PS2FB SkyDome_NoClouds_PS(VS2PS_NoClouds Input)
{
	PS2FB Output;

	Output.Color = tex2D(SampleTex0, Input.Tex0);
	Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);

	return Output;
}

PS2FB SkyDome_NoClouds_Lit_PS(VS2PS_NoClouds Input)
{
	PS2FB Output;

	float4 Sky = tex2D(SampleTex0, Input.Tex0);
	Sky.rgb += _LightingColor.rgb * (Sky.a * _LightingBlend);

	Output.Color = Sky;
	Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);

	return Output;
}

/*
	SkyDome with flare shaders
*/

VS2PS_NoClouds SkyDome_SunFlare_VS(APP2VS_NoClouds Input)
{
	VS2PS_NoClouds Output;

	Output.HPos = mul(float4(Input.Pos.xyz, 1.0), _ViewProjMatrix);
	Output.Pos = Output.HPos;

	Output.Tex0 = Input.Tex0;

	return Output;
}

PS2FB SkyDome_SunFlare_PS(VS2PS_NoClouds Input)
{
	PS2FB Output;

	float3 OutputColor = tex2D(SampleTex0, Input.Tex0).rgb * _FlareParams[0];

	Output.Color = float4(OutputColor, 1.0);
	Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);

	return Output;
}

PS2FB SkyDome_Flare_Occlude_PS(VS2PS_NoClouds Input)
{
	PS2FB Output;

	float4 Value = tex2D(SampleTex0, Input.Tex0);

	Output.Color = float4(0.0, 1.0, 0.0, Value.a);
	Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);

	return Output;
}

technique SkyDomeUnderWater
{
	pass Sky
	{
		AlphaBlendEnable = FALSE;
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;
		SRGBWriteEnable = FALSE;

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
		SRGBWriteEnable = FALSE;

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
		SRGBWriteEnable = FALSE;

		VertexShader = compile vs_3_0 SkyDome_VS();
		PixelShader = compile ps_3_0 SkyDome_Lit_PS();
	}
}


technique SkyDomeNV3xDualClouds
{
	pass Sky
	{
		AlphaBlendEnable = FALSE;
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;
		SRGBWriteEnable = FALSE;

		VertexShader = compile vs_3_0 SkyDome_DualClouds_VS();
		PixelShader = compile ps_3_0 SkyDome_DualClouds_PS();
	}
}

technique SkyDomeNV3xNoClouds
{
	pass Sky
	{
		AlphaBlendEnable = FALSE;
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;
		SRGBWriteEnable = FALSE;

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
		SRGBWriteEnable = FALSE;

		VertexShader = compile vs_3_0 SkyDome_NoClouds_VS();
		PixelShader = compile ps_3_0 SkyDome_NoClouds_Lit_PS();
	}
}

technique SkyDomeSunFlare
{
	pass Sky
	{
		Zenable = FALSE;
		ZWriteEnable = FALSE;
		ZFunc = ALWAYS;

		CullMode = NONE;
		// ColorWriteEnable = 0;

		AlphaBlendEnable = TRUE;
		SrcBlend = ONE;
		DestBlend = ONE;

		SRGBWriteEnable = FALSE;

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
		AlphaRef = 50; // 255
		AlphaFunc = GREATER; // LESS

		SRGBWriteEnable = FALSE;

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
		AlphaRef = 50; // 255
		AlphaFunc = GREATER; // LESS

		SRGBWriteEnable = FALSE;

		VertexShader = compile vs_3_0 SkyDome_SunFlare_VS();
		PixelShader = compile ps_3_0 SkyDome_Flare_Occlude_PS();
	}
}
