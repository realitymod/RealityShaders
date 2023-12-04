#line 2 "StaticMesh_r3x0.fx"

float2 calculateOffsetCoordinatesFromAlpha(float2 inTexCoords, float2 inHeightTexCoords, sampler2D inHeightSampler, float4 inScaleBias, float3 inEyeVecUnNormalized)
{
	float2 height = tex2D(inHeightSampler, inHeightTexCoords).aa;
	float3 eyeVecN = normalize(inEyeVecUnNormalized) * float3(1,-1,1);

	height = height * inScaleBias.xy + inScaleBias.wz;
	return inTexCoords + height * eyeVecN.xy;
}

//-- ZAndDiffuse

struct appdata_vsZAndDiffuseBase {
    float4 Pos : POSITION;
    float2 TexCoordDiff : TEXCOORD0;
};

struct VS_OUT_vsZAndDiffuseBase {
	float4 HPos : POSITION;
	float2 Tex0Diff : TEXCOORD0;
};

VS_OUT_vsZAndDiffuseBase vsZAndDiffuseBase(appdata_vsZAndDiffuseBase input)
{
	VS_OUT_vsZAndDiffuseBase Out;

 	Out.HPos = mul(input.Pos, viewProjMatrix);
	Out.Tex0Diff = input.TexCoordDiff;

	return Out;
}

float4 psZAndDiffuseBase(VS_OUT_vsZAndDiffuseBase indata) : COLOR
{
	return tex2D(samplerWrap0, indata.Tex0Diff);
}

struct appdata_ZAndDiffuseBaseDetail {
    float4 Pos : POSITION;
    float2 TexCoordDiff : TEXCOORD0;
    float2 TexCoordDetail : TEXCOORD1;
};

struct VS_OUT_ZAndDiffuseBaseDetail {
	float4 HPos : POSITION;
	float2 Tex0Diff : TEXCOORD0;
	float2 Tex1Detail : TEXCOORD1;
};

VS_OUT_ZAndDiffuseBaseDetail vsZAndDiffuseBaseDetail(appdata_ZAndDiffuseBaseDetail input)
{
	VS_OUT_ZAndDiffuseBaseDetail Out;

 	Out.HPos = mul(input.Pos, viewProjMatrix);
	Out.Tex0Diff = input.TexCoordDiff;
	Out.Tex1Detail = input.TexCoordDetail;
	return Out;
}


float4 psZAndDiffuseBaseDetail(VS_OUT_ZAndDiffuseBaseDetail indata) : COLOR
{
	float4 detail = tex2D(samplerWrapAniso1, indata.Tex1Detail);
	float4 base = tex2D(samplerWrapAniso0, indata.Tex0Diff);
	return base * detail;
}

struct appdata_ZAndDiffuseBaseDetailParallax {
    float4 Pos : POSITION;
    float2 TexCoordDiff : TEXCOORD0;
    float2 TexCoordDetail : TEXCOORD1;
    float3 Tan : TANGENT;
    float3 Normal : NORMAL;
};

struct VS_OUT_ZAndDiffuseBaseDetailParallax {
	float4 HPos : POSITION;
	float2 Tex0Diff : TEXCOORD0;
	float2 Tex1Detail : TEXCOORD1;
   	float3 tanEyeVec : TEXCOORD2;
};

VS_OUT_ZAndDiffuseBaseDetailParallax vsZAndDiffuseBaseDetailParallax(appdata_ZAndDiffuseBaseDetailParallax input)
{
	VS_OUT_ZAndDiffuseBaseDetailParallax Out;

 	Out.HPos = mul(input.Pos, viewProjMatrix);

	float3 binormal = normalize(cross(input.Tan, input.Normal));
	float3x3 tanBasis = float3x3(input.Tan, binormal, input.Normal);
	Out.tanEyeVec = mul(eyePosObjectSpace.xyz-input.Pos.xyz, tanBasis);

	Out.Tex0Diff = input.TexCoordDiff;
	Out.Tex1Detail = input.TexCoordDetail;
	return Out;
}

float4 psZAndDiffuseBaseDetailParallax(VS_OUT_ZAndDiffuseBaseDetailParallax indata) : COLOR
{
	float2 newTex0Diff = calculateOffsetCoordinatesFromAlpha(indata.Tex0Diff.xy, indata.Tex1Detail.xy, samplerWrapAniso1, parallaxScaleBias, indata.tanEyeVec);
	float2 newTex1Detail = calculateOffsetCoordinatesFromAlpha(indata.Tex1Detail.xy, indata.Tex1Detail.xy, samplerWrapAniso1, parallaxScaleBias, indata.tanEyeVec);

	float4 base = tex2D(samplerWrapAniso0, newTex0Diff);
	float4 detail = tex2D(samplerWrapAniso1, newTex1Detail);

	return base * detail;
}

struct appdata_ZAndDiffuseBaseDetailDirt {
    float4 Pos : POSITION;
    float2 TexCoordDiff : TEXCOORD0;
    float2 TexCoordDetail : TEXCOORD1;
    float2 TexCoordDirt : TEXCOORD2;
};

struct VS_OUT_ZAndDiffuseBaseDetailDirt {
	float4 HPos : POSITION;
	float2 Tex0Diff : TEXCOORD0;
	float2 Tex1Detail : TEXCOORD1;
	float2 Tex2Dirt : TEXCOORD2;
};

VS_OUT_ZAndDiffuseBaseDetailDirt vsZAndDiffuseBaseDetailDirt(appdata_ZAndDiffuseBaseDetailDirt input)
{
	VS_OUT_ZAndDiffuseBaseDetailDirt Out;

 	Out.HPos = mul(input.Pos, viewProjMatrix);
	Out.Tex0Diff = input.TexCoordDiff;
	Out.Tex1Detail = input.TexCoordDetail;
	Out.Tex2Dirt = input.TexCoordDirt;

	return Out;
}

float4 psZAndDiffuseBaseDetailDirt(VS_OUT_ZAndDiffuseBaseDetailDirt indata) : COLOR
{
	float4 detail = tex2D(samplerWrapAniso1, indata.Tex1Detail);
	float4 base = tex2D(samplerWrapAniso0, indata.Tex0Diff);
	float4 dirt = tex2D(samplerWrapAniso2, indata.Tex2Dirt);
	return base * detail * dirt;
}

struct appdata_ZAndDiffuseBaseDetailDirtParallax {
    float4 Pos : POSITION;
    float2 TexCoordDiff : TEXCOORD0;
    float2 TexCoordDetail : TEXCOORD1;
    float2 TexCoordDirt : TEXCOORD2;
    float3 Tan : TANGENT;
    float3 Normal : NORMAL;
};

struct VS_OUT_ZAndDiffuseBaseDetailDirtParallax {
	float4 HPos : POSITION;
	float2 Tex0Diff : TEXCOORD0;
	float2 Tex1Detail : TEXCOORD1;
	float2 Tex2Dirt : TEXCOORD2;
   	float3 tanEyeVec : TEXCOORD3;
};

VS_OUT_ZAndDiffuseBaseDetailDirtParallax vsZAndDiffuseBaseDetailDirtParallax(appdata_ZAndDiffuseBaseDetailDirtParallax input)
{
	VS_OUT_ZAndDiffuseBaseDetailDirtParallax Out;

 	Out.HPos = mul(input.Pos, viewProjMatrix);
	float3 binormal = normalize(cross(input.Tan, input.Normal));
	float3x3 tanBasis = float3x3(input.Tan, binormal, input.Normal);
	Out.tanEyeVec = mul(eyePosObjectSpace.xyz-input.Pos.xyz, tanBasis);
	Out.Tex0Diff = input.TexCoordDiff;
	Out.Tex1Detail = input.TexCoordDetail;
	Out.Tex2Dirt = input.TexCoordDirt;

	return Out;
}

float4 psZAndDiffuseBaseDetailDirtParallax(VS_OUT_ZAndDiffuseBaseDetailDirtParallax indata) : COLOR
{
	float2 newTex0Diff = calculateOffsetCoordinatesFromAlpha(indata.Tex0Diff.xy, indata.Tex1Detail.xy, samplerWrapAniso1, parallaxScaleBias, indata.tanEyeVec);
	float2 newTex1Detail = calculateOffsetCoordinatesFromAlpha(indata.Tex1Detail.xy, indata.Tex1Detail.xy, samplerWrapAniso1, parallaxScaleBias, indata.tanEyeVec);
	float2 newTex2Dirt = calculateOffsetCoordinatesFromAlpha(indata.Tex2Dirt.xy, indata.Tex1Detail.xy, samplerWrapAniso1, parallaxScaleBias, indata.tanEyeVec);

	float4 base = tex2D(samplerWrapAniso0, newTex0Diff);
	float4 detail = tex2D(samplerWrapAniso1, newTex1Detail);
	float4 dirt = tex2D(samplerWrapAniso2, newTex2Dirt);
	return base * detail * dirt;
}

struct appdata_ZAndDiffuseBaseDetailCrack {
    float4 Pos : POSITION;
    float2 TexCoordDiff : TEXCOORD0;
    float2 TexCoordDetail : TEXCOORD1;
    float2 TexCoordCrack : TEXCOORD2;
};

struct VS_OUT_ZAndDiffuseBaseDetailCrack {
	float4 HPos : POSITION;
	float2 Tex0Diff : TEXCOORD0;
	float2 Tex1Detail : TEXCOORD1;
	float2 Tex2Crack : TEXCOORD2;
};

VS_OUT_ZAndDiffuseBaseDetailCrack vsZAndDiffuseBaseDetailCrack(appdata_ZAndDiffuseBaseDetailCrack input)
{
	VS_OUT_ZAndDiffuseBaseDetailCrack Out;

 	Out.HPos = mul(input.Pos, viewProjMatrix);
	Out.Tex0Diff = input.TexCoordDiff;
	Out.Tex1Detail = input.TexCoordDetail;
	Out.Tex2Crack = input.TexCoordCrack;

	return Out;
}

float4 psZAndDiffuseBaseDetailCrack(VS_OUT_ZAndDiffuseBaseDetailCrack indata) : COLOR
{
	float4 detail = tex2D(samplerWrapAniso1, indata.Tex1Detail);
	float4 base = tex2D(samplerWrapAniso0, indata.Tex0Diff);
	float4 crack = tex2D(samplerWrapAniso2, indata.Tex2Crack);
	float4 color = base * detail * (1-crack.a);
	color.rgb = crack.rgb*crack.a + color.rgb;
	color.a = detail.a;
	return color;
}

