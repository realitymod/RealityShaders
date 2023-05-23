#line 2 "TerrainShader_nv3x.fx"
//
// -- Basic morphed technique
//

struct APP2VS_BM_Dx9
{
    float4 Pos0 : POSITION0;
    float4 Pos1 : POSITION1;
    float4 MorphDelta : POSITION2;
    float2 TexCoord0 : TEXCOORD0;
    float3 Normal : NORMAL;
};

struct VS2PS_BM_Dx9_Base
{
    float4 Pos : POSITION;
    float2 Tex0 : TEXCOORD0;
};

float4 psDx9_BM_Base(VS2PS_BM_Dx9_Base indata) : COLOR
{
	float4 lightmap = tex2D(sampler0Clamp, indata.Tex0);
	float4 light = (lightmap.z * vGIColor) * 0.5;
	light.w = saturate(lightmap.y);
	return light; 
}

VS2PS_BM_Dx9_Base vsDx9_BM_Base(APP2VS_BM_Dx9 indata)
{
	VS2PS_BM_Dx9_Base outdata;
	
	float4 wPos;
	wPos.xz = (indata.Pos0.xy * vScaleTransXZ.xy) + vScaleTransXZ.zw;
	wPos.yw = (indata.Pos1.xw * vScaleTransY.xy) + vScaleTransY.zw;
// wPos.yw = indata.Pos1.xw;

	float cameraDist = length(wPos.xz - vCamerapos.xz) + vCamerapos.w;
	float interpVal = saturate(cameraDist * vNearFarMorphLimits.x - vNearFarMorphLimits.y);
	float yDelta = dot(vMorphDeltaSelector, indata.MorphDelta) * interpVal;
	wPos.y -= yDelta * vScaleTransY.x;

 	outdata.Pos = mul(wPos, mViewProj);
 	outdata.Tex0 = indata.TexCoord0;
 	  
	return outdata;
}

struct VS2PS_BM_Dx9_PPPt
{
    float4 Pos : POSITION;
    float3 wPos : TEXCOORD0;
    float3 Normal : TEXCOORD1;
};

float4 psDx9_BM_PPPt(VS2PS_BM_Dx9_PPPt indata) : COLOR
{
 	return float4(calcPVPointTerrain(indata.wPos, indata.Normal), 0) * 0.5;
}

VS2PS_BM_Dx9_PPPt vsDx9_BM_PPPt(APP2VS_BM_Dx9 indata)
{
	VS2PS_BM_Dx9_PPPt outdata;
	
	
	float4 wPos;
	wPos.xz = (indata.Pos0.xy * vScaleTransXZ.xy) + vScaleTransXZ.zw;
	wPos.yw = (indata.Pos1.xw * vScaleTransY.xy) + vScaleTransY.zw;
// wPos.yw = indata.Pos1.xw;
	
	float cameraDist = length(wPos.xz - vCamerapos.xz) + vCamerapos.w;
	float interpVal = saturate(cameraDist * vNearFarMorphLimits.x - vNearFarMorphLimits.y);
	float yDelta = dot(vMorphDeltaSelector, indata.MorphDelta) * interpVal;
	wPos.y -= yDelta * vScaleTransY.x;

 	outdata.Pos = mul(wPos, mViewProj);
 	outdata.Normal = indata.Normal;
 	outdata.wPos = wPos.xyz;

	return outdata;
}


struct VS2PS_BM_Dx9
{
    float4 Pos : POSITION;
    float2 Tex0 : TEXCOORD0;
    float4 Color : COLOR0;
};

float4 psDx9_BM_Pt(VS2PS_BM_Dx9 indata) : COLOR
{
	return indata.Color * 0.5;
}

VS2PS_BM_Dx9 vsDx9_BM_Pt(APP2VS_BM_Dx9 indata)
{
	VS2PS_BM_Dx9 outdata;
	
	float4 wPos;
	wPos.xz = (indata.Pos0.xy * vScaleTransXZ.xy) + vScaleTransXZ.zw;
	wPos.yw = (indata.Pos1.xw * vScaleTransY.xy) + vScaleTransY.zw;
// wPos.yw = indata.Pos1.xw;
	
	float cameraDist = length(wPos.xz - vCamerapos.xz) + vCamerapos.w;
	float interpVal = saturate(cameraDist * vNearFarMorphLimits.x - vNearFarMorphLimits.y);
	float yDelta = dot(vMorphDeltaSelector, indata.MorphDelta) * interpVal;
	wPos.y -= yDelta * vScaleTransY.x;

 	outdata.Pos = mul(wPos, mViewProj);
 	outdata.Tex0 = indata.TexCoord0;
 	outdata.Color = float4(calcPVPointTerrain(wPos.xyz, indata.Normal), 0);

	return outdata;
}

float4 psDx9_BM_Sp(VS2PS_BM_Dx9 indata) : COLOR
{
	return indata.Color * 0.5;
}

VS2PS_BM_Dx9 vsDx9_BM_Sp(APP2VS_BM_Dx9 indata)
{
	VS2PS_BM_Dx9 outdata;
	
	float4 wPos;
	wPos.xz = (indata.Pos0.xy * vScaleTransXZ.xy) + vScaleTransXZ.zw;
	wPos.yw = (indata.Pos1.xw * vScaleTransY.xy) + vScaleTransY.zw;
// wPos.yw = indata.Pos1.xw;
	
	float cameraDist = length(wPos.xz - vCamerapos.xz) + vCamerapos.w;
	float interpVal = saturate(cameraDist * vNearFarMorphLimits.x - vNearFarMorphLimits.y);
	float yDelta = dot(vMorphDeltaSelector, indata.MorphDelta) * interpVal;
	wPos.y -= yDelta * vScaleTransY.x;

 	outdata.Pos = mul(wPos, mViewProj);
 	outdata.Tex0 = indata.TexCoord0;
	outdata.Color = float4(calcPVSpot(spotLight, wPos, indata.Normal), 0);
	
	return outdata;
}

