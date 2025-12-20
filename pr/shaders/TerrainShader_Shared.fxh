#line 2 "TerrainShader_Shared.fxh"

/*
	Description: Shared functions for terrain shader
*/

#include "shaders/TerrainShader.fxh"
#if !defined(_HEADERS_)
	#include "TerrainShader.fxh"
#endif

/*
	Fill lightmapping

	ZFillLightMap generates the accumulation lightmap for the following shaders:
		RaShaderRoad.fx | texture LightMap; SampleAccumLightMap
		RoadCompiled.fx | texture LightMap; SampleAccumLightMap
		TerrainShader_Shared.fxh | PS_Shared_LowDetail() -> SampleTex1_Clamp
		TerrainShader_Shared.fxh | FullDetail_Hi() -> SampleTex1_Clamp
*/

struct VS2PS_Shared_ZFillLightMap
{
	float4 HPos : POSITION;
	float3 Tex0 : TEXCOORD0;
};

VS2PS_Shared_ZFillLightMap VS_Shared_ZFillLightMap(APP2VS_Shared Input)
{
	VS2PS_Shared_ZFillLightMap Output = (VS2PS_Shared_ZFillLightMap)0.0;
	float4 MorphedWorldPos = GetMorphedWorldPos(Input);

	Output.HPos = mul(MorphedWorldPos, _ViewProj);
	Output.Tex0.xy = (Input.Pos0.xy * _ScaleBaseUV * _ColorLightTex.x) + _ColorLightTex.y;

	// Output Depth
	#if PR_LOG_DEPTH
		Output.Tex0.z = Output.HPos.w + 1.0;
	#endif

	return Output;
}

float4 ZFillLightMapColor : register(c0);

RGraphics_PS2FB PS_Shared_ZFillLightMap_1(VS2PS_Shared_ZFillLightMap Input)
{
	RGraphics_PS2FB Output = (RGraphics_PS2FB)0.0;
	float4 LightMap = RPixel_SampleLightMap(SampleTex0_Clamp, Input.Tex0.xy, PR_LIGHTMAP_SIZE_TERRAIN);

	// Pack accumulated light
	Output.Color = Ra_SetPackedAccumulatedLight(LightMap, _GIColor.rgb, _PointColor.rgb);

	#if PR_LOG_DEPTH
		Output.Depth = RDepth_ApplyLogarithmicDepth(Input.Tex0.z);
	#endif

	return Output;
}

RGraphics_PS2FB PS_Shared_ZFillLightMap_2(VS2PS_Shared_ZFillLightMap Input)
{
	RGraphics_PS2FB Output = (RGraphics_PS2FB)0.0;

	Output.Color = saturate(ZFillLightMapColor);

	#if PR_LOG_DEPTH
		Output.Depth = RDepth_ApplyLogarithmicDepth(Input.Tex0.z);
	#endif

	return Output;
}

/*
	Pointlight
*/

float GetLighting(float3 WorldPos, float3 WorldNormal)
{
	WorldNormal = normalize(WorldNormal);
	float3 WorldLightVec = _PointLight.pos - WorldPos;
	float3 WorldLightDir = normalize(WorldLightVec);

	// Calculate lighting
	float Attenuation = RPixel_GetLightAttenuation(WorldLightVec, _PointLight.attSqrInv);
	float HalfNL = RDirectXTK_GetHalfNL(WorldNormal, WorldLightDir);

	return HalfNL * Attenuation;
}

struct VS2PS_Shared_PointLight_PerVertex
{
	float4 HPos : POSITION;
	float2 Tex0 : TEXCOORD0; // .x = DotNL; .y = Depth;
};

VS2PS_Shared_PointLight_PerVertex VS_Shared_PointLight_PerVertex(APP2VS_Shared Input)
{
	VS2PS_Shared_PointLight_PerVertex Output = (VS2PS_Shared_PointLight_PerVertex)0.0;
	float4 MorphedWorldPos = GetMorphedWorldPos(Input);

	// Uncompress normal
	float3 WorldNormal = RGraphics_ConvertUNORMtoSNORM_FLT3(Input.Normal);
	float Lighting = GetLighting(MorphedWorldPos.xyz, WorldNormal);

	Output.HPos = mul(MorphedWorldPos, _ViewProj);
	Output.Tex0.x = Lighting;

	// Output Depth
	#if PR_LOG_DEPTH
		Output.Tex0.y = Output.HPos.w + 1.0;
	#endif

	return Output;
}

