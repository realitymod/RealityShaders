#line 2 "TerrainShader_nv3x.fx"
//
// -- Low Terrain
//



float4 Low_PS_DirectionalLightShadows(Shared_VS2PS_DirectionalLightShadows indata) : COLOR
{
	float4 lightmap = tex2D(sampler0Clamp, indata.Tex0);
	
	float avgShadowValue = tex2Dproj(sampler2PointClamp, indata.ShadowTex);
	avgShadowValue = avgShadowValue == 1.f;

	float4 light = saturate(lightmap.z * vGIColor*2) * 0.5;
	if (avgShadowValue < lightmap.y)
		light.w = 1-saturate(4-indata.Z.x)+avgShadowValue.x;
	else
		light.w = lightmap.y;

	return light; 
}

technique Low_Terrain
{
	pass ZFillLightmap // p0
	{
		CullMode = CW;
		ZEnable = TRUE;
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;
		AlphaBlendEnable = FALSE;
		FogEnable = false;
		
		VertexShader = compile vs_1_1 Shared_VS_ZFillLightmap();

		// tl: Using a 1.4 profile shortens this shader considerably (from 4 to 1
		// instructions because of arbitrary component select), however HLSL 
		// is unable to compile this optimally hence the inline assembly... :-|
		PixelShaderConstantF[0] = (vGIColor);
		Sampler[1] = (sampler0Clamp);
		PixelShader = asm {
ps_1_4
texld r1, t0
mul r0.xyz, r1.z, c0
+mov_sat r0.w, r1.y
		};

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
		VertexShader = compile vs_1_1 Shared_VS_PointLight();
		PixelShader = compile ps_1_1 Shared_PS_PointLight();
	}
	pass {} // spotlight (removed)
	pass LowDetail // p3
	{
		CullMode = CW;
		ZEnable = TRUE;
		ZWriteEnable = FALSE;
		ZFunc = LESSEQUAL;
		FogEnable = true;
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_1_1 Shared_VS_LowDetail();
				
#if MIDTERRAIN
		PixelShader = compile ps_1_4 Shared_PS_LowDetail();
#else
		PixelShader = compile ps_1_4 Shared_PS_LowDetail();
		
		Sampler[0] = (sampler0Clamp); // colormap
		Sampler[1] = (sampler1Clamp); // lightmap
		Sampler[3] = (sampler4Wrap); // lowDetailTexture
		PixelShaderConstantF[0] = (vSunColor);
		PixelShaderConstantF[1] = (terrainWaterColor);

		PixelShader = asm {
	                ps_1_4
	                def c2, 0, 0, 0, 1
			texld r1, t1_dw.xyww
                	texld r0, t0
	                texld r3, t3
	                mad r1.xyz, r1_x2.w, c0, r1
	                mul r0.xyz, r1, r0
	              + lrp r1.w, v0.y, r3.z, r3.x
	                mul r0.xyz, r0_x2, r1.w
	                lrp r0.xyz, v0.w, c1, r0_x2
	              + mov r0.w, c2.w
	                
/*	                
	                mad r1.xyz, r1_x2.w, c0, r1
	                mov r1, r0
	                mul r1.xyz, r0, r0
			mov r1, r0
*/	                
/*	                
	                texld r0, t1_dw.xyww 
	                texld r1, t0
	                texld r2, t3
	                mad r0.xyz, r0_x2.w, c0, r0
	                mul r0.xyz, r1, r0
	              + lrp r1.w, v0.y, r2.z, r2.x
	                mul r0.xyz, r0_x2, r1.w
	                lrp r0.xyz, v0.w, c1, r0_x2
	              + mov r0.w, c2.w
*/	              
		};

/*
		Sampler[0] = (sampler0Clamp);
		Sampler[1] = (sampler1Clamp);
		Sampler[2] = (sampler5Clamp);
		Sampler[3] = (sampler4Wrap);
		Sampler[4] = (sampler4Wrap2);
		Sampler[5] = (sampler4Wrap3);
		PixelShaderConstantF[0] = (vSunColor);
		PixelShaderConstantF[1] = (terrainWaterColor);
*/
              
/*		PixelShader = asm {
	                ps_1_4
	                def c2, 0, 0, 1, 0.5
	                mov r0, c2
	                
			texld r1, t1_dw.xyww
                	texld r0, t0
	                texld r2, t0
	                texld r3, t3
	                mul r4, r1.w, c0
	                add r1, r4_x2, r1
	                mul_x8 r0, r1, r0
	                lrp r1.w, r2.x, r3.z, c2.w
	                mul r1, r0, r1.w
	                phase
	                texld r4, t2
	                texld r5, t4
	                mul r2.w, r4.y, v0.x
	                mad r2.w, r3.x, v0.y, r2.w
	                mad r2.w, r5.y, v0.z, r2.w
	                lrp r2.w, r2.z, r2.w, c2.w
	                mov r1.w, c2.z
	                mul r0, r1, r2.w
	                lrp r0, v0.w, r0, c1
               };*/
#endif 
	}
	pass {} // FullDetail p4
	pass {} // mulDiffuseDetailMounten (Not used on Low) p5
	pass {} // p6 tunnels (removed) p6
	pass DirectionalLightShadows // p7
	{
		CullMode = CW;
		ZEnable = TRUE;
		ZWriteEnable = FALSE;
		ZFunc = LESSEQUAL;
 		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_1_1 Shared_VS_DirectionalLightShadows();
		PixelShader = compile ps_1_4 Low_PS_DirectionalLightShadows();
	}
	pass {} // DirectionalLightShadowsNV (removed)	// p8
	pass DynamicShadowmap // p9
	{
		CullMode = CW;
		ZEnable = FALSE;
		ZWriteEnable = FALSE;
		ZFunc = LESSEQUAL;
 		AlphaBlendEnable = TRUE;
 		SrcBlend = DESTCOLOR;
 		DestBlend = ZERO;
		VertexShader = compile vs_1_1 Shared_VS_DynamicShadowmap();
		PixelShader = compile ps_1_4 Shared_PS_DynamicShadowmap();
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
		FogEnable = false;
		VertexShader = compile vs_1_1 Shared_VS_UnderWater();
		PixelShader = compile ps_1_4 Shared_PS_UnderWater();
	}
}


technique Low_SurroundingTerrain
{
	pass p0 // Normal
	{
		CullMode = CW;
		ZEnable = TRUE;
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;
		AlphaBlendEnable = FALSE;
		FogEnable = true;
		VertexShader = compile vs_1_1 Shared_VS_STNormal();		
		PixelShader = compile ps_1_4 Shared_PS_STNormal();
	}
/*
	pass p1 // Fast
	{
		CullMode = CW;
		ZEnable = TRUE;
		ZWriteEnable = TRUE;
		ZFunc = LESSEQUAL;
		AlphaBlendEnable = FALSE;
		FogEnable = true;
		VertexShader = compile vs_1_1 Shared_VS_STFast();		
		PixelShader = compile ps_1_4 Shared_PS_STFast();
	}
*/
}






