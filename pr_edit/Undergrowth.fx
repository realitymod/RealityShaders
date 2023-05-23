float4x4 worldViewProj : WorldViewProjection;
float4x4 worldView : WorldView;
float4 posOffsetAndScale : PosOffsetAndScale;
float2 sinCos : SinCos;
float4 terrainTexCoordScaleAndOffset : TerrainTexCoordScaleAndOffset;
float3 cameraPos : CameraPos;
float4 fadeAndHeightScaleOffset : FadeAndHeightScaleOffset;
float4 swayOffsets[16] : SwayOffset;
float4 vShadowTexCoordScaleAndOffset : ShadowTexCoordScaleAndOffset;
float4 vSunColor : SunColor;
float4 vGIColor : GIColor;
float4 pointLightPosAtten[4]           : PointLightPosAtten;
float4 pointLightColor[4]              : PointLightColor;
int alphaRefValue : AlphaRef;
float1 lightingScale : LightingScale;

float4 Transparency_x8 : TRANSPARENCY_X8;

#if NVIDIA
#define _CUSTOMSHADOWSAMPLER_ s3
#define _CUSTOMSHADOWSAMPLERINDEX_ 3
#define SHADOWPSMODEL ps_1_3
#define SHADOWVERSION 13
#else
#define SHADOWPSMODEL PS2_EXT
#define SHADOWVERSION 20
#endif

string Category = "Effects\\Lighting";
#include "shaders\racommon.fx"

texture texture0 : TEXLAYER0;
texture texture1 : TEXLAYER1;
texture texture2 : TEXLAYER2;

sampler2D sampler0 = sampler_state
{
	Texture = <texture0>;
	MipFilter = LINEAR;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	AddressU = CLAMP;
	AddressV = CLAMP;
};

sampler2D sampler1 = sampler_state
{
	Texture = <texture1>;
	MipFilter = LINEAR;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	AddressU = CLAMP;
	AddressV = CLAMP;
};
sampler2D sampler2 = sampler_state
{
	Texture = <texture2>;
	MipFilter = LINEAR;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	AddressU = CLAMP;
	AddressV = CLAMP;
};

struct APP2VS
{
	float4 Pos : POSITION;
	float2 TexCoord : TEXCOORD0;
    float4 Packed : COLOR;
};

struct APP2VS_Simple
{
	float4 Pos : POSITION;
	float2 TexCoord : TEXCOORD0;
    float4 Packed : COLOR;    
    float4 TerrainColormap : COLOR1;
    float4 TerrainLightmap : COLOR2;
};

struct VS2PS
{
    float4 Pos : POSITION;
    float2 Tex0 : TEXCOORD0;
    float2 Tex1 : TEXCOORD1;
    float2 Tex2 : TEXCOORD2;
    float4 TexShadow : TEXCOORD3; 
    float Fog : FOG;
    float4 LightAndScale : COLOR0;    
};

struct VS2PS_Simple
{
    float4 Pos : POSITION;
    float2 Tex0 : TEXCOORD0;
    float4 TexShadow : TEXCOORD3; 
    float Fog : FOG;
    float4 LightAndScale : COLOR1;
    float3 SunLight : TEXCOORD1;
    float3 TerrainColor : COLOR0;
};

struct VS2PS_ZOnly
{
    float4 Pos : POSITION;
    float2 Tex0 : TEXCOORD0;
};

VS2PS_ZOnly VShader_ZOnly(APP2VS indata)
{	
	VS2PS_ZOnly outdata = (VS2PS_ZOnly)0;
	
	float4 pos = float4((indata.Pos.xyz / 32767 * posOffsetAndScale.w), 1.0);
	pos.xz += swayOffsets[indata.Packed.z*255].xy * indata.Packed.y * 3.0f;
	pos.xyz += posOffsetAndScale.xyz;

 	float3 vec = pos - cameraPos;
 	float dist = sqrt(dot(vec, vec));

 	float viewDistance = fadeAndHeightScaleOffset.x;
	float fadeFactor = fadeAndHeightScaleOffset.y;

	float heightScale =  clamp((viewDistance-dist)*fadeFactor, 0, 1);
	pos.y = (indata.Pos.y / 32767 * posOffsetAndScale.w)*heightScale + posOffsetAndScale.y + (indata.Pos.w / 32767 * posOffsetAndScale.w);
	
	outdata.Pos = mul(pos, worldViewProj);
 	outdata.Tex0 = indata.TexCoord / 32767.0;
 	 	 	
	return outdata;
}


