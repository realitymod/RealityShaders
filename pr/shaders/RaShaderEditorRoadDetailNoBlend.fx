#line 2 "RaShaderEditorRoadDetailNoBlend.fx"

/*
    This shader renders roads with detail textures in the editor without texture blending, building upon RaShaderEditorRoad.fx with detail texture support and disabled blending.
*/

#define USE_DETAIL
#define NO_BLEND
#include "shaders/RaShaderEditorRoad.fx"