RGraphics_PS2FB PS_Shared_PointLight_PerVertex(VS2PS_Shared_PointLight_PerVertex Input)
{
	RGraphics_PS2FB Output = (RGraphics_PS2FB)0.0;

	float DotNL = Input.Tex0.x;

	Output.Color = float4(_PointLight.col * DotNL, 0.0);
	RDirectXTK_TonemapAndLinearToSRGBEst(Output.Color);

	#if PR_LOG_DEPTH
		Output.Depth = RDepth_ApplyLogarithmicDepth(Input.Tex0.y);
	#endif

	return Output;
}

struct VS2PS_Shared_PointLight_PerPixel
{
	float4 HPos : POSITION;
	float4 Pos : TEXCOORD0; // .rgb = Lighting; .w = Depth;
	float3 Normal : TEXCOORD1;
};

VS2PS_Shared_PointLight_PerPixel VS_Shared_PointLight_PerPixel(APP2VS_Shared Input)
{
	VS2PS_Shared_PointLight_PerPixel Output = (VS2PS_Shared_PointLight_PerPixel)0.0;
	float4 MorphedWorldPos = GetMorphedWorldPos(Input);

	Output.HPos = mul(MorphedWorldPos, _ViewProj);
	Output.Pos = MorphedWorldPos;

	// Output Depth
	#if PR_LOG_DEPTH
		Output.Pos.w = Output.HPos.w + 1.0;
	#endif

	Output.Normal = RGraphics_ConvertUNORMtoSNORM_FLT3(Input.Normal);

	return Output;
}

RGraphics_PS2FB PS_Shared_PointLight_PerPixel(VS2PS_Shared_PointLight_PerPixel Input)
{
	RGraphics_PS2FB Output = (RGraphics_PS2FB)0.0;

	float3 WorldPos = Input.Pos.xyz;
	float Lighting = GetLighting(WorldPos, Input.Normal);

	Output.Color = float4(Lighting * _PointLight.col, 0.0);
	RDirectXTK_TonemapAndLinearToSRGBEst(Output.Color);

	#if PR_LOG_DEPTH
		Output.Depth = RDepth_ApplyLogarithmicDepth(Input.Pos.w);
	#endif

	return Output;
}

/*
	Low detail
*/

struct VS2PS_Shared_LowDetail
{
	float4 HPos : POSITION;
	float4 Pos : TEXCOORD0;
	float3 Normal : TEXCOORD1;
	float4 Tex0 : TEXCOORD2; // .xy = ColorLight; .zw = DetailTex;
	float2 YPlaneTex : TEXCOORD3;
	float4 XZPlaneTex : TEXCOORD4;
	float4 LightTex : TEXCOORD5;
};

struct LowDetail
{
	float2 YPlaneTex;
	float2 XPlaneTex;
	float2 ZPlaneTex;
};

LowDetail GetLowDetail(float3 MorphedWorldPos, float2 WorldPos)
{
	LowDetail Output = (LowDetail)0.0;

	float3 WorldTex = 0.0;
	WorldTex.x = WorldPos.x * _TexScale.x;
	WorldTex.y = MorphedWorldPos.y * _TexScale.y;
	WorldTex.z = WorldPos.y * _TexScale.z;

	// Calculate far texcoords
	Output.YPlaneTex = (WorldTex.xz * _FarTexTiling.z);
	Output.XPlaneTex = (WorldTex.zy * _FarTexTiling.xy) + float2(0.0, _FarTexTiling.w);
	Output.ZPlaneTex = (WorldTex.xy * _FarTexTiling.xy) + float2(0.0, _FarTexTiling.w);

	return Output;
}

