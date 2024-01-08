
/*
	Description: Shared functions for terrain shader
*/

#include "shaders/TerrainShader.fxh"
#if !defined(INCLUDED_HEADERS)
	#include "TerrainShader.fxh"
#endif

/*
	Fill lightmapping
*/

struct VS2PS_Shared_ZFillLightMap
{
	float4 HPos : POSITION;
	float3 Tex0 : TEXCOORD0;
};

void VS_Shared_ZFillLightMap(in APP2VS_Shared Input, out VS2PS_Shared_ZFillLightMap Output)
{
	Output = (VS2PS_Shared_ZFillLightMap)0.0;

	float4 MorphedWorldPos = GetMorphedWorldPos(Input);
	Output.HPos = mul(MorphedWorldPos, _ViewProj);

	Output.Tex0.xy = (Input.Pos0.xy * _ScaleBaseUV * _ColorLightTex.x) + _ColorLightTex.y;
	#if defined(LOG_DEPTH)
		Output.Tex0.z = Output.HPos.w + 1.0; // Output depth
	#endif
}

float4 ZFillLightMapColor : register(c0);

void PS_Shared_ZFillLightMap_1(in VS2PS_Shared_ZFillLightMap Input, out PS2FB Output)
{
	float4 LightMap = tex2D(SampleTex0_Clamp, Input.Tex0.xy);

	Output.Color.rgb = saturate(_GIColor.rgb * LightMap.b);
	Output.Color.a = saturate(LightMap.g);

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Tex0.z);
	#endif
}

void PS_Shared_ZFillLightMap_2(in VS2PS_Shared_ZFillLightMap Input, out PS2FB Output)
{
	Output.Color = saturate(ZFillLightMapColor);

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Tex0.z);
	#endif
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
	float Attenuation = GetLightAttenuation(WorldLightVec, _PointLight.attSqrInv);
	float3 HalfNL = GetHalfNL(WorldNormal, WorldLightDir);

	return HalfNL * Attenuation;
}

struct VS2PS_Shared_PointLight_PerVertex
{
	float4 HPos : POSITION;
	float2 Tex0 : TEXCOORD0; // .x = DotNL; .y = Depth;
};

void VS_Shared_PointLight_PerVertex(in APP2VS_Shared Input, out VS2PS_Shared_PointLight_PerVertex Output)
{
	Output = (VS2PS_Shared_PointLight_PerVertex)0.0;

	float4 MorphedWorldPos = GetMorphedWorldPos(Input);

	// Uncompress normal
	float3 WorldNormal = (Input.Normal * 2.0) - 1.0;
	float Lighting = GetLighting(MorphedWorldPos.xyz, WorldNormal);

	Output.HPos = mul(MorphedWorldPos, _ViewProj);
	Output.Tex0.x = Lighting;
	#if defined(LOG_DEPTH)
		Output.Tex0.y = Output.HPos.w + 1.0; // Output depth
	#endif
}

void PS_Shared_PointLight_PerVertex(in VS2PS_Shared_PointLight_PerVertex Input, out PS2FB Output)
{
	Output.Color.rgb = _PointLight.col * Input.Tex0.x;
	Output.Color.a = 0.0;

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Tex0.y);
	#endif
}

struct VS2PS_Shared_PointLight_PerPixel
{
	float4 HPos : POSITION;
	float4 Pos : TEXCOORD0; // .rgb = Lighting; .w = Depth;
	float3 Normal : TEXCOORD1;
};

void VS_Shared_PointLight_PerPixel(in APP2VS_Shared Input, out VS2PS_Shared_PointLight_PerPixel Output)
{
	Output = (VS2PS_Shared_PointLight_PerPixel)0.0;

	float4 MorphedWorldPos = GetMorphedWorldPos(Input);

	Output.HPos = mul(MorphedWorldPos, _ViewProj);
	Output.Pos = MorphedWorldPos;
	#if defined(LOG_DEPTH)
		Output.Pos.w = Output.HPos.w + 1.0; // Output depth
	#endif

	Output.Normal = (Input.Normal * 2.0) - 1.0;
}

