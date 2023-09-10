#include "shaders/RealityGraphics.fxh"

/*
	Description:
	- High-settings terrain shader
	- Renders the terrain's high-setting shading
	- Renders the terrain's high-setting shadowing
*/

/*
	Terrainmapping shader
*/

struct VS2PS_FullDetail_Hi
{
	float4 HPos : POSITION;
	float4 Pos : TEXCOORD0;
	float3 Normal : TEXCOORD1;
	float3 Tex0 : TEXCOORD2; // .xy = Input.Pos0.xy; .z = InterpVal;
	float4 LightTex : TEXCOORD3;
};

VS2PS_FullDetail_Hi VS_FullDetail_Hi(APP2VS_Shared Input)
{
	VS2PS_FullDetail_Hi Output = (VS2PS_FullDetail_Hi)0;
	WorldSpace WS = GetWorldSpaceData(Input);

	// tl: output HPos as early as possible.
	Output.HPos = mul(WS.Pos, _ViewProj);
	Output.Pos.xyz = WS.Pos.xyz;
	#if defined(LOG_DEPTH)
		Output.Pos.w = Output.HPos.w + 1.0; // Output depth
	#endif

	// tl: uncompress normal
	Output.Normal.xyz = (Input.Normal * 2.0) - 1.0;
	Output.Tex0 = float3(Input.Pos0.xy, saturate(WS.LerpValue));
	Output.LightTex = ProjToLighting(Output.HPos);

	return Output;
}

struct FullDetail
{
	float2 NearYPlane;
	float2 NearXPlane;
	float2 NearZPlane;
	float2 FarYPlane;
	float2 FarXPlane;
	float2 FarZPlane;
	float2 ColorLight;
	float2 Detail;
};

FullDetail GetFullDetail(float3 WorldPos, float2 Tex)
{
	FullDetail Output = (FullDetail)0;

	// Calculate triplanar texcoords
	float3 WorldTex = 0.0;
	WorldTex.x = Tex.x * _TexScale.x;
	WorldTex.y = WorldPos.y * _TexScale.y;
	WorldTex.z = Tex.y * _TexScale.z;

	float2 XPlaneTex = WorldTex.zy;
	float2 YPlaneTex = WorldTex.xz;
	float2 ZPlaneTex = WorldTex.xy;
	Output.NearYPlane = (YPlaneTex * _NearTexTiling.z);
	Output.NearXPlane = (XPlaneTex * _NearTexTiling.xy) + float2(0.0, _NearTexTiling.w);
	Output.NearZPlane = (ZPlaneTex * _NearTexTiling.xy) + float2(0.0, _NearTexTiling.w);
	Output.FarYPlane = (YPlaneTex * _FarTexTiling.z);
	Output.FarXPlane = (XPlaneTex * _FarTexTiling.xy) + float2(0.0, _FarTexTiling.w);
	Output.FarZPlane = (ZPlaneTex * _FarTexTiling.xy) + float2(0.0, _FarTexTiling.w);
	Output.ColorLight = (YPlaneTex * _ColorLightTex.x) + _ColorLightTex.y;
	Output.Detail = (YPlaneTex * _DetailTex.x) + _DetailTex.y;

	return Output;
}

