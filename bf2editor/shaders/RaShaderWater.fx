#line 2 "RaShaderWater.fx"

// This shader renders water with fresnel, specular, shadows, and 3D textures.

#define USE_FRESNEL
#define USE_SPECULAR
#define USE_SHADOWS
#define PIXEL_CAMSPACE
#define USE_3DTEXTURE
#define PS_20

#include "shaders/RaShaderWaterBase.fx"