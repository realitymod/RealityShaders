#line 2 "TerrainShader_Hi.fx"
//
// -- Hi Terrain
//

// Special samplers for dynamic filtering types
sampler dsampler3Wrap = sampler_state {
	Texture = (texture3);
	AddressU = WRAP;
	AddressV = WRAP;
	MipFilter = FILTER_TRN_MIP;
	MinFilter = FILTER_TRN_DIFF_MIN;
	MagFilter = FILTER_TRN_DIFF_MAG;
#ifdef FILTER_TRN_DIFF_MAX_ANISOTROPY
	MaxAnisotropy = FILTER_TRN_DIFF_MAX_ANISOTROPY;
#endif
};

sampler dsampler4Wrap = sampler_state {
	Texture = (texture4);
	AddressU = WRAP;
	AddressV = WRAP;
	MipFilter = FILTER_TRN_MIP;
	MinFilter = FILTER_TRN_DIFF_MIN;
	MagFilter = FILTER_TRN_DIFF_MAG;
#ifdef FILTER_TRN_DIFF_MAX_ANISOTROPY
	MaxAnisotropy = FILTER_TRN_DIFF_MAX_ANISOTROPY;
#endif
};

sampler dsampler6Wrap = sampler_state {
	Texture = (texture6);
	AddressU = WRAP;
	AddressV = WRAP;
	MipFilter = FILTER_TRN_MIP;
	MinFilter = FILTER_TRN_DIFF_MIN;
	MagFilter = FILTER_TRN_DIFF_MAG;
#ifdef FILTER_TRN_DIFF_MAX_ANISOTROPY
	MaxAnisotropy = FILTER_TRN_DIFF_MAX_ANISOTROPY;
#endif
};


#if NVIDIA
	#define SHADOWPSMODEL ps_1_4
	#define SHADOWVERSION 14
#else
	#define SHADOWPSMODEL PS2_EXT
	#define SHADOWVERSION 20
#endif

struct Hi_VS2PS_FullDetail
{
    float4 Pos : POSITION;
    float4 Tex0 : TEXCOORD0;
    float4 Tex1 : TEXCOORD1;
    float4 BlendValueAndFade : TEXCOORD2; // tl: texcoord because we don't want clamping
    float4 Tex3 : TEXCOORD3;
    float2 Tex5 : TEXCOORD4;
    float2 Tex6 : TEXCOORD5;
    float4 FogAndFade2 : COLOR0;
};

//#define LIGHTONLY 1
float4 Hi_PS_FullDetail(Hi_VS2PS_FullDetail indata) : COLOR
{
// return float4(0,0,0.25,1);
#if LIGHTONLY
	float4 accumlights = tex2Dproj(sampler1ClampPoint, indata.Tex1);
	float4 light = 2 * accumlights.w * vSunColor + accumlights;
	float4 component = tex2D(sampler2Clamp, indata.Tex0.xy);
	float chartcontrib = dot(vComponentsel, component); 
	return chartcontrib*light;
#else
#if DEBUGTERRAIN
	return float4(0,0,1,1);
#endif
	float3 colormap = tex2D(sampler0Clamp, indata.Tex0.xy);
	
	float4 accumlights = tex2Dproj(sampler1Clamp, indata.Tex1);
	
	// tl: 2* moved later in shader to avoid clamping at -+2.0 in ps1.4
	float3 light = 2*accumlights.w * vSunColor.rgb + accumlights.rgb;

	float4 component = tex2D(sampler2Clamp, indata.Tex6);
	float chartcontrib = dot(vComponentsel, component); 
	float3 detailmap = tex2D(dsampler3Wrap, indata.Tex3.xy);
// return chartcontrib * float4(indata.BlendValueAndFade.y, indata.BlendValueAndFade.y, indata.BlendValueAndFade.y, 1);

#if HIGHTERRAIN
	float4 lowComponent = tex2D(sampler5Clamp, indata.Tex6);
	float4 yplaneLowDetailmap = tex2D(sampler4Wrap, indata.Tex5);
	float4 xplaneLowDetailmap = tex2D(sampler4Wrap, indata.Tex3.xy);
	float4 zplaneLowDetailmap = tex2D(sampler4Wrap, indata.Tex0.wz);
	float lowDetailmap = lerp(0.5, yplaneLowDetailmap.z, lowComponent.x*indata.FogAndFade2.y);
#else
	float4 yplaneLowDetailmap = tex2D(ssampler4Wrap, indata.Tex5);

	// tl: do lerp in 1 MAD by precalculating constant factor in vShader
// float lowDetailmap = yplaneLowDetailmap.z * indata.BlendValueAndFade.y + indata.FogAndFade2.z;
        float lowDetailmap = lerp(yplaneLowDetailmap.x, yplaneLowDetailmap.z, indata.BlendValueAndFade.y);
 #endif

#if HIGHTERRAIN
	float mounten =	(xplaneLowDetailmap.y * indata.BlendValueAndFade.x) + 
						(yplaneLowDetailmap.x * indata.BlendValueAndFade.y) + 
						(zplaneLowDetailmap.y * indata.BlendValueAndFade.z)	;

	lowDetailmap *= (4 * lerp(0.5, mounten, lowComponent.z));

	float3 bothDetailmap = detailmap * lowDetailmap;
	float3 detailout = lerp(2*bothDetailmap, lowDetailmap, indata.BlendValueAndFade.w);
#else
	// tl: lerp optimized to handle 2*c*low + (2-2c)*detail, factors sent from vs
	float3 detailout = lowDetailmap*indata.BlendValueAndFade.x + detailmap*indata.BlendValueAndFade.z;
#endif

	float3 outColor = detailout * colormap * light;
	// tl: this 2* is the one missing from the light calculation above!
	float3 fogOutColor = lerp(FogColor, outColor*2, indata.FogAndFade2.x);
	return float4(chartcontrib * fogOutColor, chartcontrib);
#endif 
}

