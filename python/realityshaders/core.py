"""
This module searches for techniques from a specified folder
Credit: http://bytehazard.com/_temp/used_techniques.html
"""

import os

RED = "\x1b[38;5;210m"
GREEN = "\x1b[38;5;114m"
YELLOW = "\x1b[38;5;11m"
ORANGE = "\x1b[38;5;215m"
BLUE = "\x1b[38;5;153m"
GRAY = "\x1b[38;5;242m"
RESET = "\x1b[0m"
BOLD = "\x1b[1m"
UNDR = "\x1b[4m"


def getShaderFiles(folderPath):
    files = []
    for file in os.listdir(folderPath):
        if file.endswith(".fx"):
            files.append(file)
    return files


def getShaderTechniques(filePath):
    techniques = []
    for line in open(filePath, "r"):
        # Remove whitespace
        line = line.strip()
        # Skip empty lines
        if len(line) == 0:
            continue
        # Split line to words
        words = line.split(" ")
        if words[0] == "technique":
            techniques.append(words[1])
    return techniques


class shaderInfo(object):
    """
    Methods for printing  shader information
    """

    def __init__(self, folderPath):
        self.folderPath = folderPath
        self.files = getShaderFiles(self.folderPath)

    def printShaderInfo(self):
        for file in self.files:
            # Print the shader file's name
            print(YELLOW + file + RESET)
            # Get techniques from the shader file
            filePath = self.folderPath + "\\" + file
            techniques = getShaderTechniques(filePath)
            for technique in techniques:
                color = GREEN
                print("\t" + color + technique + RESET)