VS2PS VShader(
	APP2VS indata, 
	uniform int lightCount,
	uniform bool shadowmapEnable)
{
	VS2PS outdata = (VS2PS)0;
	
	float4 pos = float4((indata.Pos.xyz / 32767 * posOffsetAndScale.w), 1.0);
	pos.xz += swayOffsets[indata.Packed.z*255].xy * indata.Packed.y * 3.0f;
	pos.xyz += posOffsetAndScale.xyz;

 	float3 vec = pos - cameraPos;
 	float dist = sqrt(dot(vec, vec));

 	float viewDistance = fadeAndHeightScaleOffset.x;
	float fadeFactor = fadeAndHeightScaleOffset.y;

	float heightScale =  clamp((viewDistance-dist)*fadeFactor, 0, 1);
	pos.y = (indata.Pos.y / 32767 * posOffsetAndScale.w)*heightScale + posOffsetAndScale.y + (indata.Pos.w / 32767 * posOffsetAndScale.w);

 	outdata.LightAndScale.w = indata.Packed.w * 0.5;
 	
	outdata.Pos = mul(pos, worldViewProj);
 	outdata.Tex0 = indata.TexCoord / 32767.0;
 	outdata.Tex1.xy = pos.xz*terrainTexCoordScaleAndOffset.xy + terrainTexCoordScaleAndOffset.zw;
 	outdata.Tex2 = outdata.Tex1;
 	
 	if (shadowmapEnable)
 	{
 		outdata.TexShadow = calcShadowProjection(pos);
 	}
 		
 	outdata.Fog = calcFog(outdata.Pos.w);
 	
 	outdata.LightAndScale.rgb = 0;
 	for (int i=0; i<lightCount; i++)
 	{
 		float3 lightVec = pos - pointLightPosAtten[i].xyz;
		outdata.LightAndScale.rgb += saturate(1.0 - length(lightVec)*length(lightVec)*pointLightPosAtten[i].w) * pointLightColor[i];
	}
 	 	 	
	return outdata;
}

float4 PShader(
	VS2PS indata,
	uniform bool pointLightEnable,
	uniform bool shadowmapEnable,
	uniform sampler2D colormap,
	uniform sampler2D terrainColormap,
	uniform sampler2D terrainLightmap) : COLOR
{
	float4 base = tex2D(colormap, indata.Tex0);
	float4 terrainColor;
	terrainColor.rgb = tex2D(terrainColormap, indata.Tex1);
	terrainColor.rgb = lerp(terrainColor.rgb, 1, indata.LightAndScale.w);
	float3 terrainLightMap = tex2D(terrainLightmap, indata.Tex2);
	float4 terrainShadow;
	if (shadowmapEnable)
	{
		terrainShadow = getShadowFactor(ShadowMapSampler, indata.TexShadow, 1);
	}
	else
		terrainShadow = 1;

	float3 pointColor;
	if (pointLightEnable)
		pointColor = indata.LightAndScale.rgb;
	else
		pointColor = 0;
		
	float3 terrainLight = (terrainLightMap.y * vSunColor * terrainShadow + pointColor) * 2 + (terrainLightMap.z * vGIColor);

	terrainColor.rgb = base.rgb * terrainColor.rgb * terrainLight.rgb * 2;
	terrainColor.a = base.a;// * Transparency_x8.a * 4; // hack for the editor undergrowth to work - need to find out why this doesn't work. SP
// terrainColor.a = terrainColor.a + terrainColor.a;
	
	return terrainColor;
}


