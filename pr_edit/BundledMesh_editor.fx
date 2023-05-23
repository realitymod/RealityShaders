
technique marked
{
	pass p0 
	{		
	
		ZEnable = true;
		ZWriteEnable = true;
		// ZWriteEnable = false;
		// FillMode = WIREFRAME;
		CullMode = NONE;
		AlphaBlendEnable = true;
		AlphaTestEnable = true;
		AlphaRef = 0;
		AlphaFunc = GREATER;
		
 		VertexShader = compile vs_1_1 diffuseVertexShader(viewProjMatrix,
 															viewInverseMatrix,
 															lightPos,
 															eyePos);
		
		
		Sampler[0] = <diffuseSampler>;
	
		PixelShader = asm 
		{
			ps.1.1
			def c0,0,0,0.8,0 // ambient
			
			tex t0
			mad_sat r0, t0, v0, c0
		};
	}
}

technique submarked
{
	pass p0 
	{		
	
		ZEnable = true;
		ZWriteEnable = true;
		// ZWriteEnable = false;
		// FillMode = WIREFRAME;
		CullMode = NONE;
		AlphaBlendEnable = false;
		AlphaTestEnable = true;
		AlphaRef = 0;
		AlphaFunc = GREATER;
		
 		VertexShader = compile vs_1_1 diffuseVertexShader(viewProjMatrix,
 															viewInverseMatrix,
 															lightPos,
 															eyePos);
		
		
		Sampler[0] = <diffuseSampler>;
	
		PixelShader = asm 
		{
			ps.1.1
			def c0,0,0,0.4,0 // ambient
			
			tex t0
			mad_sat r0, t0, v0, c0
		};
	}
}

technique subPartHighlight
<
	int DetailLevel = DLHigh+DLNormal+DLLow+DLAbysmal;
	int Compatibility = CMPR300+CMPNV2X;
>
{
	pass p0
	{
		// CullMode = NONE;
		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;
		FillMode = SOLID;
		// DepthBias=-0.001;
		// ZEnable = TRUE;
		// ShadeMode = FLAT;
		// ZFunc = EQUAL;
		// FillMode = WIREFRAME;	
		ZEnable = TRUE;
		ZFunc = EQUAL;
		ZWriteEnable = FALSE;
	
		VertexShader = compile vs_1_1 diffuseVertexShader(viewProjMatrix,viewInverseMatrix,lightPos,eyePos);
		
		PixelShader = asm 
		{
			ps.1.1
			def c0,0.2f,0.5f,0.5f,0.45f // ambient 
			tex t0
			mov r0, c0
		};
	}
}