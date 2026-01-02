#line 2 "RaShaderWater.fx"

/*
    This shader renders water surfaces with dynamic lighting, reflection, and transparency effects. It supports environment mapping, lightmap accumulation, shadow mapping, and specialized water rendering techniques including Fresnel effects and depth-based transparency. The shader forms the base for various water rendering variants.
*/

#define USE_FRESNEL
#define USE_SPECULAR
#define USE_SHADOWS
#define PIXEL_CAMSPACE
#define USE_3DTEXTURE
#define PS_20

#include "shaders/RaShaderWaterBase.fx"