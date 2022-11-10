
/*
	Description: High-settings terrain shader
*/

#include "shaders/RealityGraphics.fxh"

/*
	Terrainmapping shader
*/

struct VS2PS_FullDetail_Hi
{
	float4 HPos : POSITION;
	float2 ColorTex : TEXCOORD0;
	float2 DetailTex : TEXCOORD1;
	float4 LightTex : TEXCOORD2;
	float4 YPlaneTex : TEXCOORD3; // .xy = Near; .zw = Far;
	float4 XPlaneTex : TEXCOORD4; // .xy = Near; .zw = Far;
	float4 ZPlaneTex : TEXCOORD5; // .xy = Near; .zw = Far;
	float3 WorldPos : TEXCOORD6;
	float4 P_WorldNormal_Fade : TEXCOORD7; // .xyz = Normal; .w = InterpVal;
};

VS2PS_FullDetail_Hi FullDetail_Hi_VS(APP2VS_Shared_Default Input)
{
	VS2PS_FullDetail_Hi Output;

	float4 WorldPos = 0.0;
	WorldPos.xz = (Input.Pos0.xy * _ScaleTransXZ.xy) + _ScaleTransXZ.zw;
	WorldPos.yw = (Input.Pos1.xw * _ScaleTransY.xy); // tl: Trans is always 0

	float YDelta, InterpVal;
	MorphPosition(WorldPos, Input.MorphDelta, Input.Pos0.z, YDelta, InterpVal);

	// tl: output HPos as early as possible.
	Output.HPos = mul(WorldPos, _ViewProj);

	float3 Tex = 0.0;
	Tex.x = Input.Pos0.x * _TexScale.x;
	Tex.y = WorldPos.y * _TexScale.y;
	Tex.z = Input.Pos0.y * _TexScale.z;
	float2 XPlaneTexCoord = Tex.zy;
	float2 YPlaneTexCoord = Tex.xz;
	float2 ZPlaneTexCoord = Tex.xy;

	Output.ColorTex = (YPlaneTexCoord * _ColorLightTex.x) + _ColorLightTex.y;
	Output.DetailTex = (YPlaneTexCoord * _DetailTex.x) + _DetailTex.y;

	Output.LightTex = ProjToLighting(Output.HPos);

	Output.YPlaneTex.xy = (YPlaneTexCoord * _NearTexTiling.z);
	Output.YPlaneTex.zw = (YPlaneTexCoord * _FarTexTiling.z);

	Output.XPlaneTex.xy = (XPlaneTexCoord * _NearTexTiling.xy) + float2(0.0, _NearTexTiling.w);
	Output.XPlaneTex.zw = (XPlaneTexCoord * _FarTexTiling.xy) + float2(0.0, _FarTexTiling.w);

	Output.ZPlaneTex.xy = (ZPlaneTexCoord * _NearTexTiling.xy) + float2(0.0, _NearTexTiling.w);
	Output.ZPlaneTex.zw = (ZPlaneTexCoord * _FarTexTiling.xy) + float2(0.0, _FarTexTiling.w);

	Output.WorldPos = WorldPos;

	// tl: uncompress normal
	Output.P_WorldNormal_Fade.xyz = normalize((Input.Normal * 2.0) - 1.0);
	Output.P_WorldNormal_Fade.w = InterpVal;

	return Output;
}

