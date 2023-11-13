struct PointLightData
{
	float3 pos;
	float attSqrInv;
	float3 col;
};

struct SpotLightData
{
	float3 pos;
	float attSqrInv;
	float3 col;
	float coneAngle;
	float3 dir;
	float oneminusconeAngle;
};

PointLightData pointLight : POINTLIGHT;
SpotLightData spotLight : SPOTLIGHT;


float4 lightPosAndAttSqrInv : LightPositionAndAttSqrInv;
float4 lightColor : LightColor;

float3 calcPVPoint(PointLightData indata, float3 wPos, float3 normal)
{
	float3 lvec = lightPosAndAttSqrInv.xyz - wPos;
	float radialAtt = saturate(1 - dot(lvec, lvec)*lightPosAndAttSqrInv.w);
	lvec = normalize(lvec);
	float intensity = dot(lvec, normal) * radialAtt;

	return intensity * lightColor.xyz;
}

float3 calcPVPointTerrain(float3 wPos, float3 normal)
{
	float3 lvec = pointLight.pos - wPos;
	float radialAtt = saturate(1 - (dot(lvec, lvec))*pointLight.attSqrInv);
// return radialAtt * pointLight.col;
	lvec = normalize(lvec);
	float intensity = dot(lvec, normal) * radialAtt;

	return intensity * pointLight.col;
}

float3 calcPVSpot(SpotLightData indata, float3 wPos, float3 normal)
{
	float3 lvec = indata.pos - wPos;
	
	float radialAtt = saturate(1 - dot(lvec, lvec)*indata.attSqrInv);
	lvec = normalize(lvec);
	
	float conicalAtt =	saturate(dot(lvec, indata.dir)-indata.oneminusconeAngle) / indata.coneAngle;

	float intensity = dot(lvec, normal) * radialAtt * conicalAtt;

	return intensity * indata.col;
}
