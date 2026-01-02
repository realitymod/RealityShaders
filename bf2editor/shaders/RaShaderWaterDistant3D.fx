#line 2 "RaShaderWaterDistant3D.fx"

/*
    This shader renders 3D water surfaces for distant viewing with lightmap and 3D texture support, building upon RaShaderWaterBase.fx with optimized volumetric rendering for distant water surfaces.
*/

#define USE_LIGHTMAP
#define USE_3DTEXTURE
#include "shaders/RaShaderWaterBase.fx"