technique Dx9Style_BM_States <bool Restore = true;> {
	pass BeginStates {
		CullMode = CW;
	}
	
	pass EndStates {
	}
}

struct VS2PS_BM_Dx9_MulDFast
{
    float4 Pos : POSITION;
    float2 Tex0 : TEXCOORD0;
    float4 Tex1 : TEXCOORD1;
    float Fog : FOG;
};

float4 psDx9_BM_MulDFast(VS2PS_BM_Dx9_MulDFast indata) : COLOR
{
// return indata.BlendValue.x;
	
	float4 colormap = tex2D(sampler0Clamp, indata.Tex0.xy);
	float4 accumlights = tex2Dproj(sampler1Clamp, indata.Tex1);
	float4 light = (accumlights.w * vSunColor) + accumlights*2;

	return colormap * light;
}

VS2PS_BM_Dx9_MulDFast vsDx9_BM_MulDFast(APP2VS_BM_Dx9 indata)
{
	VS2PS_BM_Dx9_MulDFast outdata;
	
	float4 wPos;
	wPos.xz = (indata.Pos0.xy * vScaleTransXZ.xy) + vScaleTransXZ.zw;
	wPos.yw = (indata.Pos1.xw * vScaleTransY.xy) + vScaleTransY.zw;

 	outdata.Pos = mul(wPos, mViewProj);

 	outdata.Tex0.xy = indata.TexCoord0;

 	outdata.Tex1.xy = outdata.Pos.xy/outdata.Pos.w;
 	outdata.Tex1.xy = (outdata.Tex1.xy + 1) / 2;
 	outdata.Tex1.y = 1-outdata.Tex1.y;
 	outdata.Tex1.xy += vTexProjOffset;
	outdata.Tex1.xy = outdata.Tex1.xy * outdata.Pos.w;
	outdata.Tex1.zw = outdata.Pos.zw;
	
	outdata.Fog = calcFog(outdata.Pos.w);
	
	return outdata;
}

struct VS2PS_BM_Dx9_MulD
{
    float4 Pos : POSITION;
    float2 Tex0a : TEXCOORD0;
    float2 Tex0b : TEXCOORD3;
    float4 Tex1 : TEXCOORD1;
    float2 Tex2a : TEXCOORD2;
    float2 Tex2b : TEXCOORD4;
    float4 BlendValueAndWater : COLOR0;
    float Fog : FOG;
};

float4 psDx9_BM_MulD2(VS2PS_BM_Dx9_MulD indata) : COLOR
{
// return indata.BlendValue.x;
	
	float4 colormap = tex2D(sampler0Clamp, indata.Tex0a);
	float4 accumlights = tex2Dproj(sampler1Clamp, indata.Tex1);
	float4 light = ((accumlights.w * vSunColor) + accumlights)*2;

	return colormap * light;
}

float4 psDx9_BM_MulD(VS2PS_BM_Dx9_MulD indata) : COLOR
{
	float4 colormap = tex2D(sampler0Clamp, indata.Tex0a);
	float4 accumlights = tex2Dproj(sampler1Clamp, indata.Tex1);
	float4 light = ((accumlights.w * vSunColor) + accumlights)*2;
	
	float4 lowComponent = tex2D(sampler5Clamp, indata.Tex0a);

	float4 yplaneLowDetailmap = tex2D(sampler4Wrap, indata.Tex0b);
	float4 xplaneLowDetailmap = tex2D(sampler4Wrap2, indata.Tex2a);
	float4 zplaneLowDetailmap = tex2D(sampler4Wrap3, indata.Tex2b);
	
	float mounten = (xplaneLowDetailmap.y * indata.BlendValueAndWater.x) + 
			 (yplaneLowDetailmap.x * indata.BlendValueAndWater.y) + 
			 (zplaneLowDetailmap.y * indata.BlendValueAndWater.z);
			 
	float4 outColor = colormap * light * 4 * lerp(0.5, yplaneLowDetailmap.z, lowComponent.x) * lerp(0.5, mounten, lowComponent.z);
	return lerp(terrainWaterColor, outColor, indata.BlendValueAndWater.w);
}

VS2PS_BM_Dx9_MulD vsDx9_BM_MulD(APP2VS_BM_Dx9 indata)
{
	VS2PS_BM_Dx9_MulD outdata;
	
	float4 wPos;
	wPos.xz = (indata.Pos0.xy * vScaleTransXZ.xy) + vScaleTransXZ.zw;
	wPos.yw = (indata.Pos1.xw * vScaleTransY.xy) + vScaleTransY.zw;
	
	float cameraDist = length(wPos.xz - vCamerapos.xz) + vCamerapos.w;
	float interpVal = saturate(cameraDist * vNearFarMorphLimits.x - vNearFarMorphLimits.y);
	float yDelta = dot(vMorphDeltaSelector, indata.MorphDelta) * interpVal;
	wPos.y -= yDelta * vScaleTransY.x;

 	outdata.BlendValueAndWater.w = 1 - saturate((waterHeight - wPos.y)/3.0f);

	float3 tex = float3(indata.Pos0.y * vTexScale.z, -(indata.Pos1.x - yDelta) * vTexScale.y, indata.Pos0.x * vTexScale.x);
	float2 xPlaneTexCord = tex.xy;
	float2 yPlaneTexCord = tex.zx;
	float2 zPlaneTexCord = tex.zy;
	
 	outdata.Pos = mul(wPos, mViewProj);

 	outdata.Tex0a = indata.TexCoord0; // frac(yPlaneTexCord);

 	outdata.Tex0b = yPlaneTexCord * vFarTexTiling.z;
	outdata.Tex2a = xPlaneTexCord.xy * vFarTexTiling.xy;
	outdata.Tex2a.y += vFarTexTiling.w;
	outdata.Tex2b = zPlaneTexCord.xy * vFarTexTiling.xy;
	outdata.Tex2b.y += vFarTexTiling.w;

	outdata.BlendValueAndWater.xyz = saturate(abs(indata.Normal) - vBlendMod);
	float tot = dot(1, outdata.BlendValueAndWater.xyz);
	outdata.BlendValueAndWater.xyz /= tot;
	
 	outdata.Tex1.xy = outdata.Pos.xy/outdata.Pos.w;
 	outdata.Tex1.xy = (outdata.Tex1.xy + 1) / 2;
 	outdata.Tex1.y = 1-outdata.Tex1.y;
 	outdata.Tex1.xy += vTexProjOffset;
	outdata.Tex1.xy = outdata.Tex1.xy * outdata.Pos.w;
	outdata.Tex1.zw = outdata.Pos.zw;
	
	outdata.Fog = calcFog(outdata.Pos.w);

 	outdata.Tex0a = indata.TexCoord0; // frac(yPlaneTexCord);
	
	return outdata;
}

