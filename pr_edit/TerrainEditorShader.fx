
#include "shaders/RealityGraphics.fxh"
#include "shaders/shared/RealityDirectXTK.fxh"
#include "shaders/shared/RealityDepth.fxh"
#include "shaders/shared/RealityPixel.fxh"
#include "shaders/CommonPixelLight.fxh"
#include "shaders/RaCommon.fxh"
#if !defined(_HEADERS_)
	#include "RealityGraphics.fxh"
	#include "shared/RealityDirectXTK.fxh"
	#include "shared/RealityDepth.fxh"
	#include "shared/RealityPixel.fxh"
	#include "CommonPixelLight.fxh"
	#include "RaCommon.fxh"
#endif

#define POINT_WATER_BIAS 2

float4x4 _ViewProj: matVIEWPROJ;
float4 _ScaleTransXZ : SCALETRANSXZ;
float4 _ScaleTransY : SCALETRANSY;
float4x4 _SETTransXZ : SETTRANSXZ;

float4 _SunColor : SUNCOLOR;
float4 _GIColor : GICOLOR;
float4 _PointColor: POINTCOLOR;
float _DetailFadeMod : DETAILFADEMOD;
float4 _TexOffset : TEXOFFSET;
float2 _SETBiFixTex : SETBIFIXTEX;
float2 _SETBiFixTex2 : SETBIFIXTEX2;
float2 _BiFixTex : BIFIXTEX;

float3 _BlendMod : BLENDMOD = float3(0.2, 0.5, 0.2);
float _WaterHeight : WaterHeight;
float4 _TerrainWaterColor : TerrainWaterColor;

// #define WaterLevel 22.5
// #define _PointColor float4(1.0, 0.5, 0.5, 1.0)

float4 _CameraPos : CAMERAPOS;
float3 _ComponentSelector : COMPONENTSELECTOR;
float2 _NearFarMorphLimits : NEARFARMORPHLIMITS;

float4 _TexScale : TEXSCALE;
float4 _NearTexTiling : NEARTEXTILING;
float4 _FarTexTiling : FARTEXTILING;

float _RefractionIndexRatio = 0.15;
static float R0 = pow(1.0 - _RefractionIndexRatio, 2.0) / pow(1.0 + _RefractionIndexRatio, 2.0);

texture Tex0 : TEXLAYER0;
texture Tex1 : TEXLAYER1;
texture Tex2 : TEXLAYER2;
texture Tex3 : TEXLAYER3;
texture Tex4 : TEXLAYER4;
texture Tex5 : TEXLAYER5;
texture Tex6 : TEXLAYER6;
texture Tex7 : TEXLAYER7;

#define CREATE_SAMPLER(SAMPLER_TYPE, SAMPLER_NAME, TEXTURE, FILTER, ADDRESS) \
	sampler SAMPLER_NAME = sampler_state \
	{ \
		Texture = (TEXTURE); \
		MinFilter = FILTER; \
		MagFilter = FILTER; \
		MipFilter = LINEAR; \
		AddressU = ADDRESS; \
		AddressV = ADDRESS; \
		MaxAnisotropy = PR_MAX_ANISOTROPY; \
	};

CREATE_SAMPLER(sampler, SampleTex0, Tex0, LINEAR, CLAMP)
CREATE_SAMPLER(sampler, SampleTex0Point, Tex0, POINT, CLAMP)
CREATE_SAMPLER(sampler, SampleTex1, Tex1, LINEAR, CLAMP)
CREATE_SAMPLER(sampler, SampleTex1Wrap, Tex1, LINEAR, WRAP)
CREATE_SAMPLER(sampler, SampleTex2, Tex2, LINEAR, CLAMP)
CREATE_SAMPLER(sampler, SampleTex3Wrap, Tex3, LINEAR, WRAP)
CREATE_SAMPLER(sampler, SampleTex4, Tex4, LINEAR, CLAMP)
CREATE_SAMPLER(sampler, SampleTex5, Tex5, LINEAR, CLAMP)
CREATE_SAMPLER(samplerCUBE, SampleTex7Cube, Tex7, LINEAR, WRAP)

struct APP2VS
{
	float2 Pos0 : POSITION0;
	float4 Pos1 : POSITION1;
	float2 Tex0 : TEXCOORD0;
};

struct APP2VS_EditorDetailTextured
{
	float4 Pos0 : POSITION0;
	float4 Pos1 : POSITION1;
	float2 Tex0 : TEXCOORD0;
	float3 Normal : NORMAL;
};

struct APP2VS_VS_EditorZFill
{
	float4 Pos0 : POSITION0;
	float4 Pos1 : POSITION1;
	float2 Tex0 : TEXCOORD0;
};

struct APP2VS_SET
{
	float2 Pos0 : POSITION0;
	float4 Pos1 : POSITION1;
	float2 Tex0 : TEXCOORD0;
	float3 Normal : NORMAL;
};

struct VS2PS
{
	float4 HPos : POSITION;
	float4 Pos : TEXCOORD0;
	float4 Tex0 : TEXCOORD1;
};