VS2PS_Shared_LowDetail VS_Shared_LowDetail(APP2VS_Shared Input)
{
	VS2PS_Shared_LowDetail Output = (VS2PS_Shared_LowDetail)0.0;
	float4 MorphedWorldPos = GetMorphedWorldPos(Input);

	Output.HPos = mul(MorphedWorldPos, _ViewProj);
	Output.Pos = MorphedWorldPos;

	// Output Depth
	#if PR_LOG_DEPTH
		Output.Pos.w = Output.HPos.w + 1.0;
	#endif

	Output.Normal = RGraphics_ConvertUNORMtoSNORM_FLT3(Input.Normal);
	Output.Tex0.xy = ((Input.Pos0.xy * _ScaleBaseUV) * _ColorLightTex.x) + _ColorLightTex.y;
	Output.Tex0.zw = ((Input.Pos0.xy * _TexScale.xz) * _DetailTex.x) + _DetailTex.y;
	Output.LightTex = ProjToLighting(Output.HPos);

	LowDetail LD = GetLowDetail(MorphedWorldPos.xyz, Input.Pos0.xy);
	Output.YPlaneTex = LD.YPlaneTex;
	Output.XZPlaneTex = float4(LD.XPlaneTex, LD.ZPlaneTex);

	return Output;
}

RGraphics_PS2FB PS_Shared_LowDetail(VS2PS_Shared_LowDetail Input)
{
	RGraphics_PS2FB Output = (RGraphics_PS2FB)0.0;

	float3 WorldPos = Input.Pos.xyz;
	float3 Normals = normalize(Input.Normal);

	float3 BlendValue = smoothstep(_BlendMod, 1.0, abs(Normals));
	BlendValue = saturate(BlendValue / dot(1.0, BlendValue));

	float4 AccumLights = tex2Dproj(SampleTex1_Clamp, Input.LightTex);
	float4 ColorMap = RDirectXTK_SRGBToLinearEst(tex2D(SampleTex0_Clamp, Input.Tex0.xy));
	float4 LowComponent = tex2D(SampleTex5_Clamp, Input.Tex0.zw);
	float4 YPlaneLowDetailmap = tex2D(SampleTex4_Wrap, Input.YPlaneTex);
	float4 XPlaneLowDetailmap = tex2D(SampleTex4_Wrap, Input.XZPlaneTex.xy);
	float4 ZPlaneLowDetailmap = tex2D(SampleTex4_Wrap, Input.XZPlaneTex.zw);
	float4 TerrainLights = Ra_GetUnpackedAccumulatedLight(AccumLights, _SunColor.rgb);

	// If thermals assume no shadows and gray color
	if (Ra_IsTisActive())
	{
		TerrainLights = Ra_GetUnpackedAccumulatedLight(AccumLights, 0.0);
		TerrainLights += (_SunColor * 2.0);
		ColorMap.rgb = 1.0 / 3.0;
	}

	float Blue = 0.0;
	Blue += (XPlaneLowDetailmap.y * BlendValue.x);
	Blue += (YPlaneLowDetailmap.x * BlendValue.y);
	Blue += (ZPlaneLowDetailmap.y * BlendValue.z);

	float LowDetailMapBlend = smoothstep(0.0, 1.0, LowComponent.r + LowComponent.g);
	float LowDetailMap = lerp(1.0, YPlaneLowDetailmap.b * 2.0, LowDetailMapBlend);
	LowDetailMap *= lerp(1.0, Blue * 2.0, LowComponent.b);
	float4 OutputColor = ColorMap * LowDetailMap * TerrainLights;

	// tl: changed a few things with this factor:
	// - using (1-a) is unnecessary, we can just invert the lerp in the ps instead.
	// - by pre-multiplying the _WaterHeight, we can change the (wh-wp)*c to (-wp*c)+whc i.e. from ADD+MUL to MAD
	float WaterLerp = saturate((WorldPos.y / -3.0) + _WaterHeight);
	OutputColor = lerp(OutputColor, _TerrainWaterColor, WaterLerp);

	#if defined(LIGHTONLY)
		OutputColor = TerrainLights;
	#endif

	Output.Color = OutputColor;
	Ra_ApplyFog(Output.Color.rgb, Ra_GetFogValue(WorldPos, _CameraPos.xyz));
	RDirectXTK_TonemapAndLinearToSRGBEst(Output.Color);

	#if PR_LOG_DEPTH
		Output.Depth = RDepth_ApplyLogarithmicDepth(Input.Pos.w);
	#endif

	return Output;
}

/*
	Dynamic shadowmapping
*/

struct VS2PS_Shared_DynamicShadowmap
{
	float4 HPos : POSITION;
	float4 ShadowTex : TEXCOORD0;
};