VS2PS_Simple VShader_Simple(
	APP2VS_Simple indata, 
	uniform int lightCount,
	uniform bool shadowmapEnable)
{
	VS2PS_Simple outdata = (VS2PS_Simple)0;
	
	float4 pos = float4((indata.Pos.xyz / 32767 * posOffsetAndScale.w) + posOffsetAndScale.xyz, 1.0);
	pos.xz += swayOffsets[indata.Packed.z*255].xy * indata.Packed.y * 3.0f;

 	float3 vec = pos - cameraPos;
 	float dist = sqrt(dot(vec, vec));
 	
 	float viewDistance = fadeAndHeightScaleOffset.x;
	float fadeFactor = fadeAndHeightScaleOffset.y;

	float heightScale =  clamp((viewDistance-dist)*fadeFactor, 0, 1);
	pos.y = (indata.Pos.y / 32767 * posOffsetAndScale.w)*heightScale + posOffsetAndScale.y + (indata.Pos.w / 32767 * posOffsetAndScale.w);
  	
	outdata.Pos = mul(pos, worldViewProj);
 	outdata.Tex0 = indata.TexCoord / 32767.0;
 	
 	if (shadowmapEnable)
 	{
 		outdata.TexShadow = calcShadowProjection(pos);
 	}
 		
 	outdata.Fog = calcFog(outdata.Pos.w);

	float3 light = 0;

	light += indata.TerrainLightmap.z * vGIColor;

 	for (int i=0; i<lightCount; i++)
 	{
 		float3 lightVec = pos - pointLightPosAtten[i].xyz;
		light += saturate(1.0 - length(lightVec)*length(lightVec)*pointLightPosAtten[i].w) * pointLightColor[i];
	}
	
	if (shadowmapEnable)
	{
		outdata.LightAndScale.rgb = light;
 		outdata.LightAndScale.w = indata.Packed.w;
		outdata.SunLight = indata.TerrainLightmap.y * vSunColor * 2;
		outdata.TerrainColor = lerp(indata.TerrainColormap, float4(1,1,1,1), indata.Packed.w);
 	}
 	else
 	{
		light += indata.TerrainLightmap.y * vSunColor * 2;

		outdata.TerrainColor = lerp(indata.TerrainColormap, float4(1,1,1,1), indata.Packed.w);
		outdata.TerrainColor *= light; 	
 	}	
	
	return outdata;
}

VS2PS_ZOnly VShader_ZOnly_Simple(APP2VS_Simple indata)
{	
	VS2PS_ZOnly outdata = (VS2PS_ZOnly)0;
	
	float4 pos = float4((indata.Pos.xyz / 32767 * posOffsetAndScale.w) + posOffsetAndScale.xyz, 1.0);
	pos.xz += swayOffsets[indata.Packed.z*255].xy * indata.Packed.y * 3.0f;

 	float3 vec = pos - cameraPos;
 	float dist = sqrt(dot(vec, vec));
 	
 	float viewDistance = fadeAndHeightScaleOffset.x;
	float fadeFactor = fadeAndHeightScaleOffset.y;

	float heightScale =  clamp((viewDistance-dist)*fadeFactor, 0, 1);
	pos.y = (indata.Pos.y / 32767 * posOffsetAndScale.w)*heightScale + posOffsetAndScale.y + (indata.Pos.w / 32767 * posOffsetAndScale.w);
  	
	outdata.Pos = mul(pos, worldViewProj);
 	outdata.Tex0 = indata.TexCoord / 32767.0;
 	 	 	
	return outdata;
}


float4 PShader_Simple(
	VS2PS_Simple indata,
	uniform bool pointLightEnable,
	uniform bool shadowmapEnable,
	uniform sampler2D colormap) : COLOR
{
	float4 base = tex2D(colormap, indata.Tex0);
	float3 color;

	if (shadowmapEnable)
	{
		float4 terrainShadow = getShadowFactor(ShadowMapSampler, indata.TexShadow, 1);

		float3 light = indata.SunLight * terrainShadow;
		light += indata.LightAndScale.rgb;

		color = base * indata.TerrainColor * light * 2;
	}
	else
	{
		color = base * indata.TerrainColor * 2;
	}

	float4 outcol;
	outcol.rgb = color;
	outcol.a = base.a * Transparency_x8.a * 4;
	outcol.a = outcol.a + outcol.a;
	return outcol;
}

float4 PShader_ZOnly(
	VS2PS indata,
	uniform sampler2D colormap) : COLOR
{
	float4 base = tex2D(colormap, indata.Tex0);
	base.a *= Transparency_x8.a * 4;
	base.a += base.a;
	return base;
}