void PS_Shared_PointLight_PerPixel(in VS2PS_Shared_PointLight_PerPixel Input, out PS2FB Output)
{
	float3 WorldPos = Input.Pos.xyz;
	float Lighting = GetLighting(WorldPos, Input.Normal);

	Output.Color.rgb = _PointLight.col * Lighting;
	Output.Color.a = 0.0;

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);
	#endif
}

/*
	Low detail
*/

struct VS2PS_Shared_LowDetail
{
	float4 HPos : POSITION;
	float4 Pos : TEXCOORD0;
	float3 Normal : TEXCOORD1;
	float2 Tex0 : TEXCOORD2; // .xy = ColorTex; .zw = CompTex;
	float4 Tex1 : TEXCOORD3; // .xy = ColorLight; .zw = DetailTex;
	float4 LightTex : TEXCOORD4;
};

void VS_Shared_LowDetail(in APP2VS_Shared Input, out VS2PS_Shared_LowDetail Output)
{
	Output = (VS2PS_Shared_LowDetail)0.0;

	float4 MorphedWorldPos = GetMorphedWorldPos(Input);

	Output.HPos = mul(MorphedWorldPos, _ViewProj);
	Output.Pos = MorphedWorldPos;
	#if defined(LOG_DEPTH)
		Output.Pos.w = Output.HPos.w + 1.0; // Output depth
	#endif

	Output.Normal = (Input.Normal * 2.0) - 1.0;

	Output.Tex0 = Input.Pos0.xy;
	Output.Tex1.xy = ((Output.Tex0 * _ScaleBaseUV) * _ColorLightTex.x) + _ColorLightTex.y;
	Output.Tex1.zw = ((Output.Tex0 * _TexScale.xz) * _DetailTex.x) + _DetailTex.y;
	Output.LightTex = ProjToLighting(Output.HPos);
}

struct LowDetail
{
	float2 YPlane;
	float2 XPlane;
	float2 ZPlane;
};

LowDetail GetLowDetail(float3 WorldPos, float2 Tex)
{
	LowDetail Output = (LowDetail)0.0;

	float3 WorldTex = 0.0;
	WorldTex.x = Tex.x * _TexScale.x;
	WorldTex.y = WorldPos.y * _TexScale.y;
	WorldTex.z = Tex.y * _TexScale.z;

	float2 YPlaneTex = WorldTex.xz;
	float2 XPlaneTex = WorldTex.zy;
	float2 ZPlaneTex = WorldTex.xy;
	Output.YPlane = (YPlaneTex * _FarTexTiling.z);
	Output.XPlane = (XPlaneTex * _FarTexTiling.xy) + float2(0.0, _FarTexTiling.w);
	Output.ZPlane = (ZPlaneTex * _FarTexTiling.xy) + float2(0.0, _FarTexTiling.w);

	return Output;
}

