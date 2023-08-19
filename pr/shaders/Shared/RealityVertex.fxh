
/*
	Shared functions that process/generate data in the vertex shader
*/

#if !defined(REALITY_VERTEX)
	#define REALITY_VERTEX

	float3x3 GetTangentBasis(float3 Tangent, float3 Normal, float Flip)
	{
		// Get Tangent and Normal
		// Cross product and flip to create Binormal
		Tangent = normalize(Tangent);
		Normal = normalize(Normal);
		float3 Binormal = normalize(cross(Tangent, Normal)) * Flip;
		return float3x3(Tangent, Binormal, Normal);
	}
#endif
