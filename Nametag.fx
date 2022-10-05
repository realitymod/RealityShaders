#line 2 "Nametag.fx"

/*
	[Attributes from app]
*/

uniform float4x4 _WorldViewProj : WorldViewProjection;
uniform float _TexBlendFactor : TexBlendFactor;
uniform float2 _FadeoutValues : FadeOut;
uniform float4 _LocalEyePos : LocalEye;
uniform float4 _Transformations[64] : TransformationArray;

// dep: this is a suboptimal Camp EA hack; rewrite this
uniform float _Alphas[64] : AlphaArray;
uniform float4 _Colors[9] : ColorArray;
uniform float4 _AspectMul : AspectMul;

uniform float4 _ArrowMult = float4(1.05, 1.05, 1.0, 1.0);
uniform float4 _ArrowTrans : ArrowTransformation;
uniform float4 _ArrowRot : ArrowRotation; // this is a 2x2 rotation matrix [X Y] [Z W]

uniform float4 _IconRot : IconRotation;
// uniform float4 _FIconRot : FIconRotation;
uniform float2 _IconTexOffset : IconTexOffset;
uniform float4 _IconFlashTexScaleOffset : IconFlashTexScaleOffset;

uniform int _ColorIndex1 : ColorIndex1;
uniform int _ColorIndex2 : ColorIndex2;

uniform float4 _HealthBarTrans : HealthBarTrans;
uniform float _HealthValue : HealthValue;

uniform float _CrossFadeValue : CrossFadeValue;
uniform float _AspectComp = 4.0 / 3.0;

/*
	[Textures and samplers]
*/

uniform texture Detail_0 : TEXLAYER0;
uniform texture Detail_1 : TEXLAYER1;

sampler Sampler_0 = sampler_state
{
	Texture = (Detail_0);
	AddressU = CLAMP;
	AddressV = CLAMP;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = NONE;
};

sampler Sampler_1 = sampler_state
{
	Texture = (Detail_1);
	AddressU = CLAMP;
	AddressV = CLAMP;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = NONE;
};

struct APP2VS
{
	float4 Pos : POSITION;
	float2 TexCoord0 : TEXCOORD0;
	int4 Indices : BLENDINDICES0;
};

struct VS2PS
{
	float4 Pos : POSITION;
	float2 TexCoord0 : TEXCOORD0;
	float2 TexCoord1 : TEXCOORD1;
	float4 Color0 : COLOR0;
};

struct VS2PS_2TEX
{
	float4 Pos : POSITION;
	float2 TexCoord0 : TEXCOORD0;
	float2 TexCoord1 : TEXCOORD1;
	float4 Color0 : COLOR0;
	float4 Color1 : COLOR1;
};




/*
	Nametag shader
*/

VS2PS Nametag_VS(APP2VS Input)
{
	VS2PS Output = (VS2PS)0;

	float4 IndexedTrans = _Transformations[Input.Indices.x];

	Output.Pos = float4(Input.Pos.xyz + IndexedTrans.xyz, 1.0);

	Output.TexCoord0 = Input.TexCoord0;

	Output.Color0 = lerp(_Colors[Input.Indices.y], _Colors[Input.Indices.z], _CrossFadeValue);
	Output.Color0.a = _Alphas[Input.Indices.x];
	Output.Color0.a *= 1.0 - saturate(IndexedTrans.w * _FadeoutValues.x + _FadeoutValues.y);
	Output.Color0 = saturate(Output.Color0);
	return Output;
}

float4 Nametag_PS(VS2PS Input) : COLOR0
{
	float4 Tx0 = tex2D(Sampler_0, Input.TexCoord0);
	return Tx0 * Input.Color0;
}

