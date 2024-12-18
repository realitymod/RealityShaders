#line 2 "TerrainShader.fx"

#include "shaders/TerrainShader.fxh"
#include "shaders/TerrainShader_Shared.fxh"
#if HIGHTERRAIN || MIDTERRAIN
	#include "shaders/TerrainShader_Hi.fxh"
#else
	#include "shaders/TerrainShader_Low.fxh"
#endif

