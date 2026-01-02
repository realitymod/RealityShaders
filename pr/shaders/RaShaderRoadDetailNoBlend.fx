#line 2 "RaShaderRoadDetailNoBlend.fx"

/*
    This shader renders roads with detail textures in the game without texture blending, building upon RaShaderRoad.fx with detail texture support and disabled blending.
*/

#define USE_DETAIL
#define NO_BLEND
#include "shaders/RaShaderRoad.fx"