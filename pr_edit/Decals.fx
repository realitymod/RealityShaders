#line 2 "Decals.fx"

#include "shaders/RaCommon.fx"
//#include "shaders/datatypes.fx"

// UNIFORM INPUTS
float4x4 worldViewProjection : WorldViewProjection;
float4x3 instanceTransformations[10]: InstanceTransformations;
float4x4 shadowTransformations[10] : ShadowTransformations;
float4 shadowViewPortMaps[10] : ShadowViewPortMaps;

// offset x/y heightmapsize z / hemilerpbias w
// float4 hemiMapInfo : HemiMapInfo;
// float4 skyColor : SkyColor;

float4 ambientColor : AmbientColor;
float4 sunColor : SunColor;
float4 sunDirection : SunDirection;


float2 decalFadeDistanceAndInterval : DecalFadeDistanceAndInterval = float2(100.f, 30.f);

texture texture0: TEXLAYER0;
texture texture1: HemiMapTexture;
texture shadowMapTex: ShadowMapTex;
// texture shadowMapOccluderTex: ShadowMapOccluderTex;

sampler sampler0 = sampler_state { Texture = (texture0); AddressU = CLAMP; AddressV = CLAMP; MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = LINEAR; };
sampler sampler1 = sampler_state { Texture = (texture1); AddressU = CLAMP; AddressV = CLAMP; MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = LINEAR; };
// sampler ShadowMapSampler = sampler_state { Texture = (shadowMapTex); AddressU = CLAMP; AddressV = CLAMP; MinFilter = POINT; MagFilter = POINT; MipFilter = NONE; };
// sampler sampler3 = sampler_state { Texture = (shadowMapOccluderTex); AddressU = CLAMP; AddressV = CLAMP; MinFilter = POINT; MagFilter = POINT; MipFilter = NONE; };

struct appdata {
   	float4 Pos : POSITION;    
   	float4 Normal : NORMAL;       	
   	float4 Color : COLOR;
   	float4 TexCoordsInstanceIndexAndAlpha : TEXCOORD0;
};


struct OUT_vsDecal {
	float4 HPos : POSITION;
	float2 Texture0 : TEXCOORD0;	
	float3 Color : TEXCOORD1;
	float3 Diffuse : TEXCOORD2;
	float4 Alpha : COLOR0;
	
	float Fog : FOG;
};

OUT_vsDecal vsDecal(appdata input)
{
	OUT_vsDecal Out;
	   	   	
   	int index = input.TexCoordsInstanceIndexAndAlpha.z;
   	
  	float3 Pos = mul(input.Pos, instanceTransformations[index]);
 	Out.HPos = mul(float4(Pos.xyz, 1.0f), worldViewProjection);
 	
 	float3 worldNorm = mul(input.Normal.xyz, (float3x3)instanceTransformations[index]);
 	Out.Diffuse = saturate(dot(worldNorm, -sunDirection)) * sunColor;
 	
 	float alpha = 1.0f - saturate((Out.HPos.z - decalFadeDistanceAndInterval.x)/decalFadeDistanceAndInterval.y);
	alpha *= input.TexCoordsInstanceIndexAndAlpha.w;
	Out.Alpha = alpha;
	Out.Color = input.Color;
	
	Out.Texture0 = input.TexCoordsInstanceIndexAndAlpha.xy;
	
	Out.Fog = calcFog(Out.HPos.w); 	 

	return Out;
}

float4 psDecal(OUT_vsDecal indata) : COLOR
{
	// return 1;
	float3 lighting =  ambientColor + indata.Diffuse;
	float4 outColor = tex2D(sampler0, indata.Texture0);// * indata.Color;
	
	outColor.rgb *= indata.Color * lighting;
	outColor.a *= indata.Alpha;
	
	
	return outColor;
}



struct OUT_vsDecalShadowed {
	float4 HPos : POSITION;
	float2 Texture0 : TEXCOORD0;	
	float4 TexShadow : TEXCOORD1;
	float4 ViewPortMap : TEXCOORD2;
	float3 Color : TEXCOORD3;
	float3 Diffuse : TEXCOORD4;
	float4 Alpha : COLOR0;	
	float Fog : FOG;
	
};

