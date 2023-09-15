#include "shaders/RealityGraphics.fxh"

/*
	Description: Shared functions for terrain shader
*/

struct APP2VS_Shared
{
	float4 Pos0 : POSITION0;
	float4 Pos1 : POSITION1;
	float4 MorphDelta : POSITION2;
	float3 Normal : NORMAL;
};

struct PS2FB
{
	float4 Color : COLOR;
	#if defined(LOG_DEPTH)
		float Depth : DEPTH;
	#endif
};

/*
	Basic morphed technique
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

void MorphPosition
(
	inout float4 WorldPos,
	in float4 MorphDelta,
	in float MorphDeltaAdderSelector,
	out float YDelta,
	out float LerpValue
)
{
	// tl: This is now based on squared values (besides camPos)
	// tl: This assumes that input WorldPos.w == 1 to work correctly! (it always is)
	// tl: This all works out because camera height is set to height+1 so
	//     CameraVec becomes (cx, cheight+1, cz) - (vx, 1, vz)
	// tl: YScale is now pre-multiplied into morphselector
	float3 CameraVec = _CameraPos.xwz - WorldPos.xwz;
	float CameraDist = dot(CameraVec, CameraVec);

	LerpValue = saturate(CameraDist * _NearFarMorphLimits.x - _NearFarMorphLimits.y);
	YDelta = dot(_MorphDeltaSelector, MorphDelta) * LerpValue;
	YDelta += dot(_MorphDeltaAdder[MorphDeltaAdderSelector * 256], MorphDelta);

	float AdjustedNear = GetAdjustedNear();
	LerpValue = saturate(CameraDist * AdjustedNear - _NearFarMorphLimits.y);
	WorldPos.y = WorldPos.y - YDelta;
}

float4 ProjToLighting(float4 HPos)
{
	// tl: This has been rearranged optimally (I believe) into 1 MUL and 1 MAD,
	//     don't change this without thinking twice.
	//     ProjOffset now includes screen->texture bias as well as half-texel offset
	//     ProjScale is screen->texture scale/invert operation
	// Tex = (HPos.x * 0.5 + 0.5 + HTexel, HPos.y * -0.5 + 0.5 + HTexel, HPos.z, HPos.w)
	return HPos * _TexProjScale + (_TexProjOffset * HPos.w);
}

float4 GetWorldPos(float4 Pos0, float4 Pos1)
{
	float4 WorldPos = 0.0;
	WorldPos.xz = (Pos0.xy * _ScaleTransXZ.xy) + _ScaleTransXZ.zw;
	WorldPos.yw = (Pos1.xw * _ScaleTransY.xy);
	return WorldPos;
}

struct WorldSpace
{
	float4 Pos;
	float YDelta;
	float LerpValue;
};

WorldSpace GetWorldSpaceData(APP2VS_Shared Input)
{
	WorldSpace Output = (WorldSpace)0;
	Output.Pos = GetWorldPos(Input.Pos0, Input.Pos1);
	MorphPosition(Output.Pos, Input.MorphDelta, Input.Pos0.z, Output.YDelta, Output.LerpValue);
	return Output;
}

/*
	Fill lightmapping
*/

struct VS2PS_Shared_ZFillLightMap
{
	float4 HPos : POSITION;
	float3 Tex0 : TEXCOORD0;
};

VS2PS_Shared_ZFillLightMap VS_Shared_ZFillLightMap(APP2VS_Shared Input)
{
	VS2PS_Shared_ZFillLightMap Output = (VS2PS_Shared_ZFillLightMap)0;
	WorldSpace WS = GetWorldSpaceData(Input);

	Output.HPos = mul(WS.Pos, _ViewProj);
	Output.Tex0.xy = (Input.Pos0.xy * _ScaleBaseUV * _ColorLightTex.x) + _ColorLightTex.y;
	#if defined(LOG_DEPTH)
		Output.Tex0.z = Output.HPos.w + 1.0; // Output depth
	#endif

	return Output;
}

float4 ZFillLightMapColor : register(c0);

PS2FB PS_Shared_ZFillLightMap_1(VS2PS_Shared_ZFillLightMap Input)
{
	PS2FB Output = (PS2FB)0;
	float4 LightMap = tex2D(SampleTex0_Clamp, Input.Tex0.xy);
	Output.Color = saturate(float4(_GIColor.rgb * LightMap.bbb, LightMap.g));
	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Tex0.z);
	#endif
	return Output;
}

