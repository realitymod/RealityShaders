
# RealityShaders

## About

*RealityShaders* is an HLSL shader overhaul for [Project Reality: Battlefield 2](https://www.realitymod.com/). *RealityShaders* introduces many graphical updates that did not make it into the Refactor 2 Engine.

*RealityShaders* also includes `.fxh` files that contain algorithms used in the collection.

## Features

### Shader Model 3.0

Shader Model 3.0 allows modders to add more grapical updates into the game, such as:

- 3D water and terrain
- High precision shading
- Linear lighting
- Procedural effects
- Soft shadows
- Sharper texture filtering
- Steep parallax mapping

### Updated BF2Editor Shaders

The Shader Model 3.0 update allows BF2Editor to support updated dependencies and Large Address Aware.

### Distance-Based Fog

This fogging method eliminates "corner-peeking".

### Half-Lambert Lighting

[Valve Software's](https://advances.realtimerendering.com/s2006/Mitchell-ShadingInValvesSourceEngine.pdf) smoother version of the Lambertian Term used in lighting.

### Logarithmic Depth Buffer

Logarithmic depth buffering eliminates flickering within distant objects.

### Per-Pixel Lighting

Per-pixel lighting allows sharper lighting and smoother fogging.

### Modernized Post-Processing

This shader package includes updated thermal and suppression effects.

### Procedural Sampling

No more visible texture repetition in clouds and far-away terrain.

### Sharpened Filtering

Support for 16x anisotropic filtering.

## Coding Convention

- **ALLCAPS**
    - State parameters
    - System semantics
- **ALL_CAPS**
    - Preprocessor Macros
    - Preprocessor Macro Arguments
- **_SnakeCase**
    - Uniform variables
- **SnakeCase**
    - Function arguments
    - Global Variables
    - Local Variables
    - Textures and Samples
- **Snake_Case**
    - Data subcategory
- **PREFIX_Data**
    - `struct` datatype

        `APP2VS_`

        `VS2PS_`

        `PS2FB_`

        `PS2MRT_`

    - `VertexShader` methods

        `VS_`

    - `PixelShader` methods

        `PS_`

## Acknowledgment

- [The Forgotten Hope Team](http://forgottenhope.warumdarum.de/)

    Major knowledge-base and inspiration.