struct VS2PS_BM_Dx9_MulDDetail
{
    float4 Pos : POSITION;
    float4 Tex0 : TEXCOORD0;
    float4 Tex1 : TEXCOORD1;
    float4 Tex3 : TEXCOORD3;
    float4 BlendValueAndFade : COLOR0;
    float2 Tex5 : TEXCOORD6;
    float2 FogAndWater : COLOR1;
};

float4 psDx9_BM_MulDDetail(VS2PS_BM_Dx9_MulDDetail indata) : COLOR
{
	float4 colormap = tex2D(sampler0Clamp, indata.Tex0.xy);
	
	float4 accumlights = tex2Dproj(sampler1Clamp, indata.Tex1);
	float4 light = ((accumlights.w * vSunColor) + accumlights)*2;
	
	float4 component = tex2D(sampler2Clamp, indata.Tex0.xy);
	float4 detailmap = tex2D(sampler3Wrap, indata.Tex0.wz);
	
	float4 lowComponent = tex2D(sampler5Clamp, indata.Tex0.xy);
	float chartcontrib = dot(vComponentsel, component); 

	float4 yplaneLowDetailmap = tex2D(sampler4Wrap, indata.Tex5);
	float4 xplaneLowDetailmap = tex2D(sampler4Wrap, indata.Tex3.xy);
	float4 zplaneLowDetailmap = tex2D(sampler4Wrap, indata.Tex3.wz);

	float4 lowDetailmap = lerp(0.5, yplaneLowDetailmap.z, lowComponent.x);
	float mounten = (xplaneLowDetailmap.y * indata.BlendValueAndFade.x) + 
			(yplaneLowDetailmap.x * indata.BlendValueAndFade.y) + 
			(zplaneLowDetailmap.y * indata.BlendValueAndFade.z);
	lowDetailmap *= (4 * lerp(0.5, mounten, lowComponent.z));

	float4 bothDetailmap = detailmap * lowDetailmap;
	float4 detailout = lerp(2*bothDetailmap, lowDetailmap, indata.BlendValueAndFade.w);

	float4 outColor = detailout * colormap * light;
	float4 waterOutColor = lerp(terrainWaterColor, outColor, indata.FogAndWater.y);
	float4 fogWaterOutColor = lerp(fogColor, waterOutColor, indata.FogAndWater.x);
	
// return light * chartcontrib;
	
	
	return chartcontrib * fogWaterOutColor;
}

VS2PS_BM_Dx9_MulDDetail vsDx9_BM_MulDDetail(APP2VS_BM_Dx9 indata)
{
	VS2PS_BM_Dx9_MulDDetail outdata;
	
	float4 wPos;
	wPos.xz = (indata.Pos0.xy * vScaleTransXZ.xy) + vScaleTransXZ.zw;
	wPos.yw = (indata.Pos1.xw * vScaleTransY.xy) + vScaleTransY.zw;
// wPos.yw = indata.Pos1.xw;

	float cameraDist = length(wPos.xz - vCamerapos.xz) + vCamerapos.w;
	float interpVal = saturate(cameraDist * vNearFarMorphLimits.x - vNearFarMorphLimits.y);
	float yDelta = dot(vMorphDeltaSelector, indata.MorphDelta) * interpVal;
	wPos.y -= yDelta * vScaleTransY.x;

 	outdata.FogAndWater.y = 1 - saturate((waterHeight - wPos.y)/3.0f);

	float3 tex = float3(indata.Pos0.y * vTexScale.z, -(indata.Pos1.x - yDelta) * vTexScale.y, indata.Pos0.x * vTexScale.x);
	float2 xPlaneTexCord = tex.xy;
	float2 yPlaneTexCord = tex.zx;
	float2 zPlaneTexCord = tex.zy;

 	outdata.Pos = mul(wPos, mViewProj);
	
 	outdata.Tex0.xy = yPlaneTexCord;

	outdata.Tex0.wz = yPlaneTexCord.xy * vNearTexTiling.z;
	
 	outdata.Tex5 = yPlaneTexCord * vFarTexTiling.z;
	outdata.Tex3.xy = xPlaneTexCord.xy * vFarTexTiling.xy;
	outdata.Tex3.y += vFarTexTiling.w;
	outdata.Tex3.wz = zPlaneTexCord.xy * vFarTexTiling.xy;
	outdata.Tex3.z += vFarTexTiling.w;

	outdata.BlendValueAndFade.w = interpVal;

	outdata.BlendValueAndFade.xyz = saturate(abs(indata.Normal) - vBlendMod);
	float tot = dot(1, outdata.BlendValueAndFade.xyz);
	outdata.BlendValueAndFade.xyz /= tot;

 	outdata.Tex1.xy = outdata.Pos.xy/outdata.Pos.w;
 	outdata.Tex1.xy = (outdata.Tex1.xy + 1) / 2;
 	outdata.Tex1.y = 1-outdata.Tex1.y;
 	outdata.Tex1.xy += vTexProjOffset;
	outdata.Tex1.xy = outdata.Tex1.xy * outdata.Pos.w;
	outdata.Tex1.zw = outdata.Pos.zw;

	outdata.FogAndWater.x = calcFog(outdata.Pos.w);

	return outdata;
}

