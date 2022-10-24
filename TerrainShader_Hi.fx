
/*
	Description: High-settings terrain shader
*/

#include "shaders/RealityGraphics.fx"

/*
	Hi Terrain
*/

// Special samplers for dynamic filtering types
sampler Dyn_Sampler_3_Wrap = sampler_state
{
	Texture = (Texture_3);
	AddressU = WRAP;
	AddressV = WRAP;
	MipFilter = LINEAR;
	MinFilter = FILTER_TRN_DIFF_MIN;
	MagFilter = FILTER_TRN_DIFF_MAG;
	MaxAnisotropy = 16;
};

sampler Dyn_Sampler_4_Wrap = sampler_state
{
	Texture = (Texture_4);
	AddressU = WRAP;
	AddressV = WRAP;
	MipFilter = LINEAR;
	MinFilter = FILTER_TRN_DIFF_MIN;
	MagFilter = FILTER_TRN_DIFF_MAG;
	MaxAnisotropy = 16;
};

sampler Dyn_Sampler_6_Wrap = sampler_state
{
	Texture = (Texture_6);
	AddressU = WRAP;
	AddressV = WRAP;
	MipFilter = LINEAR;
	MinFilter = FILTER_TRN_DIFF_MIN;
	MagFilter = FILTER_TRN_DIFF_MAG;
	MaxAnisotropy = 16;
};




struct Hi_VS2PS_FullDetail
{
	float4 HPos : POSITION;
	float4 Tex0 : TEXCOORD0;
	float4 Tex1 : TEXCOORD1;
	float4 Tex3 : TEXCOORD2;
	float2 Tex5 : TEXCOORD3;
	float2 Tex6 : TEXCOORD4;
	float4 P_VertexPos_Fade : TEXCOORD5; // .xyz = VertexPos; .w = Fade;

	float4 BlendValueAndFade : COLOR0; // tl: Don't clamp
};

Hi_VS2PS_FullDetail Hi_FullDetail_VS(APP2VS_Shared_Default Input)
{
	Hi_VS2PS_FullDetail Output = (Hi_VS2PS_FullDetail)0;

	float4 WorldPos = 0.0;
	WorldPos.xz = (Input.Pos0.xy * _ScaleTransXZ.xy) + _ScaleTransXZ.zw;
	WorldPos.yw = (Input.Pos1.xw * _ScaleTransY.xy); // + _ScaleTransY.zw;

	#if DEBUGTERRAIN
		Output.HPos = mul(WorldPos, _ViewProj);
		Output.Tex0 = float4(0.0);
		Output.Tex1 = float4(0.0);
		Output.BlendValueAndFade = float4(0.0);
		Output.Tex3 = float4(0.0);
		Output.Tex5.xy = float2(0.0);
		Output.P_VertexPos_Fade = float4(0.0);
		return Output;
	#endif

	float YDelta, InterpVal;
	// MorphPosition(WorldPos, Input.MorphDelta, YDelta, InterpVal);
	MorphPosition(WorldPos, Input.MorphDelta, Input.Pos0.z, YDelta, InterpVal);

	// tl: output HPos as early as possible.
 	Output.HPos = mul(WorldPos, _ViewProj);

 	// tl: uncompress normal
 	Input.Normal = Input.Normal * 2.0 - 1.0;

	float3 Tex = float3(Input.Pos0.y * _TexScale.z, WorldPos.y * _TexScale.y, Input.Pos0.x * _TexScale.x);
	float2 YPlaneTexCoord = Tex.zx;
	#if HIGHTERRAIN
		float2 XPlaneTexCoord = Tex.xy;
		float2 ZPlaneTexCoord = Tex.zy;
	#endif

 	Output.Tex0.xy = (YPlaneTexCoord * _ColorLightTex.x) + _ColorLightTex.y;
 	Output.Tex6 = (YPlaneTexCoord * _DetailTex.x) + _DetailTex.y;

	Output.Tex3.xy = YPlaneTexCoord * _NearTexTiling.z;
 	Output.Tex5.xy = YPlaneTexCoord * _FarTexTiling.z;

	#if HIGHTERRAIN
		Output.Tex0.wz = XPlaneTexCoord.xy * _FarTexTiling.xy;
		Output.Tex0.z += _FarTexTiling.w;
		Output.Tex3.wz = ZPlaneTexCoord.xy * _FarTexTiling.xy;
		Output.Tex3.z += _FarTexTiling.w;
	#endif

	Output.P_VertexPos_Fade.xyz = WorldPos.xyz;
	Output.P_VertexPos_Fade.w = saturate(0.5 + InterpVal * 0.5);

	#if HIGHTERRAIN
		Output.BlendValueAndFade.w = InterpVal;
	#elif MIDTERRAIN
		// tl: optimized so we can do more advanced lerp in same number of instructions
		//     factors are 2c and (2-2c) which equals a lerp()*2
		Output.BlendValueAndFade.xz = InterpVal * float2(2.0, -2.0) + float2(0.0, 2.0);
	#endif

	#if HIGHTERRAIN
		Output.BlendValueAndFade.xyz = saturate(abs(Input.Normal) - _BlendMod);
		Output.BlendValueAndFade.xyz /= dot(1.0, Output.BlendValueAndFade.xyz);
	#elif MIDTERRAIN
		// tl: use squared yNormal as blend val. pre-multiply with fade value.
		Output.BlendValueAndFade.yw = pow(Input.Normal.y, 8.0) /* Input.Normal.y */ * Output.P_VertexPos_Fade.w;
	#endif

	Output.Tex1 = ProjToLighting(Output.HPos);

	// Output.Tex1 = float4(_MorphDeltaAdder[Input.Pos0.z*256], 1) * 256.0 * 256.0;
	return Output;
}

