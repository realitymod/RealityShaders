#include "shaders/SettingsDefines.fxh"

/*
	Shared shader code that we use for Project Reality: BF2
	Author: [R-DEV]papadanku @ 2023
*/

#include "shaders/Shared/RealityDepth.fxh"
#include "shaders/Shared/RealityDirectXTK.fxh"
#include "shaders/Shared/RealityPixel.fxh"
#include "shaders/Shared/RealityVertex.fxh"

#if !defined(REALITY_DEFINES)
	#define REALITY_DEFINES

	// This hardcoded value fixes a bug with undergrowth's alphatesting
	// NOTE: We compensate for this change by multiplying the texture's alpha by ~2
	#define FH2_ALPHAREF 127
#endif
