#line 2 "RaShaderEditorRoadDetailNoBlend.fx"

// This shader renders roads with detail textures in the editor without blending.
// It includes the base road shader and enables the detail texture and no-blend features.

#define USE_DETAIL
#define NO_BLEND
#include "shaders/RaShaderEditorRoad.fx"