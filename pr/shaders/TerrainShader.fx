#line 2 "TerrainShader.fx"

/*
    This shader combines different parts of the terrain shader based on quality settings, integrating TerrainShader.fxh for core functionality and selecting between high and low quality implementations.
*/

#include "shaders/TerrainShader.fxh"
#include "shaders/TerrainShader_Shared.fxh"
#if HIGHTERRAIN || MIDTERRAIN
	#include "shaders/TerrainShader_Hi.fxh"
#else
	#include "shaders/TerrainShader_Low.fxh"
#endif