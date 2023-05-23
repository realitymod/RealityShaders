
technique lightmapGeneration
{
	pass p0 
	{		
	
		ZEnable = true;
		ZWriteEnable = true;
		AlphaBlendEnable = false;
		AlphaTestEnable = true;
		AlphaRef = 0;
		AlphaFunc = GREATER;
		
 		VertexShader = compile vs_1_1 bumpSpecularVertexShaderBlinn1(viewProjMatrix,
										viewInverseMatrix,
										lightPos);
		
		Sampler[0] = <normalSampler>;
		Sampler[1] = <dummySampler>;
		Sampler[2] = <colorLUTSampler>;
		Sampler[3] = <diffuseSampler>;
		
		PixelShader = asm 
		{
			ps.1.1
			def c0,0,0,0,1
			mov r0, c0 // Output black color for lightmap generation
		};
	}
}