Hi_VS2PS_FullDetail Hi_VS_FullDetail(Shared_APP2VS_Default indata)
{
	Hi_VS2PS_FullDetail outdata = (Hi_VS2PS_FullDetail)0;
	
	float4 wPos;
	wPos.xz = (indata.Pos0.xy * vScaleTransXZ.xy) + vScaleTransXZ.zw;
	wPos.yw = (indata.Pos1.xw * vScaleTransY.xy) + vScaleTransY.zw;

#if DEBUGTERRAIN
	outdata.Pos = mul(wPos, mViewProj);
	outdata.Tex0 = float4(0,0,0,0); 
	outdata.Tex1 = float4(0,0,0,0);
	outdata.BlendValueAndFade = float4(0,0,0,0);
	outdata.Tex3 = float4(0,0,0,0);
	outdata.Tex5 = float4(0,0,0,0);
	outdata.FogAndFade2 = float4(0,0,0,0);
	return outdata;
#endif

	float yDelta, interpVal;
// geoMorphPosition(wPos, indata.MorphDelta, yDelta, interpVal);
	geoMorphPosition(wPos, indata.MorphDelta, indata.Pos0.z, yDelta, interpVal);
	
	// tl: output HPos as early as possible.
 	outdata.Pos = mul(wPos, mViewProj);
 	
 	// tl: uncompress normal
 	indata.Normal = indata.Normal * 2 - 1;

	float3 tex = float3(indata.Pos0.y * vTexScale.z, wPos.y * vTexScale.y, indata.Pos0.x * vTexScale.x);
	float2 yPlaneTexCord = tex.zx;
#if HIGHTERRAIN
	float2 xPlaneTexCord = tex.xy;
	float2 zPlaneTexCord = tex.zy;
#endif
	
 	outdata.Tex0.xy = (yPlaneTexCord*vColorLightTex.x) + vColorLightTex.y;
 	outdata.Tex6 = (yPlaneTexCord*vDetailTex.x) + vDetailTex.y;

	// tl: Switched tex0.wz for tex3.xy to easier access it from 1.4
	outdata.Tex3.xy = yPlaneTexCord.xy * vNearTexTiling.z;
	
 	outdata.Tex5 = yPlaneTexCord * vFarTexTiling.z;

#if HIGHTERRAIN
	outdata.Tex0.wz = xPlaneTexCord.xy * vFarTexTiling.xy;
	outdata.Tex0.z += vFarTexTiling.w;
	outdata.Tex3.wz = zPlaneTexCord.xy * vFarTexTiling.xy;
	outdata.Tex3.z += vFarTexTiling.w;
#endif

	outdata.FogAndFade2.x = calcFog(outdata.Pos.w);
	outdata.FogAndFade2.yzw = 0.5+interpVal*0.5;

#if HIGHTERRAIN
	outdata.BlendValueAndFade.w = interpVal;
#elif MIDTERRAIN
	// tl: optimized so we can do more advanced lerp in same number of instructions
	// factors are 2c and (2-2c) which equals a lerp()*2
	// Don't use w, it's harder to access from ps1.4
	outdata.BlendValueAndFade.xz = interpVal * float2(2, -2) + float2(0, 2);
#endif

#if HIGHTERRAIN
	outdata.BlendValueAndFade.xyz = saturate(abs(indata.Normal) - vBlendMod);
	float tot = dot(1, outdata.BlendValueAndFade.xyz);
	outdata.BlendValueAndFade.xyz /= tot;
#elif MIDTERRAIN
	// tl: use squared yNormal as blend val. pre-multiply with fade value.
	outdata.BlendValueAndFade.yw = pow(indata.Normal.y,8) /** indata.Normal.y*/ * outdata.FogAndFade2.y;

	// tl: pre calculate half-lerp against constant, result is 2 ps instruction lerp distributed
	// to 1 vs MAD and 1 ps MAD
	outdata.FogAndFade2.z = outdata.BlendValueAndFade.y*-0.5 + 0.5;
#endif

	outdata.Tex1 = projToLighting(outdata.Pos);

// outdata.Tex1 = float4(vMorphDeltaAdder[indata.Pos0.z*256], 1) * 256*256;

	return outdata;
}

struct Hi_VS2PS_FullDetailMounten
{
    float4 Pos : POSITION;
    float4 Tex0 : TEXCOORD0;
    float4 Tex1 : TEXCOORD1;
    float4 BlendValueAndFade : TEXCOORD2; // tl: texcoord because we don't want clamping
#if HIGHTERRAIN 
    float4 Tex3 : TEXCOORD6;
#endif 
    float2 Tex5 : TEXCOORD5;
    float4 Tex6 : TEXCOORD3;
    float2 Tex7 : TEXCOORD4;
    float4 FogAndFade2 : COLOR0;
};
 
