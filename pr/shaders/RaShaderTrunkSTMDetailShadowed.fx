#line 2 "RaShaderTrunkSTMDetailShadowed.fx"

/*
    This shader renders static mesh tree trunks with detail textures and shadow mapping support, building upon RaShaderTrunkSTMDetail.fx with enhanced shadow rendering capabilities.
*/

#define _HASSHADOW_ 1
#define _CUSTOMSHADOWSAMPLER_ s2
#include "shaders/RaShaderTrunkSTMDetail.fx"