struct VS2PS_EditorDetail
{
	float4 HPos : POSITION;
	float4 Pos : TEXCOORD0;
	float4 Normal : TEXCOORD1;
	float4 Tex0 : TEXCOORD2; // .xy = Input.Pos0.xy; .zw = BiTex;
};

struct VS2PS_EditorGrid
{
	float4 HPos : POSITION;
	float4 Pos : TEXCOORD0;
	float4 Tex0 : TEXCOORD1;
};

struct VS2PS_EditorTopoGrid
{
	float4 HPos : POSITION;
	float4 Pos : TEXCOORD0;
	float3 Tex0 : TEXCOORD1; // .xy = Tex0; .z = Color;
	float4 Color : TEXCOORD2;
};

struct VS2PS_ZFill
{
	float4 HPos : POSITION;
	float4 Pos : TEXCOORD0;
};

struct VS2PS_EditorFoliage
{
	float4 HPos : POSITION;
	float4 Pos : TEXCOORD0;
	float2 Tex0 : TEXCOORD1;
};

struct VS2PS_LightmapGeneration
{
	float4 HPos : POSITION;
	float4 Pos : TEXCOORD0;
	float2 Tex0 : TEXCOORD1;
};

struct VS2PS_SET
{
	float4 HPos : POSITION;
	float4 Pos : TEXCOORD0;
	float3 Normal : TEXCOORD1;
	float3 Tex0 : TEXCOORD2; // .xy = Tex0; .z = Input.Pos1.x;
	float4 BiTex : TEXCOORD3; // .xy = BiTex1; .zw = BiTex2;
};

struct VS2PS_SET_ColorLightingOnly
{
	float4 HPos : POSITION;
	float4 Pos : TEXCOORD0;
	float4 BiTex : TEXCOORD3; // .xy = BiTex1; .zw = BiTex2;
};

struct PS2FB
{
	float4 Color : COLOR0;
	#if defined(LOG_DEPTH)
		float Depth : DEPTH;
	#endif
};

float4 GetWorldPos(float2 Pos0, float2 Pos1)
{
	float4 WorldPos = 0.0;
	WorldPos.xz = (Pos0 * _ScaleTransXZ.xy) + _ScaleTransXZ.zw;
	WorldPos.yw = (Pos1 * _ScaleTransY.xy) + _ScaleTransY.zw;
	return WorldPos;
}

/*
	Terrain: Detail Texture Mode
*/

struct FullDetail
{
	float2 NearYPlane;
	float2 NearXPlane;
	float2 NearZPlane;
	float2 FarYPlane;
	float2 FarXPlane;
	float2 FarZPlane;
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

	return Output;
}

VS2PS_EditorDetail VS_EditorDetailTextured(APP2VS_EditorDetailTextured Input)
{
	VS2PS_EditorDetail Output = (VS2PS_EditorDetail)0;
	float4 MorphedWorldPos = GetWorldPos(Input.Pos0.xy, Input.Pos1.xw);

	// tl: output HPos as early as possible.
	Output.HPos = mul(MorphedWorldPos, _ViewProj);
	Output.Pos = float4(MorphedWorldPos.xyz, Output.HPos.w);

	// Output depth
	#if defined(LOG_DEPTH)
		Output.Pos.w = Output.HPos.w + 1.0;
	#endif

	// tl: uncompress normal
	Output.Normal.xyz = (Input.Normal * 2.0) - 1.0;
	Output.Tex0.xy = Input.Pos0.xy;
	Output.Tex0.zw = ((Output.Tex0.xy * _TexScale.xz) * _BiFixTex.x) + _BiFixTex.y;

	return Output;
}

float4 GetTerrainLights(sampler SampleLightMap, float2 Tex, float4 Color)
{
	float4 LightMap = tex2D(SampleLightMap, Tex);
	return (Color * LightMap.r) + (_SunColor * (LightMap.g * 4.0)) + (_GIColor * (LightMap.b * 2.0));
}

float GetLerpValue(float3 WorldPos)
{
	float CameraDist = distance(WorldPos.xz, _CameraPos.xz) + _CameraPos.w;
	return saturate(CameraDist * _NearFarMorphLimits.x - _NearFarMorphLimits.y);
}