technique nametag
<
	int Declaration[] =
	{
		// StreamNo, DataType, Usage, UsageIdx
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_POSITION, 0 },
		{ 0, D3DDECLTYPE_FLOAT2, D3DDECLUSAGE_TEXCOORD, 0 },
		{ 0, D3DDECLTYPE_SHORT4, D3DDECLUSAGE_BLENDINDICES, 0 },
		DECLARATION_END	// End macro
	};
	int TechniqueStates = D3DXFX_DONOTSAVESHADERSTATE;
>
{
	pass p0
	{
		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		CullMode = NONE;
		ZEnable = FALSE;
		ZWriteEnable = FALSE;

		VertexShader = compile vs_3_0 Nametag_VS();
		PixelShader = compile ps_3_0 Nametag_PS();
	}
}




/*
	Nametag arrow shader
*/

VS2PS Nametag_Arrow_VS(APP2VS Input)
{
	VS2PS Output = (VS2PS)0;

	// Does a 2x2 matrix 2d rotation of the local vertex coordinates in screen space
	Output.Pos.x = dot(Input.Pos.xy, _ArrowRot.xy);
	Output.Pos.y = dot(Input.Pos.xy, _ArrowRot.zw);
	Output.Pos.z = 0.0;
	Output.Pos.xyz *= _AspectMul;
	Output.Pos.xyz += _ArrowTrans * _ArrowMult;
	Output.Pos.w = 1.0;

	Output.TexCoord0 = Input.TexCoord0;

	Output.Color0 = _Colors[Input.Indices.y];
	Output.Color0.a = 0.5;
	Output.Color0 = saturate(Output.Color0);
	return Output;
}

float4 Nametag_Arrow_PS(VS2PS Input) : COLOR0
{
	float4 Tx0 = tex2D(Sampler_0, Input.TexCoord0);
	float4 Result = Tx0 * Input.Color0;
	return Result;
}

technique nametag_arrow
<
	int Declaration[] =
	{
		// StreamNo, DataType, Usage, UsageIdx
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_POSITION, 0 },
		{ 0, D3DDECLTYPE_FLOAT2, D3DDECLUSAGE_TEXCOORD, 0 },
		{ 0, D3DDECLTYPE_SHORT4, D3DDECLUSAGE_BLENDINDICES, 0 },
		DECLARATION_END	// End macro
	};
	int TechniqueStates = D3DXFX_DONOTSAVESHADERSTATE;
>
{
	pass p0
	{
		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		CullMode = NONE;
		ZEnable = FALSE;
		ZWriteEnable = FALSE;

		VertexShader = compile vs_3_0 Nametag_Arrow_VS();
		PixelShader = compile ps_3_0 Nametag_Arrow_PS();
	}
}




/*
	Nametag healthbar shader
*/

VS2PS_2TEX Nametag_Healthbar_VS(APP2VS Input)
{
	VS2PS_2TEX Output = (VS2PS_2TEX)0;

	Output.Pos = float4(Input.Pos.xyz + _HealthBarTrans.xyz, 1.0);

	Output.TexCoord0 = Input.TexCoord0;
	Output.TexCoord1 = Input.TexCoord0;

	Output.Color0.rgb = Input.TexCoord0.x;
	Output.Color0.a = 1.0 - saturate(_HealthBarTrans.w * _FadeoutValues.x + _FadeoutValues.y);
	float4 Color0 = _Colors[_ColorIndex1];
	float4 Color1 = _Colors[_ColorIndex2];
	Output.Color1 = lerp(Color0, Color1, _CrossFadeValue);

	Output.Color0 = saturate(Output.Color0);
	Output.Color1 = saturate(Output.Color1);
	return Output;
}

float4 Nametag_Healthbar_PS(VS2PS_2TEX Input) : COLOR0
{
	float4 Tx0 = tex2D(Sampler_0, Input.TexCoord0);
	float4 Tx1 = tex2D(Sampler_1, Input.TexCoord1);
	return lerp(Tx0, Tx1, _HealthValue < Input.Color0.b) * Input.Color0.a * Input.Color1;
}