struct appdata_ZAndDiffuseBaseDetailCrackParallax {
    float4 Pos : POSITION;
    float2 TexCoordDiff : TEXCOORD0;
    float2 TexCoordDetail : TEXCOORD1;
    float2 TexCoordCrack : TEXCOORD2;
    float3 Tan : TANGENT;
    float3 Normal : NORMAL;
};

struct VS_OUT_ZAndDiffuseBaseDetailCrackParallax {
	float4 HPos : POSITION;
	float2 Tex0Diff : TEXCOORD0;
	float2 Tex1Detail : TEXCOORD1;
	float2 Tex2Crack : TEXCOORD2;
   	float3 tanEyeVec : TEXCOORD3;
};

VS_OUT_ZAndDiffuseBaseDetailCrackParallax vsZAndDiffuseBaseDetailCrackParallax(appdata_ZAndDiffuseBaseDetailCrackParallax input)
{
	VS_OUT_ZAndDiffuseBaseDetailCrackParallax Out;

 	Out.HPos = mul(input.Pos, viewProjMatrix);
	float3 binormal = normalize(cross(input.Tan, input.Normal));
	float3x3 tanBasis = float3x3(input.Tan, binormal, input.Normal);
	Out.tanEyeVec = mul(eyePosObjectSpace.xyz-input.Pos.xyz, tanBasis);
	Out.Tex0Diff = input.TexCoordDiff;
	Out.Tex1Detail = input.TexCoordDetail;
	Out.Tex2Crack = input.TexCoordCrack;

	return Out;
}

float4 psZAndDiffuseBaseDetailCrackParallax(VS_OUT_ZAndDiffuseBaseDetailCrackParallax indata) : COLOR
{
	float2 newTex0Diff = calculateOffsetCoordinatesFromAlpha(indata.Tex0Diff.xy, indata.Tex1Detail.xy, samplerWrapAniso1, parallaxScaleBias, indata.tanEyeVec);
	float2 newTex1Detail = calculateOffsetCoordinatesFromAlpha(indata.Tex1Detail.xy, indata.Tex1Detail.xy, samplerWrapAniso1, parallaxScaleBias, indata.tanEyeVec);

	float4 detail = tex2D(samplerWrapAniso1, newTex1Detail);
	float4 base = tex2D(samplerWrapAniso0, newTex0Diff);
	float4 crack = tex2D(samplerWrapAniso2, indata.Tex2Crack);
	float4 color = base * detail * (1-crack.a);
	color.rgb = crack.rgb*crack.a + color.rgb;
	color.a = detail.a;
	return color;
}

struct appdata_ZAndDiffuseBaseDetailDirtCrack {
    float4 Pos : POSITION;
    float2 TexCoordDiff : TEXCOORD0;
    float2 TexCoordDetail : TEXCOORD1;
    float2 TexCoordDirt : TEXCOORD2;
    float2 TexCoordCrack : TEXCOORD3;
};

struct VS_OUT_ZAndDiffuseBaseDetailDirtCrack {
	float4 HPos : POSITION;
	float2 Tex0Diff : TEXCOORD0;
	float2 Tex1Detail : TEXCOORD1;
	float2 Tex2Dirt : TEXCOORD2;
	float2 Tex3Crack : TEXCOORD3;
};

VS_OUT_ZAndDiffuseBaseDetailDirtCrack vsZAndDiffuseBaseDetailDirtCrack(appdata_ZAndDiffuseBaseDetailDirtCrack input)
{
	VS_OUT_ZAndDiffuseBaseDetailDirtCrack Out;

 	Out.HPos = mul(input.Pos, viewProjMatrix);
	Out.Tex0Diff = input.TexCoordDiff;
	Out.Tex1Detail = input.TexCoordDetail;
	Out.Tex2Dirt = input.TexCoordDirt;
	Out.Tex3Crack = input.TexCoordCrack;

	return Out;
}

float4 psZAndDiffuseBaseDetailDirtCrack(VS_OUT_ZAndDiffuseBaseDetailDirtCrack indata) : COLOR
{
	float4 detail = tex2D(samplerWrapAniso1, indata.Tex1Detail);
	float4 base = tex2D(samplerWrapAniso0, indata.Tex0Diff);
	float4 dirt = tex2D(samplerWrapAniso2, indata.Tex2Dirt);
	float4 crack = tex2D(samplerWrapAniso3, indata.Tex3Crack);
	float4 color = base * detail * dirt * (1-crack.a);
	color.rgb = crack.rgb*crack.a + color.rgb;
	color.a = detail.a;
	return color;
}

struct appdata_ZAndDiffuseBaseDetailDirtCrackParallax {
    float4 Pos : POSITION;
    float2 TexCoordDiff : TEXCOORD0;
    float2 TexCoordDetail : TEXCOORD1;
    float2 TexCoordDirt : TEXCOORD2;
    float2 TexCoordCrack : TEXCOORD3;
    float3 Tan : TANGENT;
    float3 Normal : NORMAL;
};

struct VS_OUT_ZAndDiffuseBaseDetailDirtCrackParallax {
	float4 HPos : POSITION;
	float2 Tex0Diff : TEXCOORD0;
	float2 Tex1Detail : TEXCOORD1;
	float2 Tex2Dirt : TEXCOORD2;
	float2 Tex3Crack : TEXCOORD3;
   	float3 tanEyeVec : TEXCOORD4;
};

VS_OUT_ZAndDiffuseBaseDetailDirtCrackParallax vsZAndDiffuseBaseDetailDirtCrackParallax(appdata_ZAndDiffuseBaseDetailDirtCrackParallax input)
{
	VS_OUT_ZAndDiffuseBaseDetailDirtCrackParallax Out;

 	Out.HPos = mul(input.Pos, viewProjMatrix);
	float3 binormal = normalize(cross(input.Tan, input.Normal));
	float3x3 tanBasis = float3x3(input.Tan, binormal, input.Normal);
	Out.tanEyeVec = mul(eyePosObjectSpace.xyz-input.Pos.xyz, tanBasis);
	Out.Tex0Diff = input.TexCoordDiff;
	Out.Tex1Detail = input.TexCoordDetail;
	Out.Tex2Dirt = input.TexCoordDirt;
	Out.Tex3Crack = input.TexCoordCrack;

	return Out;
}

float4 psZAndDiffuseBaseDetailDirtCrackParallax(VS_OUT_ZAndDiffuseBaseDetailDirtCrackParallax indata) : COLOR
{
	float2 newTex0Diff = calculateOffsetCoordinatesFromAlpha(indata.Tex0Diff.xy, indata.Tex1Detail.xy, samplerWrapAniso1, parallaxScaleBias, indata.tanEyeVec);
	float2 newTex1Detail = calculateOffsetCoordinatesFromAlpha(indata.Tex1Detail.xy, indata.Tex1Detail.xy, samplerWrapAniso1, parallaxScaleBias, indata.tanEyeVec);
	float2 newTex2Dirt = calculateOffsetCoordinatesFromAlpha(indata.Tex2Dirt.xy, indata.Tex1Detail.xy, samplerWrapAniso1, parallaxScaleBias, indata.tanEyeVec);

	float4 detail = tex2D(samplerWrapAniso1, newTex1Detail);
	float4 base = tex2D(samplerWrapAniso0, newTex0Diff);
	float4 dirt = tex2D(samplerWrapAniso2, newTex2Dirt);
	float4 crack = tex2D(samplerWrapAniso3, indata.Tex3Crack);
	float4 color = base * detail * dirt * (1-crack.a);
	color.rgb = crack.rgb*crack.a + color.rgb;
	color.a = detail.a;
	return color;
}

technique DX9ZAndDiffusebase
{
	pass p0
	{
		ZEnable = TRUE;
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;

		StencilEnable = TRUE;
		StencilRef = 0x40;
		StencilFunc = ALWAYS;
		StencilZFail = KEEP;
		StencilPass = REPLACE;

 		VertexShader = compile vs_1_1 vsZAndDiffuseBase();
		PixelShader = compile PS2_EXT psZAndDiffuseBase();
	}
}

technique DX9ZAndDiffusebasedetail
{
	pass p0
	{
		ZEnable = TRUE;
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;

		StencilEnable = TRUE;
		StencilRef = 0x40;
		StencilFunc = ALWAYS;
		StencilZFail = KEEP;
		StencilPass = REPLACE;

 		VertexShader = compile vs_1_1 vsZAndDiffuseBaseDetail();
		PixelShader = compile PS2_EXT psZAndDiffuseBaseDetail();
	}
}

technique DX9ZAndDiffusebasedetailparallax
{
	pass p0
	{
		ZEnable = TRUE;
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;

		StencilEnable = TRUE;
		StencilRef = 0x40;
		StencilFunc = ALWAYS;
		StencilZFail = KEEP;
		StencilPass = REPLACE;

 		VertexShader = compile vs_1_1 vsZAndDiffuseBaseDetailParallax();
		PixelShader = compile PS2_EXT psZAndDiffuseBaseDetailParallax();
	}
}

technique DX9ZAndDiffusebasedetaildirt
{
	pass p0
	{
		ZEnable = TRUE;
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;

		StencilEnable = TRUE;
		StencilRef = 0x40;
		StencilFunc = ALWAYS;
		StencilZFail = KEEP;
		StencilPass = REPLACE;

 		VertexShader = compile vs_1_1 vsZAndDiffuseBaseDetailDirt();
		PixelShader = compile PS2_EXT psZAndDiffuseBaseDetailDirt();
	}
}

technique DX9ZAndDiffusebasedetaildirtparallax
{
	pass p0
	{
		ZEnable = TRUE;
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;

		StencilEnable = TRUE;
		StencilRef = 0x40;
		StencilFunc = ALWAYS;
		StencilZFail = KEEP;
		StencilPass = REPLACE;

 		VertexShader = compile vs_1_1 vsZAndDiffuseBaseDetailDirtParallax();
		PixelShader = compile PS2_EXT psZAndDiffuseBaseDetailDirtParallax();
	}
}

technique DX9ZAndDiffusebasedetailcrack
{
	pass p0
	{
		ZEnable = TRUE;
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;

		StencilEnable = TRUE;
		StencilRef = 0x40;
		StencilFunc = ALWAYS;
		StencilZFail = KEEP;
		StencilPass = REPLACE;

 		VertexShader = compile vs_1_1 vsZAndDiffuseBaseDetailCrack();
		PixelShader = compile PS2_EXT psZAndDiffuseBaseDetailCrack();
	}
}