struct VS2PS_BM_Dx9_MulDDetailMounten
{
    float4 Pos : POSITION;
    float4 Tex0 : TEXCOORD0;
    float4 Tex1 : TEXCOORD1;
    float4 Tex3 : TEXCOORD3;
    float4 BlendValueAndFade : COLOR0;
    float2 Tex5 : TEXCOORD5;
    float4 Tex6 : TEXCOORD6;
    float2 FogAndWater : COLOR1;
};

float4 psDx9_BM_MulDDetailMounten(VS2PS_BM_Dx9_MulDDetailMounten indata) : COLOR
{
	float4 colormap = tex2D(sampler0Clamp, indata.Tex0.xy);

	float4 accumlights = tex2Dproj(sampler1Clamp, indata.Tex1);
	float4 light = ((accumlights.w * vSunColor) + accumlights)*2;

	float4 component = tex2D(sampler2Clamp, indata.Tex0.xy);
	float4 yplaneDetailmap = tex2D(sampler3Wrap, indata.Tex0.wz);
	float4 xplaneDetailmap = tex2D(sampler6Wrap, indata.Tex6.xy);
	float4 zplaneDetailmap = tex2D(sampler6Wrap, indata.Tex6.wz);

	float4 lowComponent = tex2D(sampler5Clamp, indata.Tex0.xy);
	float chartcontrib = dot(vComponentsel, component); 
	
	float4 yplaneLowDetailmap = tex2D(sampler4Wrap, indata.Tex5);
	float4 xplaneLowDetailmap = tex2D(sampler4Wrap, indata.Tex3.xy);
	float4 zplaneLowDetailmap = tex2D(sampler4Wrap, indata.Tex3.wz);

	float4 lowDetailmap = lerp(0.5, yplaneLowDetailmap.z, lowComponent.x);
	float mounten = (xplaneLowDetailmap.y * indata.BlendValueAndFade.x) + 
			(yplaneLowDetailmap.x * indata.BlendValueAndFade.y) + 
			(zplaneLowDetailmap.y * indata.BlendValueAndFade.z);
	lowDetailmap *= (4 * lerp(0.5, mounten, lowComponent.z));

	float4 detailmap = (xplaneDetailmap * indata.BlendValueAndFade.x) + 
			(yplaneDetailmap * indata.BlendValueAndFade.y) + 
			(zplaneDetailmap * indata.BlendValueAndFade.z);

	float4 bothDetailmap = detailmap * lowDetailmap;
	float4 detailout = lerp(2*bothDetailmap, lowDetailmap, indata.BlendValueAndFade.w);

	float4 outColor = detailout * colormap * light;
	float4 waterOutColor = lerp(terrainWaterColor, outColor, indata.FogAndWater.y);
	float4 fogWaterOutColor = lerp(fogColor, waterOutColor, indata.FogAndWater.x);
	return chartcontrib * fogWaterOutColor;
}

VS2PS_BM_Dx9_MulDDetailMounten vsDx9_BM_MulDDetailMounten(APP2VS_BM_Dx9 indata)
{
	VS2PS_BM_Dx9_MulDDetailMounten outdata;
	
	float4 wPos;
	wPos.xz = (indata.Pos0.xy * vScaleTransXZ.xy) + vScaleTransXZ.zw;
	wPos.yw = (indata.Pos1.xw * vScaleTransY.xy) + vScaleTransY.zw;
// wPos.yw = indata.Pos1.xw;

	float cameraDist = length(wPos.xz - vCamerapos.xz) + vCamerapos.w;
	float interpVal = saturate(cameraDist * vNearFarMorphLimits.x - vNearFarMorphLimits.y);
	float yDelta = dot(vMorphDeltaSelector, indata.MorphDelta) * interpVal;
	wPos.y -= yDelta * vScaleTransY.x;

 	outdata.FogAndWater.y = 1 - saturate((waterHeight - wPos.y)/3.0f);

	float3 tex = float3(indata.Pos0.y * vTexScale.z, -(indata.Pos1.x - yDelta) * vTexScale.y, indata.Pos0.x * vTexScale.x);
	float2 xPlaneTexCord = tex.xy;
	float2 yPlaneTexCord = tex.zx;
	float2 zPlaneTexCord = tex.zy;

 	outdata.Pos = mul(wPos, mViewProj);
	
 	outdata.Tex0.xy = yPlaneTexCord;

	outdata.Tex0.wz = yPlaneTexCord.xy * vNearTexTiling.z;
	outdata.Tex6.xy = xPlaneTexCord.xy * vNearTexTiling.xy;
	outdata.Tex6.y += vNearTexTiling.w;
	outdata.Tex6.wz = zPlaneTexCord.xy * vNearTexTiling.xy;
	outdata.Tex6.z += vNearTexTiling.w;

 	outdata.Tex5 = yPlaneTexCord * vFarTexTiling.z;
	outdata.Tex3.xy = xPlaneTexCord.xy * vFarTexTiling.xy;
	outdata.Tex3.y += vFarTexTiling.w;
	outdata.Tex3.wz = zPlaneTexCord.xy * vFarTexTiling.xy;
	outdata.Tex3.z += vFarTexTiling.w;

	outdata.BlendValueAndFade.w = interpVal;

	outdata.BlendValueAndFade.xyz = saturate(abs(indata.Normal) - vBlendMod);
	float tot = dot(1, outdata.BlendValueAndFade.xyz);
	outdata.BlendValueAndFade.xyz /= tot;

 	outdata.Tex1.xy = outdata.Pos.xy/outdata.Pos.w;
 	outdata.Tex1.xy = (outdata.Tex1.xy + 1) / 2;
 	outdata.Tex1.y = 1-outdata.Tex1.y;
 	outdata.Tex1.xy += vTexProjOffset;
	outdata.Tex1.xy = outdata.Tex1.xy * outdata.Pos.w;
	outdata.Tex1.zw = outdata.Pos.zw;

	outdata.FogAndWater.x = calcFog(outdata.Pos.w);

	return outdata;
}


