
/*
	Description:
	- Low-settings terrain shader
	- Renders the terrain's low-setting shading
	- Renders the terrain's low-setting shadowing
*/

#include "shaders/RealityGraphics.fxh"

/*
	Terrain DirShadow shader
	Applies dynamic shadows to the terrain's light buffer
*/

PS2FB Low_DirectionalLightShadows_PS(VS2PS_Shared_DirectionalLightShadows Input)
{
	PS2FB Output;

	float4 LightMap = tex2D(SampleTex0_Clamp, Input.Tex0);
	float4 Light = saturate(LightMap.z * _GIColor * 2.0) * 0.5;
	float AvgShadowValue = tex2Dproj(SampleTex2_Clamp, Input.ShadowTex);

	AvgShadowValue = AvgShadowValue == 1.0;
	Light.w = (AvgShadowValue < LightMap.y) ? 1.0 - saturate(4.0 - Input.Z.x) + AvgShadowValue.x : LightMap.y;

	Output.Color = Light;
	Output.Depth = ApplyLogarithmicDepth(Input.Z.z);

	return Output;
}

technique Low_Terrain
{
	// Pass 0
	pass ZFillLightMap
	{
		CullMode = CW;

		ZEnable = TRUE;
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;

		AlphaBlendEnable = FALSE;

		VertexShader = compile vs_3_0 Shared_ZFillLightMap_VS();
		PixelShader = compile ps_3_0 Shared_ZFillLightMap_1_PS();
	}

	// Pass 1
	pass PointLight
	{
		CullMode = CW;

		ZEnable = TRUE;
		ZWriteEnable = FALSE;
		ZFunc = LESSEQUAL;

		AlphaBlendEnable = TRUE;
		SrcBlend = ONE;
		DestBlend = ONE;

		SRGBWriteEnable = FALSE;

		VertexShader = compile vs_3_0 Shared_PointLight_VS();
		PixelShader = compile ps_3_0 Shared_PointLight_PS();
	}

	// Pass 2 (removed)
	pass SpotLight { }

	// Pass 3
	pass LowDetail
	{
		CullMode = CW;

		ZEnable = TRUE;
		ZWriteEnable = FALSE;
		ZFunc = LESSEQUAL;

		AlphaBlendEnable = FALSE;

		SRGBWriteEnable = FALSE;

		VertexShader = compile vs_3_0 Shared_LowDetail_VS();
		PixelShader = compile ps_3_0 Shared_LowDetail_PS();
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
		ZWriteEnable = FALSE;
		ZFunc = LESSEQUAL;

		AlphaBlendEnable = FALSE;

		VertexShader = compile vs_3_0 Shared_DirectionalLightShadows_VS();
		PixelShader = compile ps_3_0 Low_DirectionalLightShadows_PS();
	}

	// Pass 8 (removed)
	pass DirectionalLightShadowsNV { }

	// Pass 9
	pass DynamicShadowmap
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
		ZWriteEnable = FALSE;
		ZFunc = LESSEQUAL;

		AlphaBlendEnable = TRUE;
		SrcBlend = ONE;
		DestBlend = ONE;

		#if IS_NV4X
			StencilEnable = TRUE;
			StencilFunc = NOTEQUAL;
			StencilRef = 0xa;
			StencilPass = KEEP;
			StencilZFail = KEEP;
			StencilFail = KEEP;
		#endif

		SRGBWriteEnable = FALSE;

		VertexShader = compile vs_3_0 Shared_PointLight_VS();
		PixelShader = compile ps_3_0 Shared_PointLight_PS();
	}

	// Pass 14
	pass UnderWater
	{
		CullMode = CW;

		ZEnable = TRUE;
		ZWriteEnable = FALSE;
		ZFunc = LESSEQUAL;

		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		SRGBWriteEnable = FALSE;

		VertexShader = compile vs_3_0 Shared_UnderWater_VS();
		PixelShader = compile ps_3_0 Shared_UnderWater_PS();
	}
}
