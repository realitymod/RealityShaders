# Project: RealityShaders

## Project Overview

RealityShaders is a third-party HLSL shader overhaul for the game [Project Reality: Battlefield 2](https://www.realitymod.com/). It modernizes the 2005 game's graphics by introducing features like Shader Model 3.0, 3D water and terrain, high-precision shading, and procedural effects.

The project is structured into two main directories:
- `bf2editor/`: Contains shaders for the Battlefield 2 editor.
- `pr/`: Contains shaders for the Project Reality game itself.

The core logic is written in HLSL, with `.fx` files defining the shaders and `.fxh` files containing shared functions and definitions.

## Building and Running

This project consists of HLSL shader files that are compiled by the game engine. There are no explicit build scripts or commands in this repository. The shaders are likely loaded and compiled at runtime by the game itself.

To use these shaders, you would typically need to:

1.  Install Project Reality: Battlefield 2.
2.  Replace the original shader files with the ones from this repository, backing up the originals first.
3.  Run the game.

## Development Conventions

The project follows a strict coding convention as outlined in the `README.md` file. Key aspects include:

- **Case Styles:**
    - `ALLCAPS` for state parameters and system semantics.
    - `ALL_CAPS` for preprocessor macros.
    - `_SnakeCase` for uniform variables.
    - `SnakeCase` for function arguments, global variables, and local variables.
    - `Snake_Case` for data subcategories.
- **Prefixes:**
    - `struct` datatypes are prefixed based on their usage (e.g., `APP2VS_`, `VS2PS_`).
    - `VertexShader` methods are prefixed with `VS_`.
    - `PixelShader` methods are prefixed with `PS_`.

These conventions are crucial for maintaining consistency and readability across the shader codebase. Adhering to them is important when contributing to the project.