PS2FB PS_Shared_ZFillLightMap_2(VS2PS_Shared_ZFillLightMap Input)
{
	PS2FB Output = (PS2FB)0;
	Output.Color = saturate(ZFillLightMapColor);
	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Tex0.z);
	#endif
	return Output;
}

/*
	Pointlight
*/

float GetDotNL(float3 WorldPos, float3 WorldNormal)
{
	WorldNormal = normalize(WorldNormal);
	float3 WorldLightVec = _PointLight.pos - WorldPos;
	float3 WorldLightDir = normalize(WorldLightVec);

	// Calculate lighting
	float Attenuation = GetLightAttenuation(WorldLightVec, _PointLight.attSqrInv);
	float3 DotNL = dot(WorldNormal, WorldLightDir) * Attenuation;
	return DotNL;
}

struct VS2PS_Shared_PointLight_PerPixel
{
	float4 HPos : POSITION;
	float4 Pos : TEXCOORD0; // .rgb = Lighting; .w = Depth;
	float3 Normal : TEXCOORD1;
};

VS2PS_Shared_PointLight_PerPixel VS_Shared_PointLight_PerPixel(APP2VS_Shared Input)
{
	VS2PS_Shared_PointLight_PerPixel Output = (VS2PS_Shared_PointLight_PerPixel)0;
	WorldSpace WS = GetWorldSpaceData(Input);

	Output.HPos = mul(WS.Pos, _ViewProj);
	Output.Pos.xyz = WS.Pos.xyz;
	#if defined(LOG_DEPTH)
		Output.Pos.w = Output.HPos.w + 1.0; // Output depth
	#endif

	Output.Normal = (Input.Normal * 2.0) - 1.0;

	return Output;
}

PS2FB PS_Shared_PointLight_PerPixel(VS2PS_Shared_PointLight_PerPixel Input)
{
	PS2FB Output = (PS2FB)0;

	float DotNL = GetDotNL(Input.Pos.xyz, Input.Normal);
	Output.Color = float4(_PointLight.col * DotNL, 0.0);

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);
	#endif

	return Output;
}

struct VS2PS_Shared_PointLight_PerVertex
{
	float4 HPos : POSITION;
	float2 Tex0 : TEXCOORD0; // .x = DotNL; .y = Depth;
};

VS2PS_Shared_PointLight_PerVertex VS_Shared_PointLight_PerVertex(APP2VS_Shared Input)
{
	VS2PS_Shared_PointLight_PerVertex Output = (VS2PS_Shared_PointLight_PerVertex)0;
	WorldSpace WS = GetWorldSpaceData(Input);

	// Uncompress normal
	float3 WorldPos = WS.Pos.xyz;
	float3 WorldNormal = (Input.Normal * 2.0) - 1.0;
	float DotNL = GetDotNL(WorldPos, WorldNormal);

	Output.HPos = mul(WS.Pos, _ViewProj);
	Output.Tex0.x = DotNL;
	#if defined(LOG_DEPTH)
		Output.Tex0.y = Output.HPos.w + 1.0; // Output depth
	#endif

	return Output;
}

PS2FB PS_Shared_PointLight_PerVertex(VS2PS_Shared_PointLight_PerVertex Input)
{
	PS2FB Output = (PS2FB)0;

	float DotNL = Input.Tex0.x;
	Output.Color = float4(_PointLight.col * DotNL, 0.0);

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Tex0.y);
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
	float2 Tex0 : TEXCOORD2; // .xy = ColorTex; .zw = CompTex;
	float4 LightTex : TEXCOORD3;
};

VS2PS_Shared_LowDetail VS_Shared_LowDetail(APP2VS_Shared Input)
{
	VS2PS_Shared_LowDetail Output = (VS2PS_Shared_LowDetail)0;
	WorldSpace WS = GetWorldSpaceData(Input);

	Output.HPos = mul(WS.Pos, _ViewProj);
	Output.Pos = WS.Pos;
	#if defined(LOG_DEPTH)
		Output.Pos.w = Output.HPos.w + 1.0; // Output depth
	#endif

	Output.Normal = (Input.Normal * 2.0) - 1.0;
	Output.Tex0 = Input.Pos0.xy;
	Output.LightTex = ProjToLighting(Output.HPos);

	return Output;
}

struct LowDetail
{
	float2 YPlane;
	float2 XPlane;
	float2 ZPlane;
	float2 ColorLight;
	float2 Detail;
};