struct VS2PS_BM_Dx9_MulDDetailWithEnvMap
{
    float4 Pos : POSITION;
    float4 Tex0 : TEXCOORD0;
    float4 Tex1 : TEXCOORD1;
    float4 Tex3 : TEXCOORD3;
    float4 BlendValueAndFade : COLOR0;
    float2 Tex5 : TEXCOORD6;
    float3 EnvMap : TEXCOORD7;
    float2 FogAndWater : COLOR1;
};

float4 psDx9_BM_MulDDetailWithEnvMap(VS2PS_BM_Dx9_MulDDetailWithEnvMap indata) : COLOR
{
	float4 colormap = tex2D(sampler0Clamp, indata.Tex0.xy);
	
	float4 accumlights = tex2Dproj(sampler1Clamp, indata.Tex1);
	float4 light = ((accumlights.w * vSunColor) + accumlights)*2;
	
	float4 component = tex2D(sampler2Clamp, indata.Tex0.xy);
	float4 detailmap = tex2D(sampler3Wrap, indata.Tex0.wz);

	float4 envmapColor = texCUBE(sampler6Cube, indata.EnvMap);

	float4 lowComponent = tex2D(sampler5Clamp, indata.Tex0.xy);
	float chartcontrib = dot(vComponentsel, component); 
	
	float4 yplaneLowDetailmap = tex2D(sampler4Wrap, indata.Tex5);
	float4 xplaneLowDetailmap = tex2D(sampler4Wrap, indata.Tex3.xy);
	float4 zplaneLowDetailmap = tex2D(sampler4Wrap, indata.Tex3.wz);

	float4 lowDetailmap = lerp(0.5, yplaneLowDetailmap.z, lowComponent.x);
	float mounten = (xplaneLowDetailmap.y * indata.BlendValueAndFade.x) + 
			(yplaneLowDetailmap.x * indata.BlendValueAndFade.y) + 
			(zplaneLowDetailmap.y * indata.BlendValueAndFade.z);
	lowDetailmap *= (4 * lerp(0.5, mounten, lowComponent.z));
	
	float4 bothDetailmap = 2 * detailmap * lowDetailmap;
	float4 detailout = lerp(lowDetailmap, bothDetailmap, indata.BlendValueAndFade.w);
	float4 outColor = lerp(detailout * colormap * light, envmapColor, detailmap.w * indata.BlendValueAndFade.w);
// float4 outColor = lerp(detailout * colormap * light, envmapColor, indata.EnvMap.w * detailmap.w * indata.BlendValueAndFade.w);
// outColor = indata.EnvMap.w;

	float4 waterOutColor = lerp(terrainWaterColor, outColor, indata.FogAndWater.y);
	float4 fogWaterOutColor = lerp(fogColor, waterOutColor, indata.FogAndWater.x);
	return chartcontrib * fogWaterOutColor;
}

VS2PS_BM_Dx9_MulDDetailWithEnvMap vsDx9_BM_MulDDetailWithEnvMap(APP2VS_BM_Dx9 indata)
{
	VS2PS_BM_Dx9_MulDDetailWithEnvMap outdata;
	
	float4 wPos;
	wPos.xz = (indata.Pos0.xy * vScaleTransXZ.xy) + vScaleTransXZ.zw;
	wPos.yw = (indata.Pos1.xw * vScaleTransY.xy) + vScaleTransY.zw;
// wPos.yw = indata.Pos1.xw;

	float cameraDist = length(wPos.xz - vCamerapos.xz) + vCamerapos.w;
	float interpVal = saturate(cameraDist * vNearFarMorphLimits.x - vNearFarMorphLimits.y);
	float yDelta = dot(vMorphDeltaSelector, indata.MorphDelta) * interpVal;
	wPos.y -= yDelta * vScaleTransY.x;

 	outdata.FogAndWater.y = 1 - saturate((waterHeight - wPos.y)/3.0f);

	float3 tex = float3(indata.Pos0.y * vTexScale.z, -(indata.Pos1.x - yDelta) * vTexScale.y, indata.Pos0.x * vTexScale.x);
	float2 xPlaneTexCord = tex.xy;
	float2 yPlaneTexCord = tex.zx;
	float2 zPlaneTexCord = tex.zy;

 	outdata.Pos = mul(wPos, mViewProj);
	
 	outdata.Tex0.xy = yPlaneTexCord;

	outdata.Tex0.wz = yPlaneTexCord.xy * vNearTexTiling.z;
	
 	outdata.Tex5 = yPlaneTexCord * vFarTexTiling.z;
	outdata.Tex3.xy = xPlaneTexCord.xy * vFarTexTiling.xy;
	outdata.Tex3.y += vFarTexTiling.w;
	outdata.Tex3.wz = zPlaneTexCord.xy * vFarTexTiling.xy;
	outdata.Tex3.z += vFarTexTiling.w;

	outdata.BlendValueAndFade.w = 1 - interpVal;

	outdata.BlendValueAndFade.xyz = saturate(abs(indata.Normal) - vBlendMod);
	float tot = dot(1, outdata.BlendValueAndFade.xyz);
	outdata.BlendValueAndFade.xyz /= tot;

 	outdata.Tex1.xy = outdata.Pos.xy/outdata.Pos.w;
 	outdata.Tex1.xy = (outdata.Tex1.xy + 1) / 2;
 	outdata.Tex1.y = 1-outdata.Tex1.y;
 	outdata.Tex1.xy += vTexProjOffset;
	outdata.Tex1.xy = outdata.Tex1.xy * outdata.Pos.w;
	outdata.Tex1.zw = outdata.Pos.zw;

	outdata.FogAndWater.x = calcFog(outdata.Pos.w);

	// Environment map
// float dist = length(wPos.xyz - vCamerapos.xyz);
	float3 worldEyeVec = normalize(wPos.xyz - vCamerapos.xyz);
	outdata.EnvMap = normalize(reflect(worldEyeVec, float3(0,1,0)));
// outdata.EnvMap.xyz = normalize(reflect(worldEyeVec, float3(0,1,0)));
// outdata.EnvMap.w = saturate((1 - abs(worldEyeVec.y + 0.5)) + saturate(1 - 5/dist)); // dot(float3(0,1,0), worldEyeVec);

	return outdata;
}