float4 Hi_PS_FullDetailMounten(Hi_VS2PS_FullDetailMounten indata) : COLOR
{
#if LIGHTONLY
          float4 accumlights = tex2Dproj(sampler1ClampPoint, indata.Tex1);
          float4 light = 2 * accumlights.w * vSunColor + accumlights;
          float4 component = tex2D(sampler2Clamp, indata.Tex0.xy);
          float chartcontrib = dot(vComponentsel, component); 
          return chartcontrib*light;
#else
#if DEBUGTERRAIN
          return float4(1,0,0,1);
#endif
          float3 colormap = tex2D(sampler0Clamp, indata.Tex0.xy);
 
          float4 accumlights = tex2Dproj(sampler1Clamp, indata.Tex1);
 
          // tl: 2* moved later in shader to avoid clamping at -+2.0 in ps1.4
          float3 light = 2*accumlights.w * vSunColor.rgb + accumlights.rgb;
 
          float4 component = tex2D(sampler2Clamp, indata.Tex7);
          float chartcontrib = dot(vComponentsel, component); 
 
// return chartcontrib * indata.BlendValueAndFade.w;
#if HIGHTERRAIN
          float3 yplaneDetailmap = tex2D(dsampler3Wrap, indata.Tex6.xy);
          float3 xplaneDetailmap = tex2D(dsampler6Wrap, indata.Tex0.wz);
          float3 zplaneDetailmap = tex2D(dsampler6Wrap, indata.Tex6.wz);
          float3 yplaneLowDetailmap = tex2D(sampler4Wrap, indata.Tex5.xy);
          float3 xplaneLowDetailmap = tex2D(sampler4Wrap, indata.Tex3.xy);
          float3 zplaneLowDetailmap = tex2D(sampler4Wrap, indata.Tex3.wz);
 
          float3 lowComponent = tex2D(sampler5Clamp, indata.Tex7);
 
          float3 detailmap = (xplaneDetailmap * indata.BlendValueAndFade.x) + 
                             (yplaneDetailmap * indata.BlendValueAndFade.y) + 
                             (zplaneDetailmap * indata.BlendValueAndFade.z);
 
          float lowDetailmap = lerp(0.5, yplaneLowDetailmap.z, lowComponent.x*indata.FogAndFade2.y);
          float mounten = (xplaneLowDetailmap.y * indata.BlendValueAndFade.x) + 
                             (yplaneLowDetailmap.x * indata.BlendValueAndFade.y) + 
                             (zplaneLowDetailmap.y * indata.BlendValueAndFade.z);
          lowDetailmap *= (4 * lerp(0.5, mounten, lowComponent.z));
 
          float3 bothDetailmap = detailmap * lowDetailmap;
          float3 detailout = lerp(2*bothDetailmap, lowDetailmap, indata.BlendValueAndFade.w);
#else
          float3 yplaneDetailmap = tex2D(ssampler3Wrap, indata.Tex6.xy);
          float3 yplaneLowDetailmap = tex2D(ssampler4Wrap, indata.Tex5);
 
          float lowDetailmap = lerp(yplaneLowDetailmap.x, yplaneLowDetailmap.z, indata.BlendValueAndFade.y);
 
          // tl: lerp optimized to handle 2*c*low + (2-2c)*detail, factors sent from vs
          // tl: dont use detail mountains
       float3 detailout = lowDetailmap*indata.BlendValueAndFade.x + lowDetailmap*yplaneDetailmap*indata.BlendValueAndFade.z;
// float3 detailout = lowDetailmap*2;
#endif
          
          float3 outColor = detailout * colormap * light;
          // tl: this 2* is the one missing from the light calculation above!
          float3 fogOutColor = lerp(FogColor, outColor*2, indata.FogAndFade2.x);
          return float4(chartcontrib * fogOutColor, chartcontrib);
#endif 
}
 