technique t0_l0
<
	int Declaration[] = 
	{
		// StreamNo, DataType, Usage, UsageIdx
		{ 0, D3DDECLTYPE_SHORT4, D3DDECLUSAGE_POSITION, 0 },
		{ 0, D3DDECLTYPE_SHORT2, D3DDECLUSAGE_TEXCOORD, 0 },
		{ 0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 0 },
		DECLARATION_END // End macro 
	};
>
{
	pass Normal
	{
		CullMode = CW;
		AlphaTestEnable = true;
		AlphaRef = <alphaRefValue>;
		AlphaFunc = GREATER;		
		FogEnable = true;	
		ZFunc = Less;
		
		VertexShader = compile vs_1_1 VShader(0, false);
		PixelShader = compile ps_1_3 PShader(false, false, sampler0, sampler1, sampler2);
	}
}

technique t0_l1
<
	int Declaration[] = 
	{
		// StreamNo, DataType, Usage, UsageIdx
		{ 0, D3DDECLTYPE_SHORT4, D3DDECLUSAGE_POSITION, 0 },
		{ 0, D3DDECLTYPE_SHORT2, D3DDECLUSAGE_TEXCOORD, 0 },
		{ 0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 0 },
		DECLARATION_END // End macro 
	};
>
{
	pass Normal
	{
		CullMode = CW;
		AlphaTestEnable = true;
		AlphaRef = <alphaRefValue>;
		AlphaFunc = GREATER;		
		FogEnable = true;
		ZFunc = Less;

		VertexShader = compile vs_1_1 VShader(1, false);
		PixelShader = compile ps_1_3 PShader(true, false, sampler0, sampler1, sampler2);
	}
}

technique t0_l2
<
	int Declaration[] = 
	{
		// StreamNo, DataType, Usage, UsageIdx
		{ 0, D3DDECLTYPE_SHORT4, D3DDECLUSAGE_POSITION, 0 },
		{ 0, D3DDECLTYPE_SHORT2, D3DDECLUSAGE_TEXCOORD, 0 },
		{ 0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 0 },
		DECLARATION_END // End macro 
	};
>
{
	pass Normal
	{
		CullMode = CW;
		AlphaTestEnable = true;
		AlphaRef = <alphaRefValue>;
		AlphaFunc = GREATER;		
		FogEnable = true;
		ZFunc = Less;

		VertexShader = compile vs_1_1 VShader(2, false);
		PixelShader = compile ps_1_3 PShader(true, false, sampler0, sampler1, sampler2);
	}
}

technique t0_l3
<
	int Declaration[] = 
	{
		// StreamNo, DataType, Usage, UsageIdx
		{ 0, D3DDECLTYPE_SHORT4, D3DDECLUSAGE_POSITION, 0 },
		{ 0, D3DDECLTYPE_SHORT2, D3DDECLUSAGE_TEXCOORD, 0 },
		{ 0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 0 },
		DECLARATION_END // End macro 
	};
>
{
	pass Normal
	{
		CullMode = CW;
		AlphaTestEnable = true;
		AlphaRef = <alphaRefValue>;
		AlphaFunc = GREATER;		
		FogEnable = true;		
		ZFunc = Less;

		VertexShader = compile vs_1_1 VShader(3, false);
		PixelShader = compile ps_1_3 PShader(true, false, sampler0, sampler1, sampler2);
	}
}

technique t0_l4
<
	int Declaration[] = 
	{
		// StreamNo, DataType, Usage, UsageIdx
		{ 0, D3DDECLTYPE_SHORT4, D3DDECLUSAGE_POSITION, 0 },
		{ 0, D3DDECLTYPE_SHORT2, D3DDECLUSAGE_TEXCOORD, 0 },
		{ 0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 0 },
		DECLARATION_END // End macro 
	};
>
{
	pass Normal
	{
		CullMode = CW;
		AlphaTestEnable = true;
		AlphaRef = <alphaRefValue>;
		AlphaFunc = GREATER;		
		FogEnable = true;		
		ZFunc = Less;

		VertexShader = compile vs_1_1 VShader(4, false);
		PixelShader = compile ps_1_3 PShader(true, false, sampler0, sampler1, sampler2);
	}
}