float4 FullDetail_Hi(VS2PS_FullDetail_Hi Input, uniform bool UseMounten, uniform bool UseEnvMap)
{
	float4 AccumLights = tex2Dproj(SampleTex1_Clamp, Input.LightTex);

	float3 WorldPos = Input.WorldPos;
	float3 WorldNormal = normalize(Input.P_WorldNormal_Fade.xyz);
	float InterpVal = Input.P_WorldNormal_Fade.w;
	float ScaledInterpVal = saturate((InterpVal * 0.5) + 0.5);

	float3 BlendValue = saturate(abs(WorldNormal) - _BlendMod);
	BlendValue = saturate(BlendValue / dot(1.0, BlendValue));

	#if LIGHTONLY
		float4 Light = 2.0 * AccumLights.w * _SunColor + AccumLights;
		float4 Component = tex2D(SampleTex2_Clamp, Input.ColorTex);
		float ChartContrib = dot(_ComponentSelector, Component);
		return ChartContrib * Light;
	#else
		float3 Light = 2.0 * AccumLights.w * _SunColor.rgb + AccumLights.rgb;
		float4 Component = tex2D(SampleTex2_Clamp, Input.DetailTex);
		float ChartContrib = dot(_ComponentSelector, Component);
		float3 ColorMap = tex2D(SampleTex0_Clamp, Input.ColorTex);

		// If thermals assume no shadows and gray color
		if (FogColor.r < 0.01)
		{
			Light.rgb = 2.0 * _SunColor.rgb + AccumLights.rgb;
			ColorMap.rgb = 1.0 / 3.0;
		}

		float4 YPlaneDetailmap = tex2D(SampleTex3_Wrap, Input.YPlaneTex.xy);
		float4 XPlaneDetailmap = tex2D(SampleTex6_Wrap, Input.XPlaneTex.xy);
		float4 ZPlaneDetailmap = tex2D(SampleTex6_Wrap, Input.ZPlaneTex.xy);
		float EnvMapScale = YPlaneDetailmap.a;

		float3 HiDetail = 1.0;
		if (UseMounten)
		{
			HiDetail = (YPlaneDetailmap.xyz * BlendValue.y) +
					   (XPlaneDetailmap.xyz * BlendValue.x) +
					   (ZPlaneDetailmap.xyz * BlendValue.z);
		}
		else
		{
			HiDetail = YPlaneDetailmap.xyz;
		}

		float3 YPlaneLowDetailmap = tex2D(SampleTex4_Wrap, Input.YPlaneTex.zw);
		float3 XPlaneLowDetailmap = tex2D(SampleTex4_Wrap, Input.XPlaneTex.zw);
		float3 ZPlaneLowDetailmap = tex2D(SampleTex4_Wrap, Input.ZPlaneTex.zw);
		float Mounten = (YPlaneLowDetailmap.x * BlendValue.y) +
						(XPlaneLowDetailmap.y * BlendValue.x) +
						(ZPlaneLowDetailmap.y * BlendValue.z);

		float3 LowComponent = tex2D(SampleTex5_Clamp, Input.DetailTex);
		float LowDetailMap = lerp(0.5, YPlaneLowDetailmap.z, LowComponent.x * ScaledInterpVal);
		LowDetailMap *= (4.0 * lerp(0.5, Mounten, LowComponent.z));

		float3 BothDetailmap = (HiDetail * LowDetailMap) * 2.0;
		float3 DetailOut = lerp(BothDetailmap, LowDetailMap, InterpVal);
		float3 OutputColor = (ColorMap * DetailOut) * Light;

		if (UseEnvMap)
		{
			float3 Reflection = reflect(normalize(WorldPos.xyz - _CameraPos.xyz), float3(0.0, 1.0, 0.0));
			float3 EnvMapColor = texCUBE(SamplerTex6_Cube, Reflection);
			OutputColor = lerp(OutputColor, EnvMapColor, EnvMapScale * (1.0 - InterpVal));
		}

		OutputColor = OutputColor * 2.0;
		ApplyFog(OutputColor, GetFogValue(WorldPos, _CameraPos.xyz));
		return float4(OutputColor * ChartContrib, ChartContrib);
	#endif
}

float4 FullDetail_Hi_PS(VS2PS_FullDetail_Hi Input) : COLOR
{
	return FullDetail_Hi(Input, false, false);
}

float4 FullDetail_Hi_Mounten_PS(VS2PS_FullDetail_Hi Input) : COLOR
{
	return FullDetail_Hi(Input, true, false);
}

float4 FullDetail_Hi_EnvMap_PS(VS2PS_FullDetail_Hi Input) : COLOR
{
	return FullDetail_Hi(Input, false, true);
}

/*
	Terrain DirShadow shader
*/

float4 Hi_DirectionalLightShadows_PS(VS2PS_Shared_DirectionalLightShadows Input) : COLOR
{
	float4 LightMap = tex2D(SampleTex0_Clamp, Input.Tex0);
	float4 AvgShadowValue = GetShadowFactor(SampleShadowMap, Input.ShadowTex);

	float4 Light = saturate(LightMap.z * _GIColor * 2.0) * 0.5;
	Light.w = (AvgShadowValue.z < LightMap.y) ? AvgShadowValue.z : LightMap.y;
	return Light;
}

/*
	High terrain technique
*/

#define NV4X_RENDERSTATES \
	StencilEnable = TRUE; \
	StencilFunc = NOTEQUAL; \
	StencilRef = 0xa; \
	StencilPass = KEEP; \
	StencilZFail = KEEP; \
	StencilFail = KEEP; \