technique DX9ZAndDiffusebasedetailcrackparallax
{
	pass p0
	{
		ZEnable = TRUE;
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;

		StencilEnable = TRUE;
		StencilRef = 0x40;
		StencilFunc = ALWAYS;
		StencilZFail = KEEP;
		StencilPass = REPLACE;

 		VertexShader = compile vs_1_1 vsZAndDiffuseBaseDetailCrackParallax();
		PixelShader = compile PS2_EXT psZAndDiffuseBaseDetailCrackParallax();
	}
}

technique DX9ZAndDiffusebasedetaildirtcrack
{
	pass p0
	{
		ZEnable = TRUE;
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;

		StencilEnable = TRUE;
		StencilRef = 0x40;
		StencilFunc = ALWAYS;
		StencilZFail = KEEP;
		StencilPass = REPLACE;

 		VertexShader = compile vs_1_1 vsZAndDiffuseBaseDetailDirtCrack();
		PixelShader = compile PS2_EXT psZAndDiffuseBaseDetailDirtCrack();
	}
}

technique DX9ZAndDiffusebasedetaildirtcrackparallax
{
	pass p0
	{
		ZEnable = TRUE;
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;

		StencilEnable = TRUE;
		StencilRef = 0x40;
		StencilFunc = ALWAYS;
		StencilZFail = KEEP;
		StencilPass = REPLACE;

 		VertexShader = compile vs_1_1 vsZAndDiffuseBaseDetailDirtCrackParallax();
		PixelShader = compile PS2_EXT psZAndDiffuseBaseDetailDirtCrackParallax();
	}
}


//-- Rest of MRT

struct PS2FB_fullMRT
{
    float4 Col0 : COLOR0;
    float4 Col1 : COLOR1;
    float4 Col2 : COLOR2;
};

struct PS2FB_fullMRT4
{
    float4 Col0 : COLOR0;
    float4 Col1 : COLOR1;
    float4 Col2 : COLOR2;
    float4 Col3 : COLOR3;
};

struct appdata_vsGBuffBase {
    float4 Pos : POSITION;
    float2 TexCoordDiff : TEXCOORD0;
    float3 Tan : TANGENT;
    float3 Normal : NORMAL;
};

struct VS_OUT_vsGBuffBase {
	float4 HPos : POSITION;
	float2 Tex0Diff : TEXCOORD0;
    float4 wPos : TEXCOORD1;
	float3 Mat1 : TEXCOORD2;
	float3 Mat2 : TEXCOORD3;
	float3 Mat3 : TEXCOORD4;
};

VS_OUT_vsGBuffBase vsGBuffBase(appdata_vsGBuffBase input)
{
	VS_OUT_vsGBuffBase Out;

 	Out.HPos = mul(input.Pos, viewProjMatrix);
	Out.wPos = mul(input.Pos, worldViewMatrix);

	// Cross product to create BiNormal
	float3 binormal = normalize(cross(input.Tan, input.Normal));

	// Calculate tangent->view space transformation
	float3x3 tanBasis = float3x3(input.Tan, binormal, input.Normal);
	float3x3 tanToView = transpose(mul(tanBasis, worldViewITMatrix));
	Out.Mat1 = tanToView[0];
	Out.Mat2 = tanToView[1];
	Out.Mat3 = tanToView[2];

	// Pass-through texcoords
	Out.Tex0Diff = input.TexCoordDiff;
	return Out;
}

PS2FB_fullMRT psGBuffBase(VS_OUT_vsGBuffBase indata)
{
	PS2FB_fullMRT outdata;

	outdata.Col0 = 1;
	outdata.Col1 = indata.wPos;

	float4 expandedNormal = tex2D(samplerWrap1, indata.Tex0Diff);
	expandedNormal.xyz = (expandedNormal.xyz * 2) - 1;
	outdata.Col2.x = dot(expandedNormal, indata.Mat1);
	outdata.Col2.y = dot(expandedNormal, indata.Mat2);
	outdata.Col2.z = dot(expandedNormal, indata.Mat3);
	outdata.Col2.w = expandedNormal.w;

	return outdata;
}


struct appdata_GBuffBaseLM{
    float4 Pos : POSITION;
    float2 TexCoordDiff : TEXCOORD0;
    float2 TexCoordLMap : TEXCOORD1;
    float3 Tan : TANGENT;
    float3 Normal : NORMAL;
};


struct VS_OUT_GBuffBaseLM {
	float4 HPos : POSITION;
	float2 Tex0Diff : TEXCOORD0;
	float2 Tex1LMap : TEXCOORD1;
    	float4 wPos : TEXCOORD2;
	float3 Mat1 : TEXCOORD3;
	float3 Mat2 : TEXCOORD4;
	float3 Mat3 : TEXCOORD5;
};


VS_OUT_GBuffBaseLM vsGBuffBaseLM(appdata_GBuffBaseLM input)
{
	VS_OUT_GBuffBaseLM Out;

 	Out.HPos = mul(input.Pos, viewProjMatrix);
	Out.wPos = mul(input.Pos, worldViewMatrix);

	// Cross product to create BiNormal
	float3 binormal = normalize(cross(input.Tan, input.Normal));

	// Calculate tangent->view space transformation
	float3x3 tanBasis = float3x3(input.Tan, binormal, input.Normal);
	float3x3 tanToView = transpose(mul(tanBasis, worldViewITMatrix));
	Out.Mat1 = tanToView[0];
	Out.Mat2 = tanToView[1];
	Out.Mat3 = tanToView[2];

	// Pass-through texcoords
	Out.Tex0Diff = input.TexCoordDiff;
	Out.Tex1LMap = (input.TexCoordLMap*lightmapOffset.xy) + lightmapOffset.zw;

	return Out;
}

PS2FB_fullMRT psGBuffBaseLM(VS_OUT_GBuffBaseLM indata)
{
	PS2FB_fullMRT outdata;

	outdata.Col0 = tex2D(samplerWrap2, indata.Tex1LMap);
	outdata.Col1 = indata.wPos;

	float4 expandedNormal = tex2D(samplerWrap1, indata.Tex0Diff);
	expandedNormal.xyz = (expandedNormal.xyz * 2) - 1;
	outdata.Col2.x = dot(expandedNormal, indata.Mat1);
	outdata.Col2.y = dot(expandedNormal, indata.Mat2);
	outdata.Col2.z = dot(expandedNormal, indata.Mat3);
	outdata.Col2.w = expandedNormal.w;

	return outdata;
}

struct VS_OUT_GBuffBaseLMAT {
	float4 HPos : POSITION;
	float2 Tex0Diff : TEXCOORD0;
	float2 Tex1LMap : TEXCOORD1;
    float4 wPos : TEXCOORD2;
	float3 Mat1 : TEXCOORD3;
	float3 Mat2 : TEXCOORD4;
	float3 Mat3 : TEXCOORD5;
	float4 TexCoord6 : TEXCOORD6;
};


VS_OUT_GBuffBaseLMAT vsGBuffBaseLMAT(appdata_GBuffBaseLM input)
{
	VS_OUT_GBuffBaseLMAT Out;

 	Out.HPos = mul(input.Pos, viewProjMatrix);
	Out.wPos = mul(input.Pos, worldViewMatrix);

	// Cross product to create BiNormal
	float3 binormal = normalize(cross(input.Tan, input.Normal));

	// Calculate tangent->view space transformation
	float3x3 tanBasis = float3x3(input.Tan, binormal, input.Normal);
	float3x3 tanToView = transpose(mul(tanBasis, worldViewITMatrix));
	Out.Mat1 = tanToView[0];
	Out.Mat2 = tanToView[1];
	Out.Mat3 = tanToView[2];


	// Pass-through texcoords
	Out.Tex0Diff = input.TexCoordDiff;
	Out.Tex1LMap = (input.TexCoordLMap*lightmapOffset.xy) + lightmapOffset.zw;


// Hacked to only support 800/600
 	Out.TexCoord6.xy = Out.HPos.xy/Out.HPos.w;
 	Out.TexCoord6.xy = (Out.TexCoord6.xy * 0.5) + 0.5;
 	Out.TexCoord6.y = 1-Out.TexCoord6.y;
Out.TexCoord6.x += 0.000625;
Out.TexCoord6.y += 0.000833;
	Out.TexCoord6.xy = Out.TexCoord6.xy * Out.HPos.w;
	Out.TexCoord6.zw = Out.HPos.zw;

	return Out;
}

PS2FB_fullMRT4 psGBuffBaseLMAT0(VS_OUT_GBuffBaseLMAT indata)
{
	PS2FB_fullMRT4 outdata;

	float4 diffTex = tex2D(samplerWrapAniso0, indata.Tex0Diff);
	// float newDepth = indata.wPos.w + (1-diffTex.a);
	// outdata.Depth = newDepth;
	// clip(diffTex.a-0.1);

	float4 rtlightmap = tex2Dproj(sampler3clamppoint, indata.TexCoord6);
	float4 rtposmap = tex2Dproj(sampler4clamppoint, indata.TexCoord6);
	float4 rtnormalmap = tex2Dproj(sampler5clamppoint, indata.TexCoord6);
	float4 rtdiffmap = tex2Dproj(sampler6clamppoint, indata.TexCoord6);

	float4 LMap = tex2D(samplerWrap2, indata.Tex1LMap);
	outdata.Col0 = (diffTex.a >= 50.0/255.0) ? LMap : rtlightmap;
	outdata.Col1 = (diffTex.a >= 50.0/255.0) ? float4(indata.wPos.rgb, 0): rtposmap;
	float4 expandedNormal = tex2D(samplerWrap1, indata.Tex0Diff);
	expandedNormal.xyz = (expandedNormal.xyz * 2) - 1;
	float4 rotatedNormal;
	rotatedNormal.x = dot(expandedNormal, indata.Mat1);
	rotatedNormal.y = dot(expandedNormal, indata.Mat2);
	rotatedNormal.z = dot(expandedNormal, indata.Mat3);
	rotatedNormal.w = 0;
	outdata.Col2 = (diffTex.a >= 50.0/255.0) ? rotatedNormal : rtnormalmap;
	outdata.Col3 = (diffTex.a >= 50.0/255.0) ? diffTex : rtdiffmap;

	return outdata;
}

struct VS_OUT_GBuffBaseLMAT1 {
	float4 Pos : POSITION;
	float4 TexCoord0 : TEXCOORD0;
};

