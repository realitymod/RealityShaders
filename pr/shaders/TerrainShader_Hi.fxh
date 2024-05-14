#include "shaders/TerrainShader.fxh"
#if !defined(_HEADERS_)
	#include "TerrainShader.fxh"
#endif

/*
	Description:
	- High-settings terrain shader
	- Renders the terrain's high-setting shading
	- Renders the terrain's high-setting shadowing
*/

/*
	Terrainmapping shader
*/

float GetAdjustedNear()
{
	float NoLOD = _NearFarMorphLimits.x * 62500.0; // No-Lod: 250x normal -> 62500x
	#if HIGHTERRAIN
		float LOD = _NearFarMorphLimits.x * 16.0; // High-Lod: 4x normal -> 16x
	#else
		float LOD = _NearFarMorphLimits.x * 9.0; // Med-Lod: 3x normal -> 9x
	#endif

	// Only the near distance changes due to increased LOD distance. This needs to be multiplied by
	// the square of the factor by which we increased. Assuming 200m base lod this turns out to
	// If no-lods is enabled, then near limit is really low
	float AdjustedNear = (_NearFarMorphLimits.x < 0.00000001) ? NoLOD : LOD;
	return AdjustedNear;
}

float GetLerpValue(float3 WorldPos, float3 CameraPos)
{
	float CameraDistance = GetCameraDistance(WorldPos, CameraPos);
	float AdjustedNear = GetAdjustedNear();
	return saturate(CameraDistance * AdjustedNear - _NearFarMorphLimits.y);
}

struct VS2PS_FullDetail_Hi
{
	float4 HPos : POSITION;
	float4 Pos : TEXCOORD0;
	float4 Normal : TEXCOORD1; // .xyz = Normal; .w = Depth;
	float4 Tex0 : TEXCOORD2; // .xy = ColorLight; .zw = Detail;
	float4 YPlaneTex : TEXCOORD3; // .xy = Near; .zw = Far;
	float4 XPlaneTex : TEXCOORD4; // .xy = Near; .zw = Far;
	float4 ZPlaneTex : TEXCOORD5; // .xy = Near; .zw = Far;
	float4 LightTex : TEXCOORD6;
};

struct FullDetail
{
	float2 NearYPlane;
	float2 NearXPlane;
	float2 NearZPlane;
	float2 FarYPlane;
	float2 FarXPlane;
	float2 FarZPlane;
};

FullDetail GetFullDetail(float3 MorphedWorldPos, float2 WorldPos)
{
	FullDetail Output = (FullDetail)0.0;

	// Initialize triplanar texcoords
	float3 WorldTex = 0.0;

	// Calculate near texcoords
	WorldTex.x = WorldPos.x * _TexScale.x;
	WorldTex.y = MorphedWorldPos.y * _TexScale.y;
	WorldTex.z = WorldPos.y * _TexScale.z;
	Output.NearYPlane = (WorldTex.xz * _NearTexTiling.z);
	Output.NearXPlane = (WorldTex.zy * _NearTexTiling.xy) + float2(0.0, _NearTexTiling.w);
	Output.NearZPlane = (WorldTex.xy * _NearTexTiling.xy) + float2(0.0, _NearTexTiling.w);
	Output.FarYPlane = (WorldTex.xz * _FarTexTiling.z);
	Output.FarXPlane = (WorldTex.zy * _FarTexTiling.xy) + float2(0.0, _FarTexTiling.w);
	Output.FarZPlane = (WorldTex.xy * _FarTexTiling.xy) + float2(0.0, _FarTexTiling.w);

	return Output;
}

VS2PS_FullDetail_Hi VS_FullDetail_Hi(APP2VS_Shared Input)
{
	VS2PS_FullDetail_Hi Output = (VS2PS_FullDetail_Hi)0.0;
	float4 MorphedWorldPos = GetMorphedWorldPos(Input);
	float2 YPlaneTex = Input.Pos0.xy * _TexScale.xz;

	// tl: output HPos as early as possible.
	Output.HPos = mul(MorphedWorldPos, _ViewProj);
	Output.Pos = MorphedWorldPos;

	// tl: uncompress normal
	Output.Normal.xyz = (Input.Normal * 2.0) - 1.0;
	Output.Tex0.xy = (YPlaneTex * _ColorLightTex.x) + _ColorLightTex.y;
	Output.Tex0.zw = (YPlaneTex * _DetailTex.x) + _DetailTex.y;
	Output.LightTex = ProjToLighting(Output.HPos);

	FullDetail FD = GetFullDetail(MorphedWorldPos.xyz, Input.Pos0.xy);
	Output.YPlaneTex = float4(FD.NearYPlane, FD.FarYPlane);
	Output.XPlaneTex = float4(FD.NearXPlane, FD.FarXPlane);
	Output.ZPlaneTex = float4(FD.NearZPlane, FD.FarZPlane);

	// Output Depth
	#if defined(LOG_DEPTH)
		Output.Normal.w = Output.HPos.w + 1.0;
	#endif

	return Output;
}