technique nametag_healthbar
<
	int Declaration[] =
	{
		// StreamNo, DataType, Usage, UsageIdx
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_POSITION, 0 },
		{ 0, D3DDECLTYPE_FLOAT2, D3DDECLUSAGE_TEXCOORD, 0 },
		{ 0, D3DDECLTYPE_SHORT4, D3DDECLUSAGE_BLENDINDICES, 0 },
		DECLARATION_END	// End macro
	};
	int TechniqueStates = D3DXFX_DONOTSAVESHADERSTATE;
>
{
	pass p0
	{
		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		CullMode = NONE;
		ZEnable = FALSE;
		ZWriteEnable = FALSE;

		VertexShader = compile vs_3_0 Nametag_Healthbar_VS();
		PixelShader = compile ps_3_0 Nametag_Healthbar_PS();
	}
}




/*
	Nametag vecicle icon shader
*/

VS2PS Nametag_Vehicle_Icons_VS(APP2VS Input)
{
	VS2PS Output = (VS2PS)0;

	float3 TempPos = Input.Pos;

	// Since Input is aspect-compensated we need to compensate for that
	TempPos.y /= _AspectComp;

	// Does a 2x2 matrix 2d rotation
	float3 RotPos;
	RotPos.x = dot(TempPos.xy, _IconRot.xz);
	RotPos.y = dot(TempPos.xy, _IconRot.yw);
	RotPos.z = Input.Pos.z;

	// Fix aspect again
	RotPos.y *= _AspectComp;

	Output.Pos = float4(RotPos.xyz + _HealthBarTrans.xyz, 1.0);

	Output.TexCoord0 = Input.TexCoord0 + _IconTexOffset;
	Output.TexCoord1 = Input.TexCoord0 * _IconFlashTexScaleOffset.xy + _IconFlashTexScaleOffset.zw;

	// Counter-rotate tex1 (flash icon)
	// float2 TempUV = Input.TexCoord0;
	// TempUV -= 0.5;
	// float2 RotUV;
	// RotUV.x = dot(TempUV, _FIconRot.xz);
	// RotUV.y = dot(TempUV, _FIconRot.yw);
	// RotUV += 0.5;
	// Output.TexCoord1 = RotUV * _IconFlashTexScaleOffset.xy + _IconFlashTexScaleOffset.zw;

	float4 Color0 = _Colors[_ColorIndex1];
	float4 Color1 = _Colors[_ColorIndex2];

	Output.Color0 = lerp(Color0, Color1, _CrossFadeValue);
	Output.Color0.a *= 1.0 - saturate(_HealthBarTrans.w * _FadeoutValues.x + _FadeoutValues.y);
	Output.Color0 = saturate(Output.Color0);

	return Output;
}

float4 Nametag_Vehicle_Icons_PS(VS2PS Input) : COLOR0
{
	float4 Tx0 = tex2D(Sampler_0, Input.TexCoord0);
	float4 Tx1 = tex2D(Sampler_1, Input.TexCoord1);
	return lerp(Tx0, Tx1, _CrossFadeValue) * Input.Color0;
}

technique nametag_vehicleIcons
<
	int Declaration[] =
	{
		// StreamNo, DataType, Usage, UsageIdx
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_POSITION, 0 },
		{ 0, D3DDECLTYPE_FLOAT2, D3DDECLUSAGE_TEXCOORD, 0 },
		{ 0, D3DDECLTYPE_SHORT4, D3DDECLUSAGE_BLENDINDICES, 0 },
		DECLARATION_END	// End macro
	};
	int TechniqueStates = D3DXFX_DONOTSAVESHADERSTATE;
>
{
	pass p0
	{
		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		CullMode = NONE;
		ZEnable = FALSE;
		ZWriteEnable = FALSE;

		VertexShader = compile vs_3_0 Nametag_Vehicle_Icons_VS();
		PixelShader = compile ps_3_0 Nametag_Vehicle_Icons_PS();
	}
}
