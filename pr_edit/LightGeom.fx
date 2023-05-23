#line 2 "lightGeom.fx"

// UNIFORM INPUTS
float4x4 wvpMat : WorldViewProj;
float4x4 wvMat : WorldView;
float4 lightColor : LightColor;


float3 spotDir : SpotDir;
float spotConeAngle : ConeAngle;

// float3 spotPosition : SpotPosition;

struct appdata
{
    float4 Pos : POSITION;    
};

struct VS_OUTPUT {
	float4 HPos : POSITION;
};

VS_OUTPUT vsPointLight(appdata input, uniform float4x4 myWVP)
{
	VS_OUTPUT Out;
 	Out.HPos = mul(float4(input.Pos.xyz, 1.0f), myWVP);
	return Out;
}

float4 psPointLight() : COLOR
{
	return lightColor;
	// return float4(1,0,0,1);
}

technique Pointlight
<
	int Declaration[] = 
	{
		// StreamNo, DataType, Usage, UsageIdx
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_POSITION, 0 },
		DECLARATION_END // End macro
	};
>
{
	pass p0
	{
		CullMode = NONE;
		ZEnable = TRUE;
		ZFunc = LESSEQUAL;
		ZWriteEnable = TRUE;
		StencilEnable = TRUE;
		StencilFunc = ALWAYS;
		StencilPass = ZERO;
		
 		VertexShader = compile vs_1_1 vsPointLight(wvpMat);
		PixelShader = compile ps_1_1 psPointLight();		
	}
}

///

struct VS_SPOT_OUTPUT {
	float4 HPos : POSITION;
	float3 lightDir : TEXCOORD0; 
	float3 lightVec : TEXCOORD1;
};

VS_SPOT_OUTPUT vsSpotLight(appdata input, uniform float4x4 myWVP, uniform float4x4 myWV, uniform float3 lightDir)
{
	VS_SPOT_OUTPUT Out;
 	Out.HPos = mul(float4(input.Pos.xyz, 1.0f), myWVP);

	// transform vertex
	float3 vertPos = mul(float4(input.Pos.xyz, 1.0f), myWV);
	Out.lightVec = -normalize(vertPos);
	
	// transform lightDir to objectSpace
	Out.lightDir = mul(lightDir, float3x3(myWV[0].xyz, myWV[1].xyz, myWV[2].xyz));

	return Out;
}

float4 psSpotLight(VS_SPOT_OUTPUT input, uniform float coneAngle, uniform float oneMinusConeAngle) : COLOR
{
	float3 lvec = normalize(input.lightVec);
	float3 ldir = normalize(input.lightDir);
	float conicalAtt = saturate(pow(saturate(dot(lvec, ldir)), 2) - oneMinusConeAngle);/// coneAngle;

	return lightColor * conicalAtt;
}

///


technique Spotlight
<
	int Declaration[] = 
	{
		// StreamNo, DataType, Usage, UsageIdx
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_POSITION, 0 },
		DECLARATION_END // End macro
	};
>
{
	pass p0
	{
		CullMode = NONE;
		ZEnable = TRUE;
		ZFunc = LESSEQUAL;
		ZWriteEnable = TRUE;
		StencilEnable = TRUE;
		StencilFunc = ALWAYS;
		StencilPass = ZERO;
		
 		VertexShader = compile vs_1_1 vsSpotLight(wvpMat, wvMat, spotDir);
		PixelShader = compile PS2_EXT psSpotLight(spotConeAngle, 1.f - spotConeAngle);		
	}
}