void PS_Shared_LowDetail(in VS2PS_Shared_LowDetail Input, out PS2FB Output)
{
	float3 WorldPos = Input.Pos.xyz;
	float3 Normals = normalize(Input.Normal);
	float3 BlendValue = saturate(abs(Normals) - _BlendMod);
	BlendValue = saturate(BlendValue / dot(1.0, BlendValue));

	LowDetail LD = GetLowDetail(WorldPos, Input.Tex0);
	float4 AccumLights = tex2Dproj(SampleTex1_Clamp, Input.LightTex);
	float4 ColorMap = tex2D(SampleTex0_Clamp, Input.Tex1.xy);
	float4 LowComponent = tex2D(SampleTex5_Clamp, Input.Tex1.zw);
	float4 YPlaneLowDetailmap = GetProceduralTiles(SampleTex4_Wrap, LD.YPlane);
	float4 XPlaneLowDetailmap = GetProceduralTiles(SampleTex4_Wrap, LD.XPlane);
	float4 ZPlaneLowDetailmap = GetProceduralTiles(SampleTex4_Wrap, LD.ZPlane);

	float4 TerrainLights = (_SunColor * (AccumLights.a * 2.0)) + AccumLights;

	// If thermals assume no shadows and gray color
	if (IsTisActive())
	{
		TerrainLights = _SunColor + AccumLights;
		ColorMap.rgb = 1.0 / 3.0;
	}

	float Blue = 0.0;
	Blue += (XPlaneLowDetailmap.g * BlendValue.x);
	Blue += (YPlaneLowDetailmap.r * BlendValue.y);
	Blue += (ZPlaneLowDetailmap.g * BlendValue.z);

	float LowDetailMapBlend = LowComponent.r;
	float LowDetailMap = lerp(1.0, YPlaneLowDetailmap.b * 2.0, LowDetailMapBlend);
	LowDetailMap *= lerp(1.0, Blue * 2.0, LowComponent.b);

	// tl: changed a few things with this factor:
	// - using (1-a) is unnecessary, we can just invert the lerp in the ps instead.
	// - by pre-multiplying the _WaterHeight, we can change the (wh-wp)*c to (-wp*c)+whc i.e. from ADD+MUL to MAD
	float WaterLerp = saturate((WorldPos.y / -3.0) + _WaterHeight);
	Output.Color = ColorMap * LowDetailMap * TerrainLights * 2.0;
	Output.Color = lerp(Output.Color, _TerrainWaterColor, WaterLerp);

	#if defined(LIGHTONLY)
		Output.Color = TerrainLights;
	#endif

	ApplyFog(Output.Color.rgb, GetFogValue(WorldPos, _CameraPos.xyz));

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);
	#endif
}

/*
	Dynamic shadowmapping
*/

struct VS2PS_Shared_DynamicShadowmap
{
	float4 HPos : POSITION;
	float4 ShadowTex : TEXCOORD0;
};

void VS_Shared_DynamicShadowmap(in APP2VS_Shared Input, out VS2PS_Shared_DynamicShadowmap Output)
{
	Output = (VS2PS_Shared_DynamicShadowmap)0.0;

	float4 WorldPos = GetWorldPos(Input.Pos0, Input.Pos1);

	Output.HPos = mul(WorldPos, _ViewProj);
	Output.ShadowTex = mul(WorldPos, _LightViewProj);
	Output.ShadowTex.z = Output.ShadowTex.w;
}

void PS_Shared_DynamicShadowmap(in VS2PS_Shared_DynamicShadowmap Input, out float4 Output : COLOR0)
{
	#if NVIDIA
		Output = tex2Dproj(SampleTex2_Clamp, Input.ShadowTex);
	#else
		Output = (tex2Dproj(SampleTex2_Clamp, Input.ShadowTex) == 1.0);
	#endif
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

void VS_Shared_DirectionalLightShadows(in APP2VS_Shared Input, out VS2PS_Shared_DirectionalLightShadows Output)
{
	Output = (VS2PS_Shared_DirectionalLightShadows)0.0;

	float4 MorphedWorldPos = GetMorphedWorldPos(Input);

	Output.HPos = mul(MorphedWorldPos, _ViewProj);
	Output.Pos = Output.HPos;
	#if defined(LOG_DEPTH)
		Output.Pos.w = Output.HPos.w + 1.0; // Output depth
	#endif

	Output.ShadowTex = mul(MorphedWorldPos, _LightViewProj);
	float LightZ = mul(MorphedWorldPos, _LightViewProjOrtho).z;
	#if NVIDIA
		Output.ShadowTex.z = LightZ * Output.ShadowTex.w;
	#else
		Output.ShadowTex.z = LightZ;
	#endif

	Output.Tex0 = (Input.Pos0.xy * _ScaleBaseUV * _ColorLightTex.x) + _ColorLightTex.y;
}

void PS_Shared_DirectionalLightShadows(in VS2PS_Shared_DirectionalLightShadows Input, out PS2FB Output)
{
	float4 LightMap = tex2D(SampleTex0_Clamp, Input.Tex0.xy);
	#if HIGHTERRAIN || MIDTERRAIN
		float AvgShadowValue = GetShadowFactor(SampleShadowMap, Input.ShadowTex);
	#else
		float AvgShadowValue = GetShadowFactor(SampleTex2_Clamp, Input.ShadowTex);
	#endif

	Output.Color = saturate((LightMap.z * _GIColor) * 2.0) * 0.5;
	Output.Color.w = (AvgShadowValue < LightMap.y) ? AvgShadowValue : LightMap.y;

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);
	#endif
}

