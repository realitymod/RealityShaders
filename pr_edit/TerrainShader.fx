#line 2 "TerrainShader.fx"

#if !NVIDIA
	#if HIGHTERRAIN
		#define PSVERSION 21
	#elif MIDTERRAIN 
		#define PSVERSION 20
	#else 
		#define PSVERSION 14
	#endif
#endif

#if NVIDIA
	#define SHADOWPSMODEL ps_1_4
	#define SHADOWVERSION 14
#else
	#define SHADOWPSMODEL PS2_EXT
	#define SHADOWVERSION 20
#endif

#include "shaders/datatypes.fx"
#include "shaders/raCommon.fx"

	
//
// -- Shared stuff
//

float4x4 mViewProj: matVIEWPROJ;
float4x4 mView: matVIEW;
float4 vScaleTransXZ : SCALETRANSXZ;
float4 vScaleTransY : SCALETRANSY;
float ScaleBaseUV : SCALEBASEUV;
float4 vShadowTexCoordScaleAndOffset : SHADOWTEXCOORDSCALEANDOFFSET;

float4 vMorphDeltaSelector : MORPHDELTASELECTOR;
float2 vNearFarMorphLimits : NEARFARMORPHLIMITS;

// float2 vNearFarLowDetailMapLimits : NEARFARLOWDETAILMAPLIMITS;

float4 vDebugColor : DEBUGCELLCOLOR;


float4 vCamerapos : CAMERAPOS;

float3 vComponentsel : COMPONENTSELECTOR;

float4 vSunColor : SUNCOLOR;
float4 vGIColor : GICOLOR;

float4 vSunDirection : SUNDIRECTION;
float4 vLightPos1 : LIGHTPOS1;
float4 vLightCol1 : LIGHTCOL1;
float LightAttSqrInv1 : LIGHTATTSQRINV1;
float4 vLightPos2 : LIGHTPOS2;
float4 vLightCol2 : LIGHTCOL2;
float LightAttSqrInv2 : LIGHTATTSQRINV2;
// float4 vLightPos3 : LIGHTPOS3;
// float4 vLightCol3 : LIGHTCOL3;

float4 vTexProjOffset : TEXPROJOFFSET;
float4 vTexProjScale : TEXPROJSCALE;

float4 vTexCordXSel : TEXCORDXSEL;
float4 vTexCordYSel : TEXCORDYSEL;
float4 vTexScale : TEXSCALE;
float4 vNearTexTiling : NEARTEXTILING;
float4 vFarTexTiling : FARTEXTILING;

float4 vYPlaneTexScaleAndFarTile : YPLANETEXSCALEANDFARTILE;

// float4 vlPlaneMapSel[4] = { float4(1,0,0,0), float4(0,1,0,0), float4(0,0,1,0), float4(0,0,1,0)}; // should only use 3, but have 4 for debug.
// float4 vPlaneMapSel : PLANEMAPSEL;

float3 vBlendMod : BLENDMOD = float3(0.2, 0.5, 0.2);

float waterHeight : WaterHeight;
float4 terrainWaterColor : TerrainWaterColor;

float4x4 mLightVP : LIGHTVIEWPROJ;
float4 vViewportMap : VIEWPORTMAP;

float4x4 vSTTransXZ : STTRANSXZ;
float4 vSTFarTexTiling : STFARTEXTILING;
float4 vSTTexScale : STTEXSCALE;
float4 vSTScaleTransY : STSCALETRANSY;

float2 vColorLightTex : COLORLIGHTTEX;
float2 vDetailTex : DETAILTEX;
float2 vSTColorLightTex : STCOLORLIGHTTEX;
float2 vSTLowDetailTex : STLOWDETAILTEX;

float3 vMorphDeltaAdder[3] : MORPHDELTAADDER;

texture texture0 : TEXLAYER0;
texture texture1 : TEXLAYER1;
texture texture2 : TEXLAYER2;
texture texture3 : TEXLAYER3;
texture texture4 : TEXLAYER4;
texture texture5 : TEXLAYER5;
texture texture6 : TEXLAYER6;

