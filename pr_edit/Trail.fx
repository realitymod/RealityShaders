#line 2 "Trail.fx"
#include "shaders/FXCommon.fx"


// UNIFORM INPUTS

uniform float3 eyePos : EyePos;
uniform float fadeOffset : FresnelOffset = 0;


sampler trailDiffuseSampler = sampler_state
{
	Texture = <texture0>;
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = FILTER_PARTICLE_MIP;
	AddressU = Wrap;
	AddressV = Clamp;
};

sampler trailDiffuseSampler2 = sampler_state 
{
	Texture = <texture0>;
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = FILTER_PARTICLE_MIP;
	AddressU = Wrap;
	AddressV = Clamp;
};



// constant array
struct TemplateParameters {
	float4 m_uvRangeLMapIntensiyAndParticleMaxSize;
	float4 m_fadeInOutTileFactorAndUVOffsetVelocity;
	float4 m_color1AndLightFactor;
	float4 m_color2;
	float4 m_colorBlendGraph;
	float4 m_transparencyGraph;
	float4 m_sizeGraph;
};


TemplateParameters tParameters : TemplateParameters;

struct appdata
{
    float3 pos : POSITION;    
    float3 localCoords : NORMAL0;
    float3 tangent : NORMAL1;
    float4 intensityAgeAnimBlendFactorAndAlpha : TEXCOORD0;
    float4 uvOffsets : TEXCOORD1;
    float2 texCoords : TEXCOORD2;
};


struct VS_TRAIL_OUTPUT {
	float4 HPos : POSITION;
	float4 color : TEXCOORD3;
	float3 animBFactorAndLMapIntOffset : COLOR0;
	float4 lightFactorAndAlpha : COLOR1;
	float2 texCoords0 : TEXCOORD0;
	float2 texCoords1 : TEXCOORD1;
	float2 texCoords2 : TEXCOORD2;
	// float3 animBFactorAndLMapIntOffset : TEXCOORD3;
	
	float Fog : FOG;
	
};