OUT_vsDecalShadowed vsDecalShadowed(appdata input)
{
	OUT_vsDecalShadowed Out;
	   	   	
   	int index = input.TexCoordsInstanceIndexAndAlpha.z;
   	
  	float3 Pos = mul(input.Pos, instanceTransformations[index]);
 	Out.HPos = mul(float4(Pos.xyz, 1.0f), worldViewProjection);
 	
 	float3 worldNorm = mul(input.Normal.xyz, (float3x3)instanceTransformations[index]);
 	Out.Diffuse = saturate(dot(worldNorm, -sunDirection)) * sunColor;

 	float3 color = input.Color;
 	float alpha = 1.0f - saturate((Out.HPos.z - decalFadeDistanceAndInterval.x)/decalFadeDistanceAndInterval.y);
	alpha *= input.TexCoordsInstanceIndexAndAlpha.w;
	Out.Alpha = alpha;


	Out.Color = color;
 	
 	Out.ViewPortMap = shadowViewPortMaps[index];
 	Out.TexShadow =  mul(float4(Pos, 1), shadowTransformations[index]);
	Out.TexShadow.z -= 0.007;
	
	Out.Texture0 = input.TexCoordsInstanceIndexAndAlpha.xy;
	Out.Fog = calcFog(Out.HPos.w); 	 
	
	return Out;
}

float4 psDecalShadowed(OUT_vsDecalShadowed indata) : COLOR
{
	// return 1;
	float2 texel = float2(1.0 / 1024.0, 1.0 / 1024.0);
	float4 samples;

/*	indata.TexShadow.xy = clamp(indata.TexShadow.xy,  indata.ViewPortMap.xy, indata.ViewPortMap.zw);
	samples.x = tex2D(ShadowMapSampler, indata.TexShadow);
	samples.y = tex2D(ShadowMapSampler, indata.TexShadow + float2(texel.x, 0));
	samples.z = tex2D(ShadowMapSampler, indata.TexShadow + float2(0, texel.y));
	samples.w = tex2D(ShadowMapSampler, indata.TexShadow + texel);
	
	float4 cmpbits = samples >= saturate(indata.TexShadow.z);
	float dirShadow = dot(cmpbits, float4(0.25, 0.25, 0.25, 0.25));
	*/
	float dirShadow = 1;
		
	float4 outColor = tex2D(sampler0, indata.Texture0);
	outColor.rgb *=  indata.Color;
	outColor.a *= indata.Alpha;
	
	float3 lighting =  ambientColor.rgb + indata.Diffuse*dirShadow;
	
	outColor.rgb *= lighting;
	
	return outColor;
}


technique Decal
<
	int Declaration[] = 
	{
		// StreamNo, DataType, Usage, UsageIdx
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_POSITION, 0 },
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_NORMAL, 0 },
		{ 0, D3DDECLTYPE_D3DCOLOR, D3DDECLUSAGE_COLOR, 0 },
		{ 0, D3DDECLTYPE_FLOAT4, D3DDECLUSAGE_TEXCOORD, 0 },		
		DECLARATION_END // End macro
	};
>
{
	pass p0 
	{	
		// FillMode = WireFrame;
		AlphaTestEnable = TRUE;
		ZEnable = TRUE;	
		ZWriteEnable = FALSE;		
		AlphaRef = 0;
		AlphaFunc = GREATER;
		CullMode = CW;
		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;				
		FogEnable = TRUE;
		
 		VertexShader = compile vs_1_1 vsDecal();
		PixelShader = compile ps_1_4 psDecal();
	}
	
	pass p1
	{
		// FillMode = WireFrame;
		AlphaTestEnable = TRUE;
		ZEnable = TRUE;	
		ZWriteEnable = FALSE;		
		AlphaRef = 0;
		AlphaFunc = GREATER;
		CullMode = CW;
		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;				
		FogEnable = TRUE;
		
 		VertexShader = compile vs_1_1 vsDecalShadowed();
		PixelShader = compile ps_1_4 psDecalShadowed();
	}
}

