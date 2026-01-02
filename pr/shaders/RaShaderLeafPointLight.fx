#line 2 "RaShaderLeafPointLight.fx"

/*
    This shader renders leaf objects with dynamic point light illumination support, building upon RaShaderLeaf.fx with enhanced lighting calculations.
*/

#define _POINTLIGHT_ 1
#include "shaders/RaShaderLeaf.fx"