VS_OUT_GBuffBaseLMAT1 vsGBuffBaseLMAT1(appdata_GBuffBaseLM indata)
{
	VS_OUT_GBuffBaseLMAT1 outdata;

  	outdata.Pos = mul(indata.Pos, viewProjMatrix);

 	outdata.TexCoord0.xy = outdata.Pos.xy/outdata.Pos.w;
 	outdata.TexCoord0.xy = (outdata.TexCoord0.xy * 0.5) + 0.5;
 	outdata.TexCoord0.y = 1-outdata.TexCoord0.y;
outdata.TexCoord0.x += 0.000625;
outdata.TexCoord0.y += 0.000833;
	outdata.TexCoord0.xy = outdata.TexCoord0.xy * outdata.Pos.w;
	outdata.TexCoord0.zw = outdata.Pos.zw;

	return outdata;
}

float4 psGBuffBaseLMAT1_Diffuse(VS_OUT_GBuffBaseLMAT1 indata) : COLOR
{
	return tex2Dproj(sampler3clamppoint, indata.TexCoord0);
}

PS2FB_fullMRT psGBuffBaseLMAT1_MRT(VS_OUT_GBuffBaseLMAT1 indata)
{
	PS2FB_fullMRT outdata;

	outdata.Col0 = tex2Dproj(sampler0clamppoint, indata.TexCoord0);
	outdata.Col1 = tex2Dproj(sampler1clamppoint, indata.TexCoord0);
	outdata.Col2 = tex2Dproj(sampler2clamppoint, indata.TexCoord0);

	return outdata;
}

struct appdata_GBuffBaseDetail {
    float4 Pos : POSITION;
    float2 TexCoordDetail : TEXCOORD0;
    float3 Tan : TANGENT;
    float3 Normal : NORMAL;
};

struct VS_OUT_GBuffBaseDetail {
	float4 HPos : POSITION;
	float2 Tex1Detail : TEXCOORD0;
    float4 wPos : TEXCOORD1;
	float3 Mat1 : TEXCOORD2;
	float3 Mat2 : TEXCOORD3;
	float3 Mat3 : TEXCOORD4;
};

VS_OUT_GBuffBaseDetail vsGBuffBaseDetail(appdata_GBuffBaseDetail input)
{
	VS_OUT_GBuffBaseDetail Out;

 	Out.HPos = mul(input.Pos, viewProjMatrix);
	Out.wPos = mul(input.Pos, worldViewMatrix);

	// Cross product to create BiNormal
	float3 binormal = normalize(cross(input.Tan, input.Normal));

	// Calculate tangent->view space transformation
	float3x3 tanBasis = float3x3(input.Tan, binormal, input.Normal);
	float3x3 tanToView = transpose(mul(tanBasis, worldViewITMatrix));
	Out.Mat1 = tanToView[0];
	Out.Mat2 = tanToView[1];
	Out.Mat3 = tanToView[2];

	// Pass-through texcoords
	Out.Tex1Detail = input.TexCoordDetail;
	return Out;
}

PS2FB_fullMRT psGBuffBaseDetail(VS_OUT_GBuffBaseDetail indata)
{
	PS2FB_fullMRT outdata;

	outdata.Col0 = 1;
	outdata.Col1 = indata.wPos;

	float4 expandedNormal = tex2D(samplerWrap2, indata.Tex1Detail);
	expandedNormal.xyz = (expandedNormal.xyz * 2) - 1;
	outdata.Col2.x = dot(expandedNormal, indata.Mat1);
	outdata.Col2.y = dot(expandedNormal, indata.Mat2);
	outdata.Col2.z = dot(expandedNormal, indata.Mat3);
	outdata.Col2.w = expandedNormal.w;

	return outdata;
}

struct VS_OUT_GBuffBaseDetailParallax {
	float4 HPos : POSITION;
	float2 Tex1Detail : TEXCOORD0;
    float4 wPos : TEXCOORD1;
	float3 Mat1 : TEXCOORD2;
	float3 Mat2 : TEXCOORD3;
	float3 Mat3 : TEXCOORD4;
   	float3 tanEyeVec : TEXCOORD5;
};

VS_OUT_GBuffBaseDetailParallax vsGBuffBaseDetailParallax(appdata_GBuffBaseDetail input)
{
	VS_OUT_GBuffBaseDetailParallax Out;

 	Out.HPos = mul(input.Pos, viewProjMatrix);
	Out.wPos = mul(input.Pos, worldViewMatrix);

	// Cross product to create BiNormal
	float3 binormal = normalize(cross(input.Tan, input.Normal));

	// Calculate tangent->view space transformation
	float3x3 tanBasis = float3x3(input.Tan, binormal, input.Normal);
	Out.tanEyeVec = mul(eyePosObjectSpace.xyz-input.Pos.xyz, tanBasis);
	float3x3 tanToView = transpose(mul(tanBasis, worldViewITMatrix));
	Out.Mat1 = tanToView[0];
	Out.Mat2 = tanToView[1];
	Out.Mat3 = tanToView[2];

	// Pass-through texcoords
	Out.Tex1Detail = input.TexCoordDetail;
	return Out;
}

PS2FB_fullMRT psGBuffBaseDetailParallax(VS_OUT_GBuffBaseDetailParallax indata)
{
	PS2FB_fullMRT outdata;

	outdata.Col0 = 1;
	outdata.Col1 = indata.wPos;

	float2 newTex1Detail = calculateOffsetCoordinatesFromAlpha(indata.Tex1Detail.xy, indata.Tex1Detail.xy, samplerWrap1, parallaxScaleBias, indata.tanEyeVec);

	float4 expandedNormal = tex2D(samplerWrap2, newTex1Detail);
	expandedNormal.xyz = (expandedNormal.xyz * 2) - 1;
	outdata.Col2.x = dot(expandedNormal, indata.Mat1);
	outdata.Col2.y = dot(expandedNormal, indata.Mat2);
	outdata.Col2.z = dot(expandedNormal, indata.Mat3);
	outdata.Col2.w = expandedNormal.w;

	return outdata;
}

struct appdata_GBuffBaseDetailLM {
    float4 Pos : POSITION;
    float2 TexCoordDetail : TEXCOORD0;
    float2 TexCoordLMap : TEXCOORD1;
    float3 Tan : TANGENT;
    float3 Normal : NORMAL;
};

struct VS_OUT_GBuffBaseDetailLM {
	float4 HPos : POSITION;
	float2 Tex1Detail : TEXCOORD0;
	float2 Tex2LMap : TEXCOORD1;
    	float4 wPos : TEXCOORD2;
	float3 Mat1 : TEXCOORD3;
	float3 Mat2 : TEXCOORD4;
	float3 Mat3 : TEXCOORD5;
};

VS_OUT_GBuffBaseDetailLM vsGBuffBaseDetailLM(appdata_GBuffBaseDetailLM input)
{
	VS_OUT_GBuffBaseDetailLM Out;

  	Out.HPos = mul(input.Pos, viewProjMatrix);
	Out.wPos = mul(input.Pos, worldViewMatrix);

	// Cross product to create BiNormal
	float3 binormal = normalize(cross(input.Tan, input.Normal));

	// Calculate tangent->view space transformation
	float3x3 tanBasis = float3x3(input.Tan, binormal, input.Normal);
	float3x3 tanToView = transpose(mul(tanBasis, worldViewITMatrix));
	Out.Mat1 = tanToView[0];
	Out.Mat2 = tanToView[1];
	Out.Mat3 = tanToView[2];

	// Pass-through texcoords
	Out.Tex1Detail = input.TexCoordDetail;
	Out.Tex2LMap = (input.TexCoordLMap*lightmapOffset.xy) + lightmapOffset.zw;
	return Out;
}

PS2FB_fullMRT psGBuffBaseDetailLM(VS_OUT_GBuffBaseDetailLM indata)
{
	PS2FB_fullMRT outdata;

	outdata.Col0 = tex2D(samplerWrap3, indata.Tex2LMap);
	outdata.Col1 = indata.wPos;

	float4 expandedNormal = tex2D(samplerWrap2, indata.Tex1Detail);
	expandedNormal.xyz = (expandedNormal.xyz * 2) - 1;
	outdata.Col2.x = dot(expandedNormal, indata.Mat1);
	outdata.Col2.y = dot(expandedNormal, indata.Mat2);
	outdata.Col2.z = dot(expandedNormal, indata.Mat3);
	outdata.Col2.w = expandedNormal.w;

	return outdata;
}

struct VS_OUT_GBuffBaseDetailLMParallax {
	float4 HPos : POSITION;
	float2 Tex1Detail : TEXCOORD0;
	float2 Tex2LMap : TEXCOORD1;
    	float4 wPos : TEXCOORD2;
	float3 Mat1 : TEXCOORD3;
	float3 Mat2 : TEXCOORD4;
	float3 Mat3 : TEXCOORD5;
   	float3 tanEyeVec : TEXCOORD6;
};

VS_OUT_GBuffBaseDetailLMParallax vsGBuffBaseDetailLMParallax(appdata_GBuffBaseDetailLM input)
{
	VS_OUT_GBuffBaseDetailLMParallax Out;

  	Out.HPos = mul(input.Pos, viewProjMatrix);
	Out.wPos = mul(input.Pos, worldViewMatrix);

	// Cross product to create BiNormal
	float3 binormal = normalize(cross(input.Tan, input.Normal));

	// Calculate tangent->view space transformation
	float3x3 tanBasis = float3x3(input.Tan, binormal, input.Normal);
	Out.tanEyeVec = mul((eyePosObjectSpace.xyz-input.Pos.xyz), tanBasis);
	float3x3 tanToView = transpose(mul(tanBasis, worldViewITMatrix));
	Out.Mat1 = tanToView[0];
	Out.Mat2 = tanToView[1];
	Out.Mat3 = tanToView[2];

	// Pass-through texcoords
	Out.Tex1Detail = input.TexCoordDetail;
	Out.Tex2LMap = (input.TexCoordLMap*lightmapOffset.xy) + lightmapOffset.zw;
	return Out;
}

PS2FB_fullMRT psGBuffBaseDetailLMParallax(VS_OUT_GBuffBaseDetailLMParallax indata)
{
	PS2FB_fullMRT outdata;

	float2 newTex1Detail = calculateOffsetCoordinatesFromAlpha(indata.Tex1Detail.xy, indata.Tex1Detail.xy, samplerWrap1, parallaxScaleBias, indata.tanEyeVec);

	float4 expandedNormal = tex2D(samplerWrap2, newTex1Detail);
	expandedNormal.xyz = (expandedNormal.xyz * 2) - 1;
	outdata.Col2.x = dot(expandedNormal, indata.Mat1);
	outdata.Col2.y = dot(expandedNormal, indata.Mat2);
	outdata.Col2.z = dot(expandedNormal, indata.Mat3);
	outdata.Col2.w = expandedNormal.w;

	outdata.Col0 = tex2D(samplerWrap3, indata.Tex2LMap.xy);
	outdata.Col1 = indata.wPos;

	return outdata;
}