PS2FB FullDetail_Hi(VS2PS_FullDetail_Hi Input, uniform bool UseMounten, uniform bool UseEnvMap)
{
	PS2FB Output = (PS2FB)0.0;

	float4 WorldPos = Input.Pos;
	float3 WorldNormal = normalize(Input.Normal.xyz);
	float Depth = Input.Normal.w;

	float LerpValue = GetLerpValue(WorldPos.xwz, _CameraPos.xwz);
	float ScaledLerpValue = saturate((LerpValue * 0.5) + 0.5);

	float4 AccumLights = SRGBToLinearEst(tex2Dproj(SampleTex1_Clamp, Input.LightTex));
	float4 Component = tex2D(SampleTex2_Clamp, Input.Tex0.zw);

	float3 BlendValue = saturate(abs(WorldNormal.xyz) - _BlendMod);
	BlendValue = saturate(BlendValue / dot(1.0, BlendValue));
	float3 TerrainLights = (_SunColor.rgb * (AccumLights.a * 2.0)) + AccumLights.rgb;
	float ChartContribution = dot(Component.xyz, _ComponentSelector.xyz);

	#if defined(LIGHTONLY)
		float3 OutputColor = TerrainLights;
	#else
		float3 ColorMap = SRGBToLinearEst(tex2D(SampleTex0_Clamp, Input.Tex0.xy));
		float4 LowComponent = tex2D(SampleTex5_Clamp, Input.Tex0.zw);
		float4 YPlaneDetailmap = SRGBToLinearEst(tex2D(SampleTex3_Wrap, Input.YPlaneTex.xy) * float4(2.0, 2.0, 2.0, 1.0));
		float4 XPlaneDetailmap = SRGBToLinearEst(tex2D(SampleTex6_Wrap, Input.XPlaneTex.xy) * 2.0);
		float4 ZPlaneDetailmap = SRGBToLinearEst(tex2D(SampleTex6_Wrap, Input.ZPlaneTex.xy) * 2.0);
		float3 YPlaneLowDetailmap = SRGBToLinearEst(tex2D(SampleTex4_Wrap, Input.YPlaneTex.zw) * 2.0);
		float3 XPlaneLowDetailmap = SRGBToLinearEst(tex2D(SampleTex4_Wrap, Input.XPlaneTex.zw) * 2.0);
		float3 ZPlaneLowDetailmap = SRGBToLinearEst(tex2D(SampleTex4_Wrap, Input.ZPlaneTex.zw) * 2.0);
		float EnvMapScale = YPlaneDetailmap.a;

		// If thermals assume no shadows and gray color
		if (IsTisActive())
		{
			TerrainLights = _SunColor.rgb + AccumLights.rgb;
			ColorMap.rgb = 1.0 / 3.0;
		}

		float Blue = 0.0;
		Blue += (XPlaneLowDetailmap.g * BlendValue.x);
		Blue += (YPlaneLowDetailmap.r * BlendValue.y);
		Blue += (ZPlaneLowDetailmap.g * BlendValue.z);

		float LowDetailMapBlend = LowComponent.r * ScaledLerpValue;
		float LowDetailMap = lerp(1.0, YPlaneLowDetailmap.b, LowDetailMapBlend);
		LowDetailMap *= lerp(1.0, Blue, LowComponent.b);

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

		float4 BothDetailMap = DetailMap * LowDetailMap;
		float4 OutputDetail = lerp(BothDetailMap, LowDetailMap, LerpValue);
		float3 OutputColor = ColorMap.rgb * OutputDetail.rgb * TerrainLights * 2.0;

		if (UseEnvMap)
		{
			float3 Reflection = reflect(normalize(WorldPos.xyz - _CameraPos.xyz), float3(0.0, 1.0, 0.0));
			float3 EnvMapColor = SRGBToLinearEst(texCUBE(SamplerTex6_Cube, Reflection)).rgb;
			OutputColor = lerp(OutputColor, EnvMapColor, EnvMapScale * (1.0 - LerpValue));
		}
	#endif

	Output.Color = float4(OutputColor, ChartContribution);
	ApplyFog(Output.Color.rgb, GetFogValue(WorldPos.xyz, _CameraPos.xyz));
	TonemapAndLinearToSRGBEst(Output.Color);
	Output.Color.rgb *= ChartContribution;

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Depth);
	#endif

	return Output;
}

PS2FB PS_FullDetail_Hi(VS2PS_FullDetail_Hi Input)
{
	return FullDetail_Hi(Input, false, false);
}

PS2FB PS_FullDetail_Hi_Mounten(VS2PS_FullDetail_Hi Input)
{
	return FullDetail_Hi(Input, true, false);
}

PS2FB PS_FullDetail_Hi_EnvMap(VS2PS_FullDetail_Hi Input)
{
	return FullDetail_Hi(Input, false, true);
}

/*
	High terrain technique
*/

