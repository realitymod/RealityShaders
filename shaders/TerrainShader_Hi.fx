
/*
	Description:
	- High-settings terrain shader
	- Renders the terrain's high-setting shading
	- Renders the terrain's high-setting shadowing
*/

#include "shaders/RealityGraphics.fxh"

/*
	Terrainmapping shader
*/

struct VS2PS_FullDetail_Hi
{
	float4 HPos : POSITION;
	float4 Pos : TEXCOORD0;
	float4 P_Normal_Fade : TEXCOORD1; // .xyz = Normal; .w = InterpVal;

	float4 TexA : TEXCOORD2; // .xy = ColorTex; .zw = DetailTex;
	float4 LightTex : TEXCOORD3;

	float4 YPlaneTex : TEXCOORD4; // .xy = Near; .zw = Far;
	float4 XPlaneTex : TEXCOORD5; // .xy = Near; .zw = Far;
	float4 ZPlaneTex : TEXCOORD6; // .xy = Near; .zw = Far;
};

VS2PS_FullDetail_Hi FullDetail_Hi_VS(APP2VS_Shared Input)
{
	VS2PS_FullDetail_Hi Output;

	float4 WorldPos = 0.0;
	WorldPos.xz = (Input.Pos0.xy * _ScaleTransXZ.xy) + _ScaleTransXZ.zw;
	WorldPos.yw = (Input.Pos1.xw * _ScaleTransY.xy);

	float YDelta, InterpVal;
	MorphPosition(WorldPos, Input.MorphDelta, Input.Pos0.z, YDelta, InterpVal);

	// tl: output HPos as early as possible.
	Output.HPos = mul(WorldPos, _ViewProj);
	Output.Pos.xyz = WorldPos.xyz;
	Output.Pos.w = Output.HPos.w + 1.0; // Output depth

	// tl: uncompress normal
	Output.P_Normal_Fade.xyz = normalize((Input.Normal * 2.0) - 1.0);
	Output.P_Normal_Fade.w = InterpVal;

	// Calculate triplanar texcoords
	float3 Tex = 0.0;
	Tex.x = Input.Pos0.x * _TexScale.x;
	Tex.y = WorldPos.y * _TexScale.y;
	Tex.z = Input.Pos0.y * _TexScale.z;
	float2 XPlaneTexCoord = Tex.zy;
	float2 YPlaneTexCoord = Tex.xz;
	float2 ZPlaneTexCoord = Tex.xy;

	Output.TexA.xy = (YPlaneTexCoord * _ColorLightTex.x) + _ColorLightTex.y;
	Output.TexA.zw = (YPlaneTexCoord * _DetailTex.x) + _DetailTex.y;

	Output.LightTex = ProjToLighting(Output.HPos);

	Output.YPlaneTex.xy = (YPlaneTexCoord * _NearTexTiling.z);
	Output.YPlaneTex.zw = (YPlaneTexCoord * _FarTexTiling.z);

	Output.XPlaneTex.xy = (XPlaneTexCoord * _NearTexTiling.xy) + float2(0.0, _NearTexTiling.w);
	Output.XPlaneTex.zw = (XPlaneTexCoord * _FarTexTiling.xy) + float2(0.0, _FarTexTiling.w);

	Output.ZPlaneTex.xy = (ZPlaneTexCoord * _NearTexTiling.xy) + float2(0.0, _NearTexTiling.w);
	Output.ZPlaneTex.zw = (ZPlaneTexCoord * _FarTexTiling.xy) + float2(0.0, _FarTexTiling.w);

	return Output;
}