// #define LIGHTONLY 1
float4 Hi_FullDetail_PS(Hi_VS2PS_FullDetail Input) : COLOR
{
	//	return float4(0.0, 0.0, 0.25, 1.0);
	#if LIGHTONLY
		float4 AccumLights = tex2Dproj(Sampler_1_Clamp, Input.Tex1);
		float4 Light = 2.0 * AccumLights.w * _SunColor + AccumLights;
		float4 Component = tex2D(Sampler_2_Clamp, Input.Tex0.xy);
		float ChartContrib = dot(_ComponentSelector, Component);
		return ChartContrib * Light;
	#else
		#if DEBUGTERRAIN
			return float4(0.0, 0.0, 1.0, 1.0);
		#endif

		float3 ColorMap;
		float3 Light;

		float4 AccumLights = tex2Dproj(Sampler_1_Clamp, Input.Tex1);

		// tl: 2* moved later in shader to avoid clamping at -+2.0 in ps1.4
		if (FogColor.r < 0.01)
		{
			// On thermals no shadows
			Light = 2.0 * _SunColor.rgb + AccumLights.rgb;
			// And gray color
			ColorMap = 0.333;
		}
		else
		{
			Light = 2.0 * AccumLights.w * _SunColor.rgb + AccumLights.rgb;
			ColorMap = tex2D(Sampler_0_Clamp, Input.Tex0.xy);
		}

		float4 Component = tex2D(Sampler_2_Clamp, Input.Tex6);
		float ChartContrib = dot(_ComponentSelector, Component);
		float3 DetailMap = tex2D(Dyn_Sampler_3_Wrap, Input.Tex3.xy);

		#if HIGHTERRAIN
			float4 LowComponent = tex2D(Sampler_5_Clamp, Input.Tex6);
			float4 YPlaneLowDetailmap = tex2D(Sampler_4_Wrap, Input.Tex5.xy);
			float4 XPlaneLowDetailmap = tex2D(Sampler_4_Wrap, Input.Tex3.xy);
			float4 ZPlaneLowDetailmap = tex2D(Sampler_4_Wrap, Input.Tex0.wz);
			float LowDetailMap = lerp(0.5, YPlaneLowDetailmap.z, LowComponent.x * Input.P_VertexPos_Fade.w);
		#else
			float4 YPlaneLowDetailmap = tex2D(Sampler_4_Wrap, Input.Tex5.xy);

			// tl: do lerp in 1 MAD by precalculating constant factor in vShader
			float LowDetailMap = lerp(YPlaneLowDetailmap.x, YPlaneLowDetailmap.z, Input.BlendValueAndFade.y);
		#endif

		#if HIGHTERRAIN
			float Mounten =	(XPlaneLowDetailmap.y * Input.BlendValueAndFade.x) +
							(YPlaneLowDetailmap.x * Input.BlendValueAndFade.y) +
							(ZPlaneLowDetailmap.y * Input.BlendValueAndFade.z);
			LowDetailMap *= (4.0 * lerp(0.5, Mounten, LowComponent.z));
			float3 BothDetailmap = DetailMap * LowDetailMap;
			float3 DetailOut = lerp(2.0 * BothDetailmap, LowDetailMap, Input.BlendValueAndFade.w);
		#else
			// tl: lerp optimized to handle 2*c*low + (2-2c)*detail, factors sent from vs
			float3 DetailOut = LowDetailMap*Input.BlendValueAndFade.x + DetailMap*Input.BlendValueAndFade.z;
		#endif
		float3 OutputColor = DetailOut * ColorMap * Light * 2.0;
		float3 FogOutColor = ApplyFog(OutputColor, GetFogValue(Input.P_VertexPos_Fade.xyz, _CameraPos.xyz));
		return float4(ChartContrib * FogOutColor, ChartContrib);
	#endif
}




