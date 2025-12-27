#line 2 "CommonPixelLight.fxh"

/*
	Description: This shader file defines and outputs a common terrain light for static mesh and terrain shaders.
*/

#if !defined(_HEADERS_)
	#define _HEADERS_
#endif

#if !defined(COMMONPIXELLIGHT_FXH)
	#define COMMONPIXELLIGHT_FXH
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