struct VS2PS_DirectionalLightShadows
{
    float4 Pos : POSITION;
    float2 Tex0 : TEXCOORD0;
    float4 ShadowTex : TEXCOORD1;
};



float4 psDirectionalLightShadows(VS2PS_DirectionalLightShadows indata) : COLOR
{
	float4 lightmap = tex2D(sampler0Clamp, indata.Tex0);
	
	float4 texel = float4(1.0/1024.0, 1.0/1024.0, 0, 0);
	float4 samples;
	samples.x = tex2Dproj(sampler2PointClamp, indata.ShadowTex);
	samples.y = tex2Dproj(sampler2PointClamp, indata.ShadowTex + float4(texel.x, 0, 0, 0));
	samples.z = tex2Dproj(sampler2PointClamp, indata.ShadowTex + float4(0, texel.y, 0, 0));
	samples.w = tex2Dproj(sampler2PointClamp, indata.ShadowTex + texel);

	float4 cmpbits = samples == 1.f;
	float avgShadowValue = dot(cmpbits, 0.25);

	float4 light = saturate(lightmap.z * vGIColor) * 0.5;
	if (avgShadowValue < lightmap.y)
		light.w = 1-saturate(4-indata.ShadowTex.z)+avgShadowValue.x;
	else
		light.w = lightmap.y;

	return light; 
}

float4 psDirectionalLightShadowsNV(VS2PS_DirectionalLightShadows indata) : COLOR
{
	return float4(indata.Tex0.x, indata.Tex0.y, 0, 0);
	float2 texel = float2(1.0/1024.0, 1.0/1024.0);
	float avgShadowValue = tex2Dproj(sampler2Clamp, indata.ShadowTex); // HW percentage closer filtering.

	float4 shadow = saturate(avgShadowValue.x*0.6 + 0.4);
	float4 lightmap = tex2D(sampler0Clamp, indata.Tex0);
	return min(shadow, lightmap);
}

VS2PS_DirectionalLightShadows vsDirectionalLightShadows(APP2VS_BM_Dx9 indata)
{
	VS2PS_DirectionalLightShadows outdata;
	
	float4 wPos;
	wPos.xz = (indata.Pos0.xy * vScaleTransXZ.xy) + vScaleTransXZ.zw;
	wPos.yw = (indata.Pos1.xw * vScaleTransY.xy) + vScaleTransY.zw;
// wPos.yw = indata.Pos1.xw;

	float cameraDist = length(wPos.xz - vCamerapos.xz) + vCamerapos.w;
	float interpVal = saturate(cameraDist * vNearFarMorphLimits.x - vNearFarMorphLimits.y);
	float yDelta = dot(vMorphDeltaSelector, indata.MorphDelta) * interpVal;
	wPos.y -= yDelta * vScaleTransY.x;

 	outdata.Pos = mul(wPos, mViewProj);

	outdata.ShadowTex = mul(wPos, mLightVP);

 	outdata.Tex0 = indata.TexCoord0;
  
	return outdata;
}

struct VS2PS_DynamicShadowmap
{
    float4 Pos : POSITION;
    float4 ShadowTex : TEXCOORD1;
};


float4 psDynamicShadowmap(VS2PS_DynamicShadowmap indata) : COLOR
{
	float avgShadowValue = tex2Dproj(sampler2PointClamp, indata.ShadowTex) == 1.0;
	return 1-saturate(4-indata.ShadowTex.z)+avgShadowValue.x;
}

VS2PS_DynamicShadowmap vsDynamicShadowmap(APP2VS_BM_Dx9 indata)
{
	VS2PS_DynamicShadowmap outdata;
	
	float4 wPos;
	wPos.xz = (indata.Pos0.xy * vScaleTransXZ.xy) + vScaleTransXZ.zw;
	wPos.yw = (indata.Pos1.xw * vScaleTransY.xy) + vScaleTransY.zw;
// wPos.yw = indata.Pos1.xw;

 	outdata.Pos = mul(wPos, mViewProj);

	outdata.ShadowTex = mul(wPos, mLightVP);

	return outdata;
}