/*
	Underwater
*/

struct VS2PS_Shared_UnderWater
{
	float4 HPos : POSITION;
	float4 Pos : TEXCOORD0;
};

void VS_Shared_UnderWater(in APP2VS_Shared Input, out VS2PS_Shared_UnderWater Output)
{
	Output = (VS2PS_Shared_UnderWater)0.0;

	float4 MorphedWorldPos = GetMorphedWorldPos(Input);

	Output.HPos = mul(MorphedWorldPos, _ViewProj);
	Output.Pos = MorphedWorldPos;
	#if defined(LOG_DEPTH)
		Output.Pos.w = Output.HPos.w + 1.0; // Output depth
	#endif
}

void PS_Shared_UnderWater(in VS2PS_Shared_UnderWater Input, out PS2FB Output)
{
	float3 WorldPos = Input.Pos.xyz;

	Output.Color.rgb = _TerrainWaterColor.rgb;
	Output.Color.a = saturate((WorldPos.y / -3.0) + _WaterHeight);

	ApplyFog(Output.Color.rgb, GetFogValue(WorldPos, _CameraPos.xyz));

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);
	#endif
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
	float3 Tex0 : TEXCOORD2; // .xy = Tex0; .z = Input.Pos1.x;
	float4 Tex1 : TEXCOORD3; // .xy = ColorLight; .zw = LowDetail;
};

void VS_Shared_ST_Normal(in APP2VS_Shared_ST_Normal Input, out VS2PS_Shared_ST_Normal Output)
{
	Output = (VS2PS_Shared_ST_Normal)0.0;

	float4 WorldPos = 0.0;
	WorldPos.xz = mul(float4(Input.Pos0.xy, 0.0, 1.0), _STTransXZ).xy;
	WorldPos.yw = (Input.Pos1.xw * _STScaleTransY.xy) + _STScaleTransY.zw;

	Output.HPos = mul(WorldPos, _ViewProj);
	Output.Pos = WorldPos;
	#if defined(LOG_DEPTH)
		Output.Pos.w = Output.HPos.w + 1.0; // Output depth
	#endif

	Output.Normal = Input.Normal;

	Output.Tex0 = float3(Input.Tex0, Input.Pos1.x);
	Output.Tex1.xy = (Output.Tex0.xy * _STColorLightTex.x) + _STColorLightTex.y;
	Output.Tex1.zw = (Output.Tex0.xy * _STLowDetailTex.x) + _STLowDetailTex.y;
}

struct SurroundingTerrain
{
	float2 YPlane;
	float2 XPlane;
	float2 ZPlane;
};

SurroundingTerrain GetSurroundingTerrain(float3 WorldPos, float3 Tex)
{
	SurroundingTerrain Output = (SurroundingTerrain)0.0;

	float3 WorldTex = 0.0;
	WorldTex.x = WorldPos.x * _STTexScale.x;
	WorldTex.y = -(Tex.z * _STTexScale.y);
	WorldTex.z = WorldPos.z * _STTexScale.z;

	float2 YPlaneTex = WorldTex.xz;
	float2 XPlaneTex = WorldTex.zy;
	float2 ZPlaneTex = WorldTex.xy;
	Output.YPlane = (YPlaneTex * _STFarTexTiling.z);
	Output.XPlane = (XPlaneTex * _STFarTexTiling.xy) + float2(0.0, _STFarTexTiling.w);
	Output.ZPlane = (ZPlaneTex * _STFarTexTiling.xy) + float2(0.0, _STFarTexTiling.w);

	return Output;
}