struct VS2PS_Hi_FullDetail_Mounten
{
	float4 HPos : POSITION;
	float4 Tex0 : TEXCOORD0;
	float4 Tex1 : TEXCOORD1;
	#if HIGHTERRAIN
		float4 Tex3 : TEXCOORD2;
	#endif
	float2 Tex5 : TEXCOORD3;
	float4 Tex6 : TEXCOORD4;
	float2 Tex7 : TEXCOORD5;
	float4 P_VertexPos_Fade : TEXCOORD6; // .xyz = VertexPos; .w = Fade;

	float4 BlendValueAndFade : COLOR1; // tl: Don't clamp
};

VS2PS_Hi_FullDetail_Mounten Hi_FullDetail_Mounten_VS(APP2VS_Shared_Default Input)
{
	VS2PS_Hi_FullDetail_Mounten Output;

	float4 WorldPos = 0.0;
	WorldPos.xz = (Input.Pos0.xy * _ScaleTransXZ.xy) + _ScaleTransXZ.zw;
	// tl: Trans is always 0, and MADs cost more than MULs in certain cards.
	WorldPos.yw = Input.Pos1.xw * _ScaleTransY.xy;

	#if DEBUGTERRAIN
		Output.HPos = mul(WorldPos, _ViewProj);
		Output.Tex0 = float4(0.0);
		Output.Tex1 = float4(0.0);
		Output.BlendValueAndFade = float4(0.0);
		Output.Tex3 = float4(0.0);
		Output.Tex5.xy = float2(0.0);
		Output.Tex6 = float4(0.0);
		Output.P_VertexPos_Fade = float4(0.0);
		return Output;
	#endif

	float YDelta, InterpVal;
	// MorphPosition(WorldPos, Input.MorphDelta, YDelta, InterpVal);
	MorphPosition(WorldPos, Input.MorphDelta, Input.Pos0.z, YDelta, InterpVal);

	// tl: output HPos as early as possible.
	Output.HPos = mul(WorldPos, _ViewProj);

	// tl: uncompress normal
	Input.Normal = Input.Normal * 2.0 - 1.0;

	float3 Tex = float3(Input.Pos0.y * _TexScale.z, WorldPos.y * _TexScale.y, Input.Pos0.x * _TexScale.x);
	float2 XPlaneTexCoord = Tex.xy;
	float2 YPlaneTexCoord = Tex.zx;
	float2 ZPlaneTexCoord = Tex.zy;

	Output.Tex0.xy = (YPlaneTexCoord * _ColorLightTex.x) + _ColorLightTex.y;
	Output.Tex7 = (YPlaneTexCoord * _DetailTex.x) + _DetailTex.y;

	Output.Tex6.xy = YPlaneTexCoord.xy * _NearTexTiling.z;
	Output.Tex0.wz = XPlaneTexCoord.xy * _NearTexTiling.xy;
	Output.Tex0.z += _NearTexTiling.w;
	Output.Tex6.wz = ZPlaneTexCoord.xy * _NearTexTiling.xy;
	Output.Tex6.z += _NearTexTiling.w;

	Output.Tex5.xy = YPlaneTexCoord * _FarTexTiling.z;

	Output.P_VertexPos_Fade.xyz = WorldPos.xyz;
	Output.P_VertexPos_Fade.w = saturate(0.5 + InterpVal * 0.5);

	#if HIGHTERRAIN
		Output.Tex3.xy = XPlaneTexCoord.xy * _FarTexTiling.xy;
		Output.Tex3.y += _FarTexTiling.w;
		Output.Tex3.wz = ZPlaneTexCoord.xy * _FarTexTiling.xy;
		Output.Tex3.z += _FarTexTiling.w;
		Output.BlendValueAndFade.w = InterpVal;
	#else
		// tl: optimized so we can do more advanced lerp in same number of instructions
		//     factors are 2c and (2-2c) which equals a lerp()*2
		//     Don't use w, it's harder to access from ps1.4
		// Output.BlendValueAndFade.xz = InterpVal * float2(2.0, -2.0) + float2(0.0, 2.0);
		Output.BlendValueAndFade.xz = InterpVal * float2(1, -2) + float2(1, 2);
		// Output.BlendValueAndFade = InterpVal * float4(2, 0, -2, 0) + float4(0, 0, 2, 0);
		// Output.BlendValueAndFade.w = InterpVal;
	#endif

	#if HIGHTERRAIN
		Output.BlendValueAndFade.xyz = saturate(abs(Input.Normal) - _BlendMod);
		Output.BlendValueAndFade.xyz /= dot(1.0, Output.BlendValueAndFade.xyz);
	#else
		// tl: use squared yNormal as blend val. pre-multiply with fade value.
		Output.BlendValueAndFade.yw = pow(Input.Normal.y, 8.0);
	#endif

	Output.Tex1 = ProjToLighting(Output.HPos);

	return Output;
}

