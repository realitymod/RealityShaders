
#line 3 "TerrainShader_Shared.fx"

/*
	Basic morphed technique
*/

// void Geo_MorphPosition(inout float4 WorldPos, in float4 MorphDelta, out float YDelta, out float InterpVal)
void Geo_MorphPosition(inout float4 WorldPos, in float4 MorphDelta, in float MorphDeltaAdderSelector, out float YDelta, out float InterpVal)
{
	// tl: This is now based on squared values (besides camPos)
	// tl: This assumes that input WorldPos.w == 1 to work correctly! (it always is)
	// tl: This all works out because camera height is set to height+1 so
	//     CameraVec becomes (cx, cheight+1, cz) - (vx, 1, vz)
	// tl: YScale is now pre-multiplied into morphselector

	float3 CameraVec = _CameraPos.xwz - WorldPos.xwz;
	float CameraDist = dot(CameraVec, CameraVec);
	InterpVal = saturate(CameraDist * _NearFarMorphLimits.x - _NearFarMorphLimits.y);
	YDelta = (dot(_MorphDeltaSelector, MorphDelta) * InterpVal) + dot(_MorphDeltaAdder[MorphDeltaAdderSelector*256], MorphDelta);

	// Only the near distance changes due to increased LOD distance. This needs to be multiplied by
	// the square of the factor by which we increased. Assuming 200m base lod this turns out to
	// No-Lod: 250x normal -> 62500x
	// High-Lod: 4x normal -> 16x
	// Med-Lod: 3x normal -> 9x
	float AdjustedNear;
	// If no-lods is enabled, then near limit is really low
	if (_NearFarMorphLimits.x < 0.00000001)
	{
		AdjustedNear = _NearFarMorphLimits.x * 62500.0;
	}
	else
	{
		#if HIGHTERRAIN
			AdjustedNear = _NearFarMorphLimits.x * 16.0;
		#else
			AdjustedNear = _NearFarMorphLimits.x * 9.0;
		#endif
	}
	InterpVal = saturate(CameraDist * AdjustedNear - _NearFarMorphLimits.y);

	WorldPos.y = WorldPos.y - YDelta;
}

float4 ProjToLighting(float4 HPos)
{
	float4 Tex;
	// tl: This has been rearranged optimally (I believe) into 1 MUL and 1 MAD,
	//     don't change this without thinking twice.
	//     ProjOffset now includes screen->texture bias as well as half-texel offset
	//     ProjScale is screen->texture scale/invert operation
	// Tex = (HPos.x * 0.5 + 0.5 + HTexel, HPos.y * -0.5 + 0.5 + HTexel, HPos.z, HPos.w)
	Tex = HPos * _TexProjScale + (_TexProjOffset * HPos.w);
	return Tex;
}




struct APP2VS_Shared_Default
{
	float4 Pos0 : POSITION0;
	float4 Pos1 : POSITION1;
	float4 MorphDelta : POSITION2;
	float3 Normal : NORMAL;
};

struct VS2PS_Shared_ZFillLightMap
{
	float4 Pos : POSITION;
	float2 Tex0 : TEXCOORD0;
};

VS2PS_Shared_ZFillLightMap Shared_ZFillLightMap_VS(APP2VS_Shared_Default Input)
{
	VS2PS_Shared_ZFillLightMap Output;

	float4 WorldPos = 0.0;
	// WorldPos.xz = (Input.Pos0.xy * _ScaleTransXZ.xy) + _ScaleTransXZ.zw;
	WorldPos.xz = (Input.Pos0.xy * _ScaleTransXZ.xy) + _ScaleTransXZ.zw;
	// tl: Trans is always 0, and MADs cost more than MULs in certain cards.
	WorldPos.yw = Input.Pos1.xw * _ScaleTransY.xy;

	#if DEBUGTERRAIN
		Output.Pos = mul(WorldPos, _ViewProj);
		Output.Tex0 = float2(0.0);
		return Output;
	#endif

	float YDelta, InterpVal;
	// Geo_MorphPosition(WorldPos, Input.MorphDelta, YDelta, InterpVal);
	Geo_MorphPosition(WorldPos, Input.MorphDelta, Input.Pos0.z, YDelta, InterpVal);

	Output.Pos = mul(WorldPos, _ViewProj);
	Output.Tex0 = (Input.Pos0.xy * _ScaleBaseUV * _ColorLightTex.x) + _ColorLightTex.y;

	return Output;
}