PS2FB GetEditorDetailTextured(VS2PS_EditorDetail Input, bool UsePlaneMapping, bool UseEnvMap, bool ColorOnly)
{
	PS2FB Output = (PS2FB)0;

	float4 WorldPos = Input.Pos;
	float3 WorldNormal = normalize(Input.Normal);
	float LerpValue = GetLerpValue(WorldPos.xyz);
	float ScaledLerpValue = saturate((LerpValue * 0.5) + 0.5);
	float WaterLerp = saturate((_WaterHeight - WorldPos.y) / 3.0);

	FullDetail FD = GetFullDetail(WorldPos.xyz, Input.Tex0.xy);

	float4 Component = tex2D(SampleTex2, Input.Tex0.zw);
	float3 BlendValue = saturate(abs(WorldNormal) - _BlendMod);
	BlendValue = saturate(BlendValue / dot(1.0, BlendValue));
	float ChartContribution = dot(Component.xyz, _ComponentSelector.xyz);

	float4 ColorMap = SRGBToLinearEst(tex2D(SampleTex0, Input.Tex0.zw));
	float4 LowComponent = tex2D(SampleTex5, Input.Tex0.zw);
	float4 YPlaneDetailmap = SRGBToLinearEst(tex2D(SampleTex1Wrap, FD.NearYPlane) * float4(2.0, 2.0, 2.0, 1.0));
	float4 XPlaneDetailmap = SRGBToLinearEst(GetProceduralTiles(SampleTex1Wrap, FD.NearXPlane) * 2.0);
	float4 ZPlaneDetailmap = SRGBToLinearEst(GetProceduralTiles(SampleTex1Wrap, FD.NearZPlane) * 2.0);
	float3 YPlaneLowDetailmap = SRGBToLinearEst(GetProceduralTiles(SampleTex3Wrap, FD.FarYPlane) * 2.0);
	float3 XPlaneLowDetailmap = SRGBToLinearEst(GetProceduralTiles(SampleTex3Wrap, FD.FarXPlane) * 2.0);
	float3 ZPlaneLowDetailmap = SRGBToLinearEst(GetProceduralTiles(SampleTex3Wrap, FD.FarZPlane) * 2.0);
	float EnvMapScale = YPlaneDetailmap.a;

	float Blue = 0.0;
	Blue += (XPlaneLowDetailmap.g * BlendValue.x);
	Blue += (YPlaneLowDetailmap.r * BlendValue.y);
	Blue += (ZPlaneLowDetailmap.g * BlendValue.z);

	float LowDetailMapBlend = LowComponent.r * ScaledLerpValue;
	float LowDetailMap = lerp(1.0, YPlaneLowDetailmap.b, LowDetailMapBlend);
	LowDetailMap *= lerp(1.0, Blue, LowComponent.b);

	float4 DetailMap = 1.0;
	if(UsePlaneMapping)
	{
		DetailMap += (XPlaneDetailmap * BlendValue.x);
		DetailMap += (YPlaneDetailmap * BlendValue.y);
		DetailMap += (ZPlaneDetailmap * BlendValue.z);
	}
	else
	{
		DetailMap = YPlaneDetailmap;
	}

	float4 Lights = 1.0;
	if (!ColorOnly)
	{
		Lights = GetTerrainLights(SampleTex4, Input.Tex0.zw, _PointColor);
	}

	float4 BothDetailMap = DetailMap * LowDetailMap;
	float4 OutputDetail = lerp(BothDetailMap, LowDetailMap, LerpValue);
	float4 OutputColor = ColorMap * OutputDetail * Lights;

	if (UseEnvMap)
	{
		float3 Reflection = reflect(normalize(WorldPos.xyz - _CameraPos.xyz), float3(0.0, 1.0, 0.0));
		float4 EnvMapColor = SRGBToLinearEst(texCUBE(SampleTex7Cube, Reflection));
		OutputColor = lerp(OutputColor, EnvMapColor, EnvMapScale * (1.0 - LerpValue));
	}

	Output.Color = OutputColor;
	Output.Color = lerp(Output.Color, _TerrainWaterColor, WaterLerp);
	ApplyFog(Output.Color.rgb, GetFogValue(WorldPos, _CameraPos));
	TonemapAndLinearToSRGBEst(Output.Color);

	Output.Color.a = 1.0;
	Output.Color *= ChartContribution;

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);
	#endif

	return Output;
}

#define CREATE_PS(FUNCTION_NAME, PLANE_MAPPING, ENVMAP, COLOR_ONLY) \
	PS2FB FUNCTION_NAME(VS2PS_EditorDetail Input) \
	{ \
		return GetEditorDetailTextured(Input, PLANE_MAPPING, ENVMAP, COLOR_ONLY); \
	}

CREATE_PS(PS_EditorDetailTextured, false, false, false)
CREATE_PS(PS_EditorDetailTextured_PlaneMapping, true, false, false)
CREATE_PS(PS_EditorDetailTextured_WithEnvMap, false, true, false)
CREATE_PS(PS_EditorDetailTexturedColorOnly, false, false, true)
CREATE_PS(PS_EditorDetailTextured_PlaneMappingColorOnly, true, false, true)
CREATE_PS(PS_EditorDetailTextured_WithEnvMapColorOnly, false, true, true)

#undef CREATE_PS

#define CREATE_PASS(PASS_NAME, VERTEX_SHADER, PIXEL_SHADER) \
	pass PASS_NAME \
	{ \
		CullMode = CW; \
		AlphaBlendEnable = TRUE; \
		SrcBlend = ONE; \
		DestBlend = ONE; \
		ZEnable = TRUE; \
		ZWriteEnable = TRUE; \
		ZFunc = LESSEQUAL; \
		ColorWriteEnable = RED|BLUE|GREEN|ALPHA; \
		VertexShader = compile vs_3_0 VERTEX_SHADER; \
		PixelShader = compile ps_3_0 PIXEL_SHADER; \
	}

