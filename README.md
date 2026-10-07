
# RealityShaders

## About

*RealityShaders* is an HLSL shader overhaul for [Project Reality: Battlefield 2](https://www.realitymod.com/). *RealityShaders* introduces many graphical updates that did not make it into the Refactor 2 Engine.

*RealityShaders* also includes `.fxh` files that contain algorithms used in the collection.

## Features

- **Distance-Based Fog**: This fogging method eliminates "corner-peeking".
- **Half-Lambert Lighting**: [Valve Software's](https://advances.realtimerendering.com/s2006/Mitchell-ShadingInValvsSourceEngine.pdf) smoother version of the Lambertian Term used in lighting.
- **Logarithmic Depth Buffer**: Logarithmic depth buffering eliminates flickering within distant objects.
- **Modernized Post-Processing**: This shader package includes updated thermal and suppression effects.
- **Optional Bicubic Lightmapping**: A smoother interpolation method to eliminate blockiness and noticeable seams in baked lighting. Credit to [Felix Westin](https://github.com/Fewes).
- **Per-Pixel Lighting**: Per-pixel lighting allows sharper lighting and smoother fogging.
- **Procedural Sampling**: No more visible texture repetition off-map terrain.
- **Shader Model 3.0**: Shader Model 3.0 allows modders to add more grapical updates into the game.
- **Sharpened Filtering**: Support for 16x anisotropic filtering.
- **Updated BF2Editor Shaders**: The Shader Model 3.0 update allows BF2Editor to support updated dependencies and Large Address Aware.

## Installation

1. Click on the green **`<> Code`** drop-down button and select **`Download ZIP`**.
2. Unpack the downloaded `RealityShaders-main.zip` file.
3. Locate your `\mods\pr` directory in your Project Reality: Battlefield 2 installation.
4. In the `\mods\pr` directory, create a backup of the `shaders_client.zip` file. Name the backup something like `shaders_client_backup.zip`
5. Open the original `shaders_client.zip` file.
6. Copy the files from the `\pr\shaders` folder of the unpacked zip file into `shaders_client.zip`.

## Coding Convention

### Shared Method From Header File

1. **File path**: `shared/common/RealityLib.fxh`
1. **Function name**: `Common_RealityLib_FunctionName()`
1. **Example**:  `shared/common/RealityLib.fxh` -> `Common_RealityLib_FunctionName()`

### ALLCAPS

**State parameters**:

    BlendOp = ADD;

**System semantics**:

    float4 SV_POSITION;

### ALL_CAPS

**Preprocessor definitions**:

    #define SHADER_VERSION

**Preprocessor macros**:

    #define EXAMPLE_MACRO()

**Preprocessor macro arguments**

    #define EXAMPLE_MACRO(EXAMPLE_ARG)

### _SnakeCase

**Uniform variables**:

    uniform float _Example

### SnakeCase

**Function arguments**:

    void Function(int ArgumentOne)

**Global variables**:

    static const float4 GlobalVariable = 1.0;
    void Function()
    {
        return GlobalVariable;
    }

**Local variables**:

    void Function()
    {
        float4 LocalVariable = 1.0;
        return LocalVariable;
    }

**Textures and samplers**:

    texture2D ExampleTex(...)
    sampler2D SampleExampleTex(...)

### SNAKE_Case

**`struct` datatypes**:

    struct APP2VS_Foobar { ... };
    struct VS2PS_Foobar { ... };
    struct PS2FB_Foobar { ... };
    struct PS2MRT_Foobar { ... };

**`VertexShader` and `PixelShader`**

    VertexShader = VS_Example(...);
    PixelShader = PS_Example(...);

## Acknowledgment

- [The Forgotten Hope Team](http://forgottenhope.warumdarum.de/)

    Major knowledge-base and inspiration.

- [Felix Westin](https://github.com/Fewes)

    - Consultation and for sharing his [test of features for Battlefield 2 graphics enhancements](https://github.com/Fewes/RealityShaders)
    - Bicubic lightmapping implementation

- [The Nations At War Team](https://www.moddb.com/mods/nations-at-war)

    Lt. Fred for testing and suggestions!
