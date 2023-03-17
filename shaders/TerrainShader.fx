
/*
	Description: Renders lighting for ground terrain
*/

#include "shaders/RealityGraphics.fxh"
#include "shaders/RaCommon.fxh"

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

#define CREATE_DYNAMIC_SAMPLER(SAMPLER_TYPE, SAMPLER_NAME, TEXTURE, ADDRESS) \
	SAMPLER_TYPE SAMPLER_NAME = sampler_state \
	{ \
		Texture = (TEXTURE); \
		MinFilter = FILTER_TRN_DIFF_MIN; \
		MagFilter = FILTER_TRN_DIFF_MAG; \
		MipFilter = LINEAR; \
		MaxAnisotropy = 16; \
		AddressU = ADDRESS; \
		AddressV = ADDRESS; \
	}; \

uniform texture Tex0 : TEXLAYER0;
CREATE_DYNAMIC_SAMPLER(sampler, SampleTex0_Clamp, Tex0, CLAMP)

uniform texture Tex1 : TEXLAYER1;
CREATE_DYNAMIC_SAMPLER(sampler, SampleTex1_Clamp, Tex1, CLAMP)

uniform texture Tex2 : TEXLAYER2;
CREATE_DYNAMIC_SAMPLER(sampler, SampleTex2_Clamp, Tex2, CLAMP)

uniform texture Tex3 : TEXLAYER3;
CREATE_DYNAMIC_SAMPLER(sampler, SampleTex3_Wrap, Tex3, WRAP)

uniform texture Tex4 : TEXLAYER4;
CREATE_DYNAMIC_SAMPLER(sampler, SampleTex4_Wrap, Tex4, WRAP)

uniform texture Tex5 : TEXLAYER5;
CREATE_DYNAMIC_SAMPLER(sampler, SampleTex5_Clamp, Tex5, CLAMP)

uniform texture Tex6 : TEXLAYER6;
CREATE_DYNAMIC_SAMPLER(sampler, SampleTex6_Wrap, Tex6, WRAP)
CREATE_DYNAMIC_SAMPLER(samplerCUBE, SamplerTex6_Cube, Tex6, WRAP)

#define GET_RENDERSTATES_NV4X \
	StencilEnable = TRUE; \
	StencilFunc = NOTEQUAL; \
	StencilRef = 0xa; \
	StencilPass = KEEP; \
	StencilZFail = KEEP; \
	StencilFail = KEEP; \

#include "shaders/CommonPixelLight.fxh"

#include "shaders/TerrainShader_Shared.fx"
#if HIGHTERRAIN || MIDTERRAIN
	#include "shaders/TerrainShader_Hi.fx"
#else
	#include "shaders/TerrainShader_Low.fx"
#endif