struct appdata_GBuffBaseDetailDirt {
    float4 Pos : POSITION;
    float2 TexCoordDetail : TEXCOORD0;
    float3 Tan : TANGENT;
    float3 Normal : NORMAL;
   };

struct VS_OUT_GBuffBaseDetailDirt {
	float4 HPos : POSITION;
	float2 Tex1Detail : TEXCOORD0;
   	float4 wPos : TEXCOORD1;
	float3 Mat1 : TEXCOORD2;
	float3 Mat2 : TEXCOORD3;
	float3 Mat3 : TEXCOORD4;
};

VS_OUT_GBuffBaseDetailDirt vsGBuffBaseDetailDirt(appdata_GBuffBaseDetailDirt input)
{
	VS_OUT_GBuffBaseDetailDirt Out;

 	Out.HPos = mul(input.Pos, viewProjMatrix);
	Out.wPos = mul(input.Pos, worldViewMatrix);

	// Cross product to create BiNormal
	float3 binormal = normalize(cross(input.Tan, input.Normal));

	// Calculate tangent->view space transformation
	float3x3 tanBasis = float3x3(input.Tan, binormal, input.Normal);
	float3x3 tanToView = transpose(mul(tanBasis, worldViewITMatrix));
	Out.Mat1 = tanToView[0];
	Out.Mat2 = tanToView[1];
	Out.Mat3 = tanToView[2];

	// Pass-through texcoords
	Out.Tex1Detail = input.TexCoordDetail;

	return Out;
}

PS2FB_fullMRT psGBuffBaseDetailDirt(VS_OUT_GBuffBaseDetailDirt indata)
{
	PS2FB_fullMRT outdata;

	outdata.Col0 = 1;
	outdata.Col1 = indata.wPos;

	float4 expandedNormal = tex2D(samplerWrap3, indata.Tex1Detail);
	expandedNormal.xyz = (expandedNormal.xyz * 2) - 1;
	outdata.Col2.x = dot(expandedNormal, indata.Mat1);
	outdata.Col2.y = dot(expandedNormal, indata.Mat2);
	outdata.Col2.z = dot(expandedNormal, indata.Mat3);
	outdata.Col2.w = expandedNormal.w;

	return outdata;
}

struct VS_OUT_GBuffBaseDetailDirtParallax {
	float4 HPos : POSITION;
	float2 Tex1Detail : TEXCOORD0;
   	float4 wPos : TEXCOORD1;
	float3 Mat1 : TEXCOORD2;
	float3 Mat2 : TEXCOORD3;
	float3 Mat3 : TEXCOORD4;
   	float3 tanEyeVec : TEXCOORD5;
};

VS_OUT_GBuffBaseDetailDirtParallax vsGBuffBaseDetailDirtParallax(appdata_GBuffBaseDetailDirt input)
{
	VS_OUT_GBuffBaseDetailDirtParallax Out;

 	Out.HPos = mul(input.Pos, viewProjMatrix);
	Out.wPos = mul(input.Pos, worldViewMatrix);

	// Cross product to create BiNormal
	float3 binormal = normalize(cross(input.Tan, input.Normal));

	// Calculate tangent->view space transformation
	float3x3 tanBasis = float3x3(input.Tan, binormal, input.Normal);
	Out.tanEyeVec = mul(eyePosObjectSpace.xyz-input.Pos.xyz, tanBasis);
	float3x3 tanToView = transpose(mul(tanBasis, worldViewITMatrix));
	Out.Mat1 = tanToView[0];
	Out.Mat2 = tanToView[1];
	Out.Mat3 = tanToView[2];

	// Pass-through texcoords
	Out.Tex1Detail = input.TexCoordDetail;

	return Out;
}

PS2FB_fullMRT psGBuffBaseDetailDirtParallax(VS_OUT_GBuffBaseDetailDirtParallax indata)
{
	PS2FB_fullMRT outdata;

	outdata.Col0 = 1;
	outdata.Col1 = indata.wPos;

	float2 newTex1Detail = calculateOffsetCoordinatesFromAlpha(indata.Tex1Detail.xy, indata.Tex1Detail.xy, samplerWrap1, parallaxScaleBias, indata.tanEyeVec);

	float4 expandedNormal = tex2D(samplerWrap3, newTex1Detail);
	expandedNormal.xyz = (expandedNormal.xyz * 2) - 1;
	outdata.Col2.x = dot(expandedNormal, indata.Mat1);
	outdata.Col2.y = dot(expandedNormal, indata.Mat2);
	outdata.Col2.z = dot(expandedNormal, indata.Mat3);
	outdata.Col2.w = expandedNormal.w;

	return outdata;
}

struct appdata_GBuffBaseDetailDirtLM {
    float4 Pos : POSITION;
    float2 TexCoordDetail : TEXCOORD0;
	float2 TexCoordLMap : TEXCOORD1;
    float3 Tan : TANGENT;
    float3 Normal : NORMAL;
};

struct VS_OUT_GBuffBaseDetailDirtLM {
	float4 HPos : POSITION;
	float2 Tex1Detail : TEXCOORD0;
	float2 Tex3LMap : TEXCOORD1;
   	float4 wPos : TEXCOORD2;
	float3 Mat1 : TEXCOORD3;
	float3 Mat2 : TEXCOORD4;
	float3 Mat3 : TEXCOORD5;
};

VS_OUT_GBuffBaseDetailDirtLM vsGBuffBaseDetailDirtLM(appdata_GBuffBaseDetailDirtLM input)
{
	VS_OUT_GBuffBaseDetailDirtLM Out;

 	Out.HPos = mul(input.Pos, viewProjMatrix);
	Out.wPos = mul(input.Pos, worldViewMatrix);

	// Cross product to create BiNormal
	float3 binormal = normalize(cross(input.Tan, input.Normal));

	// Calculate tangent->view space transformation
	float3x3 tanBasis = float3x3(input.Tan, binormal, input.Normal);
	float3x3 tanToView = transpose(mul(tanBasis, worldViewITMatrix));
	Out.Mat1 = tanToView[0];
	Out.Mat2 = tanToView[1];
	Out.Mat3 = tanToView[2];

	// Pass-through texcoords
	Out.Tex1Detail = input.TexCoordDetail;
	Out.Tex3LMap = (input.TexCoordLMap*lightmapOffset.xy) + lightmapOffset.zw;
	return Out;
}

PS2FB_fullMRT psGBuffBaseDetailDirtLM(VS_OUT_GBuffBaseDetailDirtLM indata)
{
	PS2FB_fullMRT outdata;

	float4 lightmap = tex2D(samplerWrap4, indata.Tex3LMap);

	outdata.Col0 = lightmap;
	outdata.Col1 = indata.wPos;

	float4 expandedNormal = tex2D(samplerWrap3, indata.Tex1Detail);
	expandedNormal.xyz = (expandedNormal.xyz * 2) - 1;
	outdata.Col2.x = dot(expandedNormal, indata.Mat1);
	outdata.Col2.y = dot(expandedNormal, indata.Mat2);
	outdata.Col2.z = dot(expandedNormal, indata.Mat3);
	outdata.Col2.w = expandedNormal.w;

	return outdata;
}

struct VS_OUT_GBuffBaseDetailDirtLMParallax {
	float4 HPos : POSITION;
	float2 Tex1Detail : TEXCOORD0;
	float2 Tex3LMap : TEXCOORD1;
   	float4 wPos : TEXCOORD2;
	float3 Mat1 : TEXCOORD3;
	float3 Mat2 : TEXCOORD4;
	float3 Mat3 : TEXCOORD5;
   	float3 tanEyeVec : TEXCOORD6;
};

VS_OUT_GBuffBaseDetailDirtLMParallax vsGBuffBaseDetailDirtLMParallax(appdata_GBuffBaseDetailDirtLM input)
{
	VS_OUT_GBuffBaseDetailDirtLMParallax Out;

 	Out.HPos = mul(input.Pos, viewProjMatrix);
	Out.wPos = mul(input.Pos, worldViewMatrix);

	// Cross product to create BiNormal
	float3 binormal = normalize(cross(input.Tan, input.Normal));

	// Calculate tangent->view space transformation
	float3x3 tanBasis = float3x3(input.Tan, binormal, input.Normal);
	Out.tanEyeVec = mul(eyePosObjectSpace.xyz-input.Pos.xyz, tanBasis);
	float3x3 tanToView = transpose(mul(tanBasis, worldViewITMatrix));
	Out.Mat1 = tanToView[0];
	Out.Mat2 = tanToView[1];
	Out.Mat3 = tanToView[2];

	// Pass-through texcoords
	Out.Tex1Detail = input.TexCoordDetail;
	Out.Tex3LMap = (input.TexCoordLMap*lightmapOffset.xy) + lightmapOffset.zw;
	return Out;
}

PS2FB_fullMRT psGBuffBaseDetailDirtLMParallax(VS_OUT_GBuffBaseDetailDirtLMParallax indata)
{
	PS2FB_fullMRT outdata;

	float2 newTex1Detail = calculateOffsetCoordinatesFromAlpha(indata.Tex1Detail.xy, indata.Tex1Detail.xy, samplerWrap1, parallaxScaleBias, indata.tanEyeVec);

	float4 lightmap = tex2D(samplerWrap4, indata.Tex3LMap.xy);

	outdata.Col0 = lightmap;
	outdata.Col1 = indata.wPos;

	float4 expandedNormal = tex2D(samplerWrap3, newTex1Detail);
	expandedNormal.xyz = (expandedNormal.xyz * 2) - 1;
	outdata.Col2.x = dot(expandedNormal, indata.Mat1);
	outdata.Col2.y = dot(expandedNormal, indata.Mat2);
	outdata.Col2.z = dot(expandedNormal, indata.Mat3);
	outdata.Col2.w = expandedNormal.w;

	return outdata;
}

struct appdata_GBuffBaseDetailCrack {
    float4 Pos : POSITION;
    float2 TexCoordDetail : TEXCOORD0;
    float2 TexCoordCrack : TEXCOORD1;
    float3 Tan : TANGENT;
    float3 Normal : NORMAL;
   };

struct VS_OUT_GBuffBaseDetailCrack {
	float4 HPos : POSITION;
	float2 Tex1Detail : TEXCOORD0;
	float2 Tex2Crack : TEXCOORD1;
    	float4 wPos : TEXCOORD2;
	float3 Mat1 : TEXCOORD3;
	float3 Mat2 : TEXCOORD4;
	float3 Mat3 : TEXCOORD5;
};

