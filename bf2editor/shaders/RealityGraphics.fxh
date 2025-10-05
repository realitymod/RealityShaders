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

	// From Forgotten Hope 2
	#define PR_HARDCODED_PARALLAX_BIAS 0.1

	// This hardcoded value fixes a bug with undergrowth's alphatesting
	// NOTE: We compensate for this change by multiplying the texture's alpha by ~2
	#if PR_ALPHA2MASK || defined(HASHED_ALPHA)
		#define PR_ALPHA_REF 1
		#define PR_ALPHA_REF_LEAF 1
	#else
		#define PR_ALPHA_REF 127
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
		#define PR_DEPTHBIAS_DEBUG 0.00001
		#define PR_DEPTHBIAS_DECAL 0.004
		#define PR_DEPTHBIAS_ROAD 0.0035
		#define PR_DEPTHBIAS_ROAD_COMPILED 0.003
		#define PR_DEPTHBIAS_SPLINE 0.0003

		// Used in shadow fetching
		#define PR_DEPTHBIAS_OBJECT 0.003

		#define PR_SLOPESCALE_OBJECT 0.0001
		#define PR_SLOPESCALE_SHADOWMAP -0.00001
		#define PR_SLOPESCALE_ROAD 0.0001
	#else
		#define PR_ZFUNC_NOEQUAL LESS
		#define PR_ZFUNC_WITHEQUAL LESSEQUAL

		#define PR_DEPTHBIAS_SHADOWMAP 0.005
		#define PR_DEPTHBIAS_DEBUG -0.00001
		#define PR_DEPTHBIAS_DECAL -0.004
		#define PR_DEPTHBIAS_ROAD -0.0035
		#define PR_DEPTHBIAS_ROAD_COMPILED -0.003
		#define PR_DEPTHBIAS_SPLINE -0.0003

		// Used in shadow fetching
		#define PR_DEPTHBIAS_OBJECT 0.003

		#define PR_SLOPESCALE_OBJECT 0.0001
		#define PR_SLOPESCALE_SHADOWMAP 0.00001
		#define PR_SLOPESCALE_ROAD -0.0001
	#endif

	// #define PR_PARALLAX
	// #define PR_LINEARLIGHTING
	// #define PR_TONEMAPPING

	float RGraphics_GetPi()
	{
		return acos(-1.0);
	}

	float RGraphics_ConvertSNORMtoUNORM_FLT1(float X)
	{
		return (X * 0.5) + 0.5;
	}

	float2 RGraphics_ConvertSNORMtoUNORM_FLT2(float2 X)
	{
		return (X * 0.5) + 0.5;
	}

	float3 RGraphics_ConvertSNORMtoUNORM_FLT3(float3 X)
	{
		return (X * 0.5) + 0.5;
	}

	float4 RGraphics_ConvertSNORMtoUNORM_FLT4(float4 X)
	{
		return (X * 0.5) + 0.5;
	}

	float RGraphics_ConvertUNORMtoSNORM_FLT1(float X)
	{
		return (X * 2.0) - 1.0;
	}

	float2 RGraphics_ConvertUNORMtoSNORM_FLT2(float2 X)
	{
		return (X * 2.0) - 1.0;
	}

	float3 RGraphics_ConvertUNORMtoSNORM_FLT3(float3 X)
	{
		return (X * 2.0) - 1.0;
	}

	float4 RGraphics_ConvertUNORMtoSNORM_FLT4(float4 X)
	{
		return (X * 2.0) - 1.0;
	}

	/*
		http://extremelearning.com.au/unreasonable-effectiveness-of-quasirandom-sequences/
		https://pbr-book.org/4ed/Sampling_Algorithms/Sampling_Multidimensional_Functions
	*/

	float RGraphics_GetPhi(int D)
	{
		float X = 2.0;

		for (int i = 0; i < 10; i++)
		{
			X = pow(1.0 + X, 1.0 / (D + 1.0));
		}

		return X;
	}

#endif