technique EditorDetailTextured
{
	CREATE_PASS(topDownMapping, VS_EditorDetailTextured(), PS_EditorDetailTextured())
	CREATE_PASS(planeMapping, VS_EditorDetailTextured(), PS_EditorDetailTextured_PlaneMapping())
	CREATE_PASS(topDownMappingWithEnvMap, VS_EditorDetailTextured(), PS_EditorDetailTextured_WithEnvMap())

	CREATE_PASS(topDownMappingColorOnly, VS_EditorDetailTextured(), PS_EditorDetailTexturedColorOnly())
	CREATE_PASS(planeMappingColorOnly, VS_EditorDetailTextured(), PS_EditorDetailTextured_PlaneMappingColorOnly())
	CREATE_PASS(topDownMappingWithEnvMapColorOnly, VS_EditorDetailTextured(), PS_EditorDetailTextured_WithEnvMapColorOnly())
}

#undef CREATE_PASS

/*
	[DISPLAY SHADERS]
*/

VS2PS VS_Basic(APP2VS Input)
{
	VS2PS Output = (VS2PS)0;

	float4 WorldPos = float4(GetWorldPos(Input.Pos0.xy, Input.Pos1.xw).xyz, 1.0);
	Output.HPos = mul(WorldPos, _ViewProj);

	Output.Pos = float4(WorldPos.xyz, Output.HPos.w);

	// Output depth
	#if defined(LOG_DEPTH)
		Output.Pos.w = Output.HPos.w + 1.0;
	#endif

	Output.Tex0.xy = Input.Tex0;
	Output.Tex0.zw = (Input.Tex0 * _BiFixTex.x) + _BiFixTex.y;

	return Output;
}

PS2FB PS_Basic(VS2PS Input)
{
	PS2FB Output = (PS2FB)0;

	float4 WorldPos = Input.Pos;
	float4 Color = _PointColor * saturate(WorldPos.y - _WaterHeight - POINT_WATER_BIAS);

	float4 ColorMap = SRGBToLinearEst(tex2D(SampleTex0, Input.Tex0.xy));
	float4 Light = GetTerrainLights(SampleTex1, Input.Tex0.zw, Color * 2.0);
	float4 OutputColor = float4(ColorMap.rgb * Light.rgb, 1.0);

	Output.Color = OutputColor;
	ApplyFog(Output.Color.rgb, GetFogValue(WorldPos, _CameraPos));
	TonemapAndLinearToSRGBEst(Output.Color);

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);
	#endif

	return Output;
}

PS2FB PS_Basic_LightOnly(VS2PS Input)
{
	PS2FB Output = (PS2FB)0;

	float4 Light = GetTerrainLights(SampleTex1, Input.Tex0.zw, _PointColor * 2.0);
	Light.a = 1.0;

	Output.Color = Light * 0.5;
	ApplyFog(Output.Color.rgb, GetFogValue(Input.Pos, _CameraPos));

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);
	#endif

	return Output;
}

PS2FB PS_Basic_HemimapLightOnly(VS2PS Input)
{
	PS2FB Output = (PS2FB)0;

	float4 LightMap = tex2D(SampleTex1, Input.Tex0.zw);
	LightMap.a = 1.0;

	Output.Color = pow(LightMap.g * 2.0, 2.0);
	ApplyFog(Output.Color.rgb, GetFogValue(Input.Pos, _CameraPos));
	TonemapAndLinearToSRGBEst(Output.Color);

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);
	#endif

	return Output;
}

PS2FB PS_Basic_ColorOnly(VS2PS Input)
{
	PS2FB Output = (PS2FB)0;

	float4 ColorMap = SRGBToLinearEst(tex2D(SampleTex0, Input.Tex0.xy));
	ColorMap.a = 1.0;

	Output.Color = ColorMap;
	ApplyFog(Output.Color.rgb, GetFogValue(Input.Pos, _CameraPos));
	TonemapAndLinearToSRGBEst(Output.Color);

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);
	#endif

	return Output;
}

PS2FB PS_Basic_ColorOnlyPointFilter(VS2PS Input)
{
	PS2FB Output = (PS2FB)0;

	float4 ColorMap = SRGBToLinearEst(tex2D(SampleTex0Point, Input.Tex0.xy));
	ColorMap.a = 1.0;

	Output.Color = ColorMap;
	ApplyFog(Output.Color.rgb, GetFogValue(Input.Pos, _CameraPos));
	TonemapAndLinearToSRGBEst(Output.Color);

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);
	#endif

	return Output;
}

technique t0 <
	int DetailLevel = DLUltraHigh+DLVeryHigh;
	int Compatibility = CMPR300+CMPNV3X;
