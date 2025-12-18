#line 2 "RealityVertex.fxh"

/*
	Shared functions that process/generate data in the vertex shader
*/

#if !defined(_HEADERS_)
	#define _HEADERS_
#endif

#if !defined(REALITY_VERTEX)
	#define REALITY_VERTEX

	/*
		HLSL implementation of LearnOpenGL's Gram-Schmidt Process
		---
		Source: https://learnopengl.com/Advanced-Lighting/Normal-Mapping
		Gram-Schmidt Process: https://en.wikipedia.org/wiki/Gram%E2%80%93Schmidt_process
		---
		License: CC BY-NC 4.0
	*/
	float3x3 GetTangentBasis(float3 Tangent, float3 Normal, float Flip)
	{
		Tangent = normalize(Tangent);
		Normal = normalize(Normal);

		// Re-orthogonalize Tangent with respect to Normal
		Tangent = normalize(Tangent - dot(Tangent, Normal) * Normal);

		// Get Tangent and Normal
		// Cross product and flip to create Binormal
		float3 Binormal = cross(Tangent, Normal) * Flip;
		return float3x3(Tangent, Binormal, Normal);
	}
#endif