technique t0_l0_ds
<
	int Declaration[] = 
	{
		// StreamNo, DataType, Usage, UsageIdx
		{ 0, D3DDECLTYPE_SHORT4, D3DDECLUSAGE_POSITION, 0 },
		{ 0, D3DDECLTYPE_SHORT2, D3DDECLUSAGE_TEXCOORD, 0 },
		{ 0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 0 },
		DECLARATION_END // End macro 
	};
>
{
	pass Normal
	{
		CullMode = CW;
		AlphaTestEnable = true;
		AlphaRef = <alphaRefValue>;
		AlphaFunc = GREATER;		
		FogEnable = true;
		ZFunc = Less;
		
		VertexShader = compile vs_1_1 VShader(0, true);
		PixelShader = compile SHADOWPSMODEL PShader(false, true, sampler0, sampler1, sampler2);
		#if SHADOWVERSION == 13
			TextureTransformFlags[_CUSTOMSHADOWSAMPLERINDEX_] = PROJECTED;
		#endif
	}
}

technique t0_l1_ds
<
	int Declaration[] = 
	{
		// StreamNo, DataType, Usage, UsageIdx
		{ 0, D3DDECLTYPE_SHORT4, D3DDECLUSAGE_POSITION, 0 },
		{ 0, D3DDECLTYPE_SHORT2, D3DDECLUSAGE_TEXCOORD, 0 },
		{ 0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 0 },
		DECLARATION_END // End macro 
	};
>
{
	pass Normal
	{
		CullMode = CW;
		AlphaTestEnable = true;
		AlphaRef = <alphaRefValue>;
		AlphaFunc = GREATER;		
		FogEnable = true;
		ZFunc = Less;

		VertexShader = compile vs_1_1 VShader(1, true);
		PixelShader = compile SHADOWPSMODEL PShader(false, true, sampler0, sampler1, sampler2);
		#if SHADOWVERSION == 13
			TextureTransformFlags[_CUSTOMSHADOWSAMPLERINDEX_] = PROJECTED;
		#endif
	}
}

technique t0_l2_ds
<
	int Declaration[] = 
	{
		// StreamNo, DataType, Usage, UsageIdx
		{ 0, D3DDECLTYPE_SHORT4, D3DDECLUSAGE_POSITION, 0 },
		{ 0, D3DDECLTYPE_SHORT2, D3DDECLUSAGE_TEXCOORD, 0 },
		{ 0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 0 },
		DECLARATION_END // End macro 
	};
>
{
	pass Normal
	{
		CullMode = CW;
		AlphaTestEnable = true;
		AlphaRef = <alphaRefValue>;
		AlphaFunc = GREATER;		
		FogEnable = true;
		ZFunc = Less;

		VertexShader = compile vs_1_1 VShader(2, true);
		PixelShader = compile SHADOWPSMODEL PShader(false, true, sampler0, sampler1, sampler2);

		#if SHADOWVERSION == 13
			TextureTransformFlags[_CUSTOMSHADOWSAMPLERINDEX_] = PROJECTED;
		#endif
	}
}

technique t0_l3_ds
<
	int Declaration[] = 
	{
		// StreamNo, DataType, Usage, UsageIdx
		{ 0, D3DDECLTYPE_SHORT4, D3DDECLUSAGE_POSITION, 0 },
		{ 0, D3DDECLTYPE_SHORT2, D3DDECLUSAGE_TEXCOORD, 0 },
		{ 0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 0 },
		DECLARATION_END // End macro 
	};
>
{
	pass Normal
	{
		CullMode = CW;
		AlphaTestEnable = true;
		AlphaRef = <alphaRefValue>;
		AlphaFunc = GREATER;		
		FogEnable = true;
		ZFunc = Less;

		VertexShader = compile vs_1_1 VShader(3, true);
		PixelShader = compile SHADOWPSMODEL PShader(false, true, sampler0, sampler1, sampler2);
		#if SHADOWVERSION == 13
			TextureTransformFlags[_CUSTOMSHADOWSAMPLERINDEX_] = PROJECTED;
		#endif
	}
}

