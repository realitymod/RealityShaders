#line 2 "RaShaderWaterDistant2D.fx"

/*
    This shader renders 2D water surfaces for distant viewing with lightmap support, building upon RaShaderWaterBase.fx with optimized rendering for distant water surfaces.
*/

#define USE_LIGHTMAP
#include "shaders/RaShaderWaterBase.fx"