VS_OUT_GBuffBaseDetailCrack vsGBuffBaseDetailCrack(appdata_GBuffBaseDetailCrack input)
{
	VS_OUT_GBuffBaseDetailCrack Out;

 	Out.HPos = mul(input.Pos, viewProjMatrix);
	Out.wPos = mul(input.Pos, worldViewMatrix);

	// Cross product to create BiNormal
	float3 binormal = normalize(cross(input.Tan, input.Normal));

	// Calculate tangent->view space transformation
	float3x3 tanBasis = float3x3(input.Tan, binormal, input.Normal);
	float3x3 tanToView = transpose(mul(tanBasis, worldViewITMatrix));
	Out.Mat1 = tanToView[0];
	Out.Mat2 = tanToView[1];
	Out.Mat3 = tanToView[2];

	// Pass-through texcoords
	Out.Tex1Detail = input.TexCoordDetail;
	Out.Tex2Crack = input.TexCoordCrack;

	return Out;
}

PS2FB_fullMRT psGBuffBaseDetailCrack(VS_OUT_GBuffBaseDetailCrack indata)
{
	PS2FB_fullMRT outdata;

	float4 crack = tex2D(samplerWrap2, indata.Tex2Crack);
	float4 detailNormal = tex2D(samplerWrap3, indata.Tex1Detail) * (1-crack.a);
	float4 crackNormal = tex2D(samplerWrap4, indata.Tex2Crack) * crack.a;

	outdata.Col0 = 1;
	outdata.Col1 = indata.wPos;

	float4 expandedNormal = (detailNormal+crackNormal);
	expandedNormal.xyz = normalize((expandedNormal.xyz * 2) - 1);
	outdata.Col2.x = dot(expandedNormal, indata.Mat1);
	outdata.Col2.y = dot(expandedNormal, indata.Mat2);
	outdata.Col2.z = dot(expandedNormal, indata.Mat3);
	outdata.Col2.w = expandedNormal.w;

	return outdata;
}

struct VS_OUT_GBuffBaseDetailCrackParallax {
	float4 HPos : POSITION;
	float2 Tex1Detail : TEXCOORD0;
	float2 Tex2Crack : TEXCOORD1;
    	float4 wPos : TEXCOORD2;
	float3 Mat1 : TEXCOORD3;
	float3 Mat2 : TEXCOORD4;
	float3 Mat3 : TEXCOORD5;
   	float3 tanEyeVec : TEXCOORD6;
};

VS_OUT_GBuffBaseDetailCrackParallax vsGBuffBaseDetailCrackParallax(appdata_GBuffBaseDetailCrack input)
{
	VS_OUT_GBuffBaseDetailCrackParallax Out;

 	Out.HPos = mul(input.Pos, viewProjMatrix);
	Out.wPos = mul(input.Pos, worldViewMatrix);

	// Cross product to create BiNormal
	float3 binormal = normalize(cross(input.Tan, input.Normal));

	// Calculate tangent->view space transformation
	float3x3 tanBasis = float3x3(input.Tan, binormal, input.Normal);
	Out.tanEyeVec = mul(eyePosObjectSpace.xyz-input.Pos.xyz, tanBasis);
	float3x3 tanToView = transpose(mul(tanBasis, worldViewITMatrix));
	Out.Mat1 = tanToView[0];
	Out.Mat2 = tanToView[1];
	Out.Mat3 = tanToView[2];

	// Pass-through texcoords
	Out.Tex1Detail = input.TexCoordDetail;
	Out.Tex2Crack = input.TexCoordCrack;

	return Out;
}

PS2FB_fullMRT psGBuffBaseDetailCrackParallax(VS_OUT_GBuffBaseDetailCrackParallax indata)
{
	PS2FB_fullMRT outdata;

	float2 newTex1Detail = calculateOffsetCoordinatesFromAlpha(indata.Tex1Detail.xy, indata.Tex1Detail.xy, samplerWrap1, parallaxScaleBias, indata.tanEyeVec);

	float4 crack = tex2D(samplerWrap2, indata.Tex2Crack);
	float4 detailNormal = tex2D(samplerWrap3, newTex1Detail) * (1-crack.a);
	float4 crackNormal = tex2D(samplerWrap4, indata.Tex2Crack) * crack.a;

	outdata.Col0 = 1;
	outdata.Col1 = indata.wPos;

	float4 expandedNormal = (detailNormal+crackNormal);
	expandedNormal.xyz = normalize((expandedNormal.xyz * 2) - 1);
	outdata.Col2.x = dot(expandedNormal, indata.Mat1);
	outdata.Col2.y = dot(expandedNormal, indata.Mat2);
	outdata.Col2.z = dot(expandedNormal, indata.Mat3);
	outdata.Col2.w = expandedNormal.w;

	return outdata;
}

struct appdata_GBuffBaseDetailCrackLM {
    float4 Pos : POSITION;
    float2 TexCoordDetail : TEXCOORD0;
    float2 TexCoordCrack : TEXCOORD1;
	float2 TexCoordLMap : TEXCOORD2;
    float3 Tan : TANGENT;
    float3 Normal : NORMAL;
};

struct VS_OUT_GBuffBaseDetailCrackLM {
	float4 HPos : POSITION;
	float2 Tex1Detail : TEXCOORD0;
	float2 Tex2Crack : TEXCOORD1;
	float2 Tex3LMap : TEXCOORD2;
    float4 wPos : TEXCOORD3;
	float3 Mat1 : TEXCOORD4;
	float3 Mat2 : TEXCOORD5;
	float3 Mat3 : TEXCOORD6;
};

VS_OUT_GBuffBaseDetailCrackLM vsGBuffBaseDetailCrackLM(appdata_GBuffBaseDetailCrackLM input)
{
	VS_OUT_GBuffBaseDetailCrackLM Out;

 	Out.HPos = mul(input.Pos, viewProjMatrix);
	Out.wPos = mul(input.Pos, worldViewMatrix);

	// Cross product to create BiNormal
	float3 binormal = normalize(cross(input.Tan, input.Normal));

	// Calculate tangent->view space transformation
	float3x3 tanBasis = float3x3(input.Tan, binormal, input.Normal);
	float3x3 tanToView = transpose(mul(tanBasis, worldViewITMatrix));
	Out.Mat1 = tanToView[0];
	Out.Mat2 = tanToView[1];
	Out.Mat3 = tanToView[2];

	// Pass-through texcoords
	Out.Tex1Detail = input.TexCoordDetail;
	Out.Tex2Crack = input.TexCoordCrack;
	Out.Tex3LMap = (input.TexCoordLMap*lightmapOffset.xy) + lightmapOffset.zw;
	return Out;
}

PS2FB_fullMRT psGBuffBaseDetailCrackLM(VS_OUT_GBuffBaseDetailCrackLM indata)
{
	PS2FB_fullMRT outdata;

	float4 crack = tex2D(samplerWrap2, indata.Tex2Crack);
	float4 detailNormal = tex2D(samplerWrap3, indata.Tex1Detail) * (1-crack.a);
	float4 crackNormal = tex2D(samplerWrap4, indata.Tex2Crack) * crack.a;
	float4 lightmap = tex2D(samplerWrap5, indata.Tex3LMap);

	outdata.Col0 = lightmap;
	outdata.Col1 = indata.wPos;

	float4 expandedNormal = detailNormal + crackNormal;
	expandedNormal.xyz = normalize((expandedNormal.xyz * 2) - 1);
	outdata.Col2.x = dot(expandedNormal, indata.Mat1);
	outdata.Col2.y = dot(expandedNormal, indata.Mat2);
	outdata.Col2.z = dot(expandedNormal, indata.Mat3);
	outdata.Col2.w = expandedNormal.w;

	return outdata;
}

struct VS_OUT_GBuffBaseDetailCrackLMParallax {
	float4 HPos : POSITION;
	float2 Tex1Detail : TEXCOORD0;
	float2 Tex2Crack : TEXCOORD1;
	float2 Tex3LMap : TEXCOORD2;
    float4 wPos : TEXCOORD3;
	float3 Mat1 : TEXCOORD4;
	float3 Mat2 : TEXCOORD5;
	float3 Mat3 : TEXCOORD6;
   	float3 tanEyeVec : TEXCOORD7;
};

VS_OUT_GBuffBaseDetailCrackLMParallax vsGBuffBaseDetailCrackLMParallax(appdata_GBuffBaseDetailCrackLM input)
{
	VS_OUT_GBuffBaseDetailCrackLMParallax Out;

 	Out.HPos = mul(input.Pos, viewProjMatrix);
	Out.wPos = mul(input.Pos, worldViewMatrix);

	// Cross product to create BiNormal
	float3 binormal = normalize(cross(input.Tan, input.Normal));

	// Calculate tangent->view space transformation
	float3x3 tanBasis = float3x3(input.Tan, binormal, input.Normal);
	Out.tanEyeVec = mul(eyePosObjectSpace.xyz-input.Pos.xyz, tanBasis);
	float3x3 tanToView = transpose(mul(tanBasis, worldViewITMatrix));
	Out.Mat1 = tanToView[0];
	Out.Mat2 = tanToView[1];
	Out.Mat3 = tanToView[2];

	// Pass-through texcoords
	Out.Tex1Detail = input.TexCoordDetail;
	Out.Tex2Crack = input.TexCoordCrack;
	Out.Tex3LMap = (input.TexCoordLMap*lightmapOffset.xy) + lightmapOffset.zw;
	return Out;
}

PS2FB_fullMRT psGBuffBaseDetailCrackLMParallax(VS_OUT_GBuffBaseDetailCrackLMParallax indata)
{
	PS2FB_fullMRT outdata;

	float2 newTex1Detail = calculateOffsetCoordinatesFromAlpha(indata.Tex1Detail.xy, indata.Tex1Detail.xy, samplerWrap1, parallaxScaleBias, indata.tanEyeVec);

	float4 crack = tex2D(samplerWrap2, indata.Tex2Crack);
	float4 detailNormal = tex2D(samplerWrap3, newTex1Detail) * (1-crack.a);
	float4 crackNormal = tex2D(samplerWrap4, indata.Tex2Crack) * crack.a;
	float4 lightmap = tex2D(samplerWrap5, indata.Tex3LMap.xy);

	outdata.Col0 = lightmap;
	outdata.Col1 = indata.wPos;

	float4 expandedNormal = detailNormal + crackNormal;
	expandedNormal.xyz = normalize((expandedNormal.xyz * 2) - 1);
	outdata.Col2.x = dot(expandedNormal, indata.Mat1);
	outdata.Col2.y = dot(expandedNormal, indata.Mat2);
	outdata.Col2.z = dot(expandedNormal, indata.Mat3);
	outdata.Col2.w = expandedNormal.w;

	return outdata;
}