technique t0_l4_ds
<
	int Declaration[] = 
	{
		// StreamNo, DataType, Usage, UsageIdx
		{ 0, D3DDECLTYPE_SHORT4, D3DDECLUSAGE_POSITION, 0 },
		{ 0, D3DDECLTYPE_SHORT2, D3DDECLUSAGE_TEXCOORD, 0 },
		{ 0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 0 },
		DECLARATION_END // End macro 
	};
>
{
	pass Normal
	{
		CullMode = CW;
		AlphaTestEnable = true;
		AlphaRef = <alphaRefValue>;
		AlphaFunc = GREATER;		
		FogEnable = true;
		ZFunc = Less;

		VertexShader = compile vs_1_1 VShader(4, true);
		PixelShader = compile SHADOWPSMODEL PShader(false, true, sampler0, sampler1, sampler2);
		#if SHADOWVERSION == 13
			TextureTransformFlags[_CUSTOMSHADOWSAMPLERINDEX_] = PROJECTED;
		#endif
	}
}

////////////////////////

technique t0_l0_simple
<
	int Declaration[] = 
	{
		// StreamNo, DataType, Usage, UsageIdx
		{ 0, D3DDECLTYPE_SHORT4, D3DDECLUSAGE_POSITION, 0 },
		{ 0, D3DDECLTYPE_SHORT2, D3DDECLUSAGE_TEXCOORD, 0 },
		{ 0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 0 },
		{ 0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 1 },
		{ 0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 2 },
		DECLARATION_END // End macro 
	};
>
{
	pass Normal
	{
		CullMode = CW;
		AlphaTestEnable = true;
		AlphaRef = <alphaRefValue>;
		AlphaFunc = GREATER;		
		FogEnable = true;	
		ZFunc = Less;

		VertexShader = compile vs_1_1 VShader_Simple(0, false);
		PixelShader = compile ps_1_3 PShader_Simple(false, false, sampler0);
	}
}

technique t0_l1_simple
<
	int Declaration[] = 
	{
		// StreamNo, DataType, Usage, UsageIdx
		{ 0, D3DDECLTYPE_SHORT4, D3DDECLUSAGE_POSITION, 0 },
		{ 0, D3DDECLTYPE_SHORT2, D3DDECLUSAGE_TEXCOORD, 0 },
		{ 0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 0 },
		{ 0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 1 },
		{ 0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 2 },
		DECLARATION_END // End macro 
	};
>
{
	pass Normal
	{
		CullMode = CW;
		AlphaTestEnable = true;
		AlphaRef = <alphaRefValue>;
		AlphaFunc = GREATER;		
		FogEnable = true;		
		ZFunc = Less;

		VertexShader = compile vs_1_1 VShader_Simple(1, false);
		PixelShader = compile ps_1_3 PShader_Simple(true, false, sampler0);
	}
}

technique t0_l2_simple
<
	int Declaration[] = 
	{
		// StreamNo, DataType, Usage, UsageIdx
		{ 0, D3DDECLTYPE_SHORT4, D3DDECLUSAGE_POSITION, 0 },
		{ 0, D3DDECLTYPE_SHORT2, D3DDECLUSAGE_TEXCOORD, 0 },
		{ 0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 0 },
		{ 0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 1 },
		{ 0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 2 },
		DECLARATION_END // End macro 
	};
>
{
	pass Normal
	{
		CullMode = CW;
		AlphaTestEnable = true;
		AlphaRef = <alphaRefValue>;
		AlphaFunc = GREATER;		
		FogEnable = true;
		ZFunc = Less;

		VertexShader = compile vs_1_1 VShader_Simple(2, false);
		PixelShader = compile ps_1_3 PShader_Simple(true, false, sampler0);
	}
}

technique t0_l3_simple
<
	int Declaration[] = 
	{
		// StreamNo, DataType, Usage, UsageIdx
		{ 0, D3DDECLTYPE_SHORT4, D3DDECLUSAGE_POSITION, 0 },
		{ 0, D3DDECLTYPE_SHORT2, D3DDECLUSAGE_TEXCOORD, 0 },
		{ 0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 0 },
		{ 0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 1 },
		{ 0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 2 },
		DECLARATION_END // End macro 
	};
