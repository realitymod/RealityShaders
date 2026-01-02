#line 2 "RaShaderLeafShadowed.fx"

/*
    This shader renders leaf objects with shadow mapping support, building upon RaShaderLeaf.fx with enhanced shadow rendering capabilities.
*/

#define _HASSHADOW_ 1
#define _CUSTOMSHADOWSAMPLER_ s1
#include "shaders/RaShaderLeaf.fx"