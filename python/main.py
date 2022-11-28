
from realityshaders.core import shaderInfo

path = r'C:\Users\pauld\Documents\GitHub\RealityShaders\shaders'
shaders = shaderInfo(path)
shaders.getShaderFiles()
shaders.getShaderTechniques()

print(shaders.techniques)