>
{
	pass p0
	{
		CullMode = CW;
		ZEnable = TRUE;
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;

		VertexShader = compile vs_3_0 VS_Basic();
		PixelShader = compile ps_3_0 PS_Basic();
	}

	pass p1 // LightOnly
	{
		AlphaTestEnable = FALSE;
		AlphaBlendEnable = FALSE;
		CullMode = CW;
		ZEnable = TRUE;
		ZWriteEnable = TRUE;

		VertexShader = compile vs_3_0 VS_Basic();
		PixelShader = compile ps_3_0 PS_Basic_LightOnly();
	}

	pass p2 // ColorOnly
	{
		CullMode = CW;
		ZEnable = TRUE;
		ZWriteEnable = TRUE;

		VertexShader = compile vs_3_0 VS_Basic();
		PixelShader = compile ps_3_0 PS_Basic_ColorOnly();
	}

	pass p3 // ColorOnly PointFilter
	{
		CullMode = CW;
		ZEnable = TRUE;
		ZWriteEnable = TRUE;

		VertexShader = compile vs_3_0 VS_Basic();
		PixelShader = compile ps_3_0 PS_Basic_ColorOnlyPointFilter();
	}

	pass p4 // Hemimap LightOnly
	{
		AlphaTestEnable = FALSE;
		AlphaBlendEnable = FALSE;
		CullMode = CW;
		ZEnable = TRUE;
		ZWriteEnable = TRUE;

		VertexShader = compile vs_3_0 VS_Basic();
		PixelShader = compile ps_3_0 PS_Basic_HemimapLightOnly();
	}
}

/*
	Terrain: Grid (With) Texture Mode
*/

VS2PS_EditorGrid VS_EditorGrid(APP2VS Input)
{
	VS2PS_EditorGrid Output = (VS2PS_EditorGrid)0;

	float4 WorldPos = GetWorldPos(Input.Pos0.xy, Input.Pos1.xw);
	Output.HPos = mul(WorldPos, _ViewProj);
	Output.Pos = float4(WorldPos.xyz, Output.HPos.w);

	// Output depth
	#if defined(LOG_DEPTH)
		Output.Pos.w = Output.HPos.w + 1.0;
	#endif

	Output.Tex0.xy = Input.Tex0;
	Output.Tex0.zw = Input.Tex0 * 128.0;

	return Output;
}

VS2PS_EditorTopoGrid VS_EditorTopoGrid(APP2VS Input)
{
	VS2PS_EditorTopoGrid Output = (VS2PS_EditorTopoGrid)0;

	float4 WorldPos = GetWorldPos(Input.Pos0.xy, Input.Pos1.xw);
	Output.HPos = mul(WorldPos, _ViewProj);
	Output.Pos = float4(WorldPos.xyz, Output.HPos.w);

	// Output depth
	#if defined(LOG_DEPTH)
		Output.Pos.w = Output.HPos.w + 1.0;
	#endif

	Output.Tex0.xy = Input.Tex0 * 128.0;
	Output.Tex0.z = Input.Pos1.x / 65535;

	return Output;
}

PS2FB PS_EditorGrid(VS2PS_EditorGrid Input)
{
	PS2FB Output = (PS2FB)0;

	float4 ColorMap = SRGBToLinearEst(tex2D(SampleTex0, Input.Tex0.xy));
	float4 Grid = SRGBToLinearEst(tex2Dbias(SampleTex1Wrap, float4(Input.Tex0.zw, 0.0, -1.5)));

	Output.Color = ColorMap * Grid;
	ApplyFog(Output.Color.rgb, GetFogValue(Input.Pos, _CameraPos));
	TonemapAndLinearToSRGBEst(Output.Color);

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);
	#endif

	return Output;
}

PS2FB PS_EditorTopoGrid(VS2PS_EditorTopoGrid Input)
{
	PS2FB Output = (PS2FB)0;

	float4 Grid = SRGBToLinearEst(tex2Dbias(SampleTex1Wrap, float4(Input.Tex0.xy, 0.0, -0.5)));
	float4 Color = Input.Tex0.z;

	Color += float4(0.0, 0.0, 0.3, 1.0);
	Color *= (Grid);

	Output.Color = Color;
	ApplyFog(Output.Color.rgb, GetFogValue(Input.Pos, _CameraPos));
	TonemapAndLinearToSRGBEst(Output.Color);

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);
	#endif

	return Output;
}

#define CREATE_TECHNIQUE(TECHNIQUE_NAME, VERTEX_SHADER, PIXEL_SHADER) \
	technique TECHNIQUE_NAME \
	{ \
		pass p0 \
		{ \
			CullMode = CW; \
			ZEnable = TRUE; \
			ZWriteEnable = TRUE; \
			ZFunc = LESSEQUAL; \
			VertexShader = compile vs_3_0 VERTEX_SHADER; \
			PixelShader = compile ps_3_0 PIXEL_SHADER; \
		} \
	}

CREATE_TECHNIQUE(EditorGrid, VS_EditorGrid(), PS_EditorGrid())
CREATE_TECHNIQUE(EditorTopoGrid, VS_EditorTopoGrid(), PS_EditorTopoGrid())

#undef CREATE_TECHNIQUE

/*
	[ZFILL SHADER]
*/

VS2PS_ZFill VS_EditorZFill(APP2VS_VS_EditorZFill Input)
{
	VS2PS_ZFill Output = (VS2PS_ZFill)0;

	float4 WorldPos = GetWorldPos(Input.Pos0.xy, Input.Pos1.xw);
	Output.HPos = mul(WorldPos, _ViewProj);
	Output.Pos = float4(WorldPos.xyz, Output.HPos.w);

	// Output depth
	#if defined(LOG_DEPTH)
		Output.Pos.w = Output.HPos.w + 1.0;
	#endif

 	return Output;
}