LowDetail GetLowDetail(float3 WorldPos, float2 Tex)
{
	LowDetail Output = (LowDetail)0;

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
	Output.ColorLight = (Tex.xy * _ScaleBaseUV * _ColorLightTex.x) + _ColorLightTex.y;
	Output.Detail = (YPlaneTex * _DetailTex.x) + _DetailTex.y;

	return Output;
}

PS2FB PS_Shared_LowDetail(VS2PS_Shared_LowDetail Input)
{
	PS2FB Output = (PS2FB)0;

	float3 WorldPos = Input.Pos.xyz;
	float3 Normals = normalize(Input.Normal);
	float3 BlendValue = saturate(abs(Normals) - _BlendMod);
	BlendValue = saturate(BlendValue / dot(1.0, BlendValue));

	LowDetail LD = GetLowDetail(WorldPos, Input.Tex0);
	float4 AccumLights = tex2Dproj(SampleTex1_Clamp, Input.LightTex);
	float4 ColorMap = tex2D(SampleTex0_Clamp, LD.ColorLight);
	float4 LowComponent = tex2D(SampleTex5_Clamp, LD.Detail);
	float4 XPlaneLowDetailmap = tex2D(SampleTex4_Wrap, LD.XPlane);
	float4 YPlaneLowDetailmap = tex2D(SampleTex4_Wrap, LD.YPlane);
	float4 ZPlaneLowDetailmap = tex2D(SampleTex4_Wrap, LD.ZPlane);

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

	float4 OutputColor = ColorMap * LowDetailMap * TerrainLights * 2.0;

	// tl: changed a few things with this factor:
	// - using (1-a) is unnecessary, we can just invert the lerp in the ps instead.
	// - by pre-multiplying the _WaterHeight, we can change the (wh-wp)*c to (-wp*c)+whc i.e. from ADD+MUL to MAD
	float WaterLerp = saturate((WorldPos.y / -3.0) + _WaterHeight);
	OutputColor = lerp(OutputColor, _TerrainWaterColor, WaterLerp);

	#if defined(LIGHTONLY)
		OutputColor = TerrainLights;
	#endif

	Output.Color = OutputColor;
	ApplyFog(Output.Color.rgb, GetFogValue(WorldPos, _CameraPos));

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);
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
	VS2PS_Shared_DynamicShadowmap Output;

	float4 WorldPos = GetWorldPos(Input.Pos0, Input.Pos1);
	Output.HPos = mul(WorldPos, _ViewProj);
	Output.ShadowTex = mul(WorldPos, _LightViewProj);
	Output.ShadowTex.z = Output.ShadowTex.w;

	return Output;
}

float4 PS_Shared_DynamicShadowmap(VS2PS_Shared_DynamicShadowmap Input) : COLOR
{
	#if NVIDIA
		float AvgShadowValue = tex2Dproj(SampleTex2_Clamp, Input.ShadowTex);
	#else
		float AvgShadowValue = tex2Dproj(SampleTex2_Clamp, Input.ShadowTex) == 1.0;
	#endif
	return AvgShadowValue.x;
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
	VS2PS_Shared_DirectionalLightShadows Output = (VS2PS_Shared_DirectionalLightShadows)0;
	WorldSpace WS = GetWorldSpaceData(Input);

	Output.HPos = mul(WS.Pos, _ViewProj);
	Output.Pos = Output.HPos;
	#if defined(LOG_DEPTH)
		Output.Pos.w = Output.HPos.w + 1.0; // Output depth
	#endif

	Output.ShadowTex = mul(WS.Pos, _LightViewProj);
	float LightZ = mul(WS.Pos, _LightViewProjOrtho).z;
	#if NVIDIA
		Output.ShadowTex.z = LightZ * Output.ShadowTex.w;
	#else
		Output.ShadowTex.z = LightZ;
	#endif

	Output.Tex0 = (Input.Pos0.xy * _ScaleBaseUV * _ColorLightTex.x) + _ColorLightTex.y;

	return Output;
}