>
{
	pass Normal
	{
		CullMode = CW;
		AlphaTestEnable = true;
		AlphaRef = <alphaRefValue>;
		AlphaFunc = GREATER;		
		FogEnable = true;				
		ZFunc = Less;

		VertexShader = compile vs_1_1 VShader_Simple(3, false);
		PixelShader = compile ps_1_3 PShader_Simple(true, false, sampler0);
	}
}

technique t0_l4_simple
<
	int Declaration[] = 
	{
		// StreamNo, DataType, Usage, UsageIdx
		{ 0, D3DDECLTYPE_SHORT4, D3DDECLUSAGE_POSITION, 0 },
		{ 0, D3DDECLTYPE_SHORT2, D3DDECLUSAGE_TEXCOORD, 0 },
		{ 0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 0 },
		{ 0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 1 },
		{ 0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 2 },
		DECLARATION_END // End macro 
	};
>
{
	pass Normal
	{
		CullMode = CW;
		AlphaTestEnable = true;
		AlphaRef = <alphaRefValue>;
		AlphaFunc = GREATER;		
		FogEnable = true;
		ZFunc = Less;

		VertexShader = compile vs_1_1 VShader_Simple(4, false);
		PixelShader = compile ps_1_3 PShader_Simple(true, false, sampler0);
	}
}

technique t0_l0_ds_simple
<
	int Declaration[] = 
	{
		// StreamNo, DataType, Usage, UsageIdx
		{ 0, D3DDECLTYPE_SHORT4, D3DDECLUSAGE_POSITION, 0 },
		{ 0, D3DDECLTYPE_SHORT2, D3DDECLUSAGE_TEXCOORD, 0 },
		{ 0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 0 },
		{ 0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 1 },
		{ 0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 2 },
		DECLARATION_END // End macro 
	};
>
{
	pass Normal
	{
		CullMode = CW;
		AlphaTestEnable = true;
		AlphaRef = <alphaRefValue>;
		AlphaFunc = GREATER;		
		FogEnable = true;
		ZFunc = Less;

		VertexShader = compile vs_1_1 VShader_Simple(0, true);
		PixelShader = compile SHADOWPSMODEL PShader_Simple(false, true, sampler0);
		#if SHADOWVERSION == 13
			TextureTransformFlags[_CUSTOMSHADOWSAMPLERINDEX_] = PROJECTED;
		#endif
	}
}

technique t0_l1_ds_simple
<
	int Declaration[] = 
	{
		// StreamNo, DataType, Usage, UsageIdx
		{ 0, D3DDECLTYPE_SHORT4, D3DDECLUSAGE_POSITION, 0 },
		{ 0, D3DDECLTYPE_SHORT2, D3DDECLUSAGE_TEXCOORD, 0 },
		{ 0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 0 },
		{ 0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 1 },
		{ 0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 2 },
		DECLARATION_END // End macro 
	};
>
{
	pass Normal
	{
		CullMode = CW;
		AlphaTestEnable = true;
		AlphaRef = <alphaRefValue>;
		AlphaFunc = GREATER;		
		FogEnable = true;		
		ZFunc = Less;

		VertexShader = compile vs_1_1 VShader_Simple(1, true);
		PixelShader = compile SHADOWPSMODEL PShader_Simple(true, true, sampler0);
		#if SHADOWVERSION == 13
			TextureTransformFlags[_CUSTOMSHADOWSAMPLERINDEX_] = PROJECTED;
		#endif
	}
}

technique t0_l2_ds_simple
<
	int Declaration[] = 
	{
		// StreamNo, DataType, Usage, UsageIdx
		{ 0, D3DDECLTYPE_SHORT4, D3DDECLUSAGE_POSITION, 0 },
		{ 0, D3DDECLTYPE_SHORT2, D3DDECLUSAGE_TEXCOORD, 0 },
		{ 0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 0 },
		{ 0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 1 },
		{ 0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 2 },
		DECLARATION_END // End macro 
	};
