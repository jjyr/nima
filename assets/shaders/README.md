# Nima Built-In Shaders

Built-in shader source lives in `source/*.hlsl`. Precompiled runtime blobs are
expected under `compiled/<backend>/`:

- `compiled/msl/*.msl` for Metal.
- `compiled/spirv/*.spv` for Vulkan.
- `compiled/dxil/*.dxil` for Direct3D 12.

Regenerate blobs with:

```sh
nimble shaders
```

The task uses `shadercross` from SDL_shadercross when installed. Missing
`shadercross` is treated as a skip so users with only SDL3 installed can still
build the engine.
