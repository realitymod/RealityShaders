
/*
	Description: Shared functions for terrain shader
*/

#include "shaders/RealityGraphics.fx"

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
	out float InterpVal
)
{
	// tl: This is now based on squared values (besides camPos)
	// tl: This assumes that input WorldPos.w == 1 to work correctly! (it always is)
	// tl: This all works out because camera height is set to height+1 so
	//     CameraVec becomes (cx, cheight+1, cz) - (vx, 1, vz)
	// tl: YScale is now pre-multiplied into morphselector
	float3 CameraVec = _CameraPos.xwz - WorldPos.xwz;
	float CameraDist = dot(CameraVec, CameraVec);

	InterpVal = saturate(CameraDist * _NearFarMorphLimits.x - _NearFarMorphLimits.y);
	YDelta = dot(_MorphDeltaSelector, MorphDelta) * InterpVal;
	YDelta += dot(_MorphDeltaAdder[MorphDeltaAdderSelector * 256], MorphDelta);

	float AdjustedNear = GetAdjustedNear();
	InterpVal = saturate(CameraDist * AdjustedNear - _NearFarMorphLimits.y);
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

/*
	Fill lightmapping
*/

struct APP2VS_Shared_Default
{
	float4 Pos0 : POSITION0;
	float4 Pos1 : POSITION1;
	float4 MorphDelta : POSITION2;
	float3 Normal : NORMAL;
};

struct VS2PS_Shared_ZFillLightMap
{
	float4 HPos : POSITION;
	float2 Tex0 : TEXCOORD0;
};

VS2PS_Shared_ZFillLightMap Shared_ZFillLightMap_VS(APP2VS_Shared_Default Input)
{
	VS2PS_Shared_ZFillLightMap Output = (VS2PS_Shared_ZFillLightMap)0;

	float4 WorldPos = 0.0;
	WorldPos.xz = (Input.Pos0.xy * _ScaleTransXZ.xy) + _ScaleTransXZ.zw;
	WorldPos.yw = (Input.Pos1.xw * _ScaleTransY.xy);

	float YDelta, InterpVal;
	MorphPosition(WorldPos, Input.MorphDelta, Input.Pos0.z, YDelta, InterpVal);

	Output.HPos = mul(WorldPos, _ViewProj);
	Output.Tex0 = (Input.Pos0.xy * _ScaleBaseUV * _ColorLightTex.x) + _ColorLightTex.y;

	return Output;
}

float4 ZFillLightMapColor : register(c0);

float4 Shared_ZFillLightMap_1_PS(VS2PS_Shared_ZFillLightMap Input) : COLOR
{
	float4 Color = tex2D(Sampler_0_Clamp, Input.Tex0);
	float4 OutputColor;
	OutputColor.rgb = Color.b * _GIColor;
	OutputColor.a = saturate(Color.g);
	return OutputColor;
}

float4 Shared_ZFillLightMap_2_PS(VS2PS_Shared_ZFillLightMap Input) : COLOR
{
	return ZFillLightMapColor;
}

/*
	Pointlight
*/

struct VS2PS_Shared_PointLight
{
	float4 HPos : POSITION;
	float2 Tex0 : TEXCOORD0;
	float3 WorldPos : TEXCOORD1;
	float3 WorldNormal : TEXCOORD2;
};

VS2PS_Shared_PointLight Shared_PointLight_VS(APP2VS_Shared_Default Input)
{
	VS2PS_Shared_PointLight Output = (VS2PS_Shared_PointLight)0;

	float4 WorldPos = 0.0;
	WorldPos.xz = (Input.Pos0.xy * _ScaleTransXZ.xy) + _ScaleTransXZ.zw;
	WorldPos.yw = (Input.Pos1.xw * _ScaleTransY.xy);

	float YDelta, InterpVal;
	MorphPosition(WorldPos, Input.MorphDelta, Input.Pos0.z, YDelta, InterpVal);

	Output.HPos = mul(WorldPos, _ViewProj);
	Output.Tex0 = (Input.Pos0.xy * _ScaleBaseUV * _ColorLightTex.x) + _ColorLightTex.y;

	Output.WorldPos = WorldPos.xyz;
	Output.WorldNormal = normalize(Input.Normal * 2.0 - 1.0);

	return Output;
}

float4 Shared_PointLight_PS(VS2PS_Shared_PointLight Input) : COLOR
{
	return saturate(float4(GetTerrainLighting(Input.WorldPos, Input.WorldNormal), 0.0)) * 0.5;
}

/*
	Low detail
*/

struct VS2PS_Shared_LowDetail
{
	float4 HPos : POSITION;
	float3 WorldPos : TEXCOORD0;
	float2 ColorTex : TEXCOORD1;
	float4 LightTex : TEXCOORD2;
	float2 CompTex : TEXCOORD3;
	float2 YPlaneTex : TEXCOORD4;
	float2 XPlaneTex : TEXCOORD5;
	float2 ZPlaneTex : TEXCOORD6;
	float4 P_Blend_Water : COLOR0;
};

VS2PS_Shared_LowDetail Shared_LowDetail_VS(APP2VS_Shared_Default Input)
{
	VS2PS_Shared_LowDetail Output = (VS2PS_Shared_LowDetail)0;

	float4 WorldPos = 0.0;
	WorldPos.xz = (Input.Pos0.xy * _ScaleTransXZ.xy) + _ScaleTransXZ.zw;
	WorldPos.yw = (Input.Pos1.xw * _ScaleTransY.xy);

	float YDelta, InterpVal;
	MorphPosition(WorldPos, Input.MorphDelta, Input.Pos0.z, YDelta, InterpVal);

	Output.HPos = mul(WorldPos, _ViewProj);
	Output.WorldPos = WorldPos.xyz;

	Input.Normal = Input.Normal * 2.0 - 1.0;
	Output.ColorTex = (Input.Pos0.xy * _ScaleBaseUV *_ColorLightTex.x) + _ColorLightTex.y;

	// tl: changed a few things with this factor:
	// - using (1-a) is unnecessary, we can just invert the lerp in the ps instead.
	// - by pre-multiplying the _WaterHeight, we can change the (wh-wp)*c to (-wp*c)+whc i.e. from ADD+MUL to MAD
	Output.P_Blend_Water.w = saturate((WorldPos.y / -3.0) + _WaterHeight);

	#if HIGHTERRAIN
		float3 Tex = float3(Input.Pos0.y * _TexScale.z, WorldPos.y * _TexScale.y, Input.Pos0.x * _TexScale.x);
		float2 XPlaneTexCoord = Tex.xy;
		float2 YPlaneTexCoord = Tex.zx;
		float2 ZPlaneTexCoord = Tex.zy;

		Output.CompTex = (YPlaneTexCoord * _DetailTex.x) + _DetailTex.y;
		Output.YPlaneTex = (YPlaneTexCoord * _FarTexTiling.z);
		Output.XPlaneTex = (XPlaneTexCoord.xy * _FarTexTiling.xy);
		Output.XPlaneTex.y += _FarTexTiling.w;
		Output.ZPlaneTex = (ZPlaneTexCoord.xy * _FarTexTiling.xy);
		Output.ZPlaneTex.y += _FarTexTiling.w;
	#else
		Output.YPlaneTex = Input.Pos0.xy * _YPlaneTexScaleAndFarTile.xz;
	#endif

	#if HIGHTERRAIN
		Output.P_Blend_Water.xyz = saturate(abs(Input.Normal) - _BlendMod);
		float Total = dot(1.0, Output.P_Blend_Water.xyz);
		Output.P_Blend_Water.xyz = saturate(Output.P_Blend_Water.xyz / Total);
	#else
		Output.P_Blend_Water.xyz = saturate(pow(Input.Normal.y, 8.0));
	#endif

	Output.LightTex = ProjToLighting(Output.HPos);

	return Output;
}

float4 Shared_LowDetail_PS(VS2PS_Shared_LowDetail Input) : COLOR
{
	float4 AccumLights = tex2Dproj(Sampler_1_Clamp, Input.LightTex);
	float4 Light;
	float4 ColorMap;

	if (FogColor.r < 0.01)
	{
		Light = 2.0 * _SunColor + AccumLights; // On thermals no shadows
		ColorMap = 1.0 / 3.0; // And gray color
	}
	else
	{
		Light = 2.0 * AccumLights.w * _SunColor + AccumLights;
		ColorMap = tex2D(Sampler_0_Clamp, Input.ColorTex);
	}

	#if LIGHTONLY
		Light.rgb = ApplyFog(Light.rgb, GetFogValue(Input.WorldPos, _CameraPos));
		return Light;
	#endif

	#if HIGHTERRAIN
		float4 LowComponent = tex2D(Sampler_5_Clamp, Input.CompTex);
		float4 YPlaneLowDetailmap = tex2D(Sampler_4_Wrap, Input.YPlaneTex);
		float4 XPlaneLowDetailmap = tex2D(Sampler_4_Wrap, Input.XPlaneTex);
		float4 ZPlaneLowDetailmap = tex2D(Sampler_4_Wrap, Input.ZPlaneTex);
		float Mounten = (XPlaneLowDetailmap.y * Input.P_Blend_Water.x) +
						(YPlaneLowDetailmap.x * Input.P_Blend_Water.y) +
						(ZPlaneLowDetailmap.y * Input.P_Blend_Water.z);
		float4 OutputColor = ColorMap * Light * 2.0 * lerp(0.5, YPlaneLowDetailmap.z, LowComponent.x) * lerp(0.5, Mounten, LowComponent.z);
		OutputColor = lerp(OutputColor * 4.0, _TerrainWaterColor, Input.P_Blend_Water.w);

		OutputColor.rgb = ApplyFog(OutputColor.rgb, GetFogValue(Input.WorldPos, _CameraPos));
		return OutputColor;
	#else
		float4 YPlaneLowDetailmap = tex2D(Sampler_4_Wrap, Input.YPlaneTex);
		float3 OutputColor = ColorMap * Light * 2.0;
		OutputColor = OutputColor * lerp(YPlaneLowDetailmap.x, YPlaneLowDetailmap.z, Input.P_Blend_Water.y);
		OutputColor = lerp(OutputColor * 2.0, _TerrainWaterColor, Input.P_Blend_Water.w);

		OutputColor.rgb = ApplyFog(OutputColor.rgb, GetFogValue(Input.WorldPos, _CameraPos));
		return float4(OutputColor, 1.0);
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

VS2PS_Shared_DynamicShadowmap Shared_DynamicShadowmap_VS(APP2VS_Shared_Default Input)
{
	VS2PS_Shared_DynamicShadowmap Output;

	float4 WorldPos = 0.0;
	WorldPos.xz = (Input.Pos0.xy * _ScaleTransXZ.xy) + _ScaleTransXZ.zw;
	WorldPos.yw = (Input.Pos1.xw * _ScaleTransY.xy);

	Output.HPos = mul(WorldPos, _ViewProj);

	Output.ShadowTex = mul(WorldPos, _LightViewProj);
	Output.ShadowTex.z = 0.999 * Output.ShadowTex.w;

	return Output;
}

float4 Shared_DynamicShadowmap_PS(VS2PS_Shared_DynamicShadowmap Input) : COLOR
{
	#if NVIDIA
		float AvgShadowValue = tex2Dproj(Sampler_2_Clamp, Input.ShadowTex);
	#else
		float AvgShadowValue = tex2Dproj(Sampler_2_Clamp, Input.ShadowTex) == 1.0;
	#endif
	return AvgShadowValue.x;
}

/*
	Directional light shadows
*/

struct VS2PS_Shared_DirectionalLightShadows
{
	float4 HPos : POSITION;
	float2 Tex0 : TEXCOORD0;
	float4 ShadowTex : TEXCOORD1;
	float2 Z : TEXCOORD2;
};

VS2PS_Shared_DirectionalLightShadows Shared_DirectionalLightShadows_VS(APP2VS_Shared_Default Input)
{
	VS2PS_Shared_DirectionalLightShadows Output;

	float4 WorldPos = 0.0;
	WorldPos.xz = (Input.Pos0.xy * _ScaleTransXZ.xy) + _ScaleTransXZ.zw;
	WorldPos.yw = (Input.Pos1.xw * _ScaleTransY.xy);

	float YDelta, InterpVal;
	MorphPosition(WorldPos, Input.MorphDelta, Input.Pos0.z, YDelta, InterpVal);

	Output.HPos = mul(WorldPos, _ViewProj);

	Output.ShadowTex = mul(WorldPos, _LightViewProj);
	float sZ = mul(WorldPos, _LightViewProjOrtho).z;
	Output.Z.xy = Output.ShadowTex.z;
	#if NVIDIA
		Output.ShadowTex.z = sZ * Output.ShadowTex.w;
	#else
		Output.ShadowTex.z = sZ;
	#endif

	Output.Tex0 = (Input.Pos0.xy * _ScaleBaseUV * _ColorLightTex.x) + _ColorLightTex.y;

	return Output;
}

/*
	Underwater
*/

struct VS2PS_Shared_UnderWater
{
	float4 HPos : POSITION;
	float4 P_WorldPos_Water : TEXCOORD0; // .xyz = WorldPos; .w = Water;
};

VS2PS_Shared_UnderWater Shared_UnderWater_VS(APP2VS_Shared_Default Input)
{
	VS2PS_Shared_UnderWater Output;

	float4 WorldPos = 0.0;
	WorldPos.xz = (Input.Pos0.xy * _ScaleTransXZ.xy) + _ScaleTransXZ.zw;
	WorldPos.yw = (Input.Pos1.xw * _ScaleTransY.xy);

	float YDelta, InterpVal;
	MorphPosition(WorldPos, Input.MorphDelta, Input.Pos0.z, YDelta, InterpVal);

	Output.HPos = mul(WorldPos, _ViewProj);

	Output.P_WorldPos_Water.xyz = WorldPos.xyz;

	// tl: changed a few things with this factor:
	// - by pre-multiplying the _WaterHeight, we can change the (wh-wp)*c to (-wp*c)+whc i.e. from ADD+MUL to MAD
	Output.P_WorldPos_Water.w = saturate((WorldPos.y / -3.0) + _WaterHeight);

	return Output;
}

float4 Shared_UnderWater_PS(VS2PS_Shared_UnderWater Input) : COLOR
{
	return float4(ApplyFog(_TerrainWaterColor.rgb, GetFogValue(Input.P_WorldPos_Water.xyz, _CameraPos.xyz)), Input.P_WorldPos_Water.w);
}

/*
	Surrounding Terrain (ST)
*/

struct APP2VS_Shared_ST_Normal
{
	float2 Pos0 : POSITION0;
	float2 TexCoord0 : TEXCOORD0;
	float4 Pos1 : POSITION1;
	float3 Normal : NORMAL;
};

struct VS2PS_Shared_ST_Normal
{
	float4 HPos : POSITION;
	float3 WorldPos : TEXCOORD0;
	float2 ColorLightTex : TEXCOORD1;
	float2 LowDetailTex : TEXCOORD2;
	float2 YPlaneTex : TEXCOORD3;
	float2 XPlaneTex : TEXCOORD4;
	float2 ZPlaneTex : TEXCOORD5;
	float3 BlendValue : COLOR0;
};

VS2PS_Shared_ST_Normal Shared_ST_Normal_VS(APP2VS_Shared_ST_Normal Input)
{
	VS2PS_Shared_ST_Normal Output;

	Output.ColorLightTex = (Input.TexCoord0 * _STColorLightTex.x) + _STColorLightTex.y;
	Output.LowDetailTex = (Input.TexCoord0 * _STLowDetailTex.x) + _STLowDetailTex.y;

	float4 WorldPos = 0.0;
	WorldPos.xz = mul(float4(Input.Pos0.xy, 0.0, 1.0), _STTransXZ).xy;
	WorldPos.yw = (Input.Pos1.xw * _STScaleTransY.xy) + _STScaleTransY.zw;

	Output.HPos = mul(WorldPos, _ViewProj);
	Output.WorldPos = WorldPos.xyz;

	float3 Tex = float3(WorldPos.z * _STTexScale.z, -(Input.Pos1.x * _STTexScale.y), WorldPos.x * _STTexScale.x);
	float2 YPlaneTexCoord = Tex.zx;
	float2 XPlaneTexCoord = Tex.xy;
	float2 ZPlaneTexCoord = Tex.zy;

	Output.YPlaneTex = YPlaneTexCoord * _STFarTexTiling.z;
	Output.XPlaneTex = (XPlaneTexCoord * _STFarTexTiling.xy);
	Output.XPlaneTex.y += _STFarTexTiling.w;
	Output.ZPlaneTex = (ZPlaneTexCoord * _STFarTexTiling.xy);
	Output.ZPlaneTex.y += _STFarTexTiling.w;

	Output.BlendValue = saturate(abs(Input.Normal) - _BlendMod);
	Output.BlendValue /= dot(1.0, Output.BlendValue);

	return Output;
}

float4 Shared_ST_Normal_PS(VS2PS_Shared_ST_Normal Input) : COLOR
{
	float4 ColorMap;

	if (FogColor.r < 0.01)
	{
		ColorMap = 1.0 / 3.0; // If thermals assume gray terrain
	}
	else
	{
		ColorMap = tex2D(Sampler_0_Clamp, Input.ColorLightTex);
	}

	float4 LowComponent = tex2D(Sampler_5_Clamp, Input.LowDetailTex);
	float4 YPlaneLowDetailmap = tex2D(Sampler_4_Wrap, Input.YPlaneTex);
	float4 XPlaneLowDetailmap = tex2D(Sampler_4_Wrap, Input.XPlaneTex);
	float4 ZPlaneLowDetailmap = tex2D(Sampler_4_Wrap, Input.ZPlaneTex);

	float4 LowDetailMap = lerp(0.5, YPlaneLowDetailmap.z, LowComponent.x);
	float Mounten = (XPlaneLowDetailmap.y * Input.BlendValue.x) +
					(YPlaneLowDetailmap.x * Input.BlendValue.y) +
					(ZPlaneLowDetailmap.y * Input.BlendValue.z);
	LowDetailMap *= lerp(0.5, Mounten, LowComponent.z);

	float4 OutputColor = LowDetailMap * ColorMap * 4.0;
	OutputColor.rb = (_GIColor.r < 0.01) ? 0.0 : OutputColor.rb; // M (temporary fix)

	OutputColor.rgb = ApplyFog(OutputColor.rgb, GetFogValue(Input.WorldPos.xyz, _CameraPos.xyz));

	return OutputColor;
}

technique Shared_SurroundingTerrain
{
	pass p0 // Normal
	{
		CullMode = CW;
		ZEnable = TRUE;
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;
		AlphaBlendEnable = FALSE;

		VertexShader = compile vs_3_0 Shared_ST_Normal_VS();
		PixelShader = compile ps_3_0 Shared_ST_Normal_PS();
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
	float2 PosZW : TEXCOORD0;
};

HI_VS2PS_OccluderShadow Hi_OccluderShadow_VS(HI_APP2VS_OccluderShadow Input)
{
	HI_VS2PS_OccluderShadow Output;
	float4 WorldPos = 0.0;
	WorldPos.xz = (Input.Pos0.xy * _ScaleTransXZ.xy) + _ScaleTransXZ.zw;
	WorldPos.yw = (Input.Pos1.xw * _ScaleTransY.xy);
	Output.HPos = GetMeshShadowProjection(WorldPos, _vpLightTrapezMat, _vpLightMat);
	Output.PosZW = Output.HPos.zw;
	return Output;
}

float4 Hi_OccluderShadow_PS(HI_VS2PS_OccluderShadow Input) : COLOR
{
	#if NVIDIA
		return 0.5;
	#else
		return Input.PosZW.x / Input.PosZW.y;
	#endif
}

technique TerrainOccludershadow
{
	pass occludershadow // p16
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
			ColorWriteEnable = RED | BLUE | GREEN | ALPHA;
		#endif

		VertexShader = compile vs_3_0 Hi_OccluderShadow_VS();
		PixelShader = compile ps_3_0 Hi_OccluderShadow_PS();
	}
}