sampler sampler0Clamp = sampler_state { Texture = (texture0); AddressU = CLAMP; AddressV = CLAMP; MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = LINEAR; };
sampler sampler1Clamp = sampler_state { Texture = (texture1); AddressU = CLAMP; AddressV = CLAMP; MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = LINEAR; };
sampler sampler2Clamp = sampler_state { Texture = (texture2); AddressU = CLAMP; AddressV = CLAMP; MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = LINEAR; };
sampler sampler3Clamp = sampler_state { Texture = (texture3); AddressU = CLAMP; AddressV = CLAMP; MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = LINEAR; };
sampler sampler2PointClamp = sampler_state { Texture = (texture2); AddressU = CLAMP; AddressV = CLAMP; MinFilter = POINT; MagFilter = POINT; MipFilter = POINT; };
sampler sampler2Point = sampler_state { Texture = (texture2); MinFilter = POINT; MagFilter = POINT; };
sampler sampler4Clamp = sampler_state { Texture = (texture4); AddressU = CLAMP; AddressV = CLAMP; MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = LINEAR; };
sampler sampler5Clamp = sampler_state { Texture = (texture5); AddressU = CLAMP; AddressV = CLAMP; MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = LINEAR; };
sampler sampler0Wrap = sampler_state { Texture = (texture0); AddressU = WRAP; AddressV = WRAP; MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = LINEAR; };
sampler sampler1Wrap = sampler_state { Texture = (texture1); AddressU = WRAP; AddressV = WRAP; MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = LINEAR; };
sampler sampler2Wrap = sampler_state { Texture = (texture2); AddressU = WRAP; AddressV = WRAP; MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = LINEAR; };
sampler sampler3Wrap = sampler_state { Texture = (texture3); AddressU = WRAP; AddressV = WRAP; MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = LINEAR; };
sampler sampler4Wrap = sampler_state { Texture = (texture4); AddressU = WRAP; AddressV = WRAP; MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = LINEAR; };
sampler sampler4Wrap2 = sampler_state { Texture = (texture4); AddressU = WRAP; AddressV = WRAP; MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = LINEAR; };
sampler sampler4Wrap3 = sampler_state { Texture = (texture4); AddressU = WRAP; AddressV = WRAP; MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = LINEAR; };
sampler sampler5Wrap = sampler_state { Texture = (texture5); AddressU = WRAP; AddressV = WRAP; MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = LINEAR; };
sampler sampler6Wrap = sampler_state { Texture = (texture6); AddressU = WRAP; AddressV = WRAP; MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = LINEAR; };
sampler sampler3 = sampler_state { Texture = (texture3); };
sampler sampler4 = sampler_state { Texture = (texture4); };
sampler sampler0ClampPoint = sampler_state { Texture = (texture0); AddressU = CLAMP; AddressV = CLAMP; MinFilter = POINT; MagFilter = POINT; };
sampler sampler1ClampPoint = sampler_state { Texture = (texture1); AddressU = CLAMP; AddressV = CLAMP; MinFilter = POINT; MagFilter = POINT; };
sampler sampler2ClampPoint = sampler_state { Texture = (texture2); AddressU = CLAMP; AddressV = CLAMP; MinFilter = POINT; MagFilter = POINT; };
sampler sampler3ClampPoint = sampler_state { Texture = (texture3); AddressU = CLAMP; AddressV = CLAMP; MinFilter = POINT; MagFilter = POINT; };
samplerCUBE sampler6Cube = sampler_state { Texture = (texture6); AddressU = WRAP; AddressV = WRAP; MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = LINEAR; };


#include "Shaders/commonVertexLight.fx"
// #include "Shaders/TerrainShader_nv3x.fx"
#include "Shaders/TerrainShader_Shared.fx"
#if HIGHTERRAIN || MIDTERRAIN
	#include "Shaders/TerrainShader_Hi.fx"
#endif 
	#include "Shaders/TerrainShader_Low.fx"

//#include "Shaders/TerrainShader_r3x0.fx"
//#include "Shaders/TerrainShader_debug.fx"

