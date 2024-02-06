
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

// Functions from DirectXTK
#if !defined(DIRECTXTK)
	#define DIRECTXTK
	#undef _HEADERS_
	#define _HEADERS_

	static const float PI = acos(-1.0);

	// (Approximate) sRGB to linear
	float4 SRGBToLinearEst(float4 ColorMap)
	{
		float4 Color = 0.0;
		Color.rgb = pow(abs(ColorMap.rgb), 2.2);
		Color.a = ColorMap.a;
		return Color;
	}

	// Apply the (approximate) sRGB curve to linear values
	void LinearToSRGBEst(inout float4 Color)
	{
		Color.rgb = pow(abs(Color.rgb), 1.0 / 2.2);
	}

	// https://gpuopen.com/learn/optimized-reversible-tonemapper-for-resolve/
	float3 Tonemap(float3 C)
	{
		return C / (max(max(C.r, C.g), C.b) + 1.0);
	}

	// ACES Filmic tonemap operator
	// https://knarkowicz.wordpress.com/2016/01/06/aces-filmic-tone-mapping-curve/
	float3 ToneMapACESFilmic(float3 x)
	{
		float a = 2.51f;
		float b = 0.03f;
		float c = 2.43f;
		float d = 0.59f;
		float e = 0.14f;
		return saturate((x*(a*x+b))/(x*(c*x+d)+e));
	}

	// Apply the (approximate) sRGB curve to linear values
	void TonemapAndLinearToSRGBEst(inout float4 Color)
	{
		Color.rgb = ToneMapACESFilmic(Color.rgb);
		Color.rgb = LinearToSRGBEst(Color);
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
		DotNL = (DotNL * 0.5) + 0.5;
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
		float ViewAngle = dot(WorldNormal, WorldViewDir);
		return saturate(1.0 - pow(abs(ViewAngle), Exponent));
	}

	/*
		Christian Schuler, "Normal Mapping without Precomputed Tangents", ShaderX 5, Chapter 2.6, pp. 131-140
		---
		See also follow-up blog post: http://www.thetenthplanet.de/archives/1180
	*/
	float3x3 CalculateTBN(float3 Pos, float3 Normal, float2 Tex)
	{
		float3 DPos1 = ddx(Pos);
		float3 DPos2 = ddy(Pos);
		float2 DTex1 = ddx(Tex);
		float2 DTex2 = ddy(Tex);

		float3x3 M = float3x3(DPos1, DPos2, cross(DPos1, DPos2));
		float2x3 InverseM = float2x3(cross(M[1], M[2]), cross(M[2], M[0]));
		float3 Tangent = normalize(mul(float2(DTex1.x, DTex2.x), InverseM));
		float3 BiTangent = normalize(mul(float2(DTex1.y, DTex2.y), InverseM));
		return float3x3(Tangent, BiTangent, Normal);
	}

	float3 PeturbNormal(float3 LocalNormal, float3 Pos, float3 Normal, float2 Tex)
	{
		float3x3 TBN = CalculateTBN(Pos, Normal, Tex);
		return normalize(mul(LocalNormal, TBN));
	}
#endif
