
"""
This module searches for techniques from a specified folder
"""

import os

class shaderInfo(object):
    """
    Methods for finding shader information
    """

    def __init__(self, folderPath):
        self.path = folderPath
        self.files = []
        self.techniques = []

    def getShaderFiles(self):
        """
        Finds shader files in a folder
        """
        for file in os.listdir(self.path):
            if file.endswith('.fx'):
                self.files.append(self.path + '\\' + file)
        return self.files
    
    def getShaderTechniques(self):
        """
        Finds techniques in a shader
        """
        for file in self.files:
            shaderFile = open(file, 'r')
            for line in shaderFile:
                # Remove whitespace
                line = line.strip()
                # Skip empty lines
                if len(line) == 0:
                    continue
                # Split line to words
                words = line.split(' ')
                if words[0] == 'technique':
                    self.techniques.append(words[1])
        return self.techniques