float4 Shared_ZFillLightMap_1_PS(VS2PS_Shared_ZFillLightMap Input) : COLOR
{
	float4 Color = tex2D(Sampler_0_Clamp, Input.Tex0);
	float4 OutColor;
	OutColor.rgb = Color.b * _GIColor;
	OutColor.a = saturate(Color.g);
	return OutColor;
}

float4 ZFillLightMapColor : register(c0);

float4 Shared_ZFillLightMap_2_PS(VS2PS_Shared_ZFillLightMap Input) : COLOR
{
	return ZFillLightMapColor;
}



struct VS2PS_Shared_PointLight
{
	float4 Pos : POSITION;
	float2 Tex0 : TEXCOORD0;
	float3 WorldPos : TEXCOORD1;
	float3 WorldNormal : TEXCOORD2;
};

VS2PS_Shared_PointLight Shared_PointLight_VS(APP2VS_Shared_Default Input)
{
	VS2PS_Shared_PointLight Output;

	float4 WorldPos = 0.0;
	WorldPos.xz = (Input.Pos0.xy * _ScaleTransXZ.xy) + _ScaleTransXZ.zw;
	// tl: Trans is always 0, and MADs cost more than MULs in certain cards.
	WorldPos.yw = Input.Pos1.xw * _ScaleTransY.xy;

	float YDelta, InterpVal;
	// Geo_MorphPosition(WorldPos, Input.MorphDelta, YDelta, InterpVal);
	Geo_MorphPosition(WorldPos, Input.MorphDelta, Input.Pos0.z, YDelta, InterpVal);

	Output.Pos = mul(WorldPos, _ViewProj);
	// Output.Tex0 = Input.Pos0.xy * _ScaleBaseUV;
	Output.Tex0 = (Input.Pos0.xy * _ScaleBaseUV * _ColorLightTex.x) + _ColorLightTex.y;

	Output.WorldPos = WorldPos.xyz;

	// tl: uncompress normal
	Output.WorldNormal = normalize(Input.Normal * 2.0 - 1.0);

	return Output;
}

float4 Shared_PointLight_PS(VS2PS_Shared_PointLight Input) : COLOR
{
	return saturate(float4(GetTerrainLighting(Input.WorldPos, normalize(Input.WorldNormal)), 0.0)) * 0.5;
}




struct VS2PS_Shared_LowDetail
{
	float4 Pos : POSITION;
	float2 Tex0a : TEXCOORD0;
	float2 Tex0b : TEXCOORD1;
	float4 Tex1 : TEXCOORD2;
	#if HIGHTERRAIN
		float2 Tex2a : TEXCOORD3;
		float2 Tex2b : TEXCOORD4;
		float2 Tex3 : TEXCOORD5;
	#endif
	float3 VertexPos : TEXCOORD6;

	float4 BlendValueAndWater : COLOR0;
};

