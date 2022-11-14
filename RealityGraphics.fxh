
/*
	Third-party shader code
	Author: [R-CON]papadanku
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

#if !defined(DIRECTXTK)
	#define DIRECTXTK

	static const float PI = 3.14159265;

	// (Approximate) sRGB to linear
	float3 SRGBToLinearEst(float3 Color)
	{
		return pow(abs(Color), 2.2);
	}

	// Apply the (approximate) sRGB curve to linear values
	float3 LinearToSRGBEst(float3 Color)
	{
		return pow(abs(Color), 1.0 / 2.2);
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
#endif

/*
	Third-party depth-based functions
*/

#if !defined(REALITYDEPTH)
	#define REALITYDEPTH

	// Gets slope-scaled bias from depth
	// Source: https://developer.amd.com/wordpress/media/2012/10/Isidoro-ShadowMapping.pdf
	float GetSlopedBasedBias(float Depth, uniform float SlopeScaleBias = -0.001, uniform float Bias = -0.003)
	{
		return Depth + (SlopeScaleBias * fwidth(Depth)) + Bias;
	}

	// Converts linear depth to logarithmic depth in the vertex shader
	// Source: https://outerra.blogspot.com/2013/07/logarithmic-depth-buffer-optimizations.html
	void ApplyLogarithmicDepth(inout float4 HPos)
	{
		const float Far = 1000000000.0;
		const float FCoef = 1.0 / log(Far + 1.0);
		HPos.z = (log(HPos.z + 1.0) * FCoef) * HPos.w;
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

/*
	Third-party math-based functions
*/

#if !defined(REALITYMATH)
	#define REALITYMATH

	// Gets Orthonormal (TBN) matrix
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
		float SqDistance = dot(LightVec, LightVec);
		return saturate(1.0 - (SqDistance * Attenuation));
	}
#endif