technique Hi_Terrain
{
	// Pass 0
	pass ZFillLightMap
	{
		CullMode = CW;

		ZEnable = TRUE;
		ZFunc = PR_ZFUNC_NOEQUAL;
		ZWriteEnable = TRUE;

		AlphaBlendEnable = FALSE;

		#if IS_NV4X
			GET_RENDERSTATES_NV4X
		#endif

		VertexShader = compile vs_3_0 VS_Shared_ZFillLightMap();
		PixelShader = compile ps_3_0 PS_Shared_ZFillLightMap_1();
	}

	// Pass 1
	pass PointLight
	{
		CullMode = CW;

		ZEnable = TRUE;
		ZFunc = PR_ZFUNC_WITHEQUAL;
		ZWriteEnable = FALSE;

		AlphaBlendEnable = TRUE;
		SrcBlend = ONE;
		DestBlend = ONE;

		#if IS_NV4X
			GET_RENDERSTATES_NV4X
		#endif

		VertexShader = compile vs_3_0 VS_Shared_PointLight_PerVertex();
		PixelShader = compile ps_3_0 PS_Shared_PointLight_PerVertex();
	}

	// Pass 2 (removed)
	pass Spotlight { }

	// Pass 3
	pass LowDiffuse
	{
		CullMode = CW;

		ZEnable = TRUE;
		ZFunc = PR_ZFUNC_WITHEQUAL;
		ZWriteEnable = FALSE;

		AlphaBlendEnable = FALSE;
		AlphaTestEnable = FALSE;

		#if IS_NV4X
			GET_RENDERSTATES_NV4X
		#endif

		VertexShader = compile vs_3_0 VS_Shared_LowDetail();
		PixelShader = compile ps_3_0 PS_Shared_LowDetail();
	}

	// Pass 4
	pass FullDetail
	{
		CullMode = CW;

		ZEnable = TRUE;
		ZFunc = PR_ZFUNC_WITHEQUAL;
		ZWriteEnable = FALSE;

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

		VertexShader = compile vs_3_0 VS_FullDetail_Hi();
		PixelShader = compile ps_3_0 PS_FullDetail_Hi();
	}

	// Pass 5
	pass FullDetailMounten
	{
		CullMode = CW;

		ZEnable = TRUE;
		ZFunc = PR_ZFUNC_WITHEQUAL;
		ZWriteEnable = FALSE;

		AlphaBlendEnable = TRUE;
		SrcBlend = ONE;
		DestBlend = ONE;

		#if IS_NV4X
			GET_RENDERSTATES_NV4X
		#endif

		VertexShader = compile vs_3_0 VS_FullDetail_Hi();
		PixelShader = compile ps_3_0 PS_FullDetail_Hi_Mounten();
	}

	// Pass 6 (removed)
	pass Tunnels { }

	// Pass 7
	pass DirectionalLightShadows
	{
		CullMode = CW;

		// ColorWriteEnable = RED|BLUE|GREEN|ALPHA;

		ZEnable = TRUE;
		ZFunc = PR_ZFUNC_WITHEQUAL;
		ZWriteEnable = TRUE;

 		AlphaBlendEnable = FALSE;

		#if IS_NV4X
			GET_RENDERSTATES_NV4X
		#endif

		VertexShader = compile vs_3_0 VS_Shared_DirectionalLightShadows();
		PixelShader = compile ps_3_0 PS_Shared_DirectionalLightShadows();
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
		ZFunc = PR_ZFUNC_WITHEQUAL;
		ZWriteEnable = FALSE;

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

		VertexShader = compile vs_3_0 VS_FullDetail_Hi();
		PixelShader = compile ps_3_0 PS_FullDetail_Hi_EnvMap();
	}

	// Pass 12 (removed)
	pass MulDiffuseFast { }

	// Pass 13
	pass PerPixelPointlight
	{
		CullMode = CW;

		ZEnable = TRUE;
		ZFunc = PR_ZFUNC_WITHEQUAL;
		ZWriteEnable = FALSE;

		AlphaBlendEnable = TRUE;
		SrcBlend = ONE;
		DestBlend = ONE;

		#if IS_NV4X
			GET_RENDERSTATES_NV4X
		#endif

		VertexShader = compile vs_3_0 VS_Shared_PointLight_PerPixel();
		PixelShader = compile ps_3_0 PS_Shared_PointLight_PerPixel();
	}

	// Pass 14
	pass UnderWater
	{
		CullMode = CW;

		ZEnable = TRUE;
		ZFunc = PR_ZFUNC_WITHEQUAL;
		ZWriteEnable = FALSE;

		AlphaTestEnable = TRUE;
		AlphaRef = 15; // tl: leave cap above 0 for better results
		AlphaFunc = GREATER;

		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		#if IS_NV4X
			GET_RENDERSTATES_NV4X
		#endif

		VertexShader = compile vs_3_0 VS_Shared_UnderWater();
		PixelShader = compile ps_3_0 PS_Shared_UnderWater();
	}

	// Pass 15
	pass ZFillLightMap2
	{
		// Note: ColorWriteEnable is disabled in code for this
		CullMode = CW;

		ZEnable = TRUE;
		ZFunc = PR_ZFUNC_NOEQUAL;
		ZWriteEnable = TRUE;

		AlphaBlendEnable = FALSE;

		VertexShader = compile vs_3_0 VS_Shared_ZFillLightMap();
		PixelShader = compile ps_3_0 PS_Shared_ZFillLightMap_2();
	}
}