technique Hi_Terrain
{
	pass ZFillLightMap // p0
	{
		CullMode = CW;
		ZEnable = TRUE;
		ZWriteEnable = TRUE;
		ZFunc = LESS;
		AlphaBlendEnable = FALSE;

		#if IS_NV4X
			NV4X_RENDERSTATES
		#endif

		VertexShader = compile vs_3_0 Shared_ZFillLightMap_VS();
		PixelShader = compile ps_3_0 Shared_ZFillLightMap_1_PS();
	}

	pass PointLight // p1
	{
		CullMode = CW;
		ZEnable = TRUE;
		ZWriteEnable = FALSE;
		ZFunc = LESSEQUAL;
		AlphaBlendEnable = TRUE;
		SrcBlend = ONE;
		DestBlend = ONE;

		#if IS_NV4X
			NV4X_RENDERSTATES
		#endif

		VertexShader = compile vs_3_0 Shared_PointLight_VS();
		PixelShader = compile ps_3_0 Shared_PointLight_PS();
	}

	pass {} // spotlight (removed) p2

	pass LowDiffuse //p3
	{
		CullMode = CW;
		ZEnable = TRUE;
		ZWriteEnable = FALSE;
		ZFunc = LESSEQUAL;
		AlphaBlendEnable = FALSE;
		AlphaTestEnable = FALSE;

		#if IS_NV4X
			NV4X_RENDERSTATES
		#endif

		VertexShader = compile vs_3_0 Shared_LowDetail_VS();
		PixelShader = compile ps_3_0 Shared_LowDetail_PS();
	}

	pass FullDetail // p4
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
			NV4X_RENDERSTATES
		#endif

		VertexShader = compile vs_3_0 FullDetail_Hi_VS();
		PixelShader = compile ps_3_0 FullDetail_Hi_PS();
	}

	pass FullDetailMounten // p5
	{
		CullMode = CW;
		ZEnable = TRUE;
		ZWriteEnable = FALSE;
		ZFunc = LESSEQUAL;
		AlphaBlendEnable = TRUE;
		SrcBlend = ONE;
		DestBlend = ONE;

		#if IS_NV4X
			NV4X_RENDERSTATES
		#endif

		VertexShader = compile vs_3_0 FullDetail_Hi_VS();
		PixelShader = compile ps_3_0 FullDetail_Hi_Mounten_PS();
	}

	pass { } // p6 tunnels (removed)

	pass DirectionalLightShadows // p7
	{
		CullMode = CW;
		//ColorWriteEnable = RED|BLUE|GREEN|ALPHA;
		ZEnable = TRUE;
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;
 		AlphaBlendEnable = FALSE;

		#if IS_NV4X
			NV4X_RENDERSTATES
		#endif

		VertexShader = compile vs_3_0 Shared_DirectionalLightShadows_VS();
		PixelShader = compile ps_3_0 Hi_DirectionalLightShadows_PS();
	}

	pass { } // DirectionalLightShadowsNV (removed) //p8
	pass DynamicShadowmap {} // Obsolete // p9
	pass { } // p10

	pass FullDetailWithEnvMap // p11
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
			NV4X_RENDERSTATES
		#endif

		VertexShader = compile vs_3_0 FullDetail_Hi_VS();
		PixelShader = compile ps_3_0 FullDetail_Hi_EnvMap_PS();
	}

	pass {} // mulDiffuseFast (removed) p12

	pass PerPixelPointlight // p13
	{
		CullMode = CW;
		ZEnable = TRUE;
		ZWriteEnable = FALSE;
		ZFunc = LESSEQUAL;
		AlphaBlendEnable = TRUE;
		SrcBlend = ONE;
		DestBlend = ONE;

		#if IS_NV4X
			NV4X_RENDERSTATES
		#endif

		VertexShader = compile vs_3_0 Shared_PointLight_VS();
		PixelShader = compile ps_3_0 Shared_PointLight_PS();
	}

	pass UnderWater // p14
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
			NV4X_RENDERSTATES
		#endif

		VertexShader = compile vs_3_0 Shared_UnderWater_VS();
		PixelShader = compile ps_3_0 Shared_UnderWater_PS();
	}

	pass ZFillLightMap2 // p15
	{
		//note: ColorWriteEnable is disabled in code for this
		CullMode = CW;
		ZEnable = TRUE;
		ZWriteEnable = TRUE;
		ZFunc = LESS;
		AlphaBlendEnable = FALSE;

		VertexShader = compile vs_3_0 Shared_ZFillLightMap_VS();
		PixelShader = compile ps_3_0 Shared_ZFillLightMap_2_PS();
	}
}
