
#line 3 "TerrainShader_nv3x.fx"

#include "shaders/RealityGraphics.fx"

/*
	Low Terrain
*/

float4 Low_DirectionalLightShadows_PS(VS2PS_Shared_DirectionalLightShadows Input) : COLOR
{
	float4 LightMap = tex2D(Sampler_0_Clamp, Input.Tex0);
	float AvgShadowValue = tex2Dproj(Sampler_2_Clamp, Input.ShadowTex);
	AvgShadowValue = AvgShadowValue == 1.0f;

	float4 Light = saturate(LightMap.z * _GIColor * 2.0) * 0.5;
	if (AvgShadowValue < LightMap.y)
		Light.w = 1.0 - saturate(4.0 - Input.Z.x) + AvgShadowValue.x;
	else
		Light.w = LightMap.y;

	return Light; 
}

technique Low_Terrain
{
	pass ZFillLightMap // p0
	{
		CullMode = CW;
		ZEnable = TRUE;
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;
		AlphaBlendEnable = FALSE;
		
		VertexShader = compile vs_3_0 Shared_ZFillLightMap_VS();
		PixelShader = compile ps_3_0 Shared_ZFillLightMap_1_PS();

	}

	pass pointlight // p1
	{
		CullMode = CW;
		ZEnable = TRUE;
		ZWriteEnable = FALSE;
		ZFunc = LESSEQUAL;
		AlphaBlendEnable = TRUE;
		SrcBlend = ONE;
		DestBlend = ONE;

		VertexShader = compile vs_3_0 Shared_PointLight_VS();
		PixelShader = compile ps_3_0 Shared_PointLight_PS();
	}

	pass {} // spotlight (removed)

	pass LowDetail //p3
	{
		CullMode = CW;
		ZEnable = TRUE;
		ZWriteEnable = FALSE;
		ZFunc = LESSEQUAL;
		AlphaBlendEnable = FALSE;

		VertexShader = compile vs_3_0 Shared_LowDetail_VS();
		PixelShader = compile ps_3_0 Shared_LowDetail_PS();
	}

	pass {} // FullDetail p4
	pass {} // mulDiffuseDetailMounten (Not used on Low) p5
	pass {} // p6 tunnels (removed) p6

	pass DirectionalLightShadows //p7
	{
		CullMode = CW;
		ZEnable = TRUE;
		ZWriteEnable = FALSE;
		ZFunc = LESSEQUAL;
		AlphaBlendEnable = FALSE;

		VertexShader = compile vs_3_0 Shared_DirectionalLightShadows_VS();
		PixelShader = compile ps_3_0 Low_DirectionalLightShadows_PS();
	}

	pass {} // DirectionalLightShadowsNV (removed) // p8

	pass DynamicShadowmap // p9
	{
		CullMode = CW;
		ZEnable = FALSE;
		ZWriteEnable = FALSE;
		ZFunc = LESSEQUAL;
		AlphaBlendEnable = TRUE;
		SrcBlend = DESTCOLOR;
		DestBlend = ZERO;

		VertexShader = compile vs_3_0 Shared_DynamicShadowmap_VS();
		PixelShader = compile ps_3_0 Shared_DynamicShadowmap_PS();
	}

	pass {} // p10
	pass {} // mulDiffuseDetailWithEnvMap (Not used on Low)	p11
	pass {} // mulDiffuseFast (removed) p12
	pass {} // PerPixelPointlight (Dont work on 1.4 shaders) // p13
	
	pass underWater // p14
	{
		CullMode = CW;
		ZEnable = TRUE;
		ZWriteEnable = FALSE;
		ZFunc = LESSEQUAL;
		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		VertexShader = compile vs_3_0 Shared_UnderWater_VS();
		PixelShader = compile ps_3_0 Shared_UnderWater_PS();
	}
}