technique Dx9Style_BM
{
	pass baseLightmap // p0
	{
		CullMode = CW;
		// ColorWriteEnable = RED|BLUE|GREEN|ALPHA;
		ZEnable = TRUE;
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;
		AlphaBlendEnable = FALSE;
		FogEnable = false;
		VertexShader = compile vs_1_1 vsDx9_BM_Base();
		PixelShader = compile ps_1_1 psDx9_BM_Base();
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
		VertexShader = compile vs_1_1 vsDx9_BM_Pt();
		PixelShader = compile ps_1_1 psDx9_BM_Pt();
	}
	pass spotlight // p2
	{
		CullMode = CW;
		ZEnable = TRUE;
		ZWriteEnable = FALSE;
		ZFunc = LESSEQUAL;
		AlphaBlendEnable = TRUE;
		SrcBlend = ONE;
		DestBlend = ONE;
		
		VertexShader = compile vs_1_1 vsDx9_BM_Sp();	
		PixelShader = compile ps_1_1 psDx9_BM_Sp();
	}
	pass mulDiffuse // p3
	{
		CullMode = CW;
		ZEnable = TRUE;
		ZWriteEnable = FALSE;
		ZFunc = LESSEQUAL;
// FogEnable = false;
		FogEnable = true;
		SrcBlend = ONE;
		DestBlend = ONE;
		VertexShader = compile vs_2_0 vsDx9_BM_MulD();
		PixelShader = compile ps_1_4 psDx9_BM_MulD();
// PixelShader = compile PS2_EXT psDx9_BM_MulD();
	}
	pass mulDiffuseDetail // p4
	{
		CullMode = CW;
		ZEnable = TRUE;
		ZWriteEnable = FALSE;
		ZFunc = LESSEQUAL;
		AlphaBlendEnable = TRUE;
		SrcBlend = ONE;
		DestBlend = ONE;
		// ColorWriteEnable = RED|BLUE|GREEN|ALPHA;
		FogEnable = false;
		VertexShader = compile vs_1_1 vsDx9_BM_MulDDetail();
		PixelShader = compile PS2_EXT psDx9_BM_MulDDetail();
	}
	pass mulDiffuseDetailMounten // p5
	{
		CullMode = CW;
		ZEnable = TRUE;
		ZWriteEnable = FALSE;
		ZFunc = LESSEQUAL;
		AlphaBlendEnable = TRUE;
		SrcBlend = ONE;
		DestBlend = ONE;
		FogEnable = false;
		// ColorWriteEnable = RED|BLUE|GREEN|ALPHA;
		VertexShader = compile vs_1_1 vsDx9_BM_MulDDetailMounten();
		PixelShader = compile PS2_EXT psDx9_BM_MulDDetailMounten();
	}
	pass {} // p6 tunnels (removed)
	pass DirectionalLightShadows // p7
	{
		CullMode = CW;
		// ColorWriteEnable = RED|BLUE|GREEN|ALPHA;
		ZEnable = TRUE;
		ZWriteEnable = FALSE;
		ZFunc = LESSEQUAL;
 		AlphaBlendEnable = FALSE;
 		SrcBlend = DESTCOLOR;
 		DestBlend = ZERO;
		VertexShader = compile vs_1_1 vsDirectionalLightShadows();
		PixelShader = compile PS2_EXT psDirectionalLightShadows();
	}

	pass DirectionalLightShadowsNV // p8
	{
		CullMode = CW;
		// ColorWriteEnable = RED|BLUE|GREEN|ALPHA;
		ZEnable = TRUE;
		ZWriteEnable = FALSE;
		ZFunc = LESSEQUAL;
 		AlphaBlendEnable = TRUE;
 		SrcBlend = DESTCOLOR;
 		DestBlend = ZERO;
		VertexShader = compile vs_1_1 vsDirectionalLightShadows();
		PixelShader = compile PS2_EXT psDirectionalLightShadowsNV();
	}

	pass DynamicShadowmap // p9
	{
		CullMode = CW;
		// ColorWriteEnable = RED|BLUE|GREEN|ALPHA;
		ZEnable = FALSE;
		ZWriteEnable = FALSE;
		ZFunc = LESSEQUAL;
 		AlphaBlendEnable = TRUE;
 		SrcBlend = DESTCOLOR;
 		DestBlend = ZERO;
		VertexShader = compile vs_1_1 vsDynamicShadowmap();
		PixelShader = compile PS2_EXT psDynamicShadowmap();
	}

	pass {} // p10
	
	pass mulDiffuseDetailWithEnvMap // p11
	{
		CullMode = CW;
		ZEnable = TRUE;
		ZWriteEnable = FALSE;
		ZFunc = LESSEQUAL;
		AlphaBlendEnable = TRUE;
		SrcBlend = ONE;
		DestBlend = ONE;
		// ColsorWriteEnable = RED|BLUE|GREEN|ALPHA;
		FogEnable = false;
		VertexShader = compile vs_1_1 vsDx9_BM_MulDDetailWithEnvMap();
		PixelShader = compile PS2_EXT psDx9_BM_MulDDetailWithEnvMap();
	}
	
	pass mulDiffuseFast // p12
	{
		CullMode = CW;
		ZEnable = TRUE;
		ZWriteEnable = FALSE;
		ZFunc = LESSEQUAL;
// FogEnable = false;
		FogEnable = true;
		VertexShader = compile vs_2_0 vsDx9_BM_MulDFast();
		PixelShader = compile PS2_EXT psDx9_BM_MulDFast();
	}

	pass PPPointlight // p13
	{
		CullMode = CW;
		ZEnable = TRUE;
		ZWriteEnable = FALSE;
		ZFunc = LESSEQUAL;
		AlphaBlendEnable = TRUE;
		SrcBlend = ONE;
		DestBlend = ONE;
		VertexShader = compile vs_1_1 vsDx9_BM_PPPt();
		PixelShader = compile PS2_EXT psDx9_BM_PPPt();
	}
	
}























//
// Surrounding Terrain
//

struct STAPP2VSNormal
{
    float2 Pos0 : POSITION0;
    float2 TexCoord0 : TEXCOORD0;
    float4 Pos1 : POSITION1;
    float3 Normal : NORMAL;
};

struct STVS2PSNormal
{
    float4 Pos : POSITION;
    float2 Tex0 : TEXCOORD0;
    float2 Tex1 : TEXCOORD1;
    float2 Tex2 : TEXCOORD2;
    float2 Tex3 : TEXCOORD3;
    float Fog : Fog;
    float3 BlendValue : TEXCOORD5;
};

STVS2PSNormal vsSTNormal(STAPP2VSNormal indata)
{
	STVS2PSNormal outdata;
	
	outdata.Pos.xz = mul(float4(indata.Pos0.xy,0,1), vSTTransXZ).xy;
	outdata.Pos.yw = (indata.Pos1.xw * vScaleTransY.xy) + vScaleTransY.zw;
 	outdata.Tex0 = indata.TexCoord0;

// float3 tex = float3((indata.Pos0.y * vTexScale.z), -(((indata.Pos1.x) * vTexScale.y)) , (indata.Pos0.x * vTexScale.x));
	float3 tex = float3((outdata.Pos.z * vTexScale.z), -(((indata.Pos1.x) * vTexScale.y)) , (outdata.Pos.x * vTexScale.x));
	float2 xPlaneTexCord = tex.xy;
	float2 yPlaneTexCord = tex.zx;
	float2 zPlaneTexCord = tex.zy;

 	outdata.Pos = mul(outdata.Pos, mViewProj);
 	outdata.Fog = calcFog(outdata.Pos.w);

 	outdata.Tex1 = yPlaneTexCord * vFarTexTiling.z;
	outdata.Tex2.xy = xPlaneTexCord.xy * vFarTexTiling.xy;
	outdata.Tex2.y += vFarTexTiling.w;
	outdata.Tex3.xy = zPlaneTexCord.xy * vFarTexTiling.xy;
	outdata.Tex3.y += vFarTexTiling.w;

	outdata.BlendValue = saturate(abs(indata.Normal) - vBlendMod);
	float tot = dot(1, outdata.BlendValue);
	outdata.BlendValue /= tot;

	return outdata;
}