Hi_VS2PS_FullDetailMounten Hi_VS_FullDetailMounten(Shared_APP2VS_Default indata)
{
          Hi_VS2PS_FullDetailMounten outdata;
          
          float4 wPos;
          wPos.xz = (indata.Pos0.xy * vScaleTransXZ.xy) + vScaleTransXZ.zw;
          // tl: Trans is always 0, and MADs cost more than MULs in certain cards.
          wPos.yw = indata.Pos1.xw * vScaleTransY.xy;
 
#if DEBUGTERRAIN
          outdata.Pos = mul(wPos, mViewProj);
          outdata.Tex0 = float4(0,0,0,0); 
          outdata.Tex1 = float4(0,0,0,0);
          outdata.BlendValueAndFade = float4(0,0,0,0);
          outdata.Tex3 = float4(0,0,0,0);
          outdata.Tex5 = float4(0,0,0,0);
          outdata.Tex6 = float4(0,0,0,0);
          outdata.FogAndFade2 = float4(0,0,0,0);
          return outdata;
#endif
 
          float yDelta, interpVal;
// geoMorphPosition(wPos, indata.MorphDelta, yDelta, interpVal);
	geoMorphPosition(wPos, indata.MorphDelta, indata.Pos0.z, yDelta, interpVal);
          
          // tl: output HPos as early as possible.
          outdata.Pos = mul(wPos, mViewProj);
 
          // tl: uncompress normal
          indata.Normal = indata.Normal * 2 - 1;
 
          float3 tex = float3(indata.Pos0.y * vTexScale.z, wPos.y * vTexScale.y, indata.Pos0.x * vTexScale.x);
          float2 xPlaneTexCord = tex.xy;
          float2 yPlaneTexCord = tex.zx;
          float2 zPlaneTexCord = tex.zy;
          
          outdata.Tex0.xy = (yPlaneTexCord*vColorLightTex.x) + vColorLightTex.y;
          outdata.Tex7 = (yPlaneTexCord*vDetailTex.x) + vDetailTex.y;
 
          outdata.Tex6.xy = yPlaneTexCord.xy * vNearTexTiling.z;
          outdata.Tex0.wz = xPlaneTexCord.xy * vNearTexTiling.xy;
          outdata.Tex0.z += vNearTexTiling.w;
          outdata.Tex6.wz = zPlaneTexCord.xy * vNearTexTiling.xy;
          outdata.Tex6.z += vNearTexTiling.w;
 
          outdata.Tex5 = yPlaneTexCord * vFarTexTiling.z;
 
          outdata.FogAndFade2.x = calcFog(outdata.Pos.w);
          outdata.FogAndFade2.yzw = 0.5+interpVal*0.5;
 
#if HIGHTERRAIN
          outdata.Tex3.xy = xPlaneTexCord.xy * vFarTexTiling.xy;
          outdata.Tex3.y += vFarTexTiling.w;
          outdata.Tex3.wz = zPlaneTexCord.xy * vFarTexTiling.xy;
          outdata.Tex3.z += vFarTexTiling.w;

          outdata.BlendValueAndFade.w = interpVal;
#else
          // tl: optimized so we can do more advanced lerp in same number of instructions
          // factors are 2c and (2-2c) which equals a lerp()*2
          // Don't use w, it's harder to access from ps1.4
// outdata.BlendValueAndFade.xz = interpVal * float2(2, -2) + float2(0, 2);
          outdata.BlendValueAndFade.xz = interpVal * float2(1, -2) + float2(1, 2);
// outdata.BlendValueAndFade = interpVal * float4(2, 0, -2, 0) + float4(0, 0, 2, 0);
// outdata.BlendValueAndFade.w = interpVal;
#endif
 
#if HIGHTERRAIN
          outdata.BlendValueAndFade.xyz = saturate(abs(indata.Normal) - vBlendMod);
          float tot = dot(1, outdata.BlendValueAndFade.xyz);
          outdata.BlendValueAndFade.xyz /= tot;
#else
          // tl: use squared yNormal as blend val. pre-multiply with fade value.
// outdata.BlendValueAndFade.yw = indata.Normal.y * indata.Normal.y * outdata.FogAndFade2.y;
          outdata.BlendValueAndFade.yw = pow(indata.Normal.y,8);
 
          // tl: pre calculate half-lerp against constant, result is 2 ps instruction lerp distributed
          // to 1 vs MAD and 1 ps MAD
// outdata.FogAndFade2.z = outdata.BlendValueAndFade.y*-0.5 + 0.5;
#endif
          outdata.Tex1 = projToLighting(outdata.Pos);
 
          return outdata;
}

struct Hi_VS2PS_FullDetailWithEnvMap
{
    float4 Pos : POSITION;
    float4 Tex0 : TEXCOORD0;
    float4 Tex1 : TEXCOORD1;
    float4 Tex3 : TEXCOORD3;
    float4 BlendValueAndFade : COLOR0;
    float2 Tex5 : TEXCOORD2;
    float2 Tex6 : TEXCOORD5;
    float3 EnvMap : TEXCOORD4;
    float4 FogAndFade2 : COLOR1;
};