struct appdata_GBuffBaseDetailDirtCrack {
    float4 Pos : POSITION;
    float2 TexCoordDetail : TEXCOORD0;
    float2 TexCoordCrack : TEXCOORD1;
    float3 Tan : TANGENT;
    float3 Normal : NORMAL;
   };

struct VS_OUT_GBuffBaseDetailDirtCrack {
	float4 HPos : POSITION;
	float2 Tex1Detail : TEXCOORD0;
	float2 Tex3Crack : TEXCOORD1;
   	float4 wPos : TEXCOORD2;
	float3 Mat1 : TEXCOORD3;
	float3 Mat2 : TEXCOORD4;
	float3 Mat3 : TEXCOORD5;
};

VS_OUT_GBuffBaseDetailDirtCrack vsGBuffBaseDetailDirtCrack(appdata_GBuffBaseDetailDirtCrack input)
{
	VS_OUT_GBuffBaseDetailDirtCrack Out;

 	Out.HPos = mul(input.Pos, viewProjMatrix);
	Out.wPos = mul(input.Pos, worldViewMatrix);

	// Cross product to create BiNormal
	float3 binormal = normalize(cross(input.Tan, input.Normal));

	// Calculate tangent->view space transformation
	float3x3 tanBasis = float3x3(input.Tan, binormal, input.Normal);
	float3x3 tanToView = transpose(mul(tanBasis, worldViewITMatrix));
	Out.Mat1 = tanToView[0];
	Out.Mat2 = tanToView[1];
	Out.Mat3 = tanToView[2];

	// Pass-through texcoords
	Out.Tex1Detail = input.TexCoordDetail;
	Out.Tex3Crack = input.TexCoordCrack;

	return Out;
}

PS2FB_fullMRT psGBuffBaseDetailDirtCrack(VS_OUT_GBuffBaseDetailDirtCrack indata)
{
	PS2FB_fullMRT outdata;

	float4 crack = tex2D(samplerWrap3, indata.Tex3Crack);
	float4 detailNormal = tex2D(samplerWrap4, indata.Tex1Detail) * (1-crack.a);
	float4 crackNormal = tex2D(samplerWrap5, indata.Tex3Crack) * crack.a;

	outdata.Col0 = 1;
	outdata.Col1 = indata.wPos;

	float4 expandedNormal = detailNormal + crackNormal;
	expandedNormal.xyz = normalize((expandedNormal.xyz * 2) - 1);
	outdata.Col2.x = dot(expandedNormal, indata.Mat1);
	outdata.Col2.y = dot(expandedNormal, indata.Mat2);
	outdata.Col2.z = dot(expandedNormal, indata.Mat3);
	outdata.Col2.w = expandedNormal.w;

	return outdata;
}

struct VS_OUT_GBuffBaseDetailDirtCrackParallax {
	float4 HPos : POSITION;
	float2 Tex1Detail : TEXCOORD0;
	float2 Tex3Crack : TEXCOORD1;
   	float4 wPos : TEXCOORD2;
	float3 Mat1 : TEXCOORD3;
	float3 Mat2 : TEXCOORD4;
	float3 Mat3 : TEXCOORD5;
   	float3 tanEyeVec : TEXCOORD6;
};

VS_OUT_GBuffBaseDetailDirtCrackParallax vsGBuffBaseDetailDirtCrackParallax(appdata_GBuffBaseDetailDirtCrack input)
{
	VS_OUT_GBuffBaseDetailDirtCrackParallax Out;

 	Out.HPos = mul(input.Pos, viewProjMatrix);
	Out.wPos = mul(input.Pos, worldViewMatrix);

	// Cross product to create BiNormal
	float3 binormal = normalize(cross(input.Tan, input.Normal));

	// Calculate tangent->view space transformation
	float3x3 tanBasis = float3x3(input.Tan, binormal, input.Normal);
	Out.tanEyeVec = mul(eyePosObjectSpace.xyz-input.Pos.xyz, tanBasis);
	float3x3 tanToView = transpose(mul(tanBasis, worldViewITMatrix));
	Out.Mat1 = tanToView[0];
	Out.Mat2 = tanToView[1];
	Out.Mat3 = tanToView[2];

	// Pass-through texcoords
	Out.Tex1Detail = input.TexCoordDetail;
	Out.Tex3Crack = input.TexCoordCrack;

	return Out;
}

PS2FB_fullMRT psGBuffBaseDetailDirtCrackParallax(VS_OUT_GBuffBaseDetailDirtCrackParallax indata)
{
	PS2FB_fullMRT outdata;

	float2 newTex1Detail = calculateOffsetCoordinatesFromAlpha(indata.Tex1Detail.xy, indata.Tex1Detail.xy, samplerWrap1, parallaxScaleBias, indata.tanEyeVec);

	float4 crack = tex2D(samplerWrap3, indata.Tex3Crack);
	float4 detailNormal = tex2D(samplerWrap4, newTex1Detail) * (1-crack.a);
	float4 crackNormal = tex2D(samplerWrap5, indata.Tex3Crack) * crack.a;

	outdata.Col0 = 1;
	outdata.Col1 = indata.wPos;

	float4 expandedNormal = detailNormal + crackNormal;
	expandedNormal.xyz = normalize((expandedNormal.xyz * 2) - 1);
	outdata.Col2.x = dot(expandedNormal, indata.Mat1);
	outdata.Col2.y = dot(expandedNormal, indata.Mat2);
	outdata.Col2.z = dot(expandedNormal, indata.Mat3);
	outdata.Col2.w = expandedNormal.w;

	return outdata;
}

struct appdata_GBuffBaseDetailDirtCrackLM {
    float4 Pos : POSITION;
    float2 TexCoordDetail : TEXCOORD0;
    float2 TexCoordCrack : TEXCOORD1;
	float2 TexCoordLMap : TEXCOORD2;
    float3 Tan : TANGENT;
    float3 Normal : NORMAL;
};

struct VS_OUT_GBuffBaseDetailDirtCrackLM {
	float4 HPos : POSITION;
	float2 Tex1Detail : TEXCOORD0;
	float4 Tex3CrackAndLMap : TEXCOORD1;
    	float4 wPos : TEXCOORD2;
	float3 Mat1 : TEXCOORD3;
	float3 Mat2 : TEXCOORD4;
	float3 Mat3 : TEXCOORD5;
};

VS_OUT_GBuffBaseDetailDirtCrackLM vsGBuffBaseDetailDirtCrackLM(appdata_GBuffBaseDetailDirtCrackLM input)
{
	VS_OUT_GBuffBaseDetailDirtCrackLM Out;

 	Out.HPos = mul(input.Pos, viewProjMatrix);
	Out.wPos = mul(input.Pos, worldViewMatrix);

	// Cross product to create BiNormal
	float3 binormal = normalize(cross(input.Tan, input.Normal));

	// Calculate tangent->view space transformation
	float3x3 tanBasis = float3x3(input.Tan, binormal, input.Normal);
	float3x3 tanToView = transpose(mul(tanBasis, worldViewITMatrix));
	Out.Mat1 = tanToView[0];
	Out.Mat2 = tanToView[1];
	Out.Mat3 = tanToView[2];

	// Pass-through texcoords
	Out.Tex1Detail = input.TexCoordDetail;
	Out.Tex3CrackAndLMap.xy = input.TexCoordCrack;
	Out.Tex3CrackAndLMap.zw = (input.TexCoordLMap*lightmapOffset.xy) + lightmapOffset.zw;
	return Out;
}

PS2FB_fullMRT psGBuffBaseDetailDirtCrackLM(VS_OUT_GBuffBaseDetailDirtCrackLM indata)
{
	PS2FB_fullMRT outdata;

	float4 crack = tex2D(samplerWrapAniso3, indata.Tex3CrackAndLMap.xy);
	float4 detailNormal = tex2D(samplerWrap4, indata.Tex1Detail) * (1-crack.a);
	float4 crackNormal = tex2D(samplerWrap5, indata.Tex3CrackAndLMap.xy) * crack.a;
	float4 lightmap = tex2D(samplerWrap6, indata.Tex3CrackAndLMap.zw);

	outdata.Col0 = lightmap;
	outdata.Col1 = indata.wPos;

	float4 expandedNormal = detailNormal + crackNormal;
	expandedNormal.xyz = normalize((expandedNormal.xyz * 2) - 1);
	outdata.Col2.x = dot(expandedNormal, indata.Mat1);
	outdata.Col2.y = dot(expandedNormal, indata.Mat2);
	outdata.Col2.z = dot(expandedNormal, indata.Mat3);
	outdata.Col2.w = expandedNormal.w;

	return outdata;
}

struct VS_OUT_GBuffBaseDetailDirtCrackLMParallax {
	float4 HPos : POSITION;
	float2 Tex1Detail : TEXCOORD0;
	float4 Tex3CrackAndLMap : TEXCOORD1;
    	float4 wPos : TEXCOORD2;
	float3 Mat1 : TEXCOORD3;
	float3 Mat2 : TEXCOORD4;
	float3 Mat3 : TEXCOORD5;
   	float3 tanEyeVec : TEXCOORD6;
};

VS_OUT_GBuffBaseDetailDirtCrackLMParallax vsGBuffBaseDetailDirtCrackLMParallax(appdata_GBuffBaseDetailDirtCrackLM input)
{
	VS_OUT_GBuffBaseDetailDirtCrackLMParallax Out;

 	Out.HPos = mul(input.Pos, viewProjMatrix);
	Out.wPos = mul(input.Pos, worldViewMatrix);

	// Cross product to create BiNormal
	float3 binormal = normalize(cross(input.Tan, input.Normal));

	// Calculate tangent->view space transformation
	float3x3 tanBasis = float3x3(input.Tan, binormal, input.Normal);
	Out.tanEyeVec = mul(eyePosObjectSpace.xyz-input.Pos.xyz, tanBasis);
	float3x3 tanToView = transpose(mul(tanBasis, worldViewITMatrix));
	Out.Mat1 = tanToView[0];
	Out.Mat2 = tanToView[1];
	Out.Mat3 = tanToView[2];

	// Pass-through texcoords
	Out.Tex1Detail = input.TexCoordDetail;
	Out.Tex3CrackAndLMap.xy = input.TexCoordCrack;
	Out.Tex3CrackAndLMap.zw = (input.TexCoordLMap*lightmapOffset.xy) + lightmapOffset.zw;
	return Out;
}

