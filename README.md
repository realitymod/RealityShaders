
# RealityShaders

## About

*RealityShaders* is an HLSL shader overhaul for [Project Reality: BF2](https://www.realitymod.com/). *RealityShaders* introduces many graphical updates that did not make it into the Refactor 2 Engine.

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

### Distance-Based Fog

This fogging method eliminates "corner-peeking".

### Logarithmic Depth Buffer

Logarithmic depth buffering eliminates flickering within distant objects.

### Per-Pixel Lighting

Per-pixel lighting allows sharper lighting and smoother fogging.

### Modernized Post-Processing

This shader package includes updated thermal and suppression effects.

### Procedural Terrain Detailmapping

No more visible texture repetition.

## Coding Convention

Practice | Elements
-------- | --------
**ALLCAPS** | system semantics • state parameters
**ALL_CAPS** | preprocessor (macros & arguments)
**_SnakeCase** | variables (uniform)
**SnakeCase** | variables (local & global) • method arguments
**Snake_Case** | data subcatagory
**PREFIX_Data** | `struct` • `PixelShader` • `VertexShader`