VS2PS_Shared_DynamicShadowmap VS_Shared_DynamicShadowmap(APP2VS_Shared Input)
{
	VS2PS_Shared_DynamicShadowmap Output = (VS2PS_Shared_DynamicShadowmap)0.0;

	float4 WorldPos = GetWorldPos(Input.Pos0, Input.Pos1);
	Output.HPos = mul(WorldPos, _ViewProj);
	Output.ShadowTex = mul(WorldPos, _LightViewProj);
	Output.ShadowTex.z = Output.ShadowTex.w;

	return Output;
}

float4 PS_Shared_DynamicShadowmap(VS2PS_Shared_DynamicShadowmap Input) : COLOR0
{
	float AvgShadowValue = tex2Dproj(SampleTex2_Clamp, Input.ShadowTex).x == 1.0;
	return AvgShadowValue;
}

/*
	Terrain Directional shadow shader
	Applies dynamic shadows to the terrain's light buffer

	NOTE: Do not apply fog in this shader because it only writes to a light buffer, not the terrain itself.
	NOTE: Final compositing happens in PS_Shared_LowDetail and PS_FullDetail_Hi
*/

struct VS2PS_Shared_DirectionalLightShadows
{
	float4 HPos : POSITION;
	float4 Pos : TEXCOORD0;
	float2 Tex0 : TEXCOORD1;
	float4 ShadowTex : TEXCOORD2;
};

VS2PS_Shared_DirectionalLightShadows VS_Shared_DirectionalLightShadows(APP2VS_Shared Input)
{
	VS2PS_Shared_DirectionalLightShadows Output = (VS2PS_Shared_DirectionalLightShadows)0.0;
	float4 MorphedWorldPos = GetMorphedWorldPos(Input);

	Output.HPos = mul(MorphedWorldPos, _ViewProj);
	Output.Pos = Output.HPos;

	// Output Depth
	#if PR_LOG_DEPTH
		Output.Pos.w = Output.HPos.w + 1.0;
	#endif

	Output.ShadowTex = mul(MorphedWorldPos, _LightViewProj);
	float LightZ = mul(MorphedWorldPos, _LightViewProjOrtho).z;
	#if NVIDIA
		Output.ShadowTex.z = LightZ * Output.ShadowTex.w;
	#else
		Output.ShadowTex.z = LightZ;
	#endif

	Output.Tex0 = (Input.Pos0.xy * _ScaleBaseUV * _ColorLightTex.x) + _ColorLightTex.y;

	return Output;
}

RGraphics_PS2FB PS_Shared_DirectionalLightShadows(VS2PS_Shared_DirectionalLightShadows Input)
{
	RGraphics_PS2FB Output = (RGraphics_PS2FB)0.0;

	float4 LightMap = RPixel_SampleLightMap(SampleTex0_Clamp, Input.Tex0.xy, PR_LIGHTMAP_SIZE_TERRAIN);
	#if HIGHTERRAIN || MIDTERRAIN
		float AvgShadowValue = RDepth_GetShadowFactor(SampleShadowMap, Input.ShadowTex);
	#else
		float AvgShadowValue = RDepth_GetShadowFactor(SampleTex2_Clamp, Input.ShadowTex);
	#endif

	// Pack accumulated light
	LightMap.g = min(LightMap.g, AvgShadowValue);
	Output.Color = Ra_SetPackedAccumulatedLight(LightMap, _GIColor.rgb, _PointColor.rgb);

	#if PR_LOG_DEPTH
		Output.Depth = RDepth_ApplyLogarithmicDepth(Input.Pos.w);
	#endif

	return Output;
}

/*
	Underwater
*/

struct VS2PS_Shared_UnderWater
{
	float4 HPos : POSITION;
	float4 Pos : TEXCOORD0;
};

VS2PS_Shared_UnderWater VS_Shared_UnderWater(APP2VS_Shared Input)
{
	VS2PS_Shared_UnderWater Output = (VS2PS_Shared_UnderWater)0.0;
	float4 MorphedWorldPos = GetMorphedWorldPos(Input);

	Output.HPos = mul(MorphedWorldPos, _ViewProj);
	Output.Pos = MorphedWorldPos;

	// Output Depth
	#if PR_LOG_DEPTH
		Output.Pos.w = Output.HPos.w + 1.0;
	#endif

	return Output;
}

