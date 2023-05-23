#line 2 "FXCommon.fx"
#include "shaders/RaCommon.fx"

// Particle Texture
uniform texture texture0: Texture0;

// Groundhemi Texture
uniform texture texture1: Texture1;

// commonparams
uniform float4x4 viewMat : ViewMat;
uniform float4x4 projMat : ProjMat;

uniform float uvScale = 1.0f/sqrt(2.0f);
uniform float4 hemiMapInfo : HemiMapInfo;
uniform float hemiShadowAltitude : HemiShadowAltitude;
uniform float alphaPixelTestRef : AlphaPixelTestRef = 0;

const float OneOverShort = 1.0/32767.0;


sampler diffuseSampler = sampler_state
{
	Texture = <texture0>;
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = FILTER_PARTICLE_MIP;
	AddressU = Clamp;
	AddressV = Clamp;
};

sampler diffuseSampler2 = sampler_state 
{
	Texture = <texture0>;
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = FILTER_PARTICLE_MIP;
	AddressU = Clamp;
	AddressV = Clamp;
};


sampler lutSampler = sampler_state 
{ 
	Texture = <texture1>; 
	AddressU = CLAMP; 
	AddressV = CLAMP; 
	MinFilter = LINEAR; 
	MagFilter = LINEAR; 
	MipFilter = FILTER_PARTICLE_MIP; 
};

uniform float3 effectSunColor : EffectSunColor;
uniform float3 effectShadowColor : EffectShadowColor;

float3 calcParticleLighting(float lm, float lmOffset, float lightFactor)
{
	float lut = saturate(lm + lmOffset);
	float3 diffuse = lerp(effectShadowColor, effectSunColor, lut);

	return lerp(1, diffuse, lightFactor);
}