VS2PS_Shared_LowDetail Shared_LowDetail_VS(APP2VS_Shared_Default Input)
{
	VS2PS_Shared_LowDetail Output;

	float4 WorldPos = 0.0;
	WorldPos.xz = (Input.Pos0.xy * _ScaleTransXZ.xy) + _ScaleTransXZ.zw;
	// tl: Trans is always 0, and MADs cost more than MULs in certain cards.
	WorldPos.yw = Input.Pos1.xw * _ScaleTransY.xy;

	#if DEBUGTERRAIN
		Output.Pos = mul(WorldPos, _ViewProj);
		Output.Tex0a = 0.0;
		Output.Tex0b = 0.0;
		Output.Tex1 = 0.0;
	#if HIGHTERRAIN
		Output.Tex2a = 0.0;
		Output.Tex2b = 0.0;
	#endif
		Output.BlendValueAndWater = 0.0;
		Output.VertexPos = 1.0;
		return Output;
	#endif

	float YDelta, InterpVal;
	Geo_MorphPosition(WorldPos, Input.MorphDelta, Input.Pos0.z, YDelta, InterpVal);
	// Geo_MorphPosition(WorldPos, Input.MorphDelta, YDelta, InterpVal);

	// tl: output HPos as early as possible.
	Output.Pos = mul(WorldPos, _ViewProj);

	// tl: uncompress normal
	Input.Normal = Input.Normal * 2.0 - 1.0;

	Output.Tex0a = (Input.Pos0.xy * _ScaleBaseUV*_ColorLightTex.x) + _ColorLightTex.y;

	// tl: changed a few things with this factor:
	// - using (1-a) is unnecessary, we can just invert the lerp in the ps instead.
	// - saturate is unneeded because color interpolators are clamped [0,1] before the pixel shader
	// - by pre-multiplying the _WaterHeight, we can change the (wh-wp)*c to (-wp*c)+whc i.e. from ADD+MUL to MAD
	Output.BlendValueAndWater.w = saturate((WorldPos.y / -3.0) + _WaterHeight);

	#if HIGHTERRAIN
		float3 Tex = float3(Input.Pos0.y * _TexScale.z, WorldPos.y * _TexScale.y, Input.Pos0.x * _TexScale.x);
		float2 XPlaneTexCoord = Tex.xy;
		float2 YPlaneTexCoord = Tex.zx;
		float2 ZPlaneTexCoord = Tex.zy;

		Output.Tex3 = (YPlaneTexCoord*_DetailTex.x) + _DetailTex.y;
		Output.Tex0b = YPlaneTexCoord * _FarTexTiling.z;
		Output.Tex2a = XPlaneTexCoord.xy * _FarTexTiling.xy;
		Output.Tex2a.y += _FarTexTiling.w;
		Output.Tex2b = ZPlaneTexCoord.xy * _FarTexTiling.xy;
		Output.Tex2b.y += _FarTexTiling.w;
	#else
		// tl: _YPlaneTexScaleAndFarTile = _TexScale * _FarTexTiling.z  //CPU pre-multiplied
		Output.Tex0b = Input.Pos0.xy * _YPlaneTexScaleAndFarTile.xz;
	#endif

	#if HIGHTERRAIN
		Output.BlendValueAndWater.xyz = saturate(abs(Input.Normal) - _BlendMod);
		float Total = dot(1.0, Output.BlendValueAndWater.xyz);
		Output.BlendValueAndWater.xyz = saturate(Output.BlendValueAndWater.xyz / Total);
	#else
		// Output.BlendValueAndWater.xyz = Input.Normal.y * Input.Normal.y;
		Output.BlendValueAndWater.xyz = saturate(pow(Input.Normal.y, 8));
	#endif

	Output.Tex1 = ProjToLighting(Output.Pos);

	Output.VertexPos = WorldPos.xyz;

	// Output.Tex1 = InterpVal;
	// Output.Tex1 = float4(_MorphDeltaAdder[Input.Pos0.z*256], 1) * 256.0 * 256.0;

	return Output;
}

