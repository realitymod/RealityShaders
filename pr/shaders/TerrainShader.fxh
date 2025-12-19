#line 2 "TerrainShader.fxh"

/*
	Include header files
*/

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

#if !defined(_HEADERS_)
	#define _HEADERS_
#endif

#if !defined(TERRAINSHADER_FXH)
	#define TERRAINSHADER_FXH

	/*
		Description: Renders lighting for ground terrain
	*/

	/*
		[Uniform data from app]
	*/

	float4x4 _ViewProj: matVIEWPROJ;
	float4x4 _View: matVIEW;
	float4 _ScaleTransXZ : SCALETRANSXZ;
	float4 _ScaleTransY : SCALETRANSY;
	float _ScaleBaseUV : SCALEBASEUV;
	float4 _ShadowTexCoordScaleAndOffset : SHADOWTEXCOORDSCALEANDOFFSET;

	float4 _MorphDeltaSelector : MORPHDELTASELECTOR;
	float2 _NearFarMorphLimits : NEARFARMORPHLIMITS;
	// float2 _NearFarLowDetailMapLimits : NEARFARLOWDETAILMAPLIMITS;

	float4 _CameraPos : CAMERAPOS;
	float3 _ComponentSelector : COMPONENTSELECTOR;

	float4 _DebugColor : DEBUGCELLCOLOR;
	float4 _SunColor : SUNCOLOR;
	float4 _GIColor : GICOLOR;
	float4 _PointColor : POINTCOLOR = float4(1.0, 1.0, 1.0, 1.0);

	float4 _SunDirection : SUNDIRECTION;
	float4 _LightPos1 : LIGHTPOS1;
	float4 _LightPos2 : LIGHTPOS2;
	// float4 _LightPos3 : LIGHTPOS3;
	float4 _LightCol1 : LIGHTCOL1;
	float4 _LightCol2 : LIGHTCOL2;
	// float4 _LightCol3 : LIGHTCOL3;
	float _LightAttSqrInv1 : LIGHTATTSQRINV1;
	float _LightAttSqrInv2 : LIGHTATTSQRINV2;

	float4 _TexProjOffset : TEXPROJOFFSET;
	float4 _TexProjScale : TEXPROJSCALE;
	float4 _TexCordXSel : TEXCORDXSEL;
	float4 _TexCordYSel : TEXCORDYSEL;
	float4 _TexScale : TEXSCALE;
	float4 _NearTexTiling : NEARTEXTILING;
	float4 _FarTexTiling : FARTEXTILING;
	float4 _YPlaneTexScaleAndFarTile : YPLANETEXSCALEANDFARTILE;

	/*
		uniform float4 _ListPlaneMapSel[4] =
		{
			float4(1.0, 0.0, 0.0, 0.0),
			float4(0.0, 1.0, 0.0, 0.0),
			float4(0.0, 0.0, 1.0, 0.0),
			float4(0.0, 0.0, 1.0, 0.0)
		}; // should only use 3, but have 4 for debug.

		// float4 _PlaneMapSel : PLANEMAPSEL;
	*/

	float3 _BlendMod : BLENDMOD = float3(0.0, 0.0, 0.0);

	float _WaterHeight : WaterHeight;
	float4 _TerrainWaterColor : TerrainWaterColor;

	float4x4 _LightViewProj : LIGHTVIEWPROJ;
	float4x4 _LightViewProjOrtho : LIGHTVIEWPROJORTHO;
	float4 _ViewportMap : VIEWPORTMAP;

	// Attributes for surrounding terrain (ST)
	float4x4 _STTransXZ : STTRANSXZ;
	float4 _STFarTexTiling : STFARTEXTILING;
	float4 _STTexScale : STTEXSCALE;
	float4 _STScaleTransY : STSCALETRANSY;
	float2 _STColorLightTex : STCOLORLIGHTTEX;
	float2 _STLowDetailTex : STLOWDETAILTEX;

	float2 _ColorLightTex : COLORLIGHTTEX;
	float2 _DetailTex : DETAILTEX;

	float3 _MorphDeltaAdder[3] : MORPHDELTAADDER;

	/*
		[Textures and samplers]
	*/

	#define CREATE_SAMPLER(SAMPLER_TYPE, SAMPLER_NAME, TEXTURE, ADDRESS) \
		SAMPLER_TYPE SAMPLER_NAME = sampler_state \
		{ \
			Texture = (TEXTURE); \
			MinFilter = FILTER_TRN_DIFF_MIN; \
			MagFilter = FILTER_TRN_DIFF_MAG; \
			MipFilter = LINEAR; \
			MaxAnisotropy = PR_MAX_ANISOTROPY; \
			AddressU = ADDRESS; \
			AddressV = ADDRESS; \
		}; \

	texture Tex0 : TEXLAYER0;
	CREATE_SAMPLER(sampler, SampleTex0_Clamp, Tex0, CLAMP)

	texture Tex1 : TEXLAYER1;
	CREATE_SAMPLER(sampler, SampleTex1_Clamp, Tex1, CLAMP)

	texture Tex2 : TEXLAYER2;
	CREATE_SAMPLER(sampler, SampleTex2_Clamp, Tex2, CLAMP)

	texture Tex3 : TEXLAYER3;
	CREATE_SAMPLER(sampler, SampleTex3_Wrap, Tex3, WRAP)

	texture Tex4 : TEXLAYER4;
	CREATE_SAMPLER(sampler, SampleTex4_Wrap, Tex4, WRAP)

	texture Tex5 : TEXLAYER5;
	CREATE_SAMPLER(sampler, SampleTex5_Clamp, Tex5, CLAMP)

	texture Tex6 : TEXLAYER6;
	CREATE_SAMPLER(sampler, SampleTex6_Wrap, Tex6, WRAP)
	CREATE_SAMPLER(samplerCUBE, SamplerTex6_Cube, Tex6, WRAP)

	#define GET_RENDERSTATES_NV4X \
		StencilEnable = TRUE; \
		StencilFunc = NOTEQUAL; \
		StencilRef = 0xa; \
		StencilPass = KEEP; \
		StencilZFail = KEEP; \
		StencilFail = KEEP; \

	struct APP2VS_Shared
	{
		float4 Pos0 : POSITION0;
		float4 Pos1 : POSITION1;
		float4 MorphDelta : POSITION2;
		float3 Normal : NORMAL;
	};

	struct RGraphics_PS2FB
	{
		float4 Color : COLOR;
		#if defined(LOG_DEPTH)
			float Depth : DEPTH;
		#endif
	};

	float GetCameraDistance(float3 WorldPos, float3 CameraPos)
	{
		// tl: This is now based on squared values (besides camPos)
		// tl: This assumes that input WorldPos.w == 1 to work correctly! (it always is)
		// tl: This all works out because camera height is set to height+1 so
		//     CameraVec becomes (cx, cheight+1, cz) - (vx, 1, vz)
		float3 CameraVec = CameraPos - WorldPos;
		return dot(CameraVec, CameraVec);
	}

	float4 MorphPosition(float4 WorldPos, float4 MorphDelta, float MorphDeltaAdderSelector)
	{
		// tl: YScale is now pre-multiplied into morphselector
		float CameraDistance = GetCameraDistance(WorldPos.xwz, _CameraPos.xwz);
		float LerpValue = saturate(CameraDistance * _NearFarMorphLimits.x - _NearFarMorphLimits.y);
		float YDelta = dot(_MorphDeltaSelector, MorphDelta) * LerpValue;
		YDelta += dot(_MorphDeltaAdder[MorphDeltaAdderSelector * 256], MorphDelta.xyz);
		WorldPos.y = WorldPos.y - YDelta;
		return WorldPos;
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

	float4 GetMorphedWorldPos(APP2VS_Shared Input)
	{
		float4 WorldPos = GetWorldPos(Input.Pos0, Input.Pos1);
		return MorphPosition(WorldPos, Input.MorphDelta, Input.Pos0.z);
	}

#endif