float4 Hi_FullDetail_Mounten_PS(VS2PS_Hi_FullDetail_Mounten Input) : COLOR
{
	#if LIGHTONLY
		float4 AccumLights = tex2Dproj(Sampler_1_Clamp, Input.Tex1);
		float4 Light = 2.0 * AccumLights.w * _SunColor + AccumLights;
		float4 Component = tex2D(Sampler_2_Clamp, Input.Tex0.xy);
		float ChartContrib = dot(_ComponentSelector, Component);
		return ChartContrib * Light;
	#else
		#if DEBUGTERRAIN
			return float4(1,0, 0.0, 1.0);
		#endif

		float4 AccumLights = tex2Dproj(Sampler_1_Clamp, Input.Tex1);

		// tl: 2* moved later in shader to avoid clamping at -+2.0 in ps1.4
		float3 Light;
		float3 ColorMap;
		if (FogColor.r < 0.01)
		{
			// On thermals no shadows
			Light = 2.0 * _SunColor.rgb + AccumLights.rgb;
			// And gray color
			ColorMap = 0.333;
		}
		else
		{
			Light = 2.0 * AccumLights.w * _SunColor.rgb + AccumLights.rgb;
			ColorMap = tex2D(Sampler_0_Clamp, Input.Tex0.xy);
		}

		float4 Component = tex2D(Sampler_2_Clamp, Input.Tex7);
		float ChartContrib = dot(_ComponentSelector, Component);

		#if HIGHTERRAIN
			float3 YPlaneDetailmap = tex2D(Dyn_Sampler_3_Wrap, Input.Tex6.xy);
			float3 XPlaneDetailmap = tex2D(Dyn_Sampler_6_Wrap, Input.Tex0.wz);
			float3 ZPlaneDetailmap = tex2D(Dyn_Sampler_6_Wrap, Input.Tex6.wz);
			float3 YPlaneLowDetailmap = tex2D(Sampler_4_Wrap, Input.Tex5.xy);
			float3 XPlaneLowDetailmap = tex2D(Sampler_4_Wrap, Input.Tex3.xy);
			float3 ZPlaneLowDetailmap = tex2D(Sampler_4_Wrap, Input.Tex3.wz);
			float3 LowComponent = tex2D(Sampler_5_Clamp, Input.Tex7);
			float3 DetailMap = 	(XPlaneDetailmap * Input.BlendValueAndFade.x) +
								(YPlaneDetailmap * Input.BlendValueAndFade.y) +
								(ZPlaneDetailmap * Input.BlendValueAndFade.z);

			float LowDetailMap = lerp(0.5, YPlaneLowDetailmap.z, LowComponent.x * Input.P_VertexPos_Fade.w);
			float Mounten = (XPlaneLowDetailmap.y * Input.BlendValueAndFade.x) +
							(YPlaneLowDetailmap.x * Input.BlendValueAndFade.y) +
							(ZPlaneLowDetailmap.y * Input.BlendValueAndFade.z);
			LowDetailMap *= (4.0 * lerp(0.5, Mounten, LowComponent.z));

			float3 BothDetailmap = DetailMap * LowDetailMap;
			float3 DetailOut = lerp(2.0 * BothDetailmap, LowDetailMap, Input.BlendValueAndFade.w);
		#else
			float3 YPlaneDetailmap = tex2D(Sampler_3_Wrap, Input.Tex6.xy);
			float3 YPlaneLowDetailmap = tex2D(Sampler_4_Wrap, Input.Tex5.xy);
			float LowDetailMap = lerp(YPlaneLowDetailmap.x, YPlaneLowDetailmap.z, Input.BlendValueAndFade.y);
			// tl: lerp optimized to handle 2*c*low + (2-2c)*detail, factors sent from vs
			// tl: dont use detail mountains
			float3 DetailOut = LowDetailMap * Input.BlendValueAndFade.x + LowDetailMap * YPlaneDetailmap * Input.BlendValueAndFade.z;
			// float3 DetailOut = LowDetailMap * 2.0;
		#endif
		float3 OutputColor = DetailOut * ColorMap * Light * 2.0;
		float3 FogOutColor = ApplyFog(OutputColor, GetFogValue(Input.P_VertexPos_Fade.xyz, _CameraPos.xyz));
		return float4(ChartContrib * FogOutColor, ChartContrib);
	#endif
}




