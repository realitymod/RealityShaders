#line 2 "PointSpriteParticles.fx"

// UNIFORM INPUTS
float4x4 wvpMat : WorldViewProj;

// Particle Texture
texture texture0: Texture0;

//$TODO this is a temporary solution that is inefficient
// Groundhemi Texture
uniform texture texture1: Texture1;

uniform float baseSize : BaseSize;

uniform float2 heightmapSize : HeightmapSize = 2048.f;
uniform float alphaPixelTestRef : AlphaPixelTestRef = 0;

sampler diffuseSampler = sampler_state
{
	Texture = <texture0>;
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
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
	MipFilter = LINEAR; 
};


// constant array
struct TemplateParameters {
	float4 m_uvRangeLMapIntensiyAndParticleMaxSize;
	float4 m_lightColorAndRandomIntensity;
	float4 m_color1;
	float4 m_color2;
	float4 m_colorBlendGraph;
	float4 m_transparencyGraph;
	float4 m_sizeGraph;
};

TemplateParameters tParameters[10] : TemplateParameters;
// TemplateParameters tParameters : TemplateParameters;

struct appdata
{
    float4 pos : POSITION;    
    float1 ageFactor : TEXCOORD0;
    float1 graphIndex : TEXCOORD1;
    float2 randomSizeAndAlpha : TEXCOORD2;
    float2 intensityAndRandomIntensity : TEXCOORD3;
};


struct VS_POINTSPRITE_OUTPUT {
	float4 HPos : POSITION;
	float4 color : COLOR;
	float2 texCoords : TEXCOORD0;
	float2 texCoords1 : TEXCOORD1;	
	float lightMapIntensityOffset : TEXCOORD2;
	float pointSize : PSIZE0; 
};

VS_POINTSPRITE_OUTPUT vsPointSprite(appdata input, uniform float4x4 myWVP, uniform TemplateParameters templ[10], uniform float scale, uniform float myHeightmapSize)
{
	VS_POINTSPRITE_OUTPUT Out;
 	Out.HPos = mul(float4(input.pos.xyz, 1.0f), myWVP);
	Out.texCoords.xy = 0;
	
	// hemi lookup coords
 	Out.texCoords1 = (input.pos.xyz + (myHeightmapSize/2)).xz / myHeightmapSize;	
	

	// Compute Cubic polynomial factors.
	float4 pc = {input.ageFactor*input.ageFactor*input.ageFactor, input.ageFactor*input.ageFactor, input.ageFactor, 1.f};
	
	// compute size of particle using the constants of the template (mSizeGraph)
	float pointSize = min(dot(templ[input.graphIndex.x].m_sizeGraph, pc), 1) * templ[input.graphIndex.x].m_uvRangeLMapIntensiyAndParticleMaxSize.w;
	pointSize = (pointSize + input.randomSizeAndAlpha.x) * scale;
	Out.pointSize = pointSize / Out.HPos.w;
	Out.lightMapIntensityOffset = templ[input.graphIndex.x].m_uvRangeLMapIntensiyAndParticleMaxSize.z;
	
	float colorBlendFactor = min(dot(templ[input.graphIndex.x].m_colorBlendGraph, pc), 1);
	float3 color = colorBlendFactor * templ[input.graphIndex.x].m_color2;
	color += (1 - colorBlendFactor) * templ[input.graphIndex.x].m_color1;
	
	Out.color.rgb = (color * input.intensityAndRandomIntensity[0]) + input.intensityAndRandomIntensity[1];
	float alphaBlendFactor = min(dot(templ[input.graphIndex.x].m_transparencyGraph, pc), 1);
	Out.color.a = alphaBlendFactor * input.randomSizeAndAlpha[1];
					
	return Out;
}

float4 psPointSprite(VS_POINTSPRITE_OUTPUT input) : COLOR
{
	float4 tDiffuse = tex2D(diffuseSampler, input.texCoords);    
	float4 tLut = tex2D(lutSampler, input.texCoords1);
	float4 color = input.color * tDiffuse;
	color.rgb *= tLut.a + input.lightMapIntensityOffset;
	
	return color;
}


technique PointSprite
<
	int Declaration[] = 
	{
		// StreamNo, DataType, Usage, UsageIdx
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_POSITION, 0 },
		{ 0, D3DDECLTYPE_FLOAT1, D3DDECLUSAGE_TEXCOORD, 0 },
		{ 0, D3DDECLTYPE_FLOAT1, D3DDECLUSAGE_TEXCOORD, 1 },
		{ 0, D3DDECLTYPE_FLOAT2, D3DDECLUSAGE_TEXCOORD, 2 },		
		{ 0, D3DDECLTYPE_FLOAT2, D3DDECLUSAGE_TEXCOORD, 3 },				
		DECLARATION_END // End macro
	};
>
{
	pass p0
	{
		CullMode = NONE;
		ZEnable = TRUE;
		ZFunc = LESSEQUAL;
		ZWriteEnable = FALSE;
		StencilEnable = TRUE;
		StencilFunc = ALWAYS;
		StencilPass = ZERO;
		AlphaTestEnable = TRUE;
		AlphaRef = <alphaPixelTestRef>;
		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = ONE;		

		Texture[0] = (texture0);		
		Texture[1] = NULL;		
		Texture[2] = NULL;		
		Texture[3] = NULL;		
		
		PointSpriteEnable = TRUE;
		PointScaleEnable = TRUE;
		// ColorArg1[0] = DIFFUSE;
		// ColorArg2[0] = TEXTURE;
		// ColorOp[0] = MODULATE;
		
		// PointSpriteScaleEnable = TRUE;
		
 		VertexShader = compile vs_1_1 vsPointSprite(wvpMat, tParameters, baseSize, heightmapSize);
		PixelShader = compile PS2_EXT psPointSprite();		
		
		// PixelShader = NULL;
		/*PixelShader = asm {
			ps.1.1
			tex t0
			mul r0, v0, t0
		};*/
	}
}