PS2FB_fullMRT psGBuffBaseDetailDirtCrackLMParallax(VS_OUT_GBuffBaseDetailDirtCrackLMParallax indata)
{
	PS2FB_fullMRT outdata;

	float2 newTex1Detail = calculateOffsetCoordinatesFromAlpha(indata.Tex1Detail.xy, indata.Tex1Detail.xy, samplerWrap1, parallaxScaleBias, indata.tanEyeVec);

	float4 crack = tex2D(samplerWrapAniso3, indata.Tex3CrackAndLMap.xy);
	float4 detailNormal = tex2D(samplerWrap4, newTex1Detail) * (1-crack.a);
	float4 crackNormal = tex2D(samplerWrap5, indata.Tex3CrackAndLMap.xy) * crack.a;
	float4 lightmap = tex2D(samplerWrap6, indata.Tex3CrackAndLMap.zw);

	outdata.Col0 = lightmap;
	outdata.Col1 = indata.wPos;

	float4 expandedNormal = detailNormal + crackNormal;
	expandedNormal.xyz = normalize((expandedNormal.xyz * 2) - 1);
	outdata.Col2.x = dot(expandedNormal, indata.Mat1);
	outdata.Col2.y = dot(expandedNormal, indata.Mat2);
	outdata.Col2.z = dot(expandedNormal, indata.Mat3);
	outdata.Col2.w = expandedNormal.w;

	return outdata;
}

technique DX9GBuffbase
{
	pass p0
	{
		ZWriteEnable = FALSE;
		ZFunc = EQUAL;
		ZEnable = TRUE;

		StencilEnable = FALSE;

 		VertexShader = compile vs_1_1 vsGBuffBase();
		PixelShader = compile PS2_EXT psGBuffBase();
	}
}

technique DX9GBuffbaseLM
{
	pass p0
	{
		ZWriteEnable = FALSE;
		ZFunc = EQUAL;
		ZEnable = TRUE;

		StencilEnable = FALSE;

 		VertexShader = compile vs_1_1 vsGBuffBaseLM();
		PixelShader = compile PS2_EXT psGBuffBaseLM();
	}
}

technique DX9GBuffbaseLMAT0
{
	pass p0
	{
		// ZWriteEnable = FALSE;
		// ZFunc = EQUAL;
		ZEnable = TRUE;
		ZWriteEnable = FALSE;
		ZFunc = LESSEQUAL;

		ColorWriteEnable = RED|BLUE|GREEN|ALPHA;
		StencilEnable = FALSE;
// TL: Need stencil from this?
// StencilEnable = TRUE;
// StencilRef = 0x40;
// StencilFunc = ALWAYS;
// StencilZFail = KEEP;
// StencilPass = REPLACE;

 		VertexShader = compile vs_1_1 vsGBuffBaseLMAT();
		PixelShader = compile PS2_EXT psGBuffBaseLMAT0();
	}
}

technique DX9GBuffbaseLMAT1
{
	pass diffuse
	{
		// ZWriteEnable = FALSE;
		// ZFunc = EQUAL;
		ZEnable = TRUE;
		ZWriteEnable = FALSE;
		ZFunc = LESSEQUAL;

		ColorWriteEnable = RED|BLUE|GREEN|ALPHA;
		StencilEnable = FALSE;

 		VertexShader = compile vs_1_1 vsGBuffBaseLMAT1();
		PixelShader = compile PS2_EXT psGBuffBaseLMAT1_Diffuse();
	}
}

technique DX9GBuffbaseLMAT2
{
	pass mrt
	{
		// ZWriteEnable = FALSE;
		// ZFunc = EQUAL;
		ZEnable = TRUE;
		ZWriteEnable = FALSE;
		ZFunc = LESSEQUAL;

		ColorWriteEnable = RED|BLUE|GREEN|ALPHA;
		StencilEnable = FALSE;

 		VertexShader = compile vs_1_1 vsGBuffBaseLMAT1();
		PixelShader = compile PS2_EXT psGBuffBaseLMAT1_MRT();
	}
}


technique DX9GBuffbasedetail
{
	pass p0
	{
		ZWriteEnable = FALSE;
		ZFunc = EQUAL;
		ZEnable = TRUE;

		StencilEnable = FALSE;

 		VertexShader = compile vs_1_1 vsGBuffBaseDetail();
		PixelShader = compile PS2_EXT psGBuffBaseDetail();
	}
}

technique DX9GBuffbasedetailparallax
{
	pass p0
	{
		ZWriteEnable = FALSE;
		ZFunc = EQUAL;
		ZEnable = TRUE;

		StencilEnable = FALSE;

 		VertexShader = compile vs_1_1 vsGBuffBaseDetailParallax();
		PixelShader = compile PS2_EXT psGBuffBaseDetailParallax();
	}
}

technique DX9GBuffbasedetailLM
{
	pass p0
	{
		ZWriteEnable = FALSE;
		ZFunc = EQUAL;
		ZEnable = TRUE;

		StencilEnable = FALSE;

 		VertexShader = compile vs_1_1 vsGBuffBaseDetailLM();
		PixelShader = compile PS2_EXT psGBuffBaseDetailLM();
	}
}

technique DX9GBuffbasedetailLMparallax
{
	pass p0
	{
		ZWriteEnable = FALSE;
		ZFunc = EQUAL;
		ZEnable = TRUE;

		StencilEnable = FALSE;

 		VertexShader = compile vs_1_1 vsGBuffBaseDetailLMParallax();
		PixelShader = compile PS2_EXT psGBuffBaseDetailLMParallax();
	}
}

technique DX9GBuffbasedetaildirt
{
	pass p0
	{
		ZWriteEnable = FALSE;
		ZFunc = EQUAL;
		ZEnable = TRUE;

		StencilEnable = FALSE;

 		VertexShader = compile vs_1_1 vsGBuffBaseDetailDirt();
		PixelShader = compile PS2_EXT psGBuffBaseDetailDirt();
	}
}

technique DX9GBuffbasedetaildirtparallax
{
	pass p0
	{
		ZWriteEnable = FALSE;
		ZFunc = EQUAL;
		ZEnable = TRUE;

		StencilEnable = FALSE;

 		VertexShader = compile vs_1_1 vsGBuffBaseDetailDirtParallax();
		PixelShader = compile PS2_EXT psGBuffBaseDetailDirtParallax();
	}
}

technique DX9GBuffbasedetaildirtLM
{
	pass p0
	{
		ZWriteEnable = FALSE;
		ZFunc = EQUAL;
		ZEnable = TRUE;

		StencilEnable = FALSE;

 		VertexShader = compile vs_1_1 vsGBuffBaseDetailDirtLM();
		PixelShader = compile PS2_EXT psGBuffBaseDetailDirtLM();
	}
}

technique DX9GBuffbasedetaildirtLMparallax
{
	pass p0
	{
		ZWriteEnable = FALSE;
		ZFunc = EQUAL;
		ZEnable = TRUE;

		StencilEnable = FALSE;

 		VertexShader = compile vs_1_1 vsGBuffBaseDetailDirtLMParallax();
		PixelShader = compile PS2_EXT psGBuffBaseDetailDirtLMParallax();
	}
}

technique DX9GBuffbasedetailcrack
{
	pass p0
	{
		ZWriteEnable = FALSE;
		ZFunc = EQUAL;
		ZEnable = TRUE;

		StencilEnable = FALSE;

 		VertexShader = compile vs_1_1 vsGBuffBaseDetailCrack();
		PixelShader = compile PS2_EXT psGBuffBaseDetailCrack();
	}
}

technique DX9GBuffbasedetailcrackparallax
{
	pass p0
	{
		ZWriteEnable = FALSE;
		ZFunc = EQUAL;
		ZEnable = TRUE;

		StencilEnable = FALSE;

 		VertexShader = compile vs_1_1 vsGBuffBaseDetailCrackParallax();
		PixelShader = compile PS2_EXT psGBuffBaseDetailCrackParallax();
	}
}

technique DX9GBuffbasedetailcrackLM
{
	pass p0
	{
		ZWriteEnable = FALSE;
		ZFunc = EQUAL;
		ZEnable = TRUE;

		StencilEnable = FALSE;

 		VertexShader = compile vs_1_1 vsGBuffBaseDetailCrackLM();
		PixelShader = compile PS2_EXT psGBuffBaseDetailCrackLM();
	}
}

technique DX9GBuffbasedetailcrackLMparallax
{
	pass p0
	{
		ZWriteEnable = FALSE;
		ZFunc = EQUAL;
		ZEnable = TRUE;

		StencilEnable = FALSE;

 		VertexShader = compile vs_1_1 vsGBuffBaseDetailCrackLMParallax();
		PixelShader = compile PS2_EXT psGBuffBaseDetailCrackLMParallax();
	}
}

technique DX9GBuffbasedetaildirtcrack
{
	pass p0
	{
		ZWriteEnable = FALSE;
		ZFunc = EQUAL;
		ZEnable = TRUE;

		StencilEnable = FALSE;

 		VertexShader = compile vs_1_1 vsGBuffBaseDetailDirtCrack();
		PixelShader = compile PS2_EXT psGBuffBaseDetailDirtCrack();
	}
}

technique DX9GBuffbasedetaildirtcrackparallax
{
	pass p0
	{
		ZWriteEnable = FALSE;
		ZFunc = EQUAL;
		ZEnable = TRUE;

		StencilEnable = FALSE;

 		VertexShader = compile vs_1_1 vsGBuffBaseDetailDirtCrackParallax();
		PixelShader = compile PS2_EXT psGBuffBaseDetailDirtCrackParallax();
	}
}

technique DX9GBuffbasedetaildirtcrackLM
{
	pass p0
	{
		ZWriteEnable = FALSE;
		ZFunc = EQUAL;
		ZEnable = TRUE;

		StencilEnable = FALSE;

 		VertexShader = compile vs_1_1 vsGBuffBaseDetailDirtCrackLM();
		PixelShader = compile PS2_EXT psGBuffBaseDetailDirtCrackLM();
	}
}

technique DX9GBuffbasedetaildirtcrackLMparallax
{
	pass p0
	{
		ZWriteEnable = FALSE;
		ZFunc = EQUAL;
		ZEnable = TRUE;

		StencilEnable = FALSE;

 		VertexShader = compile vs_1_1 vsGBuffBaseDetailDirtCrackLMParallax();
		PixelShader = compile PS2_EXT psGBuffBaseDetailDirtCrackLMParallax();
	}
}
