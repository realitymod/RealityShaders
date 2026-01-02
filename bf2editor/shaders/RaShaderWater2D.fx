#line 2 "RaShaderWater2D.fx"

/*
    This shader renders 2D water surfaces with lightmap and shadow support, building upon RaShaderWaterBase.fx with enhanced lighting and shadow rendering capabilities.
*/

#define USE_LIGHTMAP
#define USE_SHADOWS
#include "shaders/RaShaderWaterBase.fx"