VS_TRAIL_OUTPUT vsTrail(appdata input, uniform float4x4 myWV, uniform float4x4 myWP)
{
	
	VS_TRAIL_OUTPUT Out = (VS_TRAIL_OUTPUT)0;
	
	// Compute Cubic polynomial factors.
	float age = input.intensityAgeAnimBlendFactorAndAlpha[1];

	// FADE values
	float fadeIn = saturate(age/tParameters.m_fadeInOutTileFactorAndUVOffsetVelocity.x);
	float fadeOut = saturate((1.f - age)/tParameters.m_fadeInOutTileFactorAndUVOffsetVelocity.y);
		 
	float3 eyeVec = eyePos - input.pos;
	
	// project eyevec to tangent vector to get position on axis
	float tanPos = dot(eyeVec, input.tangent);
	  
	// closest point to camera
	float3 axisVec = eyeVec - (input.tangent * tanPos);
	axisVec = normalize(axisVec);
		
	// find rotation around axis
	float3 norm = cross(input.tangent, input.localCoords*-1);
	
	float fadeFactor = dot(axisVec, norm);
	fadeFactor *= fadeFactor;
	fadeFactor += fadeOffset;
	fadeFactor *= fadeIn * fadeOut;
		
	// age factor polynomials
	float4 pc = {age*age*age, age*age, age, 1.f};

	// comput size of particle using the constants of the templ[input.ageFactorAndGraphIndex.y]ate (mSizeGraph)
	float size = min(dot(tParameters.m_sizeGraph, pc), 1) * tParameters.m_uvRangeLMapIntensiyAndParticleMaxSize.w;
	// size += input.randomSizeAlphaAndIntensityBlendFactor.x;

	// displace vertex
	float4 pos = mul(float4(input.pos.xyz + size*(input.localCoords.xyz*input.texCoords.y), 1), myWV);
	Out.HPos = mul(pos, myWP);
	
	float colorBlendFactor = min(dot(tParameters.m_colorBlendGraph, pc), 1);
	float3 color = colorBlendFactor * tParameters.m_color2.rgb;
	color += (1 - colorBlendFactor) * tParameters.m_color1AndLightFactor.rgb;
	
	// lighting??
	
	// color.rgb *=   + ((1.0f + input.localCoords.y*input.texCoords.y)/2);
	// float3 lightVec = float3(.46f,0.57f,0.68f);
	// float3 lightVec = float3(0.7,0.7,0);
	// color.rgb *= 2*saturate(dot(input.localCoords*input.texCoords.y, lightVec));
	// float3 norm2 = cross(input.tangent, input.localCoords*input.texCoords.y)*input.texCoords.y;
	
	// if (dot(norm2, eyeVec) >= 0)
	 // color.rgb = SUNCOLOR;
	// else
	// color.rgb = GROUNDCOLOR;
	// color.rgb *= 2*saturate(dot(norm2, lightVec));
	// color.rgb = norm2;
	
	// color.rgb *= lerp(GROUNDCOLOR, SUNCOLOR, (1.0f + input.localCoords.y*input.texCoords.y)*0.5f);
	// input.localCoords.y*input.texCoords.y
	// color.rgb += lerp(0, SUNCOLOR, clamp(input.localCoords.y*input.texCoords.y, 0, 1));
	// color.rgb += lerp(0, GROUNDCOLOR, clamp(-input.localCoords.y*input.texCoords.y, 0, 1));
	

	float alphaBlendFactor = min(dot(tParameters.m_transparencyGraph, pc), 1) * input.intensityAgeAnimBlendFactorAndAlpha[3];
	alphaBlendFactor *= fadeFactor;
	
	Out.color.rgb = color/2;
	Out.lightFactorAndAlpha.b = alphaBlendFactor;
				
	// Out.color.a = alphaBlendFactor * input.randomSizeAlphaAndIntensityBlendFactor[1];
	// Out.color.rgb = (color * input.intensityAndRandomIntensity[0]) + input.intensityAndRandomIntensity[1];

	Out.animBFactorAndLMapIntOffset.x = input.intensityAgeAnimBlendFactorAndAlpha[2];
	
	float lightMapIntensity = saturate(clamp((input.pos.y - hemiShadowAltitude) / 10.f, 0.f, 1.0f) + tParameters.m_uvRangeLMapIntensiyAndParticleMaxSize.z);
	// Out.animBFactorAndLMapIntOffset.y = tParameters.m_uvRangeLMapIntensiyAndParticleMaxSize.z;
	Out.animBFactorAndLMapIntOffset.yz = lightMapIntensity;
			
	// compute texcoords for trail
	float2 rotatedTexCoords = input.texCoords;
	
	rotatedTexCoords.x -= age * tParameters.m_fadeInOutTileFactorAndUVOffsetVelocity.w;
	rotatedTexCoords *= tParameters.m_uvRangeLMapIntensiyAndParticleMaxSize.xy;
	rotatedTexCoords.x *= tParameters.m_fadeInOutTileFactorAndUVOffsetVelocity.z / tParameters.m_uvRangeLMapIntensiyAndParticleMaxSize.w;
	
	// Bias texcoords.
	rotatedTexCoords.x += tParameters.m_uvRangeLMapIntensiyAndParticleMaxSize.x;
	rotatedTexCoords.y = tParameters.m_uvRangeLMapIntensiyAndParticleMaxSize.y - rotatedTexCoords.y;
	rotatedTexCoords.y *= 0.5f;

	
	// Offset texcoords
	float4 uvOffsets = input.uvOffsets * OneOverShort;

	Out.texCoords0 = rotatedTexCoords.xy + uvOffsets.xy;
	Out.texCoords1 = rotatedTexCoords.xy + uvOffsets.zw;
			
	// hemi lookup coords
 	Out.texCoords2.xy = ((input.pos + (hemiMapInfo.z/2)).xz - hemiMapInfo.xy) / hemiMapInfo.z;	
 	Out.texCoords2.y = 1 - Out.texCoords2.y;
 	
 	Out.lightFactorAndAlpha.a = tParameters.m_color1AndLightFactor.a;
 	 	 		
	Out.Fog = calcFog(Out.HPos.w); 	 	 						
	
	return Out;
}

