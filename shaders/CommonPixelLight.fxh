
/*
	Description: Outputs common terrain light for staticmesh and terrain shaders
*/

#if !defined(COMMONPIXELLIGHT_FXH)
	#define COMMONPIXELLIGHT_FXH

	struct PointLightData
	{
		float3 pos;
		float attSqrInv;
		float3 col;
	};

	PointLightData _PointLight : POINTLIGHT;

	struct SpotLightData
	{
		float3 pos;
		float attSqrInv;
		float3 col;
		float coneAngle;
		float3 dir;
		float oneminusconeAngle;
	};

	SpotLightData _SpotLight : SPOTLIGHT;

	float4 _LightPosAndAttSqrInv : LightPositionAndAttSqrInv;
	float4 _LightColor : LightColor;

#endif