struct Hi_VS2PS_FullDetail_EnvMap
{
	float4 HPos : POSITION;
	float4 Tex0 : TEXCOORD0;
	float4 Tex1 : TEXCOORD1;
	float4 Tex3 : TEXCOORD2;
	float3 Tex5 : TEXCOORD3;
	float2 Tex6 : TEXCOORD4;
	float3 EnvMap : TEXCOORD5;
	float4 P_VertexPos_Fade : TEXCOORD6; // .xyz = VertexPos; .w = Fade;

	float4 BlendValueAndFade : COLOR0;
};

Hi_VS2PS_FullDetail_EnvMap Hi_FullDetail_EnvMap_VS(APP2VS_Shared_Default Input)
{
	Hi_VS2PS_FullDetail_EnvMap Output = (Hi_VS2PS_FullDetail_EnvMap)0;

	float4 WorldPos = 0.0;
	WorldPos.xz = (Input.Pos0.xy * _ScaleTransXZ.xy) + _ScaleTransXZ.zw;
	WorldPos.yw = (Input.Pos1.xw * _ScaleTransY.xy); // + _ScaleTransY.zw;

	#if DEBUGTERRAIN
		Output.HPos = mul(WorldPos, _ViewProj);
		Output.Tex0 = float4(0.0);
		Output.Tex1 = float4(0.0);
		Output.BlendValueAndFade = float4(0.0);
		Output.Tex3 = float4(0.0);
		Output.Tex5.xy = float2(0.0);
		Output.EnvMap = float3(0.0);
		Output.P_VertexPos_Fade = float4(0.0);
		return Output;
	#endif

	float YDelta, InterpVal;
	// MorphPosition(WorldPos, Input.MorphDelta, YDelta, InterpVal);
	MorphPosition(WorldPos, Input.MorphDelta, Input.Pos0.z, YDelta, InterpVal);

	// tl: output HPos as early as possible.
 	Output.HPos = mul(WorldPos, _ViewProj);

 	// tl: uncompress normal
 	Input.Normal = Input.Normal * 2.0 - 1.0;

	float3 Tex = float3(Input.Pos0.y * _TexScale.z, WorldPos.y * _TexScale.y, Input.Pos0.x * _TexScale.x);
	float2 YPlaneTexCoord = Tex.zx;
	#if HIGHTERRAIN
		float2 XPlaneTexCoord = Tex.xy;
		float2 ZPlaneTexCoord = Tex.zy;
	#endif

 	Output.Tex0.xy = (YPlaneTexCoord * _ColorLightTex.x) + _ColorLightTex.y;
 	Output.Tex6 = (YPlaneTexCoord * _DetailTex.x) + _DetailTex.y;

	// tl: Switched tex0.wz for tex3.xy to easier access it from 1.4
	Output.Tex3.xy = YPlaneTexCoord.xy * _NearTexTiling.z;

 	Output.Tex5.xy = YPlaneTexCoord * _FarTexTiling.z;

	#if HIGHTERRAIN
		Output.Tex0.wz = XPlaneTexCoord.xy * _FarTexTiling.xy;
		Output.Tex0.z += _FarTexTiling.w;
		Output.Tex3.wz = ZPlaneTexCoord.xy * _FarTexTiling.xy;
		Output.Tex3.z += _FarTexTiling.w;
	#endif

	Output.P_VertexPos_Fade.xyz = WorldPos.xyz;
	Output.P_VertexPos_Fade.w = saturate(0.5 + InterpVal * 0.5);

	#if HIGHTERRAIN
		Output.BlendValueAndFade.w = InterpVal;
	#elif MIDTERRAIN
		// tl: optimized so we can do more advanced lerp in same number of instructions
		//    factors are 2c and (2-2c) which equals a lerp()*2.0
		//    Don't use w, it's harder to access from ps1.4
		Output.BlendValueAndFade.xz = InterpVal * float2(2.0, -2.0) + float2(0.0, 2.0);
	#endif

	#if HIGHTERRAIN
		Output.BlendValueAndFade.xyz = saturate(abs(Input.Normal) - _BlendMod);
		Output.BlendValueAndFade.xyz /= dot(1.0, Output.BlendValueAndFade.xyz);
	#elif MIDTERRAIN
		// tl: use squared yNormal as blend val. pre-multiply with fade value.
		Output.BlendValueAndFade.yw = Input.Normal.y * Input.Normal.y * Output.P_VertexPos_Fade.w;
		Output.P_VertexPos_Fade.w = InterpVal;
	#endif

	Output.BlendValueAndFade = saturate(Output.BlendValueAndFade);

	Output.Tex1 = ProjToLighting(Output.HPos);

	// Environment map
	Output.EnvMap = reflect(normalize(WorldPos.xyz - _CameraPos.xyz), float3(0.0, 1.0, 0.0));

	return Output;
}