// #define LIGHTONLY 1
float4 Shared_LowDetail_PS(VS2PS_Shared_LowDetail Input) : COLOR
{
	// return Input.Tex1;

	#if DEBUGTERRAIN
		return float4(1.0);
	#endif
	float4 AccumLights = tex2Dproj(Sampler_1_Clamp, Input.Tex1);
	float4 Light;
	float4 ColorMap;
	if (FogColor.r < 0.01)
	{
		// On thermals no shadows
		Light = 2.0 * _SunColor + AccumLights;
		// And gray color
		ColorMap = 0.333;
	}
	else
	{
		Light = 2.0 * AccumLights.w * _SunColor + AccumLights;
		#if HIGHTERRAIN
			ColorMap = tex2D(Sampler_0_Clamp, Input.Tex0a);
		#else
			ColorMap = tex2D(Sampler_0_Clamp, Input.Tex0a);
		#endif
	}
	#if LIGHTONLY
		Light.rgb = ApplyFog(OutColor.rgb, GetFogValue(Input.VertexPos.xyz, _CameraPos.xyz));
		return Light;
	#endif

	#if HIGHTERRAIN
		float4 LowComponent = tex2D(Sampler_5_Clamp, Input.Tex3);
		float4 YPlaneLowDetailmap = tex2D(Sampler_4_Wrap, Input.Tex0b);
		float4 XPlaneLowDetailmap = tex2D(Sampler_4_Wrap, Input.Tex2a);
		float4 ZPlaneLowDetailmap = tex2D(Sampler_4_Wrap, Input.Tex2b);
		float Mounten = (XPlaneLowDetailmap.y * Input.BlendValueAndWater.x) +
						(YPlaneLowDetailmap.x * Input.BlendValueAndWater.y) +
						(ZPlaneLowDetailmap.y * Input.BlendValueAndWater.z);
		float4 OutColor = ColorMap * Light * 2.0 * lerp(0.5, YPlaneLowDetailmap.z, LowComponent.x) * lerp(0.5, Mounten, LowComponent.z);
		OutColor = lerp(OutColor * 4.0, _TerrainWaterColor, Input.BlendValueAndWater.w);

		OutColor.rgb = ApplyFog(OutColor.rgb, GetFogValue(Input.VertexPos.xyz, _CameraPos.xyz));
		return OutColor;
	#else
		float4 YPlaneLowDetailmap = tex2D(Sampler_4_Wrap, Input.Tex0b);
		float3 OutColor = ColorMap * Light * 2.0;
		OutColor = OutColor * lerp(YPlaneLowDetailmap.x, YPlaneLowDetailmap.z, Input.BlendValueAndWater.y);
		OutColor = lerp(OutColor * 2.0, _TerrainWaterColor, Input.BlendValueAndWater.w);

		OutColor.rgb = ApplyFog(OutColor.rgb, GetFogValue(Input.VertexPos.xyz, _CameraPos.xyz));
		return float4(OutColor, 1.0);
	#endif
}




struct Shared_VS2PS_DynamicShadowmap
{
	float4 Pos : POSITION;
	float4 ShadowTex : TEXCOORD0;
	float2 Z : TEXCOORD1;
};

Shared_VS2PS_DynamicShadowmap Shared_DynamicShadowmap_VS(APP2VS_Shared_Default Input)
{
	Shared_VS2PS_DynamicShadowmap Output;

	float4 WorldPos = 0.0;
	WorldPos.xz = (Input.Pos0.xy * _ScaleTransXZ.xy) + _ScaleTransXZ.zw;
	// tl: Trans is always 0, and MADs cost more than MULs in certain cards.
	WorldPos.yw = Input.Pos1.xw * _ScaleTransY.xy;

	Output.Pos = mul(WorldPos, _ViewProj);

	Output.ShadowTex = mul(WorldPos, _LightViewProj);
	Output.ShadowTex.z = 0.999 * Output.ShadowTex.w;
	Output.Z.xy = Output.ShadowTex.z;

	return Output;
}

float4 Shared_DynamicShadowmap_PS(Shared_VS2PS_DynamicShadowmap Input) : COLOR
{
	#if NVIDIA
		float AvgShadowValue = tex2Dproj(Sampler_2_Clamp, Input.ShadowTex);
	#else
		float AvgShadowValue = tex2Dproj(Sampler_2_Clamp, Input.ShadowTex) == 1.0;
		// float AvgShadowValue = GetShadowFactor(ShadowMapSampler, Input.ShadowTex);
		// float AvgShadowValue = 0.5;
	#endif
	return AvgShadowValue.x;
	// return 1.0 - saturate(4.0 - Input.Z.x) + AvgShadowValue.x;
}




struct VS2PS_Shared_DirectionalLightShadows
{
	float4 Pos : POSITION;
	float2 Tex0 : TEXCOORD0;
	float4 ShadowTex : TEXCOORD1;
	float2 Z : TEXCOORD2;
};