void PS_Shared_ST_Normal(in VS2PS_Shared_ST_Normal Input, out PS2FB Output)
{
	float3 WorldPos = Input.Pos.xyz;
	float3 WorldNormal = normalize(Input.Normal);
	float3 BlendValue = saturate(abs(WorldNormal) - _BlendMod);
	BlendValue = saturate(BlendValue / dot(1.0, BlendValue));

	SurroundingTerrain ST = GetSurroundingTerrain(WorldPos, Input.Tex0);
	float4 ColorMap = tex2D(SampleTex0_Clamp, Input.Tex1.xy);
	float4 LowComponent = tex2D(SampleTex5_Clamp, Input.Tex1.zw);
	float4 YPlaneLowDetailmap = GetProceduralTiles(SampleTex4_Wrap, ST.YPlane) * 2.0;
	float4 XPlaneLowDetailmap = GetProceduralTiles(SampleTex4_Wrap, ST.XPlane) * 2.0;
	float4 ZPlaneLowDetailmap = GetProceduralTiles(SampleTex4_Wrap, ST.ZPlane) * 2.0;

	// If thermals assume gray color
	if (IsTisActive())
	{
		ColorMap.rgb = 1.0 / 3.0;
	}

	float LowDetailMap = lerp(1.0, YPlaneLowDetailmap.z, saturate(dot(LowComponent.xy, 1.0)));
	float Blue = 0.0;
	Blue += (XPlaneLowDetailmap.y * BlendValue.x);
	Blue += (YPlaneLowDetailmap.x * BlendValue.y);
	Blue += (ZPlaneLowDetailmap.y * BlendValue.z);
	LowDetailMap *= lerp(1.0, Blue, LowComponent.z);

	Output.Color = ColorMap * LowDetailMap;

	// M (temporary fix)
	if (_GIColor.r < 0.01)
	{
		Output.Color.rb = 0.0;
	}

	ApplyFog(Output.Color.rgb, GetFogValue(WorldPos, _CameraPos.xyz));

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);
	#endif
}

technique Shared_SurroundingTerrain
{
	// Normal
	pass p0
	{
		CullMode = CW;

		ZEnable = TRUE;
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;

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

struct HI_APP2VS_OccluderShadow
{
	float4 Pos0 : POSITION0;
	float4 Pos1 : POSITION1;
};

struct HI_VS2PS_OccluderShadow
{
	float4 HPos : POSITION;
	float4 DepthPos : TEXCOORD0;
};

float4 GetOccluderShadow(float4 Pos, float4x4 LightTrapMat, float4x4 LightMat)
{
	float4 ShadowTex = mul(Pos, LightTrapMat);
	float LightZ = mul(Pos, LightMat).z;
	ShadowTex.z = LightZ * ShadowTex.w;
	return ShadowTex;
}

void VS_Hi_OccluderShadow(in HI_APP2VS_OccluderShadow Input, out HI_VS2PS_OccluderShadow Output)
{
	Output = (HI_VS2PS_OccluderShadow)0.0;

	float4 WorldPos = GetWorldPos(Input.Pos0, Input.Pos1);
	Output.HPos = GetOccluderShadow(WorldPos, _vpLightTrapezMat, _vpLightMat);
	Output.DepthPos = Output.HPos; // Output shadow depth
}

void PS_Hi_OccluderShadow(in HI_VS2PS_OccluderShadow Input, out float4 Output : COLOR0)
{
	#if NVIDIA
		Output = 0.5;
	#else
		Output = Input.DepthPos.z / Input.DepthPos.w;
	#endif
}

technique TerrainOccludershadow
{
	// Pass 16
	pass OccluderShadow
	{
		CullMode = NONE;

		ZEnable = TRUE;
		ZWriteEnable = TRUE;
		ZFunc = LESS;

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