float4 Hi_FullDetail_EnvMap_PS(Hi_VS2PS_FullDetail_EnvMap Input) : COLOR
{
	#if LIGHTONLY
		float4 AccumLights = tex2Dproj(Sampler_1_Clamp, Input.Tex1);
		float4 Light = 2.0 * AccumLights.w * _SunColor + AccumLights;
		float4 Component = tex2D(Sampler_2_Clamp, Input.Tex0.xy);
		float ChartContrib = dot(_ComponentSelector, Component);
		return ChartContrib * Light;
	#else
		#if DEBUGTERRAIN
			return float4(0.0, 1.0, 0.0, 1.0);
		#endif

		float4 AccumLights = tex2Dproj(Sampler_1_Clamp, Input.Tex1);

		float3 Light;
		float3 ColorMap;
		if (FogColor.r < 0.01)
		{
			// On thermals no shadows
			Light = 2.0 * _SunColor.rgb + AccumLights.rgb;
			// And gray color
			ColorMap = 0.333;
		}
		else
		{
			Light = 2.0 * AccumLights.w * _SunColor.rgb + AccumLights.rgb;
			ColorMap = tex2D(Sampler_0_Clamp, Input.Tex0.xy);
		}

		float4 Component = tex2D(Sampler_2_Clamp, Input.Tex6);
		float ChartContrib = dot(_ComponentSelector, Component);
		float4 DetailMap = tex2D(Dyn_Sampler_3_Wrap, Input.Tex3.xy);

		#if HIGHTERRAIN
			float4 LowComponent = tex2D(Sampler_5_Clamp, Input.Tex6);
			float4 YPlaneLowDetailmap = tex2D(Sampler_4_Wrap, Input.Tex5.xy);
			float4 XPlaneLowDetailmap = tex2D(Sampler_4_Wrap, Input.Tex3.xy);
			float4 ZPlaneLowDetailmap = tex2D(Sampler_4_Wrap, Input.Tex0.wz);
			float LowDetailMap = lerp(0.5, YPlaneLowDetailmap.z, LowComponent.x * Input.P_VertexPos_Fade.w);
		#else
			float4 YPlaneLowDetailmap = tex2D(Sampler_4_Wrap, Input.Tex5.xy);
			float LowDetailMap = 2.0 * YPlaneLowDetailmap.z * Input.BlendValueAndFade.y + (Input.P_VertexPos_Fade.w * -0.5 + 0.5);
		#endif

		#if HIGHTERRAIN
			float Mounten =	(XPlaneLowDetailmap.y * Input.BlendValueAndFade.x) +
							(YPlaneLowDetailmap.x * Input.BlendValueAndFade.y) +
							(ZPlaneLowDetailmap.y * Input.BlendValueAndFade.z);
			LowDetailMap *= (4.0 * lerp(0.5, Mounten, LowComponent.z));
			float3 BothDetailmap = DetailMap * LowDetailMap;
			float3 DetailOut = lerp(2.0 * BothDetailmap, LowDetailMap, Input.BlendValueAndFade.w);
		#else
			// tl: lerp optimized to handle 2*c*low + (2-2c)*detail, factors sent from vs
			float3 DetailOut = LowDetailMap * Input.BlendValueAndFade.x + 2.0 * DetailMap * Input.BlendValueAndFade.z;
		#endif

		float3 OutputColor = DetailOut * ColorMap * Light;
		float4 EnvMapColor = texCUBE(Sampler_6_Cube, Input.EnvMap);

		#if HIGHTERRAIN
			OutputColor = lerp(OutputColor, EnvMapColor, DetailMap.w * (1.0 - Input.BlendValueAndFade.w)) * 2.0;
		#else
			OutputColor = lerp(OutputColor, EnvMapColor, DetailMap.w * (1.0 - Input.P_VertexPos_Fade.w)) * 2.0;
		#endif

		OutputColor = ApplyFog(OutputColor, GetFogValue(Input.P_VertexPos_Fade.xyz, _CameraPos.xyz));
		return float4(ChartContrib * OutputColor, ChartContrib);
	#endif
}