RGraphics_PS2FB PS_Shared_UnderWater(VS2PS_Shared_UnderWater Input)
{
	RGraphics_PS2FB Output = (RGraphics_PS2FB)0.0;

	float3 WorldPos = Input.Pos.xyz;
	float3 OutputColor = _TerrainWaterColor.rgb;
	float WaterLerp = saturate((WorldPos.y / -3.0) + _WaterHeight);

	Output.Color = float4(OutputColor, WaterLerp);
	Ra_ApplyFog(Output.Color.rgb, Ra_GetFogValue(WorldPos, _CameraPos.xyz));
	RDirectXTK_TonemapAndLinearToSRGBEst(Output.Color);

	#if PR_LOG_DEPTH
		Output.Depth = RDepth_ApplyLogarithmicDepth(Input.Pos.w);
	#endif

	return Output;
}

/*
	Surrounding Terrain (ST)
*/

struct APP2VS_Shared_ST_Normal
{
	float2 Pos0 : POSITION0;
	float4 Pos1 : POSITION1;
	float2 Tex0 : TEXCOORD0;
	float3 Normal : NORMAL;
};

struct VS2PS_Shared_ST_Normal
{
	float4 HPos : POSITION;
	float4 Pos : TEXCOORD0;
	float3 Normal : TEXCOORD1;
	float4 Tex0 : TEXCOORD2; // .xy = ColorLight; .zw = LowDetail;
	float2 YPlaneTex : TEXCOORD3;
	float4 XZPlaneTex : TEXCOORD4; // .xy = XPlane; .zw = ZPlane;
};

struct SurroundingTerrain
{
	float2 YPlaneTex;
	float2 XPlaneTex;
	float2 ZPlaneTex;
};

SurroundingTerrain GetSurroundingTerrain(float3 WorldPos)
{
	SurroundingTerrain Output = (SurroundingTerrain)0.0;

	float3 WorldTex = 0.0;
	WorldTex.x = WorldPos.x * _STTexScale.x;
	WorldTex.y = WorldPos.y * _STTexScale.y;
	WorldTex.z = WorldPos.z * _STTexScale.z;

	// Get surrounding terrain texcoords
	Output.YPlaneTex = (WorldTex.xz * _STFarTexTiling.z);
	Output.XPlaneTex = (WorldTex.zy * _STFarTexTiling.xy) + float2(0.0, _STFarTexTiling.w);
	Output.ZPlaneTex = (WorldTex.xy * _STFarTexTiling.xy) + float2(0.0, _STFarTexTiling.w);

	return Output;
}

VS2PS_Shared_ST_Normal VS_Shared_ST_Normal(APP2VS_Shared_ST_Normal Input)
{
	VS2PS_Shared_ST_Normal Output = (VS2PS_Shared_ST_Normal)0.0;

	float4 WorldPos = 0.0;
	WorldPos.xz = mul(float4(Input.Pos0.xy, 0.0, 1.0), _STTransXZ).xy;
	WorldPos.yw = (Input.Pos1.xw * _STScaleTransY.xy) + _STScaleTransY.zw;

	Output.HPos = mul(WorldPos, _ViewProj);
	Output.Pos = WorldPos;

	// Output Depth
	#if PR_LOG_DEPTH
		Output.Pos.w = Output.HPos.w + 1.0;
	#endif

	Output.Normal = Input.Normal;
	Output.Tex0.xy = (Input.Tex0.xy * _STColorLightTex.x) + _STColorLightTex.y;
	Output.Tex0.zw = (Input.Tex0.xy * _STLowDetailTex.x) + _STLowDetailTex.y;

	SurroundingTerrain ST = GetSurroundingTerrain(WorldPos.xyz);
	Output.YPlaneTex = ST.YPlaneTex;
	Output.XZPlaneTex = float4(ST.XPlaneTex, ST.ZPlaneTex);

	return Output;
}