float4 Hi_PS_FullDetailWithEnvMap(Hi_VS2PS_FullDetailWithEnvMap indata) : COLOR
{
#if LIGHTONLY
	float4 accumlights = tex2Dproj(sampler1ClampPoint, indata.Tex1);
	float4 light = 2 * accumlights.w * vSunColor + accumlights;
	float4 component = tex2D(sampler2Clamp, indata.Tex0.xy);
	float chartcontrib = dot(vComponentsel, component); 
	return chartcontrib*light;
#else
#if DEBUGTERRAIN
	return float4(0,1,0,1);
#endif
	float3 colormap = tex2D(sampler0Clamp, indata.Tex0.xy);
	
	float4 accumlights = tex2Dproj(sampler1Clamp, indata.Tex1);
	
	// tl: 2* moved later in shader to avoid clamping at -+2.0 in ps1.4
	float3 light = 2*accumlights.w * vSunColor.rgb + accumlights.rgb;

	float4 component = tex2D(sampler2Clamp, indata.Tex6);
	float chartcontrib = dot(vComponentsel, component); 
	float4 detailmap = tex2D(dsampler3Wrap, indata.Tex3.xy);

#if HIGHTERRAIN
	float4 lowComponent = tex2D(sampler5Clamp, indata.Tex6);
	float4 yplaneLowDetailmap = tex2D(sampler4Wrap, indata.Tex5);
	float4 xplaneLowDetailmap = tex2D(sampler4Wrap, indata.Tex3.xy);
	float4 zplaneLowDetailmap = tex2D(sampler4Wrap, indata.Tex0.wz);
	float lowDetailmap = lerp(0.5, yplaneLowDetailmap.z, lowComponent.x*indata.FogAndFade2.y);
#else
	float4 yplaneLowDetailmap = tex2D(ssampler4Wrap, indata.Tex5);

	// tl: do lerp in 1 MAD by precalculating constant factor in vShader
	float lowDetailmap = 2*yplaneLowDetailmap.z * indata.BlendValueAndFade.y + indata.FogAndFade2.z;
#endif

#if HIGHTERRAIN
	float mounten =	(xplaneLowDetailmap.y * indata.BlendValueAndFade.x) + 
						(yplaneLowDetailmap.x * indata.BlendValueAndFade.y) + 
						(zplaneLowDetailmap.y * indata.BlendValueAndFade.z)	;

	lowDetailmap *= (4 * lerp(0.5, mounten, lowComponent.z));

	float3 bothDetailmap = detailmap * lowDetailmap;
	float3 detailout = lerp(2*bothDetailmap, lowDetailmap, indata.BlendValueAndFade.w);
#else
	// tl: lerp optimized to handle 2*c*low + (2-2c)*detail, factors sent from vs
	float3 detailout = lowDetailmap*indata.BlendValueAndFade.x + 2*detailmap*indata.BlendValueAndFade.z;
#endif

	float3 outColor = detailout * colormap * light;

	float4 envmapColor = texCUBE(sampler6Cube, indata.EnvMap);
#if HIGHTERRAIN
	outColor = lerp(outColor, envmapColor, detailmap.w * (1-indata.BlendValueAndFade.w));
#else
	outColor = lerp(outColor, envmapColor, detailmap.w * (1-indata.FogAndFade2.y));
#endif
	
	// tl: this 2* is the one missing from the light calculation above!
	float3 fogOutColor = lerp(FogColor, outColor*2, indata.FogAndFade2.x);
	return float4(chartcontrib * fogOutColor, chartcontrib);
#endif 
}

Hi_VS2PS_FullDetailWithEnvMap Hi_VS_FullDetailWithEnvMap(Shared_APP2VS_Default indata)
{
	Hi_VS2PS_FullDetailWithEnvMap outdata = (Hi_VS2PS_FullDetailWithEnvMap)0;
	
	float4 wPos;
	wPos.xz = (indata.Pos0.xy * vScaleTransXZ.xy) + vScaleTransXZ.zw;
	wPos.yw = (indata.Pos1.xw * vScaleTransY.xy) + vScaleTransY.zw;

#if DEBUGTERRAIN
	outdata.Pos = mul(wPos, mViewProj);
	outdata.Tex0 = float4(0,0,0,0); 
	outdata.Tex1 = float4(0,0,0,0);
	outdata.BlendValueAndFade = float4(0,0,0,0);
	outdata.Tex3 = float4(0,0,0,0);
	outdata.Tex5 = float2(0,0);
	outdata.EnvMap = float3(0,0,0);
	outdata.FogAndFade2 = float4(0,0,0,0);
	return outdata;
#endif

	float yDelta, interpVal;
// geoMorphPosition(wPos, indata.MorphDelta, yDelta, interpVal);
	geoMorphPosition(wPos, indata.MorphDelta, indata.Pos0.z, yDelta, interpVal);
	
	// tl: output HPos as early as possible.
 	outdata.Pos = mul(wPos, mViewProj);

 	// tl: uncompress normal
 	indata.Normal = indata.Normal * 2 - 1;

	float3 tex = float3(indata.Pos0.y * vTexScale.z, wPos.y * vTexScale.y, indata.Pos0.x * vTexScale.x);
	float2 yPlaneTexCord = tex.zx;
#if HIGHTERRAIN
	float2 xPlaneTexCord = tex.xy;
	float2 zPlaneTexCord = tex.zy;
#endif
	
 	outdata.Tex0.xy = (yPlaneTexCord*vColorLightTex.x) + vColorLightTex.y;
 	outdata.Tex6 = (yPlaneTexCord*vDetailTex.x) + vDetailTex.y;

	// tl: Switched tex0.wz for tex3.xy to easier access it from 1.4
	outdata.Tex3.xy = yPlaneTexCord.xy * vNearTexTiling.z;
	
 	outdata.Tex5 = yPlaneTexCord * vFarTexTiling.z;

#if HIGHTERRAIN
	outdata.Tex0.wz = xPlaneTexCord.xy * vFarTexTiling.xy;
	outdata.Tex0.z += vFarTexTiling.w;
	outdata.Tex3.wz = zPlaneTexCord.xy * vFarTexTiling.xy;
	outdata.Tex3.z += vFarTexTiling.w;
#endif

	outdata.FogAndFade2.x = calcFog(outdata.Pos.w);
	outdata.FogAndFade2.yzw = 0.5+interpVal*0.5;

#if HIGHTERRAIN
	outdata.BlendValueAndFade.w = interpVal;
#elif MIDTERRAIN
	// tl: optimized so we can do more advanced lerp in same number of instructions
	// factors are 2c and (2-2c) which equals a lerp()*2
	// Don't use w, it's harder to access from ps1.4
	outdata.BlendValueAndFade.xz = interpVal * float2(2, -2) + float2(0, 2);
#endif

#if HIGHTERRAIN
	outdata.BlendValueAndFade.xyz = saturate(abs(indata.Normal) - vBlendMod);
	float tot = dot(1, outdata.BlendValueAndFade.xyz);
	outdata.BlendValueAndFade.xyz /= tot;
#elif MIDTERRAIN
	// tl: use squared yNormal as blend val. pre-multiply with fade value.
	outdata.BlendValueAndFade.yw = indata.Normal.y * indata.Normal.y * outdata.FogAndFade2.y;

	outdata.FogAndFade2.y = interpVal;
	outdata.FogAndFade2.z = outdata.BlendValueAndFade.y*-0.5 + 0.5;
#endif

	outdata.Tex1 = projToLighting(outdata.Pos);

	// Environment map
	// tl: no need to normalize, reflection works with long vectors, 
	// and cube maps auto-normalize.
	// outdata.EnvMap = reflect(wPos.xyz - vCamerapos.xyz, float3(0,1,0));
	// outdata.EnvMap = float3(1,-1,1)*wPos.xyz - float3(1,-1,1)*vCamerapos.xyz;
	outdata.EnvMap = reflect(wPos.xyz - vCamerapos.xyz, float3(0,1,0));

	return outdata;
}