PS2FB PS_Shared_DirectionalLightShadows(VS2PS_Shared_DirectionalLightShadows Input)
{
	PS2FB Output = (PS2FB)0;

	float4 LightMap = tex2D(SampleTex0_Clamp, Input.Tex0.xy);
	#if HIGHTERRAIN || MIDTERRAIN
		float AvgShadowValue = GetShadowFactor(SampleShadowMap, Input.ShadowTex);
	#else
		float AvgShadowValue = GetShadowFactor(SampleTex2_Clamp, Input.ShadowTex);
	#endif

	float4 Light = _GIColor * LightMap.z;
	Light.w = (AvgShadowValue < LightMap.y) ? AvgShadowValue : LightMap.y;
	Output.Color = Light;

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);
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
	VS2PS_Shared_UnderWater Output = (VS2PS_Shared_UnderWater)0;
	WorldSpace WS = GetWorldSpaceData(Input);

	Output.HPos = mul(WS.Pos, _ViewProj);
	Output.Pos = WS.Pos;
	#if defined(LOG_DEPTH)
		Output.Pos.w = Output.HPos.w + 1.0; // Output depth
	#endif

	return Output;
}

PS2FB PS_Shared_UnderWater(VS2PS_Shared_UnderWater Input)
{
	PS2FB Output = (PS2FB)0;

	float3 WorldPos = Input.Pos;
	float3 OutputColor = _TerrainWaterColor.rgb;
	float WaterLerp = saturate((WorldPos.y / -3.0) + _WaterHeight);

	Output.Color = float4(OutputColor, WaterLerp);
	ApplyFog(Output.Color.rgb, GetFogValue(WorldPos, _CameraPos));

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);
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
	float3 Tex0 : TEXCOORD2; // .xy = Tex0; .z = Input.Pos1.x;
};

VS2PS_Shared_ST_Normal VS_Shared_ST_Normal(APP2VS_Shared_ST_Normal Input)
{
	VS2PS_Shared_ST_Normal Output = (VS2PS_Shared_ST_Normal)0;

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

	return Output;
}

struct ST
{
	float2 YPlane;
	float2 XPlane;
	float2 ZPlane;
	float2 ColorLight;
	float2 LowDetail;
};

ST GetST(float3 WorldPos, float3 Tex)
{
	ST Output = (ST)0;

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
	Output.ColorLight = (Tex.xy * _STColorLightTex.x) + _STColorLightTex.y;
	Output.LowDetail = (Tex.xy * _STLowDetailTex.x) + _STLowDetailTex.y;

	return Output;
}

PS2FB PS_Shared_ST_Normal(VS2PS_Shared_ST_Normal Input)
{
	PS2FB Output = (PS2FB)0;

	float3 WorldPos = Input.Pos.xyz;
	float3 WorldNormal = normalize(Input.Normal);
	float3 BlendValue = saturate(abs(WorldNormal) - _BlendMod);
	BlendValue = saturate(BlendValue / dot(1.0, BlendValue));

	ST Tex = GetST(WorldPos, Input.Tex0);
	float4 ColorMap = tex2D(SampleTex0_Clamp, Tex.ColorLight);
	float4 LowComponent = tex2D(SampleTex5_Clamp, Tex.LowDetail);
	float4 YPlaneLowDetailmap = tex2D(SampleTex4_Wrap, Tex.YPlane) * 2.0;
	float4 XPlaneLowDetailmap = tex2D(SampleTex4_Wrap, Tex.XPlane) * 2.0;
	float4 ZPlaneLowDetailmap = tex2D(SampleTex4_Wrap, Tex.ZPlane) * 2.0;

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
	float4 OutputColor = ColorMap * LowDetailMap;

	// M (temporary fix)
	if (_GIColor.r < 0.01)
	{
		OutputColor.rb = 0.0;
	}

	Output.Color = OutputColor;
	ApplyFog(Output.Color.rgb, GetFogValue(WorldPos, _CameraPos));

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);
	#endif

	return Output;
}

technique Shared_SurroundingTerrain
{
	// Normal
	pass Pass0
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

HI_VS2PS_OccluderShadow VS_Hi_OccluderShadow(HI_APP2VS_OccluderShadow Input)
{
	HI_VS2PS_OccluderShadow Output;

	float4 WorldPos = GetWorldPos(Input.Pos0, Input.Pos1);
	Output.HPos = GetOccluderShadow(WorldPos, _vpLightTrapezMat, _vpLightMat);
	Output.DepthPos = Output.HPos; // Output shadow depth

	return Output;
}

float4 PS_Hi_OccluderShadow(HI_VS2PS_OccluderShadow Input) : COLOR
{
	#if NVIDIA
		return 0.5;
	#else
		return Input.DepthPos.z / Input.DepthPos.w;
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
