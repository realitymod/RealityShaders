#line 2 "TerrainShader_Low.fxh"

/*
    This low-settings terrain shader renders terrain with optimized performance and reduced quality. It provides basic terrain rendering with simplified shading and shadowing for lower-end hardware or performance-critical scenarios.
*/

technique Low_Terrain
{
	// Pass 0
	pass ZFillLightMap
	{
		CullMode = CW;

		ZEnable = TRUE;
		ZFunc = PR_ZFUNC_WITHEQUAL;
		ZWriteEnable = TRUE;

		AlphaBlendEnable = FALSE;

		VertexShader = compile vs_3_0 VS_Shared_ZFillLightMap();
		PixelShader = compile ps_3_0 PS_Shared_ZFillLightMap_1();
	}

	// Pass 1
	pass PointLight
	{
		CullMode = CW;

		ZEnable = TRUE;
		ZFunc = PR_ZFUNC_WITHEQUAL;
		ZWriteEnable = FALSE;

		AlphaBlendEnable = TRUE;
		SrcBlend = ONE;
		DestBlend = ONE;

		VertexShader = compile vs_3_0 VS_Shared_PointLight_PerVertex();
		PixelShader = compile ps_3_0 PS_Shared_PointLight_PerVertex();
	}

	// Pass 2 (removed)
	pass SpotLight { }

	// Pass 3
	pass LowDetail
	{
		CullMode = CW;

		ZEnable = TRUE;
		ZFunc = PR_ZFUNC_WITHEQUAL;
		ZWriteEnable = FALSE;

		AlphaBlendEnable = FALSE;

		VertexShader = compile vs_3_0 VS_Shared_LowDetail();
		PixelShader = compile ps_3_0 PS_Shared_LowDetail();
	}

	// Pass 4
	pass FullDetail { }

	// Pass 5 (not used on Low)
	pass MulDiffuseDetailMounten { }

	// Pass 6 (removed)
	pass Tunnels { }

	// Pass 7
	pass DirectionalLightShadows
	{
		CullMode = CW;

		ZEnable = TRUE;
		ZFunc = PR_ZFUNC_WITHEQUAL;
		ZWriteEnable = FALSE;

		AlphaBlendEnable = FALSE;

		VertexShader = compile vs_3_0 VS_Shared_DirectionalLightShadows();
		PixelShader = compile ps_3_0 PS_Shared_DirectionalLightShadows();
	}

	// Pass 8 (removed)
	pass DirectionalLightShadowsNV { }

	// Pass 9
	pass DynamicShadowmap
	{
		CullMode = CW;

		ZEnable = FALSE;
		ZWriteEnable = FALSE;
		ZFunc = PR_ZFUNC_WITHEQUAL;

		AlphaBlendEnable = TRUE;
		SrcBlend = DESTCOLOR;
		DestBlend = ZERO;

		VertexShader = compile vs_3_0 VS_Shared_DynamicShadowmap();
		PixelShader = compile ps_3_0 PS_Shared_DynamicShadowmap();
	}

	// Pass 10
	pass { }

	// Pass 11 (Not used on Low)
	pass MulDiffuseDetailWithEnvMap { }

	// Pass 12 (removed)
	pass MulDiffuseFast { }

	// Pass 13
	pass PerPixelPointlight
	{
		CullMode = CW;

		ZEnable = TRUE;
		ZFunc = PR_ZFUNC_WITHEQUAL;
		ZWriteEnable = FALSE;

		AlphaBlendEnable = TRUE;
		SrcBlend = ONE;
		DestBlend = ONE;

		#if IS_NV4X
			GET_RENDERSTATES_NV4X
		#endif

		VertexShader = compile vs_3_0 VS_Shared_PointLight_PerPixel();
		PixelShader = compile ps_3_0 PS_Shared_PointLight_PerPixel();
	}

	// Pass 14
	pass UnderWater
	{
		CullMode = CW;

		ZEnable = TRUE;
		ZFunc = PR_ZFUNC_WITHEQUAL;
		ZWriteEnable = FALSE;

		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		VertexShader = compile vs_3_0 VS_Shared_UnderWater();
		PixelShader = compile ps_3_0 PS_Shared_UnderWater();
	}
}
