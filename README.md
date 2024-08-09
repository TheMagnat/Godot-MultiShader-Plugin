# Godot-MultiShader-Plugin
#### An add-on for Godot 4.2 and beyond
A simple plugin to help you merge multiple shaders in one.

## Features:
- A new "MultiShaderMaterial" resource.

## Basic Use:
On anything that can receive a "ShaderMaterial", create a new "MultiShaderMaterial".
You can add your Shaders in the Managed Shaders property from the inspector.
This will automaticaly bake a new Shader if the automatic mode is activated, or you can manually bake a new shader using the "Bake" button.
If automatic mode is on, any edition on the original shaders will also re-bake the main shader.

Becareful, you should not edit the generated shder, or you may loose your work !
If you really want to edit it, save it first using the "save as" button and then use a standard "ShaderMaterial".

### Author:
- **[Magnat](https://github.com/TheMagnat)**
