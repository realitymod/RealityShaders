
/*
	Description: Outputs common terrain light for staticmesh and terrain shaders
*/

#if !defined(COMMONVERTEXLIGHT_FX)
	#define COMMONVERTEXLIGHT_FX

	struct PointLightData
	{
		float3 pos;
		float attSqrInv;
		float3 col;
	};

	struct SpotLightData
	{
		float3 pos;
		float attSqrInv;
		float3 col;
		float coneAngle;
		float3 dir;
		float oneminusconeAngle;
	};

	PointLightData _PointLight : POINTLIGHT;
	SpotLightData _SpotLight : SPOTLIGHT;

	float4 _LightPosAndAttSqrInv : LightPositionAndAttSqrInv;
	float4 _LightColor : LightColor;

	float3 GetTerrainLighting(float3 WorldPos, float3 WorldNormal)
	{
		float3 LightVec = _PointLight.pos - WorldPos;
		float RadialAtt = saturate(1.0 - (length(LightVec) * _PointLight.attSqrInv));

		LightVec = normalize(LightVec);

		float Intensity = dot(LightVec, WorldNormal) * RadialAtt;
		return Intensity * _PointLight.col;
	}
#endif
