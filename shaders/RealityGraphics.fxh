
/*
	Third-party shader code
	Author: [R-CON]papadanku @ 2022
*/

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

#if !defined(SETTINGS_DEFINES)
	#define SETTINGS_DEFINES

	#include "shaders/SettingsDefines.fxh"
#endif

// Functions from DirectXTK
#if !defined(DIRECTXTK)
	#define DIRECTXTK

	static const float PI = 3.14159265;

	// (Approximate) sRGB to linear
	float4 SRGBToLinearEst(float4 ColorMap)
	{
		float4 Color = 0.0;
		Color.rgb = pow(abs(ColorMap.rgb), 2.2);
		Color.a = ColorMap.a;
		return Color;
	}

	// Apply the (approximate) sRGB curve to linear values
	void LinearToSRGBEst(inout float3 Color)
	{
		Color = pow(abs(Color), 1.0 / 2.2);
	}

	struct ColorPair
	{
		float3 Diffuse;
		float3 Specular;
	};

	ColorPair ComputeLights
	(
		float3 Normal, float3 LightVec, float3 ViewVec,
		uniform float SpecPower = 32.0, uniform bool NormSpec = false
	)
	{
		ColorPair Output = (ColorPair)0;

		float3 HalfVec = normalize(LightVec + ViewVec);
		float3 DotNL = saturate(dot(Normal, LightVec));
		float3 DotNH = saturate(dot(Normal, HalfVec));
		float3 ZeroNL = step(0.0, DotNL);

		Output.Diffuse = DotNL * ZeroNL;
		float Cons = (NormSpec) ? (SpecPower + 8.0) / 8.0 : 1.0;
		Output.Specular = Cons * pow(abs(DotNH * ZeroNL), SpecPower) * DotNL;
		return Output;
	}

	float LambertLighting(float3 Normal, float3 LightVec)
	{
		return saturate(dot(Normal, LightVec));
	}

	float ComputeFresnelFactor(float3 WorldNormal, float3 ViewVec)
	{
		float ViewAngle = dot(WorldNormal, ViewVec);
		return saturate(1.0 - abs(ViewAngle));
	}

	// Christian Schuler, "Normal Mapping without Precomputed Tangents", ShaderX 5, Chapter 2.6, pp. 131-140
	// See also follow-up blog post: http://www.thetenthplanet.de/archives/1180
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

// Depth-based functions
#if !defined(REALITY_DEPTH)
	#define REALITY_DEPTH

	static const float FarPlane = 10000.0;
	static const float FCoef = 1.0 / log2(FarPlane + 1.0);

	// Gets slope-scaled shadow bias from depth
	// Source: https://developer.amd.com/wordpress/media/2012/10/Isidoro-ShadowMapping.pdf
	float GetSlopedBasedBias(float Depth, uniform float SlopeScaleBias = -0.001, uniform float Bias = -0.003)
	{
		return Depth + (SlopeScaleBias * fwidth(Depth)) + Bias;
	}

	// Converts linear depth to logarithmic depth in the pixel shader
	// Source: https://outerra.blogspot.com/2013/07/logarithmic-depth-buffer-optimizations.html
	float ApplyLogarithmicDepth(float Depth)
	{
		return saturate(log2(Depth) * FCoef);
	}

	// Description: Transforms the vertex position's depth from World/Object space to light space
	// tl: Make sure Pos and matrices are in same space!
	float4 GetMeshShadowProjection(float4 Pos, float4x4 LightTrapezMat, float4x4 LightMat)
	{
		float4 ShadowCoords = mul(Pos, LightTrapezMat);
		float4 LightCoords = mul(Pos, LightMat);
		ShadowCoords.z = (LightCoords.z * ShadowCoords.w) / LightCoords.w; // (zL*wT)/wL == zL/wL post homo
		return ShadowCoords;
	}

	// Description: Compares the depth between the shadowmap's depth (ShadowSampler)
	// and the vertex position's transformed, light-space depth (ShadowCoords.z)
	float4 GetShadowFactor(sampler ShadowSampler, float4 ShadowCoords)
	{
		float4 Texel = float4(0.5 / 1024.0, 0.5 / 1024.0, 0.0, 0.0);
		float4 Samples = 0.0;
		Samples.x = tex2Dproj(ShadowSampler, ShadowCoords);
		Samples.y = tex2Dproj(ShadowSampler, ShadowCoords + float4(Texel.x, 0.0, 0.0, 0.0));
		Samples.z = tex2Dproj(ShadowSampler, ShadowCoords + float4(0.0, Texel.y, 0.0, 0.0));
		Samples.w = tex2Dproj(ShadowSampler, ShadowCoords + Texel);
		float4 CMPBits = step(saturate(GetSlopedBasedBias(ShadowCoords.z)), Samples);
		return dot(CMPBits, 0.25);
	}
#endif

// Math-based functions
#if !defined(REALITY_MATH)
	#define REALITY_MATH

	// Gets orthonormal Tangent-BiNormal-Normal (TBN) matrix
	// Source: https://en.wikipedia.org/wiki/Gram-Schmidt_process
	// License: https://creativecommons.org/licenses/by-sa/3.0/
	float3x3 GetTangentBasis(float3 Tangent, float3 Normal, float Flip)
	{
		// Get Tangent and Normal
		Tangent = normalize(Tangent);
		Normal = normalize(Normal);

		// Re-orthogonalize Tangent with respect to Normal
		Tangent = normalize(Tangent - (Normal * dot(Tangent, Normal)));

		// Cross product and flip to create Binormal
		float3 Binormal = normalize(cross(Tangent, Normal) * Flip);

		return float3x3(Tangent, Binormal, Normal);
	}

	// Gets radial light attenuation value for pointlights
	float GetLightAttenuation(float3 LightVec, float Attenuation)
	{
		return saturate(1.0 - dot(LightVec, LightVec) * Attenuation);
	}

	// Sorry DICE, we're yoinking your code - Project Reality
	// Function to generate world-space normals from terrain heightmap
	// Source: https://media.contentapi.ea.com/content/dam/eacom/frostbite/files/chapter5-andersson-terrain-rendering-in-frostbite.pdf
	float3 GetNormalsFromHeight(sampler SampleHeight, float2 TexCoord)
	{
		float2 TexelSize = float2(ddx(TexCoord.x), ddy(TexCoord.y));
		float4 H;
		H[0] = tex2D(SampleHeight, TexCoord + (TexelSize * float2( 0.0,-1.0))).a;
		H[1] = tex2D(SampleHeight, TexCoord + (TexelSize * float2(-1.0, 0.0))).a;
		H[2] = tex2D(SampleHeight, TexCoord + (TexelSize * float2( 1.0, 0.0))).a;
		H[3] = tex2D(SampleHeight, TexCoord + (TexelSize * float2( 0.0, 1.0))).a;

		float3 N;
		N.z = H[0] - H[3];
		N.x = H[1] - H[2];
		N.y = 2.0;
		return normalize(N);
	}
#endif