float4 psSTNormal(STVS2PSNormal indata) : COLOR
{
	float4 colormap = tex2D(sampler0Clamp, indata.Tex0);
	
	float4 lowComponent = tex2D(sampler1Clamp, indata.Tex0);
	float4 yplaneLowDetailmap = tex2D(sampler2Wrap, indata.Tex1);
	float4 xplaneLowDetailmap = tex2D(sampler2Wrap, indata.Tex2);
	float4 zplaneLowDetailmap = tex2D(sampler2Wrap, indata.Tex3);

	float4 lowDetailmap = lerp(0.5, yplaneLowDetailmap.z, lowComponent.x);
	float mounten = (xplaneLowDetailmap.y * indata.BlendValue.x) + 
			(yplaneLowDetailmap.x * indata.BlendValue.y) + 
			(zplaneLowDetailmap.y * indata.BlendValue.z);
	lowDetailmap *= lerp(0.5, mounten, lowComponent.z);

	float4 outColor = lowDetailmap * colormap * 4;

	return outColor;
}



struct STAPP2VSFast
{
    float2 Pos0 : POSITION0;
    float2 TexCoord0 : TEXCOORD0;
    float4 Pos1 : POSITION1;
};

struct STVS2PSFast
{
    float4 Pos : POSITION;
    float2 Tex0 : TEXCOORD0;
    float Fog : Fog;
};

STVS2PSFast vsSTFast(STAPP2VSFast indata)
{
	STVS2PSFast outdata;
	
	outdata.Pos.xz = mul(float4(indata.Pos0.xy,0,1), vSTTransXZ).xy;
	outdata.Pos.yw = (indata.Pos1.xw * vScaleTransY.xy) + vScaleTransY.zw;
 	outdata.Tex0 = indata.TexCoord0;
 	outdata.Pos = mul(outdata.Pos, mViewProj);
 	outdata.Fog = calcFog(outdata.Pos.w);

	return outdata;
}


float4 psSTFast(STVS2PSFast indata) : COLOR
{
	return tex2D(sampler0Clamp, indata.Tex0);
}



technique Dx9Style_SurroundingTerrain
{
	pass p0 // Normal
	{
// FillMode = WIREFRAME;
		CullMode = CW;
		ZEnable = TRUE;
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;
		AlphaBlendEnable = FALSE;
		FogEnable = true;
		VertexShader = compile vs_1_1 vsSTNormal();		
		PixelShader = compile ps_1_4 psSTNormal();
	}

	pass p1 // Fast
	{
		CullMode = CW;
		ZEnable = TRUE;
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;
		AlphaBlendEnable = FALSE;
		FogEnable = true;
		VertexShader = compile vs_1_1 vsSTFast();		
		PixelShader = compile ps_1_4 psSTFast();
	}
}
























/*
struct STAPP2VSFill
{
    float2 Pos0 : POSITION0;
    float2 TexCoord0 : TEXCOORD0;
    float4 Pos1 : POSITION1;
};

struct STVS2PSFill
{
    float4 Pos : POSITION;
    float2 Tex0 : TEXCOORD0;
    float4 Color : TEXCOORD1;
};

float4 psSTZFill(STVS2PSFill indata) : COLOR
{
	return indata.Color;
}

STVS2PSFill vsSTZFill(STAPP2VSFill indata)
{
	STVS2PSFill outdata;
	
	outdata.Pos.xz = mul(float4(indata.Pos0.xy,0,1), vSTTransXZ).xy;
	outdata.Pos.yw = (indata.Pos1.xw * vScaleTransY.xy) + vScaleTransY.zw;
 	outdata.Tex0 = indata.TexCoord0;
 	outdata.Pos = mul(outdata.Pos, mViewProj);
	

	return outdata;
}
*/



/*
struct APP2VS_BM_Dx9_Tunnel
{
    float4 Pos0 : POSITION0;
    float4 Pos1 : POSITION1;
    float4 MorphDelta : POSITION2;
    float2 TexCoord0 : TEXCOORD0;
    float3 Normal : NORMAL;

};


float4 vsDx9_StencilFillForTunnels(APP2VS_BM_Dx9_Tunnel indata) : POSITION
{
	float4 wPos;
	wPos.xz = (indata.Pos0.xy * vScaleTransXZ.xy) + vScaleTransXZ.zw;
	wPos.yw = (indata.Pos1.xw * vScaleTransY.xy) + vScaleTransY.zw;
// wPos.yw = indata.Pos1.xw;

	float cameraDist = length(wPos.xz - vCamerapos.xz) + vCamerapos.w;
	float interpVal = saturate(cameraDist * vNearFarMorphLimits.x - vNearFarMorphLimits.y);
	float yDelta = dot(vMorphDeltaSelector, indata.MorphDelta) * interpVal;
	wPos.y -= yDelta * vScaleTransY.x;

 	return mul(wPos, mViewProj);
}




	pass stencilFillForTunnels // p6
	{
		CullMode = CW;
		ColorWriteEnable = 0;
		ZEnable = FALSE;
		
		StencilEnable = TRUE;
		StencilFunc = ALWAYS;
		StencilRef = 0x80;
		StencilFail = KEEP;
		StencilZFail = KEEP;
		StencilPass = REPLACE;
		
		AlphaBlendEnable = FALSE;

		VertexShader = compile vs_1_1 vsDx9_StencilFillForTunnels();
		PixelShader = asm { 
			ps.1.1
			def c0, 0, 0, 0, 0
			mov r0, c0
		};
	}

*/