PS2FB FullDetail_Hi(VS2PS_FullDetail_Hi Input, uniform bool UseMounten, uniform bool UseEnvMap)
{
	PS2FB Output;

	float4 AccumLights = tex2Dproj(SampleTex1_Clamp, Input.LightTex);
	float4 Component = tex2D(SampleTex2_Clamp, Input.TexA.zw);
	float ChartContrib = dot(Component.xyz, _ComponentSelector.xyz);

	float3 WorldPos = Input.Pos.xyz;
	float3 WorldNormal = normalize(Input.P_Normal_Fade.xyz);
	float LerpValue = Input.P_Normal_Fade.w;

	float3 BlendValue = saturate(abs(WorldNormal) - _BlendMod);
	BlendValue = saturate(BlendValue / dot(1.0, BlendValue));

	float3 TerrainSunColor = _SunColor * 2.0;
	float3 TerrainLights = ((TerrainSunColor * AccumLights.w) + AccumLights.rgb) * 2.0;

	#if defined(LIGHTONLY)
		Output.Color = TerrainLights * ChartContrib;
		Output.Color.a = 1.0;
	#else
		float3 ColorMap = tex2D(SampleTex0_Clamp, Input.TexA.xy);
		float4 LowComponent = tex2D(SampleTex5_Clamp, Input.TexA.zw);
		float4 XPlaneDetailmap = tex2D(SampleTex6_Wrap, Input.XPlaneTex.xy);
		float4 YPlaneDetailmap = tex2D(SampleTex3_Wrap, Input.YPlaneTex.xy);
		float4 ZPlaneDetailmap = tex2D(SampleTex6_Wrap, Input.ZPlaneTex.xy);
		float3 XPlaneLowDetailmap = tex2D(SampleTex4_Wrap, Input.XPlaneTex.zw) * 2.0;
		float3 YPlaneLowDetailmap = tex2D(SampleTex4_Wrap, Input.YPlaneTex.zw) * 2.0;
		float3 ZPlaneLowDetailmap = tex2D(SampleTex4_Wrap, Input.ZPlaneTex.zw) * 2.0;
		float EnvMapScale = YPlaneDetailmap.a;

		// If thermals assume no shadows and gray color
		if (FogColor.r < 0.01)
		{
			TerrainLights = (TerrainSunColor + AccumLights.rgb) * 2.0;
			ColorMap.rgb = 1.0 / 3.0;
		}

		float Color = lerp(1.0, YPlaneLowDetailmap.z, saturate(dot(LowComponent.xy, 1.0)));
		float Blue = 0.0;
		Blue += (XPlaneLowDetailmap.y * BlendValue.x);
		Blue += (YPlaneLowDetailmap.x * BlendValue.y);
		Blue += (ZPlaneLowDetailmap.y * BlendValue.z);
		Color *= lerp(1.0, Blue, LowComponent.z);

		float4 DetailMap = 0.0;
		if(UseMounten)
		{
			DetailMap += (XPlaneDetailmap * BlendValue.x);
			DetailMap += (YPlaneDetailmap * BlendValue.y);
			DetailMap += (ZPlaneDetailmap * BlendValue.z);
		}
		else
		{
			DetailMap = YPlaneDetailmap;
		}

		float4 LowDetailMap = Color;
		float4 BothDetailMap = (DetailMap * LowDetailMap) * 2.0;
		float4 OutputDetail = lerp(BothDetailMap, LowDetailMap, LerpValue);
		float3 OutputColor = saturate((ColorMap.rgb * OutputDetail.rgb) * TerrainLights);

		if (UseEnvMap)
		{
			float3 Reflection = reflect(normalize(WorldPos.xyz - _CameraPos.xyz), float3(0.0, 1.0, 0.0));
			float3 EnvMapColor = texCUBE(SamplerTex6_Cube, Reflection);
			OutputColor = saturate(lerp(OutputColor, EnvMapColor, EnvMapScale * (1.0 - LerpValue)));
		}

		ApplyFog(OutputColor, GetFogValue(WorldPos, _CameraPos.xyz));

		Output.Color.rgb = OutputColor * ChartContrib;
		Output.Color.a = 1.0;
	#endif

	Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);

	return Output;
}

PS2FB FullDetail_Hi_PS(VS2PS_FullDetail_Hi Input)
{
	return FullDetail_Hi(Input, false, false);
}

PS2FB FullDetail_Hi_Mounten_PS(VS2PS_FullDetail_Hi Input)
{
	return FullDetail_Hi(Input, true, false);
}

PS2FB FullDetail_Hi_EnvMap_PS(VS2PS_FullDetail_Hi Input)
{
	return FullDetail_Hi(Input, false, true);
}

/*
	High terrain technique
*/

#define GET_RENDERSTATES_NV4X \
	StencilEnable = TRUE; \
	StencilFunc = NOTEQUAL; \
	StencilRef = 0xa; \
	StencilPass = KEEP; \
	StencilZFail = KEEP; \
	StencilFail = KEEP; \

