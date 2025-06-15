#line 2 "RealityGraphics.fxh"

#include "shaders/SettingsDefines.fxh"

/*
	Shared shader code that we use for Project Reality: BF2
	Author: [R-DEV]papadanku @ 2025
*/

#if !defined(_HEADERS_)
	#define _HEADERS_
#endif

#if !defined(REALITY_DEFINES)
	#define REALITY_DEFINES

	// We are using BFEditor
	#define _EDITOR_

	// 16x is more or less the modern GPU standard
	#define PR_MAX_ANISOTROPY 16

	// This hardcoded value fixes a bug with undergrowth's alphatesting
	// NOTE: We compensate for this change by multiplying the texture's alpha by ~2
	#define PR_ALPHA_REF 127

	#if defined(HASHED_ALPHA)
		#define PR_ALPHA_REF_LEAF 0
	#else
		#define PR_ALPHA_REF_LEAF 127
	#endif

	/*
		D3DCMP_NEVER = 1,
		D3DCMP_LESS = 2,
		D3DCMP_EQUAL = 3,
		D3DCMP_LESSEQUAL = 4,
		D3DCMP_GREATER = 5,
		D3DCMP_NOTEQUAL = 6,
		D3DCMP_GREATEREQUAL = 7,
		D3DCMP_ALWAYS = 8,
	*/

	// Project Reality's default Z-testing
	// We expose it here so it is easy to port over to reversed depth buffering
	#define PR_IS_REVERSED_Z 0
	#if PR_IS_REVERSED_Z
		#define PR_ZFUNC_NOEQUAL GREATER
		#define PR_ZFUNC_WITHEQUAL GREATEREQUAL

		#define PR_DEPTHBIAS_SHADOWMAP -0.005
		#define PR_DEPTHBIAS_OBJECT 0.005
		#define PR_DEPTHBIAS_DEBUG 0.00001
		#define PR_DEPTHBIAS_ROAD 0.0001
		#define PR_DEPTHBIAS_SPLINE 0.0003

		#define PR_SLOPESCALE_SHADOWMAP -0.00001
		#define PR_SLOPESCALE_OBJECT 0.00001
		#define PR_SLOPESCALE_ROAD 0.00001
	#else
		#define PR_ZFUNC_NOEQUAL LESS
		#define PR_ZFUNC_WITHEQUAL LESSEQUAL

		#define PR_DEPTHBIAS_SHADOWMAP 0.005
		#define PR_DEPTHBIAS_OBJECT -0.005
		#define PR_DEPTHBIAS_DEBUG -0.00001
		#define PR_DEPTHBIAS_ROAD -0.0001
		#define PR_DEPTHBIAS_SPLINE -0.0003

		#define PR_SLOPESCALE_SHADOWMAP 0.00001
		#define PR_SLOPESCALE_OBJECT -0.00001
		#define PR_SLOPESCALE_ROAD -0.00001
	#endif

	// #define _USELINEARLIGHTING_
	// #define _USETONEMAP_

	float GetPi()
	{
		return acos(-1.0);
	}
#endif