PS2FB PS_EditorZFill(VS2PS_ZFill Input)
{
	PS2FB Output = (PS2FB)0;

	Output.Color = 0.0;

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);
	#endif

	return Output;
}

technique EditorDetailBasePass
{
	pass p0
	{
		CullMode = CW;
		ColorWriteEnable = 0;
		ZEnable = TRUE;
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;

		VertexShader = compile vs_3_0 VS_EditorZFill();
		PixelShader = compile ps_3_0 PS_EditorZFill();
	}
}

/*
	Terrain: Overgrowth/Undergrowth/Materialmap Mode
*/

VS2PS_EditorFoliage VS_EditorGrowth(APP2VS Input)
{
	VS2PS_EditorFoliage Output = (VS2PS_EditorFoliage)0;

	float4 WorldPos = GetWorldPos(Input.Pos0.xy, Input.Pos1.xw);
	Output.HPos = mul(WorldPos, _ViewProj);
	Output.Pos = float4(WorldPos.xyz, Output.HPos.w);

	// Output depth
	#if defined(LOG_DEPTH)
		Output.Pos.w = Output.HPos.w + 1.0;
	#endif

	Output.Tex0 = Input.Tex0;

	return Output;
}

PS2FB PS_EditorGrowth(VS2PS_EditorFoliage Input)
{
	PS2FB Output = (PS2FB)0;

	Output.Color = SRGBToLinearEst(tex2D(SampleTex0Point, Input.Tex0));
	ApplyFog(Output.Color.rgb, GetFogValue(Input.Pos, _CameraPos));
	TonemapAndLinearToSRGBEst(Output.Color);

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);
	#endif

	return Output;
}

#define CREATE_TECHNIQUE(TECHNIQUE_NAME, VERTEX_SHADER, PIXEL_SHADER) \
	technique TECHNIQUE_NAME \
	{ \
		pass p0 \
		{ \
			CullMode = CW; \
			ZEnable = TRUE; \
			ZWriteEnable = TRUE; \
			ZFunc = LESSEQUAL; \
			ColorWriteEnable = RED|BLUE|GREEN|ALPHA; \
			VertexShader = compile vs_3_0 VERTEX_SHADER; \
			PixelShader = compile ps_3_0 PIXEL_SHADER; \
		} \
	}

CREATE_TECHNIQUE(EditorUndergrowth, VS_EditorGrowth(), PS_EditorGrowth())
CREATE_TECHNIQUE(EditorOvergrowth, VS_EditorGrowth(), PS_EditorGrowth())
CREATE_TECHNIQUE(EditorOvergrowthShadow, VS_EditorGrowth(), PS_EditorGrowth())
CREATE_TECHNIQUE(EditorMaterialmap, VS_EditorGrowth(), PS_EditorGrowth())

#undef CREATE_TECHNIQUE

/*
	Terrain: Hemimap Mode
*/

VS2PS_EditorFoliage VS_EditorHemimap(APP2VS Input)
{
	VS2PS_EditorFoliage Output = (VS2PS_EditorFoliage)0;

	float4 WorldPos = GetWorldPos(Input.Pos0.xy, Input.Pos1.xw);
	Output.HPos = mul(WorldPos, _ViewProj);
	Output.Pos = float4(WorldPos.xyz, Output.HPos.w);
	
	// Output depth
	#if defined(LOG_DEPTH)
		Output.Pos.w = Output.HPos.w + 1.0;
	#endif

	Output.Tex0 = (Input.Tex0 * _TexOffset.zz) + _TexOffset.xy;
	Output.Tex0.y = 1.0 - Output.Tex0.y;

	return Output;
}

PS2FB PS_EditorHemimap(VS2PS_EditorFoliage Input)
{
	PS2FB Output = (PS2FB)0;

	float4 HemiMap = SRGBToLinearEst(tex2D(SampleTex0, Input.Tex0));

	Output.Color = float4(HemiMap.rgb, 1.0);
	ApplyFog(Output.Color.rgb, GetFogValue(Input.Pos, _CameraPos));
	TonemapAndLinearToSRGBEst(Output.Color);

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);
	#endif

	return Output;
}

PS2FB PS_EditorHemimapAlpha(VS2PS_EditorFoliage Input)
{
	PS2FB Output = (PS2FB)0;

	float4 HemiMap = SRGBToLinearEst(tex2D(SampleTex0, Input.Tex0));

	Output.Color = float4(HemiMap.aaa, 1.0);
	ApplyFog(Output.Color.rgb, GetFogValue(Input.Pos, _CameraPos));
	TonemapAndLinearToSRGBEst(Output.Color);

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);
	#endif

	return Output;
}

technique EditorHemimap
{
	pass p0
	{
		CullMode = CW;
		ZEnable = TRUE;
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;
		ColorWriteEnable = RED|BLUE|GREEN|ALPHA;

		VertexShader = compile vs_3_0 VS_EditorHemimap();
		PixelShader = compile ps_3_0 PS_EditorHemimap();
	}

	pass p1
	{
		CullMode = CW;
		ZEnable = TRUE;
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;
		ColorWriteEnable = RED|BLUE|GREEN|ALPHA;

		VertexShader = compile vs_3_0 VS_EditorHemimap();
		PixelShader = compile ps_3_0 PS_EditorHemimapAlpha();
	}
}