struct Hi_VS2PS_PerPixelPointLight
{
    float4 Pos : POSITION;
    float3 wPos : TEXCOORD0;
    float3 Normal : TEXCOORD1;
};

float4 Hi_PS_PerPixelPointLight(Hi_VS2PS_PerPixelPointLight indata) : COLOR
{
 	return float4(calcPVPointTerrain(indata.wPos, indata.Normal), 0) * 0.5;
}

Hi_VS2PS_PerPixelPointLight Hi_VS_PerPixelPointLight(Shared_APP2VS_Default indata)
{
	Hi_VS2PS_PerPixelPointLight outdata;
	
	float4 wPos;
	wPos.xz = (indata.Pos0.xy * vScaleTransXZ.xy) + vScaleTransXZ.zw;
	// tl: Trans is always 0, and MADs cost more than MULs in certain cards.
	wPos.yw = indata.Pos1.xw * vScaleTransY.xy;

	float yDelta, interpVal;
// geoMorphPosition(wPos, indata.MorphDelta, yDelta, interpVal);
	geoMorphPosition(wPos, indata.MorphDelta, indata.Pos0.z, yDelta, interpVal);
	
	// tl: output HPos as early as possible.
 	outdata.Pos = mul(wPos, mViewProj);

 	// tl: uncompress normal
 	indata.Normal = indata.Normal * 2 - 1;
 	
 	outdata.Normal = indata.Normal;
 	outdata.wPos = wPos.xyz;

	return outdata;
}


float4 Hi_PS_DirectionalLightShadows(Shared_VS2PS_DirectionalLightShadows indata) : COLOR
{
	float4 lightmap = tex2D(sampler0Clamp, indata.Tex0);
	
// float avgShadowValue = getShadowFactor(ShadowMapSampler, indata.ShadowTex, 4, 20);
	float avgShadowValue = getShadowFactor(ShadowMapSampler, indata.ShadowTex, 4);

	float4 light = saturate(lightmap.z * vGIColor*2) * 0.5;
	if (avgShadowValue < lightmap.y)
		light.w = 1-saturate(4-indata.Z.x)+avgShadowValue.x;
	else
		light.w = lightmap.y;

	return light; 
}
















