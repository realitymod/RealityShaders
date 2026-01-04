#line 2 "RealityDepth.fxh"

/*
    This file contains depth-based functions used in various shaders for depth calculations and comparisons.
*/

#include "shaders/RealityGraphics.fxh"
#if !defined(_HEADERS_)
	#include "../RealityGraphics.fxh"
#endif

#if !defined(_HEADERS_)
	#define _HEADERS_
#endif

#if !defined(REALITY_DEPTH)
	#define REALITY_DEPTH

	static float FarPlane = 10000.0;
	static float FCoef = 1.0 / log2(FarPlane + 1.0);

	/*
		Gets slope-scaled shadow bias from depth
		---
		Source: https://download.nvidia.com/developer/presentations/2004/GPU_Jackpot/Shadow_Mapping.pdf
	*/
	float RDepth_GetSlopedBasedBias(float Depth, uniform float SlopeScale = PR_SLOPESCALE_OBJECT, uniform float Bias = PR_DEPTHBIAS_OBJECT)
	{
		float M = fwidth(Depth);
		return Bias + (M * SlopeScale);
	}

	/*
		Converts linear depth to logarithmic depth in the pixel shader
		---
		Source: https://outerra.blogspot.com/2013/07/logarithmic-depth-buffer-optimizations.html
	*/
	float RDepth_ApplyLogarithmicDepth(float Depth)
	{
		return saturate(log2(Depth) * FCoef);
	}

	/*
		Transforms the vertex position's depth from World/Object space to light space
		---
		NOTE: Make sure Pos and matrices are in same space!
	*/
	float4 RDepth_GetMeshShadowProjection(float4 Pos, float4x4 LightTrapezMat, float4x4 LightMat, out float2 Depth)
	{
		float4 LightCoords = mul(Pos, LightMat);
		float4 ShadowCoords = mul(Pos, LightTrapezMat);

		// Output depth for map rendering
		Depth = LightCoords.zw;

		// (Lz / Lw) * Sw -> Lz / Lw;
		ShadowCoords.z = (Depth.z / Depth.w) * ShadowCoords.w;

		return ShadowCoords;
	}

	/*
		Compares the depth between the shadowmap's depth (ShadowSampler) and the vertex position's transformed, light-space depth (ShadowCoords.z)
	*/
	float RDepth_GetShadowFactor(sampler ShadowSampler, float4 ShadowCoords)
	{
		float2 Texel = fwidth(ShadowCoords.xy);
		float SlopedBias = RDepth_GetSlopedBasedBias(ShadowCoords.z);

		float4 Samples = 0.0;
		Samples.x = tex2Dproj(ShadowSampler, ShadowCoords + float4(Texel.x, Texel.y, 0.0, 0.0)).r;
		Samples.y = tex2Dproj(ShadowSampler, ShadowCoords + float4(-Texel.x, -Texel.y, 0.0, 0.0)).r;
		Samples.z = tex2Dproj(ShadowSampler, ShadowCoords + float4(-Texel.x, Texel.y, 0.0, 0.0)).r;
		Samples.w = tex2Dproj(ShadowSampler, ShadowCoords + float4(Texel.x, -Texel.y, 0.0, 0.0)).r;

		float4 CMPBits = float4(saturate(ShadowCoords.z - SlopedBias) <= Samples);
		return dot(CMPBits, 0.25);
	}

	void RDepth_ReverseDepth(inout float4 HPos)
	{
		// HPos.z = (1.0 - (HPos.z / HPos.w)) * HPos.w;
	}

#endif