/*
	[LIGHTMAPPING SHADERS]
*/

VS2PS_LightmapGeneration VS_LightmapGeneration_QP(APP2VS Input)
{
	VS2PS_LightmapGeneration Output = (VS2PS_LightmapGeneration)0;

	float4 WorldPos = GetWorldPos(Input.Pos0.xy, Input.Pos1.xw);
	Output.HPos = mul(WorldPos, _ViewProj);
	Output.Pos = float4(WorldPos.xyz, Output.HPos.w);

	// Output depth
	#if defined(LOG_DEPTH)
		Output.Pos.w = Output.HPos.w + 1.0;
	#endif

	Output.Tex0 = Input.Tex0;

	return Output;
}

VS2PS_LightmapGeneration VS_LightmapGeneration_SP(APP2VS Input)
{
	VS2PS_LightmapGeneration Output = (VS2PS_LightmapGeneration)0;

	float4 WorldPos = 0.0;
	WorldPos.xz = mul(float4(Input.Pos0.xy, 0.0, 1.0), _SETTransXZ).xy;
	WorldPos.yw = (Input.Pos1.xw * _ScaleTransY.xy) + _ScaleTransY.zw;
	Output.HPos = mul(WorldPos, _ViewProj);
	Output.Pos = WorldPos;

	// Output depth
	#if defined(LOG_DEPTH)
		Output.Pos.w = Output.HPos.w + 1.0;
	#endif

	Output.Tex0 = Input.Tex0;

	return Output;
}

PS2FB PS_LightmapGeneration(VS2PS Input)
{
	PS2FB Output = (PS2FB)0;

	// Output pure black.
	Output.Color = float4(0.0, 0.0, 0.0, 1.0);

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);
	#endif

	return Output;
}

technique lightmapGeneration <
	int DetailLevel = DLUltraHigh+DLVeryHigh;
	int Compatibility = CMPR300+CMPNV3X;
>
{
	pass p0 // QuadPatchs
	{
		AlphaBlendEnable = FALSE;
		AlphaTestEnable = FALSE;
		CullMode = CW;
		ZEnable = TRUE;
		ZWriteEnable = TRUE;

		VertexShader = compile vs_3_0 VS_LightmapGeneration_QP();
		PixelShader = compile ps_3_0 PS_LightmapGeneration();
	}

	pass p0 // SurroundingPatchs
	{
		AlphaBlendEnable = FALSE;
		AlphaTestEnable = FALSE;
		CullMode = CW;
		ZEnable = TRUE;
		ZWriteEnable = TRUE;

		VertexShader = compile vs_3_0 VS_LightmapGeneration_SP();
		PixelShader = compile ps_3_0 PS_LightmapGeneration();
	}
}

/*
	[SURROUNDING EDITOR TERRAIN (SET)]
*/

VS2PS_SET VS_SET(APP2VS_SET Input)
{
	VS2PS_SET Output = (VS2PS_SET)0;

	float4 WorldPos = 0.0;
	WorldPos.xz = mul(float4(Input.Pos0.xy, 0.0, 1.0), _SETTransXZ).xy;
	WorldPos.yw = (Input.Pos1.xw * _ScaleTransY.xy) + _ScaleTransY.zw;

	Output.HPos = mul(WorldPos, _ViewProj);
	Output.Pos = float4(WorldPos.xyz, Output.HPos.w);

	// Output depth
	#if defined(LOG_DEPTH)
		Output.Pos.w = Output.HPos.w + 1.0;
	#endif

	Output.Normal = Input.Normal;
	Output.Tex0 = float3(Input.Tex0, Input.Pos1.x);
	Output.BiTex.xy = (Input.Tex0.xy * _SETBiFixTex.x) + _SETBiFixTex.y;
	Output.BiTex.zw = (Input.Tex0.xy * _SETBiFixTex2.x) + _SETBiFixTex2.y;

	return Output;
}

VS2PS_SET_ColorLightingOnly VS_SET_ColorLightingOnly(APP2VS_SET Input)
{
	VS2PS_SET_ColorLightingOnly Output = (VS2PS_SET_ColorLightingOnly)0;

	float4 WorldPos = 0.0;
	WorldPos.xz = mul(float4(Input.Pos0.xy, 0.0, 1.0), _SETTransXZ).xy;
	WorldPos.yw = (Input.Pos1.xw * _ScaleTransY.xy) + _ScaleTransY.zw;

	Output.HPos = mul(WorldPos, _ViewProj);
	Output.Pos = float4(WorldPos.xyz, Output.HPos.w);

	// Output depth
	#if defined(LOG_DEPTH)
		Output.Pos.w = Output.HPos.w + 1.0;
	#endif

	Output.BiTex.xy = (Input.Tex0.xy * _SETBiFixTex.x) + _SETBiFixTex.y;
	Output.BiTex.zw = (Input.Tex0.xy * _SETBiFixTex2.x) + _SETBiFixTex2.y;

	return Output;
}

