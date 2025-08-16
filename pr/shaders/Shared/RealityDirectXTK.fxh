#line 2 "RealityDirectXTK.fxh"

#include "shaders/RealityGraphics.fxh"
#if !defined(_HEADERS_)
	#include "../RealityGraphics.fxh"
#endif

/*
	https://github.com/microsoft/DirectXTK

	The MIT License (MIT)

	Copyright (c) 2012-2022 Microsoft Corp

	Permission is hereby granted, free of charge, to any person obtaining a copy of this
	software and associated documentation files (the "Software"), to deal in the Software
	without restriction, including without limitation the rights to use, copy, modify,
	merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
	permit persons to whom the Software is furnished to do so, subject to the following
	conditions:

	The above copyright notice and this permission notice shall be included in all copies
	or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
	INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
	PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
	HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
	CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE
	OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

#if !defined(_HEADERS_)
	#define _HEADERS_
#endif

#if !defined(DIRECTXTK)
	#define DIRECTXTK

	/*
		https://github.com/microsoft/DirectX-Specs
	*/

	// (Approximate) sRGB to linear
	float4 SRGBToLinearEst(float4 ColorMap)
	{
		#if defined(_USELINEARLIGHTING_)
			ColorMap.rgb = (ColorMap <= 0.04045) ? ColorMap / 12.92 : pow((ColorMap + 0.055) / 1.055, 2.4);
		#endif
		return ColorMap;
	}

	// Apply the (approximate) sRGB curve to linear values
	void LinearToSRGBEst(inout float4 Color)
	{
		#if defined(_USELINEARLIGHTING_)
			Color = (Color <= 0.0031308) ? 12.92 * Color : 1.055 * pow(Color, 1.0 / 2.4) - 0.055;
		#endif
	}

	// AMD resolve tonemap
	// https://gpuopen.com/learn/optimized-reversible-tonemapper-for-resolve/
	float3 AMDResolve(float3 x)
	{
		return x / (max(max(x.r, x.g), x.b) + 1.0);
	}

	float3 TonemapAMDResolve(float3 x)
	{
		float3 WhiteAMDResolve = 1.0 / AMDResolve(1.0);
		return AMDResolve(x) * WhiteAMDResolve;
	}

	// ACES Filmic tonemap operator
	// https://knarkowicz.wordpress.com/2016/01/06/aces-filmic-tone-mapping-curve/
	float3 ACESFilmic(float3 x)
	{
		float a = 2.51;
		float b = 0.03;
		float c = 2.43;
		float d = 0.59;
		float e = 0.14;
		return saturate((x*(a*x+b))/(x*(c*x+d)+e));
	}

	float3 ToneMapACESFilmic(float3 x)
	{
		float WhiteACES = 1.0 / ACESFilmic(1.0);
		return ACESFilmic(x) * WhiteACES;
	}

	// Apply the (approximate) sRGB curve to linear values
	// Tonemapping through seperation of Max and RGB Ratio
	// https://gpuopen.com/wp-content/uploads/2016/03/GdcVdrLottes.pdf
	void TonemapAndLinearToSRGBEst(inout float4 Color)
	{
		#if defined(_USETONEMAP_)
			Color.rgb = TonemapAMDResolve(Color.rgb);
		#endif

		#if defined(_USELINEARLIGHTING_)
			LinearToSRGBEst(Color);
		#endif
	}

	struct ColorPair
	{
		float Diffuse;
		float Specular;
	};

	/*
		Blinn-Phong light generator using the Half-Lambert technique
		---
		https://developer.valvesoftware.com/wiki/Half_Lambert
	*/

	float ToHalfNL(float DotNL)
	{
		DotNL = saturate((DotNL * 0.5) + 0.5);
		return DotNL * DotNL;
	}

	float GetHalfNL(float3 Normal, float3 LightDir)
	{
		float DotNL = dot(Normal, LightDir);
		return ToHalfNL(DotNL);
	}

	ColorPair ComputeLights
	(
		float3 Normal, float3 LightDir, float3 ViewDir,
		uniform float SpecPower = 32.0, uniform bool Normalized = false
	)
	{
		ColorPair Output = (ColorPair)0.0;

		float3 HalfVec = normalize(LightDir + ViewDir);
		float DotNH = saturate(dot(Normal, HalfVec));
		float DotNL = dot(Normal, LightDir);
		float DotNL_Clamped = saturate(DotNL);
		float N = (Normalized) ? (SpecPower + 8.0) / 8.0 : 1.0;

		Output.Diffuse = ToHalfNL(DotNL);
		Output.Specular = N * pow(abs(DotNH), SpecPower) * DotNL_Clamped;
		return Output;
	}

	float3 CompositeLights(float3 Color, float3 Ambient, float3 Diffuse, float3 Specular)
	{
		return (Color * (Ambient + Diffuse)) + Specular;
	}

	float ComputeFresnelFactor(float3 WorldNormal, float3 WorldViewDir, float Exponent)
	{
		float ViewAngle = 1.0 - saturate(dot(WorldNormal, WorldViewDir));
		return saturate(pow(abs(ViewAngle), Exponent));
	}

	/*
		Christian Schuler, "Normal Mapping without Precomputed Tangents", ShaderX 5, Chapter 2.6, pp. 131-140
		---
		See also follow-up blog post: http://www.thetenthplanet.de/archives/1180
	*/
	float3x3 CalculateTBN(float3 Pos, float2 Tex, float3 Normal)
	{
		// Get edge vectors of the pixel triangle
		float3 DP1 = ddx(Pos);
		float3 DP2 = ddy(Pos);
		float2 DT1 = ddx(Tex);
		float2 DT2 = ddy(Tex);

		// Solve the linear system
		float3 DP2perp = cross(DP2, Normal);
		float3 DP1perp = cross(Normal, DP1);
		float3 Tangent = (DP2perp * DT1.xxx) + (DP1perp * DT2.xxx);
		float3 BiTangent = (DP2perp * DT1.yyy) + (DP1perp * DT2.yyy);

		// Construct a scale-invariant frame
		float InvMax = rsqrt(max(dot(Tangent, Tangent), dot(BiTangent, BiTangent)));
		return float3x3(Tangent * InvMax, BiTangent * InvMax, Normal);
	}

	float3 PeturbNormal(float3 LocalNormal, float3 Pos, float3 Normal, float2 Tex)
	{
		float3x3 TBN = CalculateTBN(Pos, Tex, Normal);
		return normalize(mul(LocalNormal, TBN));
	}
#endif