struct VS2PS_Hi_PerPixelPointLight
{
	float4 HPos : POSITION;
	float3 WorldPos : TEXCOORD0;
	float3 Normal : TEXCOORD1;
};

VS2PS_Hi_PerPixelPointLight Hi_PerPixelPointLight_VS(APP2VS_Shared_Default Input)
{
	VS2PS_Hi_PerPixelPointLight Output;

	float4 WorldPos = 0.0;
	WorldPos.xz = (Input.Pos0.xy * _ScaleTransXZ.xy) + _ScaleTransXZ.zw;
	// tl: Trans is always 0, and MADs cost more than MULs in certain cards.
	WorldPos.yw = Input.Pos1.xw * _ScaleTransY.xy;

	float YDelta, InterpVal;
	// MorphPosition(WorldPos, Input.MorphDelta, YDelta, InterpVal);
	MorphPosition(WorldPos, Input.MorphDelta, Input.Pos0.z, YDelta, InterpVal);

	// tl: output HPos as early as possible.
 	Output.HPos = mul(WorldPos, _ViewProj);

 	// tl: uncompress normal
 	Input.Normal = Input.Normal * 2.0 - 1.0;

 	Output.Normal = Input.Normal;
 	Output.WorldPos = WorldPos.xyz;

	return Output;
}

float4 Hi_PerPixelPointLight_PS(VS2PS_Hi_PerPixelPointLight Input) : COLOR
{
	return float4(GetTerrainLighting(Input.WorldPos, Input.Normal), 0) * 0.5;
}