technique Hi_Terrain
{
	pass ZFillLightmap // p0
	{
		CullMode = CW;
		ZEnable = TRUE;
		ZWriteEnable = TRUE;
		ZFunc = LESS;
		AlphaBlendEnable = FALSE;
		FogEnable = false;
		
#if IS_NV4X
		StencilEnable = true;
		StencilFunc = NOTEQUAL;
		StencilRef = 0xa;
		StencilPass = KEEP;
		StencilZFail = KEEP;
		StencilFail = KEEP;
#endif

		VertexShader = compile vs_1_1 Shared_VS_ZFillLightmap();

		// tl: Using a 1.4 profile shortens this shader considerably (from 4 to 1
		// instructions because of arbitrary component select), however HLSL 
		// is unable to compile this optimally hence the inline assembly... :-|
		PixelShaderConstantF[0] = (vGIColor);
		Sampler[1] = (sampler0Clamp);
		PixelShader = asm {
ps_1_4
texld r1, t0
mul r0.xyz, r1.z, c0
+mov_sat r0.w, r1.y
		};
	}
	pass pointlight // p1
	{
		CullMode = CW;
		ZEnable = TRUE;
		ZWriteEnable = FALSE;
		ZFunc = LESSEQUAL;
		AlphaBlendEnable = TRUE;
		SrcBlend = ONE;
		DestBlend = ONE;
		
#if IS_NV4X
		StencilEnable = true;
		StencilFunc = NOTEQUAL;
		StencilRef = 0xa;
		StencilPass = KEEP;
		StencilZFail = KEEP;
		StencilFail = KEEP;
#endif

		VertexShader = compile vs_1_1 Shared_VS_PointLight();
		PixelShader = compile ps_1_1 Shared_PS_PointLight();
	}
	pass {} // spotlight (removed) p2
	pass LowDiffuse // p3
	{
		CullMode = CW;
		ZEnable = TRUE;
		ZWriteEnable = FALSE;
		ZFunc = LESSEQUAL;
		FogEnable = true;
		AlphaBlendEnable = FALSE;
		AlphaTestEnable = FALSE;
// FillMode = WireFrame;
		
#if IS_NV4X
		StencilEnable = true;
		StencilFunc = NOTEQUAL;
		StencilRef = 0xa;
		StencilPass = KEEP;
		StencilZFail = KEEP;
		StencilFail = KEEP;
#endif

		VertexShader = compile vs_1_1 Shared_VS_LowDetail();
#if 1 
		PixelShader = compile ps_1_4 Shared_PS_LowDetail();
#else 
		
		Sampler[0] = (sampler0Clamp); // colormap
		Sampler[1] = (sampler1Clamp); // lightmap
		Sampler[3] = (sampler4Wrap); // lowDetailTexture
		PixelShaderConstantF[0] = (vSunColor);
		PixelShaderConstantF[1] = (terrainWaterColor);

		PixelShader = asm {
	                ps_1_4
	                def c2, 0, 0, 0, 1
// mov r0, v0.y
// mov r0.w, c2.w
                
			texld r1, t1_dw.xyww
                	texld r0, t0
	                texld r3, t3
	                mad r1.xyz, r1_x2.w, c0, r1
	                mul r0.xyz, r1, r0
	              + lrp r1.w, v0.y, r3.z, r3.x
	                mul r0.xyz, r0_x2, r1.w
	                lrp r0.xyz, v0.w, c1, r0_x2
	              + mov r0.w, c2.w
	              
		};
#endif 
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
		FogEnable = false;
// FillMode = WireFrame;
		
		
#if IS_NV4X
		StencilEnable = true;
		StencilFunc = NOTEQUAL;
		StencilRef = 0xa;
		StencilPass = KEEP;
		StencilZFail = KEEP;
		StencilFail = KEEP;
#endif

		VertexShader = compile vs_1_1 Hi_VS_FullDetail();
#if HIGHTERRAIN
		PixelShader = compile PS2_EXT Hi_PS_FullDetail();
#elif MIDTERRAIN
	#if 1 
		PixelShader = compile ps_1_4 Hi_PS_FullDetail();
	#else
		// tl: Once again hand written is required to take advantage of 1.4
		PixelShaderConstantF[0] = (FogColor);
		PixelShaderConstantF[1] = (vComponentsel);
		PixelShaderConstantF[2] = (vSunColor);
		Sampler[0] = (sampler1Clamp);
		Sampler[1] = (sampler2Clamp);
		Sampler[2] = (ssampler4Wrap);
		Sampler[3] = (dsampler3Wrap);
		Sampler[4] = (sampler0Clamp);
		PixelShader = asm {
            // FogColor c0 1
            // vComponentsel c1 1
            // vSunColor c2 1
            // sampler1Clamp s0 1
            // sampler2Clamp s1 1
            // ssampler4Wrap s2 1
            // dsampler3Wrap s3 1
            // sampler0Clamp s4 1

                ps_1_4
// texcrd r0.xyz, t2
// mov r0, r0.y
             
                texld r0, t1_dw.xyww
                texld r1, t0
                mad r5.xyz, r0_x2.w, c2, r0
                dp3 r1.x, c1, r1
                phase
                texcrd r0.xyz, t2
                texld r2, t4
                texld r3, t3
                texld r4, t0
                mad r2.w, r2.z, r0.y, v0.z
              + mul r3.xyz, r3, r0.z
                mad r0.xyz, r2.w, r0.x, r3
                mul r0.xyz, r4, r0
                mul r0.xyz, r0, r5
                lrp r0.xyz, v0.x, r0_x2, c0
                mul r0.xyz, r0, r1.x
              + mov r0.w, r1.x
             
		};
	#endif
#endif
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
		FogEnable = false;
		
#if IS_NV4X
		StencilEnable = true;
		StencilFunc = NOTEQUAL;
		StencilRef = 0xa;
		StencilPass = KEEP;
		StencilZFail = KEEP;
		StencilFail = KEEP;
#endif

		VertexShader = compile vs_1_1 Hi_VS_FullDetailMounten();
#if HIGHTERRAIN
		PixelShader = compile PS2_EXT Hi_PS_FullDetailMounten();		
#elif MIDTERRAIN
		PixelShader = compile ps_1_4 Hi_PS_FullDetailMounten();
#endif
	}
	pass {} // p6 tunnels (removed)
	pass DirectionalLightShadows // p7
	{
		CullMode = CW;
		// ColorWriteEnable = RED|BLUE|GREEN|ALPHA;
		ZEnable = TRUE;
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;
 		AlphaBlendEnable = FALSE;
		
#if IS_NV4X
		StencilEnable = true;
		StencilFunc = NOTEQUAL;
		StencilRef = 0xa;
		StencilPass = KEEP;
		StencilZFail = KEEP;
		StencilFail = KEEP;
#endif

		VertexShader = compile vs_1_1 Shared_VS_DirectionalLightShadows();
		PixelShader = compile SHADOWPSMODEL Hi_PS_DirectionalLightShadows();
	}

	pass {} // DirectionalLightShadowsNV (removed)	// p8

	pass DynamicShadowmap // p9
	{
	// obsolete
	}

	pass {} // p10
	
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
		// ColsorWriteEnable = RED|BLUE|GREEN|ALPHA;
		FogEnable = false;
		
#if IS_NV4X
		StencilEnable = true;
		StencilFunc = NOTEQUAL;
		StencilRef = 0xa;
		StencilPass = KEEP;
		StencilZFail = KEEP;
		StencilFail = KEEP;
#endif

		VertexShader = compile vs_1_1 Hi_VS_FullDetailWithEnvMap();
#if HIGHTERRAIN
		PixelShader = compile PS2_EXT Hi_PS_FullDetailWithEnvMap();
#elif MIDTERRAIN
		// tl: Assembly to fit into 1.4, because HLSL can't do it. :-(
		PixelShaderConstantF[0] = (FogColor);
		PixelShaderConstantF[1] = (vComponentsel);
		PixelShaderConstantF[2] = (vSunColor);
		Sampler[0] = (sampler1Clamp);
		Sampler[1] = (ssampler4Wrap);
		Sampler[2] = (dsampler3Wrap);
		Sampler[3] = (sampler0Clamp);
		Sampler[4] = (sampler2Clamp);
		Sampler[5] = (sampler6Cube);
		PixelShader = asm {
            // Name Reg Size
            // ------------- ----- ----
            // FogColor c0 1
            // vComponentsel c1 1
            // vSunColor c2 1
            // sampler1Clamp s0 1
            // ssampler4Wrap s1 1
            // dsampler3Wrap s2 1
            // sampler0Clamp s3 1
            // sampler2Clamp s4 1
            
                ps_1_4
                def c3, 0, 0, 1, 1
                texld r0, t1_dw.xyww // sample lights
                texld r3, t0 // sample colormap
                texld r4, t0 // sample component
                texld r5, t4 // sample envmap
                mad r0.xyz, r0_x2.w, c2, r0 // get light factor
                dp3 r4.x, c1, r4 // calc component selector
                phase
                texld r1, t2 // sample ydetailmap
                texld r2, t3 // sample detailmap

				// float lowDetailmap = 2*yplaneLowDetailmap.z * indata.BlendValueAndFade.y + indata.FogAndFade2.z;
                mad r1.w, r1_x2.z, v0.y, v1.z

				// float3 detailout = lowDetailmap*indata.BlendValueAndFade.x + 2*detailmap*indata.BlendValueAndFade.z;
              + mul r2.xyz, r2, v0.z
                mad r1.xyz, r1.w, v0.x, r2_x2
                
				// float3 outColor = detailout * colormap * light;
                mul r1.xyz, r3, r1
                mul r0.xyz, r1, r0
                
				// outColor = lerp(outColor, envmapColor, detailmap.w * (1-indata.FogAndFade2.y));
                +mul r2.w, r2.w, 1-v1.y
                lrp r0.xyz, r2.w, r5, r0
                
				// float3 fogOutColor = lerp(FogColor, outColor*2, indata.FogAndFade2.x);
                lrp r0.xyz, v1.x, r0_x2, c0

				// return float4(chartcontrib * fogOutColor, chartcontrib);
                mul r0.xyz, r0, r4.x
              + mov r0.w, r4.x
		};
#endif
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
		StencilEnable = true;
		StencilFunc = NOTEQUAL;
		StencilRef = 0xa;
		StencilPass = KEEP;
		StencilZFail = KEEP;
		StencilFail = KEEP;
#endif

		VertexShader = compile vs_1_1 Hi_VS_PerPixelPointLight();
		PixelShader = compile PS2_EXT Hi_PS_PerPixelPointLight();
	}

	pass underWater // p14
	{
		CullMode = CW;
		ZEnable = TRUE;
		ZWriteEnable = FALSE;
		ZFunc = LESSEQUAL;
		AlphaTestEnable = TRUE;
		AlphaRef = 15;	// tl: leave cap above 0 for better results
		AlphaFunc = GREATER;
		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;
		FogEnable = false;
		
#if IS_NV4X
		StencilEnable = true;
		StencilFunc = NOTEQUAL;
		StencilRef = 0xa;
		StencilPass = KEEP;
		StencilZFail = KEEP;
		StencilFail = KEEP;
#endif

		VertexShader = compile vs_1_1 Shared_VS_UnderWater();
		PixelShader = compile ps_1_4 Shared_PS_UnderWater();
	}
	pass ZFillLightmap2 // p15
	{
		// note: ColorWriteEnable is disabled in code for this
		CullMode = CW;
		ZEnable = TRUE;
		ZWriteEnable = TRUE;
		ZFunc = LESS;
		AlphaBlendEnable = FALSE;
		FogEnable = false;
		VertexShader = compile vs_1_1 Shared_VS_ZFillLightmap();
		PixelShader = asm
		{
			ps.1.1
			mov r0, c0
		};
	}
}



