PS2FB FullDetail_Hi(VS2PS_FullDetail_Hi Input, uniform bool UseMounten, uniform bool UseEnvMap)
{
	PS2FB Output = (PS2FB)0;

	float LerpValue = Input.Tex0.z;
	float3 WorldPos = Input.Pos.xyz;
	float3 WorldNormal = normalize(Input.Normal);
	float ScaledLerpValue = saturate((LerpValue * 0.5) + 0.5);
	FullDetail FD = GetFullDetail(WorldPos, Input.Tex0.xy);

	float4 AccumLights = tex2Dproj(SampleTex1_Clamp, Input.LightTex);
	float4 Component = tex2D(SampleTex2_Clamp, FD.Detail);

	float3 BlendValue = saturate(abs(WorldNormal) - _BlendMod);
	BlendValue = saturate(BlendValue / dot(1.0, BlendValue));
	float3 TerrainLights = (_SunColor.rgb * (AccumLights.a * 2.0)) + AccumLights.rgb;
	float ChartContribution = dot(Component.xyz, _ComponentSelector.xyz);

	#if defined(LIGHTONLY)
		float3 OutputColor = TerrainLights;
	#else
		float3 ColorMap = tex2D(SampleTex0_Clamp, FD.ColorLight);
		float4 LowComponent = tex2D(SampleTex5_Clamp, FD.Detail);
		float4 XPlaneDetailmap = tex2D(SampleTex6_Wrap, FD.NearXPlane);
		float4 YPlaneDetailmap = tex2D(SampleTex3_Wrap, FD.NearYPlane);
		float4 ZPlaneDetailmap = tex2D(SampleTex6_Wrap, FD.NearZPlane);
		float3 XPlaneLowDetailmap = tex2D(SampleTex4_Wrap, FD.FarXPlane);
		float3 YPlaneLowDetailmap = tex2D(SampleTex4_Wrap, FD.FarYPlane);
		float3 ZPlaneLowDetailmap = tex2D(SampleTex4_Wrap, FD.FarZPlane);
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
		float LowDetailMap = lerp(1.0, YPlaneLowDetailmap.b * 2.0, LowDetailMapBlend);
		LowDetailMap *= lerp(1.0, Blue * 2.0, LowComponent.b);

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

		float4 BothDetailMap = (DetailMap * LowDetailMap) * 2.0;
		float4 OutputDetail = lerp(BothDetailMap, LowDetailMap, LerpValue);
		float3 OutputColor = ColorMap.rgb * OutputDetail.rgb * TerrainLights * 2.0;

		if (UseEnvMap)
		{
			float3 Reflection = reflect(normalize(WorldPos.xyz - _CameraPos.xyz), float3(0.0, 1.0, 0.0));
			float3 EnvMapColor = texCUBE(SamplerTex6_Cube, Reflection);
			OutputColor = lerp(OutputColor, EnvMapColor, EnvMapScale * (1.0 - LerpValue));
		}
	#endif

	Output.Color = float4(OutputColor, ChartContribution);
	ApplyFog(Output.Color.rgb, GetFogValue(WorldPos, _CameraPos));
	Output.Color.rgb *= ChartContribution;

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);
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
		ZWriteEnable = TRUE;
		ZFunc = LESS;

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
		ZWriteEnable = FALSE;
		ZFunc = LESSEQUAL;

		AlphaBlendEnable = TRUE;
		SrcBlend = ONE;
		DestBlend = ONE;

		#if IS_NV4X
			GET_RENDERSTATES_NV4X
		#endif

		VertexShader = compile vs_3_0 VS_Shared_PointLight();
		PixelShader = compile ps_3_0 PS_Shared_PointLight();
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

		VertexShader = compile vs_3_0 VS_Shared_LowDetail();
		PixelShader = compile ps_3_0 PS_Shared_LowDetail();
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

		VertexShader = compile vs_3_0 VS_FullDetail_Hi();
		PixelShader = compile ps_3_0 PS_FullDetail_Hi();
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
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;

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
		ZWriteEnable = FALSE;
		ZFunc = LESSEQUAL;

		AlphaBlendEnable = TRUE;
		SrcBlend = ONE;
		DestBlend = ONE;

		#if IS_NV4X
			GET_RENDERSTATES_NV4X
		#endif

		VertexShader = compile vs_3_0 VS_Shared_PointLight();
		PixelShader = compile ps_3_0 PS_Shared_PointLight();
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

		VertexShader = compile vs_3_0 VS_Shared_UnderWater();
		PixelShader = compile ps_3_0 PS_Shared_UnderWater();
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

		VertexShader = compile vs_3_0 VS_Shared_ZFillLightMap();
		PixelShader = compile ps_3_0 PS_Shared_ZFillLightMap_2();
	}
}
