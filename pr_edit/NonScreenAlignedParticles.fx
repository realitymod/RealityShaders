#line 2 "NonScreenAlignedParticles.fx"
#include "shaders/FXCommon.fx"


// constant array
struct TemplateParameters {
	float4 m_uvRangeLMapIntensiyAndParticleMaxSize;
	float4 m_lightColorAndRandomIntensity;
	float4 m_color1AndLightFactor;
	float4 m_color2;
	float4 m_colorBlendGraph;
	float4 m_transparencyGraph;
	float4 m_sizeGraph;
};


// TODO: change the value 10 to the approprite max value for the current hardware, need to make this a variable
TemplateParameters tParameters[10] : TemplateParameters;

struct appdata
{
    float3 pos : POSITION;    
    float2 ageFactorAndGraphIndex : TEXCOORD0;
    float3 randomSizeAlphaAndIntensityBlendFactor : TEXCOORD1;
    float3 displaceCoords : TEXCOORD2;
    float2 intensityAndRandomIntensity : TEXCOORD3;    
    float4 rotationAndWaterSurfaceOffset : TEXCOORD4;    
    float4 uvOffsets : TEXCOORD5;
    float2 texCoords : TEXCOORD6;
};


struct VS_PARTICLE_OUTPUT {
	float4 HPos : POSITION;
	float4 color : TEXCOORD0;
	float2 texCoords0 : TEXCOORD1;
	float2 texCoords1 : TEXCOORD2;
	float2 texCoords2 : TEXCOORD3;
	float4 animBFactor : COLOR0;
	float4 LMapIntOffsetAndLFactor : COLOR1;
	float Fog : FOG;
};

VS_PARTICLE_OUTPUT vsParticle(appdata input, uniform float4x4 myWV, uniform float4x4 myWP,  uniform TemplateParameters templ[10])
{
	VS_PARTICLE_OUTPUT Out = (VS_PARTICLE_OUTPUT)0;
		
	// Compute Cubic polynomial factors.
	float4 pc = {input.ageFactorAndGraphIndex[0]*input.ageFactorAndGraphIndex[0]*input.ageFactorAndGraphIndex[0], input.ageFactorAndGraphIndex[0]*input.ageFactorAndGraphIndex[0], input.ageFactorAndGraphIndex[0], 1.f};

	float colorBlendFactor = min(dot(templ[input.ageFactorAndGraphIndex.y].m_colorBlendGraph, pc), 1);
	float3 color = colorBlendFactor * templ[input.ageFactorAndGraphIndex.y].m_color2.rgb;
	color += (1 - colorBlendFactor) * templ[input.ageFactorAndGraphIndex.y].m_color1AndLightFactor.rgb;
	Out.color.rgb = ((color * input.intensityAndRandomIntensity[0]) + input.intensityAndRandomIntensity[1])/2;


	float alphaBlendFactor = min(dot(templ[input.ageFactorAndGraphIndex.y].m_transparencyGraph, pc), 1);
	// Out.color.a = alphaBlendFactor * input.randomSizeAlphaAndIntensityBlendFactor[1];
	
	Out.animBFactor.a = alphaBlendFactor * input.randomSizeAlphaAndIntensityBlendFactor[1];;
	Out.animBFactor.b = input.randomSizeAlphaAndIntensityBlendFactor[2];
	Out.LMapIntOffsetAndLFactor.a = saturate(clamp((input.pos.y - hemiShadowAltitude) / 10.f, 0.f, 1.0f) + templ[input.ageFactorAndGraphIndex.y].m_uvRangeLMapIntensiyAndParticleMaxSize.z);
	Out.LMapIntOffsetAndLFactor.b = templ[input.ageFactorAndGraphIndex.y].m_color1AndLightFactor.a;
			
	// comput size of particle using the constants of the templ[input.ageFactorAndGraphIndex.y]ate (mSizeGraph)
	float size = min(dot(templ[input.ageFactorAndGraphIndex.y].m_sizeGraph, pc), 1) * templ[input.ageFactorAndGraphIndex.y].m_uvRangeLMapIntensiyAndParticleMaxSize.w;
	size += input.randomSizeAlphaAndIntensityBlendFactor.x;


	// unpack verts
	float4 rotation = input.rotationAndWaterSurfaceOffset * OneOverShort;
	float2 texCoords = input.texCoords*OneOverShort;
	
	// displace vertex
	float3 scaledPos = input.displaceCoords * size + input.pos.xyz;
	scaledPos.y += rotation.w;

	float4 pos = mul(float4(scaledPos,1), myWV);
	Out.HPos = mul(pos, myWP);
   
	// compute texcoords 
	// Rotate and scale to correct u,v space and zoom in.
	float2 rotatedTexCoords = float2(texCoords.x * rotation.y - texCoords.y * rotation.x, texCoords.x * rotation.x + texCoords.y * rotation.y);
	rotatedTexCoords *= templ[input.ageFactorAndGraphIndex.y].m_uvRangeLMapIntensiyAndParticleMaxSize.xy * uvScale;

	// Bias texcoords.
	rotatedTexCoords.x += templ[input.ageFactorAndGraphIndex.y].m_uvRangeLMapIntensiyAndParticleMaxSize.x;
	rotatedTexCoords.y = templ[input.ageFactorAndGraphIndex.y].m_uvRangeLMapIntensiyAndParticleMaxSize.y - rotatedTexCoords.y;
	rotatedTexCoords *= 0.5f;

	// Offset texcoords
	float4 uvOffsets = input.uvOffsets * OneOverShort;
	Out.texCoords0.xy = rotatedTexCoords + uvOffsets.xy;
	Out.texCoords1.xy = rotatedTexCoords + uvOffsets.zw;
		
	// hemi lookup coords
 	Out.texCoords2.xy = ((input.pos + (hemiMapInfo.z/2)).xz - hemiMapInfo.xy) / hemiMapInfo.z;	
 	Out.texCoords2.y = 1 - Out.texCoords2.y;
 	
	Out.Fog = calcFog(Out.HPos.w); 	 
		 						 	 						
	return Out;
}

