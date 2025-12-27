
# RealityShaders

## About

*RealityShaders* is an HLSL shader overhaul for [Project Reality: Battlefield 2](https://www.realitymod.com/). *RealityShaders* introduces many graphical updates that did not make it into the Refactor 2 Engine.

*RealityShaders* also includes `.fxh` files that contain algorithms used in the collection.

## Features

- **Shader Model 3.0**: Shader Model 3.0 allows modders to add more grapical updates into the game.

    - 3D water and terrain
    - High precision shading
    - Linear lighting
    - Procedural effects
    - Soft shadows
    - Sharper texture filtering
    - Steep parallax mapping

- **Updated BF2Editor Shaders**: The Shader Model 3.0 update allows BF2Editor to support updated dependencies and Large Address Aware.
- **Distance-Based Fog**: This fogging method eliminates "corner-peeking".
- **Half-Lambert Lighting**: [Valve Software's](https://advances.realtimerendering.com/s2006/Mitchell-ShadingInValvsSourceEngine.pdf) smoother version of the Lambertian Term used in lighting.
- **Logarithmic Depth Buffer**: Logarithmic depth buffering eliminates flickering within distant objects.
- **Per-Pixel Lighting**: Per-pixel lighting allows sharper lighting and smoother fogging.
- **Modernized Post-Processing**: This shader package includes updated thermal and suppression effects.
- **Procedural Sampling**: No more visible texture repetition off-map terrain.
- **Sharpened Filtering**: Support for 16x anisotropic filtering.
- **Optional Bicubic Lightmapping**: A smoother interpolation method to eliminate blockiness and noticeable seams in baked lighting. Credit to [Felix Westin](https://github.com/Fewes).

## Installation

1. Click on the green **`<> Code`** drop-down button and select **`Download ZIP`**.
2. Unpack the downloaded `RealityShaders-main.zip` file.
3. Locate your `\mods\pr` directory in your Project Reality: Battlefield 2 installation.
4. In the `\mods\pr` directory, create a backup of the `shaders_client.zip` file. Name the backup something like `shaders_client_backup.zip`
5. Open the original `shaders_client.zip` file.
6. Copy the files from the `\pr\shaders` folder of the unpacked zip file into `shaders_client.zip`.

## Coding Convention

- **ALLCAPS**
    - State parameters
    - System semantics
- **ALL_CAPS**
    - Preprocessor macros
    - Preprocessor macro arguments
- **_SnakeCase**
    - Uniform variables
- **SnakeCase**
    - Function arguments
    - Global variables
    - Local variables
    - Textures and samples
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

- [Felix Westin](https://github.com/Fewes)

    - Consultation and for sharing his [test of features for Battlefield 2 graphics enhancements](https://github.com/Fewes/RealityShaders)
    - Bicubic lightmapping implementation

- [The Nations At War Team](https://www.moddb.com/mods/nations-at-war)

    Lt. Fred for testing and suggestions!
