
# RealityShaders

## About

*RealityShaders* is an HLSL shader overhaul for Project Reality: BF2. *RealityShaders* introduces many graphical updates that did not make it into the Refactor 2 Engine.

*RealityShaders* also includes `.fxh` files that contain algorithms used in the collection.

## Features

### Shader Model 3.0

Shader Model 3.0 allows modders to add more grapical updates into the game, such as:

- 3D water and terrain
- High precision shading
- Linear lighting
- Soft shadows
- Sharper texture filtering
- Steep parallax mapping

### Distance-Based Fog

This fogging method eliminates in-game "corner-peeking".

### Logarithmic Depth Buffer

Logarithmic depth buffering eliminates flickering within distant objects.

### Per-Pixel Lighting

This feature allows for sharper lighting and smoother fogging.

## Coding Convention

Practice | Elements
-------- | --------
**ALLCAPS** | System semantics • State parameters
**ALL_CAPS** | Preprocessor (macros & arguments)
**_SnakeCase** | Variables (uniform)
**SnakeCase** | Variables (local & global) • Method arguments
**Snake_Case** | Data subcatagory
**PREFIX_Data** | `struct` • `PixelShader` • `VertexShader`