float4 Hi_DirectionalLightShadows_PS(VS2PS_Shared_DirectionalLightShadows Input) : COLOR
{
	float4 LightMap = tex2D(Sampler_0_Clamp, Input.Tex0);

	float4 AvgShadowValue = GetShadowFactor(ShadowMapSampler, Input.ShadowTex);

	float4 Light = saturate(LightMap.z * _GIColor * 2.0) * 0.5;
	if (AvgShadowValue.z < LightMap.y)
		//Light.w = 1-saturate(4-Input.Z.x)+AvgShadowValue.x;
		Light.w = AvgShadowValue.z;
	else
		Light.w = LightMap.y;

	return Light;
}

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
			StencilEnable = TRUE;
			StencilFunc = NOTEQUAL;
			StencilRef = 0xa;
			StencilPass = KEEP;
			StencilZFail = KEEP;
			StencilFail = KEEP;
		#endif

		VertexShader = compile vs_3_0 Shared_ZFillLightMap_VS();
		PixelShader = compile ps_3_0 Shared_ZFillLightMap_1_PS();
	}

	pass pointlight		//p1
	{
		CullMode = CW;
		ZEnable = TRUE;
		ZWriteEnable = FALSE;
		ZFunc = LESSEQUAL;
		AlphaBlendEnable = TRUE;
		SrcBlend = ONE;
		DestBlend = ONE;

		#if IS_NV4X
			StencilEnable = TRUE;
			StencilFunc = NOTEQUAL;
			StencilRef = 0xa;
			StencilPass = KEEP;
			StencilZFail = KEEP;
			StencilFail = KEEP;
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
		// FillMode = WireFrame;

		#if IS_NV4X
			StencilEnable = TRUE;
			StencilFunc = NOTEQUAL;
			StencilRef = 0xa;
			StencilPass = KEEP;
			StencilZFail = KEEP;
			StencilFail = KEEP;
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
			StencilEnable = TRUE;
			StencilFunc = NOTEQUAL;
			StencilRef = 0xa;
			StencilPass = KEEP;
			StencilZFail = KEEP;
			StencilFail = KEEP;
		#endif

		VertexShader = compile vs_3_0 Hi_FullDetail_VS();
		PixelShader = compile ps_3_0 Hi_FullDetail_PS();
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
			StencilEnable = TRUE;
			StencilFunc = NOTEQUAL;
			StencilRef = 0xa;
			StencilPass = KEEP;
			StencilZFail = KEEP;
			StencilFail = KEEP;
		#endif

		VertexShader = compile vs_3_0 Hi_FullDetail_Mounten_VS();
		PixelShader = compile ps_3_0 Hi_FullDetail_Mounten_PS();
	}

	pass {} // p6 tunnels (removed)

	pass DirectionalLightShadows // p7
	{
		CullMode = CW;
		//ColorWriteEnable = RED|BLUE|GREEN|ALPHA;
		ZEnable = TRUE;
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;
 		AlphaBlendEnable = FALSE;

		#if IS_NV4X
			StencilEnable = TRUE;
			StencilFunc = NOTEQUAL;
			StencilRef = 0xa;
			StencilPass = KEEP;
			StencilZFail = KEEP;
			StencilFail = KEEP;
		#endif

		VertexShader = compile vs_3_0 Shared_DirectionalLightShadows_VS();
		PixelShader = compile ps_3_0 Hi_DirectionalLightShadows_PS();
	}

	pass {} // DirectionalLightShadowsNV (removed) //p8
	pass DynamicShadowmap {} // Obsolete // p9
	pass {} // p10

	pass FullDetailWithEnvMap	//p11
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
			StencilEnable = TRUE;
			StencilFunc = NOTEQUAL;
			StencilRef = 0xa;
			StencilPass = KEEP;
			StencilZFail = KEEP;
			StencilFail = KEEP;
		#endif

		VertexShader = compile vs_3_0 Hi_FullDetail_EnvMap_VS();
		PixelShader = compile ps_3_0 Hi_FullDetail_EnvMap_PS();
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
			StencilEnable = TRUE;
			StencilFunc = NOTEQUAL;
			StencilRef = 0xa;
			StencilPass = KEEP;
			StencilZFail = KEEP;
			StencilFail = KEEP;
		#endif

		VertexShader = compile vs_3_0 Hi_PerPixelPointLight_VS();
		PixelShader = compile ps_3_0 Hi_PerPixelPointLight_PS();
	}

	pass underWater // p14
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
			StencilEnable = TRUE;
			StencilFunc = NOTEQUAL;
			StencilRef = 0xa;
			StencilPass = KEEP;
			StencilZFail = KEEP;
			StencilFail = KEEP;
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
