#line 2 "TerrainShader.fx"

/*
	Description: Renders lighting for ground terrain
*/

#include "shaders/RealityGraphics.fx"

#include "shaders/RaCommon.fx"

/*
	[Uniform data from app]
*/

uniform float4x4 _ViewProj: matVIEWPROJ;
uniform float4x4 _View: matVIEW;
uniform float4 _ScaleTransXZ : SCALETRANSXZ;
uniform float4 _ScaleTransY : SCALETRANSY;
uniform float _ScaleBaseUV : SCALEBASEUV;
uniform float4 _ShadowTexCoordScaleAndOffset : SHADOWTEXCOORDSCALEANDOFFSET;

uniform float4 _MorphDeltaSelector : MORPHDELTASELECTOR;
uniform float2 _NearFarMorphLimits : NEARFARMORPHLIMITS;
// uniform float2 _NearFarLowDetailMapLimits : NEARFARLOWDETAILMAPLIMITS;

uniform float4 _CameraPos : CAMERAPOS;
uniform float3 _ComponentSelector : COMPONENTSELECTOR;

uniform float4 _DebugColor : DEBUGCELLCOLOR;
uniform float4 _SunColor : SUNCOLOR;
uniform float4 _GIColor : GICOLOR;

uniform float4 _SunDirection : SUNDIRECTION;
uniform float4 _LightPos1 : LIGHTPOS1;
uniform float4 _LightPos2 : LIGHTPOS2;
// uniform float4 _LightPos3 : LIGHTPOS3;
uniform float4 _LightCol1 : LIGHTCOL1;
uniform float4 _LightCol2 : LIGHTCOL2;
// uniform float4 _LightCol3 : LIGHTCOL3;
uniform float _LightAttSqrInv1 : LIGHTATTSQRINV1;
uniform float _LightAttSqrInv2 : LIGHTATTSQRINV2;

uniform float4 _TexProjOffset : TEXPROJOFFSET;
uniform float4 _TexProjScale : TEXPROJSCALE;
uniform float4 _TexCordXSel : TEXCORDXSEL;
uniform float4 _TexCordYSel : TEXCORDYSEL;
uniform float4 _TexScale : TEXSCALE;
uniform float4 _NearTexTiling : NEARTEXTILING;
uniform float4 _FarTexTiling : FARTEXTILING;
uniform float4 _YPlaneTexScaleAndFarTile : YPLANETEXSCALEANDFARTILE;

/*
	uniform float4 _ListPlaneMapSel[4] =
	{
		float4(1.0, 0.0, 0.0, 0.0),
		float4(0.0, 1.0, 0.0, 0.0),
		float4(0.0, 0.0, 1.0, 0.0),
		float4(0.0, 0.0, 1.0, 0.0)
	}; // should only use 3, but have 4 for debug.

	// uniform float4 _PlaneMapSel : PLANEMAPSEL;
*/

uniform float3 _BlendMod : BLENDMOD = float3(0.2, 0.5, 0.2);

uniform float _WaterHeight : WaterHeight;
uniform float4 _TerrainWaterColor : TerrainWaterColor;

uniform float4x4 _LightViewProj : LIGHTVIEWPROJ;
uniform float4x4 _LightViewProjOrtho : LIGHTVIEWPROJORTHO;
uniform float4 _ViewportMap : VIEWPORTMAP;

// Attributes for surrounding terrain (ST)
uniform float4x4 _STTransXZ : STTRANSXZ;
uniform float4 _STFarTexTiling : STFARTEXTILING;
uniform float4 _STTexScale : STTEXSCALE;
uniform float4 _STScaleTransY : STSCALETRANSY;
uniform float2 _STColorLightTex : STCOLORLIGHTTEX;
uniform float2 _STLowDetailTex : STLOWDETAILTEX;

uniform float2 _ColorLightTex : COLORLIGHTTEX;
uniform float2 _DetailTex : DETAILTEX;

uniform float3 _MorphDeltaAdder[3] : MORPHDELTAADDER;

/*
	[Textures and samplers]
*/

uniform texture Texture_0 : TEXLAYER0;
uniform texture Texture_1 : TEXLAYER1;
uniform texture Texture_2 : TEXLAYER2;
uniform texture Texture_3 : TEXLAYER3;
uniform texture Texture_4 : TEXLAYER4;
uniform texture Texture_5 : TEXLAYER5;
uniform texture Texture_6 : TEXLAYER6;

#define CREATE_SAMPLER(SAMPLER_TYPE, NAME, TEXTURE, ADDRESS) \
	SAMPLER_TYPE NAME = sampler_state \
	{ \
		Texture = (TEXTURE); \
		MinFilter = LINEAR; \
		MagFilter = LINEAR; \
		MipFilter = LINEAR; \
		AddressU = ADDRESS; \
		AddressV = ADDRESS; \
	}; \

CREATE_SAMPLER(sampler, Sampler_0_Clamp, Texture_0, CLAMP)
CREATE_SAMPLER(sampler, Sampler_1_Clamp, Texture_1, CLAMP)
CREATE_SAMPLER(sampler, Sampler_2_Clamp, Texture_2, CLAMP)
CREATE_SAMPLER(sampler, Sampler_5_Clamp, Texture_5, CLAMP)

CREATE_SAMPLER(sampler, Sampler_3_Wrap, Texture_3, WRAP)
CREATE_SAMPLER(sampler, Sampler_4_Wrap, Texture_4, WRAP)
CREATE_SAMPLER(sampler, Sampler_6_Wrap, Texture_6, WRAP)

CREATE_SAMPLER(samplerCUBE, Sampler_6_Cube, Texture_6, WRAP)

#include "shaders/CommonVertexLight.fx"
#include "shaders/TerrainShader_Shared.fx"
#if HIGHTERRAIN || MIDTERRAIN
	#include "shaders/TerrainShader_Hi.fx"
#else
	#include "shaders/TerrainShader_Low.fx"
#endif
