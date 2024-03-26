
/*
	Description: Outputs common terrain light for staticmesh and terrain shaders
*/

#if !defined(COMMONPIXELLIGHT_FXH)
	#define COMMONPIXELLIGHT_FXH
	#undef _HEADERS_
	#define _HEADERS_

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

#endif
