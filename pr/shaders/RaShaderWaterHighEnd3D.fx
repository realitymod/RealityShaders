#line 2 "RaShaderWaterHighEnd3D.fx"

/*
    This shader renders high-end 3D water surfaces with lightmap, shadow, and 3D texture support, building upon RaShaderWaterBase.fx with advanced volumetric water rendering capabilities.
*/

#define USE_LIGHTMAP
#define USE_SHADOWS
#define USE_3DTEXTURE
#include "shaders/RaShaderWaterBase.fx"