technique Hi_Terrain
{
	// Pass 0
	pass ZFillLightMap
	{
		CullMode = CW;

		ZEnable = TRUE;
		ZWriteEnable = TRUE;
		ZFunc = LESS;

		AlphaBlendEnable = FALSE;

		#if IS_NV4X
			GET_RENDERSTATES_NV4X
		#endif

		VertexShader = compile vs_3_0 Shared_ZFillLightMap_VS();
		PixelShader = compile ps_3_0 Shared_ZFillLightMap_1_PS();
	}

	// Pass 1
	pass PointLight
	{
		CullMode = CW;

		ZEnable = TRUE;
		ZWriteEnable = FALSE;
		ZFunc = LESSEQUAL;

		AlphaBlendEnable = TRUE;
		SrcBlend = ONE;
		DestBlend = ONE;

		#if IS_NV4X
			GET_RENDERSTATES_NV4X
		#endif

		SRGBWriteEnable = FALSE;

		VertexShader = compile vs_3_0 Shared_PointLight_VS();
		PixelShader = compile ps_3_0 Shared_PointLight_PS();
	}

	// Pass 2 (removed)
	pass Spotlight { }

	// Pass 3
	pass LowDiffuse
	{
		CullMode = CW;

		ZEnable = TRUE;
		ZWriteEnable = FALSE;
		ZFunc = LESSEQUAL;

		AlphaBlendEnable = FALSE;
		AlphaTestEnable = FALSE;

		#if IS_NV4X
			GET_RENDERSTATES_NV4X
		#endif

		SRGBWriteEnable = FALSE;

		VertexShader = compile vs_3_0 Shared_LowDetail_VS();
		PixelShader = compile ps_3_0 Shared_LowDetail_PS();
	}

	// Pass 4
	pass FullDetail
	{
		CullMode = CW;

		ZEnable = TRUE;
		ZWriteEnable = FALSE;
		ZFunc = LESSEQUAL;

		AlphaBlendEnable = TRUE;
		SrcBlend = ONE;
		DestBlend = ONE;

		AlphaTestEnable = TRUE;
		AlphaFunc = GREATER;
		AlphaRef = 0;

		// ColorWriteEnable = RED|BLUE|GREEN|ALPHA;
		// FillMode = WireFrame;

		#if IS_NV4X
			GET_RENDERSTATES_NV4X
		#endif

		SRGBWriteEnable = FALSE;

		VertexShader = compile vs_3_0 FullDetail_Hi_VS();
		PixelShader = compile ps_3_0 FullDetail_Hi_PS();
	}

	// Pass 5
	pass FullDetailMounten
	{
		CullMode = CW;

		ZEnable = TRUE;
		ZWriteEnable = FALSE;
		ZFunc = LESSEQUAL;

		AlphaBlendEnable = TRUE;
		SrcBlend = ONE;
		DestBlend = ONE;

		#if IS_NV4X
			GET_RENDERSTATES_NV4X
		#endif

		SRGBWriteEnable = FALSE;

		VertexShader = compile vs_3_0 FullDetail_Hi_VS();
		PixelShader = compile ps_3_0 FullDetail_Hi_Mounten_PS();
	}

	// Pass 6 (removed)
	pass Tunnels { }

	// Pass 7
	pass DirectionalLightShadows
	{
		CullMode = CW;

		// ColorWriteEnable = RED|BLUE|GREEN|ALPHA;

		ZEnable = TRUE;
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;

 		AlphaBlendEnable = FALSE;

		#if IS_NV4X
			GET_RENDERSTATES_NV4X
		#endif

		VertexShader = compile vs_3_0 Shared_DirectionalLightShadows_VS();
		PixelShader = compile ps_3_0 Shared_DirectionalLightShadows_PS();
	}

	// Pass 8 (removed)
	pass DirectionalLightShadowsNV { }

	// Pass 9 (obsolete)
	pass DynamicShadowmap { }

	// Pass 10
	pass { }

	// Pass 11
	pass FullDetailWithEnvMap
	{
		CullMode = CW;

		ZEnable = TRUE;
		ZWriteEnable = FALSE;
		ZFunc = LESSEQUAL;

		AlphaBlendEnable = TRUE;
		SrcBlend = ONE;
		DestBlend = ONE;

		AlphaTestEnable = TRUE;
		AlphaFunc = GREATER;
		AlphaRef = 0;

		// ColorWriteEnable = RED|BLUE|GREEN|ALPHA;

		#if IS_NV4X
			GET_RENDERSTATES_NV4X
		#endif

		SRGBWriteEnable = FALSE;

		VertexShader = compile vs_3_0 FullDetail_Hi_VS();
		PixelShader = compile ps_3_0 FullDetail_Hi_EnvMap_PS();
	}

	// Pass 12 (removed)
	pass MulDiffuseFast { }

	// Pass 13
	pass PerPixelPointlight
	{
		CullMode = CW;

		ZEnable = TRUE;
		ZWriteEnable = FALSE;
		ZFunc = LESSEQUAL;

		AlphaBlendEnable = TRUE;
		SrcBlend = ONE;
		DestBlend = ONE;

		#if IS_NV4X
			GET_RENDERSTATES_NV4X
		#endif

		SRGBWriteEnable = FALSE;

		VertexShader = compile vs_3_0 Shared_PointLight_VS();
		PixelShader = compile ps_3_0 Shared_PointLight_PS();
	}

	// Pass 14
	pass UnderWater
	{
		CullMode = CW;

		ZEnable = TRUE;
		ZWriteEnable = FALSE;
		ZFunc = LESSEQUAL;

		AlphaTestEnable = TRUE;
		AlphaRef = 15; // tl: leave cap above 0 for better results
		AlphaFunc = GREATER;

		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		#if IS_NV4X
			GET_RENDERSTATES_NV4X
		#endif

		SRGBWriteEnable = FALSE;

		VertexShader = compile vs_3_0 Shared_UnderWater_VS();
		PixelShader = compile ps_3_0 Shared_UnderWater_PS();
	}

	// Pass 15
	pass ZFillLightMap2
	{
		// Note: ColorWriteEnable is disabled in code for this
		CullMode = CW;

		ZEnable = TRUE;
		ZWriteEnable = TRUE;
		ZFunc = LESS;

		AlphaBlendEnable = FALSE;

		VertexShader = compile vs_3_0 Shared_ZFillLightMap_VS();
		PixelShader = compile ps_3_0 Shared_ZFillLightMap_2_PS();
	}
}