struct SurroundingTerrain
{
	float2 YPlane;
	float2 XPlane;
	float2 ZPlane;
};

SurroundingTerrain GetSurroundingTerrain(float3 WorldPos, float3 Tex)
{
	SurroundingTerrain Output = (SurroundingTerrain)0;

	float3 WorldTex = 0.0;
	WorldTex.x = WorldPos.x * _TexScale.x;
	WorldTex.y = -(Tex.z * _TexScale.y);
	WorldTex.z = WorldPos.z * _TexScale.z;

	float2 YPlaneTex = WorldTex.xz;
	float2 XPlaneTex = WorldTex.zy;
	float2 ZPlaneTex = WorldTex.xy;
	Output.YPlane = (YPlaneTex * _FarTexTiling.z);
	Output.XPlane = (XPlaneTex * _FarTexTiling.xy) + float2(0.0, _FarTexTiling.w);
	Output.ZPlane = (ZPlaneTex * _FarTexTiling.xy) + float2(0.0, _FarTexTiling.w);

	return Output;
}

PS2FB PS_SET(VS2PS_SET Input)
{
	PS2FB Output = (PS2FB)0;

	float4 WorldPos = Input.Pos;
	float3 WorldNormal = normalize(Input.Normal);
	float3 BlendValue = saturate(abs(WorldNormal) - _BlendMod);
	BlendValue = saturate(BlendValue / dot(1.0, BlendValue));
	float WaterLerp = saturate((_WaterHeight - WorldPos.y) / 3.0);

	SurroundingTerrain ST = GetSurroundingTerrain(WorldPos.xyz, Input.Tex0);
	float4 ColorMap = tex2D(SampleTex0, Input.BiTex.zw);
	float4 LowComponent = tex2D(SampleTex4, Input.BiTex.zw);
	float4 YPlaneLowDetailmap = SRGBToLinearEst(GetProceduralTiles(SampleTex3Wrap, ST.YPlane) * 2.0);
	float4 XPlaneLowDetailmap = SRGBToLinearEst(GetProceduralTiles(SampleTex3Wrap, ST.XPlane) * 2.0);
	float4 ZPlaneLowDetailmap = SRGBToLinearEst(GetProceduralTiles(SampleTex3Wrap, ST.ZPlane) * 2.0);

	float LowDetailMap = lerp(1.0, YPlaneLowDetailmap.z, saturate(dot(LowComponent.xy, 1.0)));
	float Blue = 0.0;
	Blue += (XPlaneLowDetailmap.y * BlendValue.x);
	Blue += (YPlaneLowDetailmap.x * BlendValue.y);
	Blue += (ZPlaneLowDetailmap.y * BlendValue.z);
	LowDetailMap *= lerp(1.0, Blue, LowComponent.z);

	float4 Lights = GetTerrainLights(SampleTex1, Input.BiTex.xy, _PointColor);
	float4 OutputColor = ColorMap * LowDetailMap * Lights;

	Output.Color = OutputColor;
	Output.Color = lerp(Output.Color, _TerrainWaterColor, WaterLerp);
	ApplyFog(Output.Color.rgb, GetFogValue(WorldPos, _CameraPos));
	TonemapAndLinearToSRGBEst(Output.Color);

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);
	#endif

	return Output;
}

PS2FB PS_SET_ColorLightingOnly(VS2PS_SET_ColorLightingOnly Input)
{
	PS2FB Output = (PS2FB)0;

	float4 WorldPos = Input.Pos;
	float WaterLerp = saturate((_WaterHeight - WorldPos.y) / 3.0);

	float4 ColorMap = SRGBToLinearEst(tex2D(SampleTex0, Input.BiTex.zw));
	float4 Lights = GetTerrainLights(SampleTex1, Input.BiTex.xy, _PointColor);

	float4 OutputColor = ColorMap * Lights;
	Output.Color = OutputColor;
	Output.Color = lerp(Output.Color, _TerrainWaterColor, WaterLerp);
	ApplyFog(Output.Color.rgb, GetFogValue(WorldPos, _CameraPos));
	TonemapAndLinearToSRGBEst(Output.Color);

	#if defined(LOG_DEPTH)
		Output.Depth = ApplyLogarithmicDepth(Input.Pos.w);
	#endif

	return Output;
}

technique SurroundingEditorTerrain <
	int DetailLevel = DLUltraHigh+DLVeryHigh;
	int Compatibility = CMPR300+CMPNV3X;
>
{
	pass p0 // Normal
	{
		CullMode = CW;
		ZEnable = TRUE;
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;
		AlphaBlendEnable = FALSE;

		VertexShader = compile vs_3_0 VS_SET();
		PixelShader = compile ps_3_0 PS_SET();
	}

	pass p1 // ColorLighting Only
	{
		CullMode = CW;
		ZEnable = TRUE;
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;
		AlphaBlendEnable = FALSE;

		VertexShader = compile vs_3_0 VS_SET_ColorLightingOnly();
		PixelShader = compile ps_3_0 PS_SET_ColorLightingOnly();
	}
}