float4 psParticleShowFill(VS_PARTICLE_OUTPUT input) : COLOR
{
	return effectSunColor.rrrr;
}


float4 psParticleLow(VS_PARTICLE_OUTPUT input) : COLOR
{
	float4 color = tex2D(diffuseSampler, input.texCoords0);    
	color.rgb *= 2*input.color.rgb;
	color.a *= input.animBFactor.a;

	return color;	
}

float4 psParticleMedium(VS_PARTICLE_OUTPUT input) : COLOR
{
	float4 tDiffuse = tex2D(diffuseSampler, input.texCoords0);    
	float4 tDiffuse2 = tex2D(diffuseSampler2, input.texCoords1);
	float4 color = lerp(tDiffuse, tDiffuse2, input.animBFactor.b);
	color.rgb *= 2*input.color.rgb;

	color.rgb *= calcParticleLighting(1, input.LMapIntOffsetAndLFactor.a, input.LMapIntOffsetAndLFactor.b);
	color.a *= input.animBFactor.a;

	return color;	
}

float4 psParticleHigh(VS_PARTICLE_OUTPUT input) : COLOR
{
	float4 tDiffuse = tex2D(diffuseSampler, input.texCoords0);    
	float4 tDiffuse2 = tex2D(diffuseSampler2, input.texCoords1);
	float4 tLut = tex2D(lutSampler, input.texCoords2.xy);
	
	float4 color = lerp(tDiffuse, tDiffuse2, input.animBFactor.b);
	color.rgb *= 2*input.color.rgb;

	color.rgb *= calcParticleLighting(tLut.a, input.LMapIntOffsetAndLFactor.a, input.LMapIntOffsetAndLFactor.b);
	color.a *= input.animBFactor.a;

	return color;	
}


//
// Ordinary technique
//
/*	int Declaration[] = 
	{
		// StreamNo, DataType, Usage, UsageIdx
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_POSITION, 0 },
		{ 0, D3DDECLTYPE_FLOAT2, D3DDECLUSAGE_TEXCOORD, 0 },
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_TEXCOORD, 1 },		
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_TEXCOORD, 2 },				
		{ 0, D3DDECLTYPE_FLOAT2, D3DDECLUSAGE_TEXCOORD, 3 },		
		{ 0, D3DDECLTYPE_SHORT4, D3DDECLUSAGE_TEXCOORD, 4 },		
		{ 0, D3DDECLTYPE_SHORT4, D3DDECLUSAGE_TEXCOORD, 5 },				
		{ 0, D3DDECLTYPE_SHORT2, D3DDECLUSAGE_TEXCOORD, 6 },								
		DECLARATION_END // End macro
	};
*/
technique NSAParticleShowFill
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
				
 		VertexShader = compile vs_1_1 vsParticle(viewMat, projMat, tParameters);
		PixelShader = compile ps_1_4 psParticleShowFill();		
	}
}

technique NSAParticleLow
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
				
 		VertexShader = compile vs_1_1 vsParticle(viewMat, projMat, tParameters);
		PixelShader = compile ps_1_4 psParticleLow();		
	}
}
technique NSAParticleMedium
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
				
 		VertexShader = compile vs_1_1 vsParticle(viewMat, projMat, tParameters);
		PixelShader = compile ps_1_4 psParticleMedium();		
	}
}
technique NSAParticleHigh
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
				
 		VertexShader = compile vs_1_1 vsParticle(viewMat, projMat, tParameters);
		PixelShader = compile ps_1_4 psParticleHigh();		
	}
}





