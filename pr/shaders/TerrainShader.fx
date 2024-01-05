#include "shaders/TerrainShader.fxh"
#include "shaders/TerrainShader_Shared.fx"
#if HIGHTERRAIN || MIDTERRAIN
	#include "shaders/TerrainShader_Hi.fx"
#else
	#include "shaders/TerrainShader_Low.fx"
#endif