RGraphics_PS2FB PS_Shared_ST_Normal(VS2PS_Shared_ST_Normal Input)
{
	RGraphics_PS2FB Output = (RGraphics_PS2FB)0.0;

	float3 WorldPos = Input.Pos.xyz;
	float3 WorldNormal = normalize(Input.Normal);

	float3 BlendValue = smoothstep(_BlendMod, 1.0, abs(WorldNormal));
	BlendValue = saturate(BlendValue / dot(1.0, BlendValue));

	float4 ColorMap = RDirectXTK_SRGBToLinearEst(tex2D(SampleTex0_Clamp, Input.Tex0.xy));
	float4 LowComponent = tex2D(SampleTex5_Clamp, Input.Tex0.zw);
	float4 YPlaneLowDetailmap = RPixel_GetProceduralTiles(SampleTex4_Wrap, Input.YPlaneTex);
	float4 XPlaneLowDetailmap = RPixel_GetProceduralTiles(SampleTex4_Wrap, Input.XZPlaneTex.xy);
	float4 ZPlaneLowDetailmap = RPixel_GetProceduralTiles(SampleTex4_Wrap, Input.XZPlaneTex.zw);

	// If thermals assume gray color
	if (Ra_IsTisActive())
	{
		ColorMap.rgb = 1.0 / 3.0;
	}

	float Blue = 0.0;
	Blue += (XPlaneLowDetailmap.y * BlendValue.x);
	Blue += (YPlaneLowDetailmap.x * BlendValue.y);
	Blue += (ZPlaneLowDetailmap.y * BlendValue.z);

	float LowDetailMapBlend = smoothstep(0.0, 1.0, LowComponent.r + LowComponent.g);
	float LowDetailMap = lerp(1.0, YPlaneLowDetailmap.b * 2.0, LowDetailMapBlend);
	LowDetailMap *= lerp(1.0, Blue * 2.0, LowComponent.b);
	float4 OutputColor = ColorMap * LowDetailMap;

	// M (temporary fix)
	if (_GIColor.r < 0.01)
	{
		OutputColor.rb = 0.0;
	}

	Output.Color = OutputColor;
	Ra_ApplyFog(Output.Color.rgb, Ra_GetFogValue(WorldPos, _CameraPos.xyz));
	RDirectXTK_TonemapAndLinearToSRGBEst(Output.Color);

	#if PR_LOG_DEPTH
		Output.Depth = RDepth_ApplyLogarithmicDepth(Input.Pos.w);
	#endif

	return Output;
}

technique Shared_SurroundingTerrain
{
	// Normal
	pass p0
	{
		CullMode = CW;

		ZEnable = TRUE;
		ZFunc = PR_ZFUNC_WITHEQUAL;
		ZWriteEnable = TRUE;

		AlphaBlendEnable = FALSE;

		VertexShader = compile vs_3_0 VS_Shared_ST_Normal();
		PixelShader = compile ps_3_0 PS_Shared_ST_Normal();
	}
}

/*
	Shadow occlusion shaders
*/

float4x4 _vpLightMat : vpLightMat;
float4x4 _vpLightTrapezMat : vpLightTrapezMat;

struct APP2VS_HI_OccluderShadow
{
	float4 Pos0 : POSITION0;
	float4 Pos1 : POSITION1;
};

struct VS2PS_HI_OccluderShadow
{
	float4 HPos : POSITION;
	float2 DepthPos : TEXCOORD0;
};

VS2PS_HI_OccluderShadow VS_Hi_OccluderShadow(APP2VS_HI_OccluderShadow Input)
{
	VS2PS_HI_OccluderShadow Output = (VS2PS_HI_OccluderShadow)0.0;

	float4 WorldPos = GetWorldPos(Input.Pos0, Input.Pos1);
	Output.HPos = RDepth_GetMeshShadowProjection(WorldPos, _vpLightTrapezMat, _vpLightMat, Output.DepthPos);

	return Output;
}

float4 PS_Hi_OccluderShadow(VS2PS_HI_OccluderShadow Input) : COLOR0
{
	return Input.DepthPos.x / Input.DepthPos.y;
}

technique TerrainOccludershadow
{
	// Pass 16
	pass OccluderShadow
	{
		CullMode = NONE;

		ZEnable = TRUE;
		ZFunc = LESS;
		ZWriteEnable = TRUE;

		AlphaBlendEnable = FALSE;
		AlphaTestEnable = FALSE;

		#if NVIDIA
			ColorWriteEnable = 0;
		#else
			ColorWriteEnable = RED|BLUE|GREEN|ALPHA;
		#endif

		VertexShader = compile vs_3_0 VS_Hi_OccluderShadow();
		PixelShader = compile ps_3_0 PS_Hi_OccluderShadow();
	}
}