float4 psTrailHigh(VS_TRAIL_OUTPUT input) : COLOR
{
	float4 tDiffuse = tex2D(trailDiffuseSampler, input.texCoords0);    
	float4 tDiffuse2 = tex2D(trailDiffuseSampler2, input.texCoords1);
	float4 tLut = tex2D(lutSampler, input.texCoords2.xy);
  		
	float4 color = lerp(tDiffuse, tDiffuse2, input.animBFactorAndLMapIntOffset.x);
	color.rgb *= 2*input.color.rgb;
	color.rgb *= calcParticleLighting(tLut.a, input.animBFactorAndLMapIntOffset.z, input.lightFactorAndAlpha.a);
	color.a *= input.lightFactorAndAlpha.b;
	
	return color;
}
float4 psTrailMedium(VS_TRAIL_OUTPUT input) : COLOR
{
	float4 tDiffuse = tex2D(trailDiffuseSampler, input.texCoords0);    
	float4 tDiffuse2 = tex2D(trailDiffuseSampler2, input.texCoords1);
  		
	float4 color = lerp(tDiffuse, tDiffuse2, input.animBFactorAndLMapIntOffset.x);
	color.rgb *= 2*input.color.rgb;
	color.rgb *= calcParticleLighting(1, input.animBFactorAndLMapIntOffset.z, input.lightFactorAndAlpha.a);
	color.a *= input.lightFactorAndAlpha.b;
	
	return color;
}
float4 psTrailLow(VS_TRAIL_OUTPUT input) : COLOR
{
	float4 color = tex2D(trailDiffuseSampler, input.texCoords0);    
	color.rgb *= 2*input.color.rgb;
	color.a *= input.lightFactorAndAlpha.b;
	
	return color;
}
float4 psTrailShowFill(VS_TRAIL_OUTPUT input) : COLOR
{
	return effectSunColor.rrrr;
}




//
// Ordinary technique
//
/*	int Declaration[] = 
	{
		// StreamNo, DataType, Usage, UsageIdx
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_POSITION, 0 },
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_NORMAL, 0 },
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_NORMAL, 1 },		
		{ 0, D3DDECLTYPE_FLOAT4, D3DDECLUSAGE_TEXCOORD, 0 },		
		{ 0, D3DDECLTYPE_SHORT4, D3DDECLUSAGE_TEXCOORD, 1 },				
		{ 0, D3DDECLTYPE_FLOAT2, D3DDECLUSAGE_TEXCOORD, 2 },		
		DECLARATION_END // End macro
	};
*/
technique TrailLow
<
>
{
	pass p0
	{
		CullMode = NONE;
		ZEnable = TRUE;
		ZFunc = LESSEQUAL;
		ZWriteEnable = FALSE;
		StencilEnable = FALSE;
		StencilFunc = ALWAYS;
		StencilPass = ZERO;
		AlphaTestEnable = TRUE;
		AlphaRef = <alphaPixelTestRef>;
		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;				
		FogEnable = TRUE;
				
 		VertexShader = compile vs_1_1 vsTrail(viewMat, projMat);
		PixelShader = compile ps_1_4 psTrailLow();		
	}
}
technique TrailMedium
<
>
{
	pass p0
	{
		CullMode = NONE;
		ZEnable = TRUE;
		ZFunc = LESSEQUAL;
		ZWriteEnable = FALSE;
		StencilEnable = FALSE;
		StencilFunc = ALWAYS;
		StencilPass = ZERO;
		AlphaTestEnable = TRUE;
		AlphaRef = <alphaPixelTestRef>;
		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;				
		FogEnable = TRUE;
				
 		VertexShader = compile vs_1_1 vsTrail(viewMat, projMat);
		PixelShader = compile ps_1_4 psTrailMedium();		
	}
}
technique TrailHigh
<
>
{
	pass p0
	{
		CullMode = NONE;
		ZEnable = TRUE;
		ZFunc = LESSEQUAL;
		ZWriteEnable = FALSE;
		StencilEnable = FALSE;
		StencilFunc = ALWAYS;
		StencilPass = ZERO;
		AlphaTestEnable = TRUE;
		AlphaRef = <alphaPixelTestRef>;
		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;				
		FogEnable = TRUE;
				
 		VertexShader = compile vs_1_1 vsTrail(viewMat, projMat);
		PixelShader = compile ps_1_4 psTrailHigh();		
	}
}
technique TrailShowFill
<
>
{
	pass p0
	{
		CullMode = NONE;
		ZEnable = TRUE;
		ZFunc = LESSEQUAL;
		ZWriteEnable = FALSE;
		StencilEnable = FALSE;
		StencilFunc = ALWAYS;
		StencilPass = ZERO;
		AlphaTestEnable = TRUE;
		AlphaRef = <alphaPixelTestRef>;
		AlphaBlendEnable = TRUE;
		SrcBlend = ONE;
		DestBlend = ONE;				
		FogEnable = TRUE;
				
 		VertexShader = compile vs_1_1 vsTrail(viewMat, projMat);
		PixelShader = compile ps_1_4 psTrailShowFill();		
	}
}