VS2PS_Shared_DirectionalLightShadows Shared_DirectionalLightShadows_VS(APP2VS_Shared_Default Input)
{
	VS2PS_Shared_DirectionalLightShadows Output;

	float4 WorldPos = 0.0;
	WorldPos.xz = (Input.Pos0.xy * _ScaleTransXZ.xy) + _ScaleTransXZ.zw;
	// tl: Trans is always 0, and MADs cost more than MULs in certain cards.
	WorldPos.yw = Input.Pos1.xw * _ScaleTransY.xy;

	float YDelta, InterpVal;
	Geo_MorphPosition(WorldPos, Input.MorphDelta, Input.Pos0.z, YDelta, InterpVal);

	// tl: output HPos as early as possible.
	Output.Pos = mul(WorldPos, _ViewProj);

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




struct VS2PS_Shared_UnderWater
{
	float4 Pos : POSITION;
	float4 P_VertexPos_Water : TEXCOORD0; // .xyz = VertexPos; .w = Water;
};

VS2PS_Shared_UnderWater Shared_UnderWater_VS(APP2VS_Shared_Default Input)
{
	VS2PS_Shared_UnderWater Output;

	float4 WorldPos = 0.0;
	WorldPos.xz = (Input.Pos0.xy * _ScaleTransXZ.xy) + _ScaleTransXZ.zw;
	// tl: Trans is always 0, and MADs cost more than MULs in certain cards.
	WorldPos.yw = Input.Pos1.xw * _ScaleTransY.xy;

	#if DEBUGTERRAIN
		Output.Pos = mul(WorldPos, _ViewProj);
		Output.WaterAndFog = float4(0.0);
		return Output;
	#endif

	float YDelta, InterpVal;
	// Geo_MorphPosition(WorldPos, Input.MorphDelta, YDelta, InterpVal);
	Geo_MorphPosition(WorldPos, Input.MorphDelta, Input.Pos0.z, YDelta, InterpVal);

	// tl: output HPos as early as possible.
	Output.Pos = mul(WorldPos, _ViewProj);

	// tl: changed a few things with this factor:
	// - by pre-multiplying the _WaterHeight, we can change the (wh-wp)*c to (-wp*c)+whc i.e. from ADD+MUL to MAD
	Output.P_VertexPos_Water.w = saturate((WorldPos.y / -3.0) + _WaterHeight);
	// Output.WaterAndFog.x = saturate((_WaterHeight * 3.0 - WorldPos.y) / 3.0f);

	Output.P_VertexPos_Water.xyz = WorldPos.xyz;

	return Output;
}

float4 Shared_UnderWater_PS(VS2PS_Shared_UnderWater Input) : COLOR
{
	#if DEBUGTERRAIN
		return float4(1.0, 1.0, 0.0, 1.0);
	#endif
	// tl: use color interpolator instead of texcoord, it makes this shader much shorter!
	return float4(ApplyFog(_TerrainWaterColor.rgb, GetFogValue(Input.P_VertexPos_Water.xyz, _CameraPos.xyz)), Input.P_VertexPos_Water.w);
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
	float4 Pos : POSITION;
	float3 BlendValue : TEXCOORD0;
	float2 ColorLightTex : TEXCOORD1;
	float2 LowDetailTex : TEXCOORD2;
	float2 Tex1 : TEXCOORD3;
	float2 Tex2 : TEXCOORD4;
	float2 Tex3 : TEXCOORD5;
	float3 VertexPos : TEXCOORD6;
};

VS2PS_Shared_ST_Normal Shared_ST_Normal_VS(APP2VS_Shared_ST_Normal Input)
{
	VS2PS_Shared_ST_Normal Output;

	Output.ColorLightTex = (Input.TexCoord0*_STColorLightTex.x) + _STColorLightTex.y;
	Output.LowDetailTex = (Input.TexCoord0*_STLowDetailTex.x) + _STLowDetailTex.y;

	float4 WorldPos = 0.0;
	WorldPos.xz = mul(float4(Input.Pos0.xy, 0.0, 1.0), _STTransXZ).xy;
	WorldPos.yw = (Input.Pos1.xw * _STScaleTransY.xy) + _STScaleTransY.zw;

	float3 Tex = float3(WorldPos.z * _STTexScale.z, -(Input.Pos1.x * _STTexScale.y), WorldPos.x * _STTexScale.x);
	float2 XPlaneTexCoord = Tex.xy;
	float2 YPlaneTexCoord = Tex.zx;
	float2 ZPlaneTexCoord = Tex.zy;

	Output.Pos = mul(WorldPos, _ViewProj);

	Output.Tex1 = YPlaneTexCoord * _STFarTexTiling.z;
	Output.Tex2.xy = XPlaneTexCoord.xy * _STFarTexTiling.xy;
	Output.Tex2.y += _STFarTexTiling.w;
	Output.Tex3.xy = ZPlaneTexCoord.xy * _STFarTexTiling.xy;
	Output.Tex3.y += _STFarTexTiling.w;

	Output.BlendValue = saturate(abs(Input.Normal) - _BlendMod);
	Output.BlendValue /= dot(1.0, Output.BlendValue);

	Output.VertexPos = WorldPos.xyz;

	return Output;
}

float4 Shared_ST_Normal_PS(VS2PS_Shared_ST_Normal Input) : COLOR
{
	float4 ColorMap;
	if (FogColor.r < 0.01)
	{
		// If thermals assume gray terrain
		ColorMap = 0.333;
	}
	else
	{
		ColorMap = tex2D(Sampler_0_Clamp, Input.ColorLightTex);
	}

	float4 LowComponent = tex2D(Sampler_5_Clamp, Input.LowDetailTex);
	float4 YPlaneLowDetailmap = tex2D(Sampler_4_Wrap, Input.Tex1);
	float4 XPlaneLowDetailmap = tex2D(Sampler_4_Wrap, Input.Tex2);
	float4 ZPlaneLowDetailmap = tex2D(Sampler_4_Wrap, Input.Tex3);

	float4 LowDetailMap = lerp(0.5, YPlaneLowDetailmap.z, LowComponent.x);
	float Mounten = (XPlaneLowDetailmap.y * Input.BlendValue.x) +
					(YPlaneLowDetailmap.x * Input.BlendValue.y) +
					(ZPlaneLowDetailmap.y * Input.BlendValue.z);
	LowDetailMap *= lerp(0.5, Mounten, LowComponent.z);

	float4 OutColor = LowDetailMap * ColorMap * 4.0;

	if (_GIColor.r < 0.01) OutColor.rb = 0; // M (temporary fix)

	OutColor.rgb = ApplyFog(OutColor.rgb, GetFogValue(Input.VertexPos.xyz, _CameraPos.xyz));

	return OutColor;
}




/*
	Surrounding Terrain
*/

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




float4x4 _VPLightMat : vpLightMat;
float4x4 _VPLightTrapezMat : vpLightTrapezMat;

struct HI_APP2VS_OccluderShadow
{
	float4 Pos0 : POSITION0;
	float4 Pos1 : POSITION1;
};

struct HI_VS2PS_OccluderShadow
{
	float4 Pos : POSITION;
	float2 PosZX : TEXCOORD0;
};

float4 Calc_ShadowProjCoords(float4 Pos, float4x4 MatTrap, float4x4 MatLight)
{
	float4 ShadowCoords = mul(Pos, MatTrap);
	float LightZ = mul(Pos, MatLight).z;
	ShadowCoords.z = LightZ * ShadowCoords.w;
	return ShadowCoords;
}

HI_VS2PS_OccluderShadow Hi_OccluderShadow_VS(HI_APP2VS_OccluderShadow Input)
{
	HI_VS2PS_OccluderShadow Output;
	float4 WorldPos = 0.0;
	WorldPos.xz = (Input.Pos0.xy * _ScaleTransXZ.xy) + _ScaleTransXZ.zw;
	WorldPos.yw = Input.Pos1.xw * _ScaleTransY.xy;
	Output.Pos = Calc_ShadowProjCoords(WorldPos, _VPLightTrapezMat, _VPLightMat);
	Output.PosZX = Output.Pos.zw;
	return Output;
}

float4 Hi_OccluderShadow_PS(HI_VS2PS_OccluderShadow Input) : COLOR
{
	#if NVIDIA
		return 0.5;
	#else
		return Input.PosZX.x / Input.PosZX.y;
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
			ColorWriteEnable = RED|BLUE|GREEN|ALPHA;
		#endif

		VertexShader = compile vs_3_0 Hi_OccluderShadow_VS();
		PixelShader = compile ps_3_0 Hi_OccluderShadow_PS();
	}
}