>
{
	pass Normal
	{
		CullMode = CW;
		AlphaTestEnable = true;
		AlphaRef = <alphaRefValue>;
		AlphaFunc = GREATER;		
		FogEnable = true;		
		ZFunc = Less;

		VertexShader = compile vs_1_1 VShader_Simple(2, true);
		PixelShader = compile SHADOWPSMODEL PShader_Simple(true, true, sampler0);
		#if SHADOWVERSION == 13
			TextureTransformFlags[_CUSTOMSHADOWSAMPLERINDEX_] = PROJECTED;
		#endif
	}
}

technique t0_l3_ds_simple
<
	int Declaration[] = 
	{
		// StreamNo, DataType, Usage, UsageIdx
		{ 0, D3DDECLTYPE_SHORT4, D3DDECLUSAGE_POSITION, 0 },
		{ 0, D3DDECLTYPE_SHORT2, D3DDECLUSAGE_TEXCOORD, 0 },
		{ 0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 0 },
		{ 0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 1 },
		{ 0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 2 },
		DECLARATION_END // End macro 
	};
>
{
	pass Normal
	{
		CullMode = CW;
		AlphaTestEnable = true;
		AlphaRef = <alphaRefValue>;
		AlphaFunc = GREATER;		
		FogEnable = true;
		ZFunc = Less;

		VertexShader = compile vs_1_1 VShader_Simple(3, true);
		PixelShader = compile SHADOWPSMODEL PShader_Simple(true, true, sampler0);
		#if SHADOWVERSION == 13
			TextureTransformFlags[_CUSTOMSHADOWSAMPLERINDEX_] = PROJECTED;
		#endif
	}
}

technique t0_l4_ds_simple
<
	int Declaration[] = 
	{
		// StreamNo, DataType, Usage, UsageIdx
		{ 0, D3DDECLTYPE_SHORT4, D3DDECLUSAGE_POSITION, 0 },
		{ 0, D3DDECLTYPE_SHORT2, D3DDECLUSAGE_TEXCOORD, 0 },
		{ 0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 0 },
		{ 0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 1 },
		{ 0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 2 },
		DECLARATION_END // End macro 
	};
>
{
	pass Normal
	{
		CullMode = CW;
		AlphaTestEnable = true;
		AlphaRef = <alphaRefValue>;
		AlphaFunc = GREATER;		
		FogEnable = true;
		ZFunc = Less;

		VertexShader = compile vs_1_1 VShader_Simple(4, true);
		PixelShader = compile SHADOWPSMODEL PShader_Simple(true, true, sampler0);
		#if SHADOWVERSION == 13
			TextureTransformFlags[_CUSTOMSHADOWSAMPLERINDEX_] = PROJECTED;
		#endif
	}
}

technique ZOnly
<
	int Declaration[] = 
	{
		// StreamNo, DataType, Usage, UsageIdx
		{ 0, D3DDECLTYPE_SHORT4, D3DDECLUSAGE_POSITION, 0 },
		{ 0, D3DDECLTYPE_SHORT2, D3DDECLUSAGE_TEXCOORD, 0 },
		{ 0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 0 },
		DECLARATION_END // End macro 
	};
>
{
	pass Normal
	{
		CullMode = CW;
		AlphaTestEnable = true;
		AlphaRef = <alphaRefValue>;
		AlphaFunc = GREATER;		
		FogEnable = false;
		ColorWriteEnable = 0;
		ZFunc = Less;
		
		VertexShader = compile vs_1_1 VShader_ZOnly();
		PixelShader = compile ps_1_3 PShader_ZOnly(sampler0);
	}
}

technique ZOnly_Simple
<
	int Declaration[] = 
	{
		// StreamNo, DataType, Usage, UsageIdx
		{ 0, D3DDECLTYPE_SHORT4, D3DDECLUSAGE_POSITION, 0 },
		{ 0, D3DDECLTYPE_SHORT2, D3DDECLUSAGE_TEXCOORD, 0 },
		{ 0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 0 },
		DECLARATION_END // End macro 
	};
>
{
	pass Normal
	{
		CullMode = CW;
		AlphaTestEnable = true;
		AlphaRef = <alphaRefValue>;
		AlphaFunc = GREATER;		
		FogEnable = false;
		ColorWriteEnable = 0;
		ZFunc = Less;
		
		VertexShader = compile vs_1_1 VShader_ZOnly_Simple();
		PixelShader = compile ps_1_3 PShader_ZOnly(sampler0);
	}
}