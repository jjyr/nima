# SDL3 Backend Design

Nima uses SDL3 as the platform layer and SDL_GPU as the target primary rendering
backend. Nim code should import SDL through the Nimble `sdl3` package:

```nim
import pkg/sdl3
```

SDL3 provides windowing, events, input, audio integration points, and a
cross-platform GPU abstraction over Metal, Vulkan, and Direct3D 12.

## Current Implementation Status

The current repository has a verified headless core and an SDL3 runtime path
gated by `-d:nimaUseSdl`.

Implemented now:

- SDL3 initialization and shutdown.
- SDL3 window creation with high-DPI support.
- SDL_Renderer bootstrap renderer.
- SDL_GPU backend scaffold gated by `-d:nimaUseSdlGpu`: device creation,
  window claim/release, swapchain acquisition, clear pass, MSL shader pipelines
  for solid quads, textured sprite quads, thick line meshes, filled circles,
  filled regular polygons, and polygon outlines on Metal, stb-decoded texture
  upload with optional SDL3_image fallback, source rectangles/tint/flip/sprite
  rotation, and SDL3_ttf glyph-atlas text for `Text.withFont(...)`. Non-MSL
  backends fall back to shaderless `SDL_BlitGPUTexture` paths for these
  primitives. No-font text falls back to SDL debug text rendered into a
  software surface and uploaded to SDL_GPU textures.
- SDL_GPU loop shares the same SDL audio bridge used by the SDL_Renderer
  bootstrap path.
- SDL core WAV playback bridge for `AudioState` through `SDL_AudioStream`, with
  optional SDL3_mixer dynamic loading for non-WAV clips.
- Optional native Dear ImGui bridge gated by `-d:nimaUseNativeImgui`, using
  vendored CImGui/Dear ImGui, SDL3 event processing, `imgui_impl_sdlrenderer3`
  for the SDL_Renderer backend, and `imgui_impl_sdlgpu3` for the SDL_GPU
  backend.
- Window close, resize, keyboard, mouse button, mouse motion, mouse wheel, and
  text-input, gamepad hotplug/button/axis event handling.
- Logical presentation mapping for fixed view size, fit, fill, stretch, and
  integer scale.
- Nima coordinate conversion from SDL top-left coordinates into +Y-up world
  coordinates.
- Rendering for rects, image-backed sprites with tint/source rectangles/fallback
  placeholders, lines, filled circles, filled polygons, polygon outlines, and
  SDL debug text. Texture decode uses `stb_image`, so PNG/JPEG/BMP/TGA-class
  assets do not require SDL3_image. If `stb_image` cannot decode a loaded
  texture, the SDL backends try runtime-loaded SDL3_image and upload the
  resulting RGBA surface.
- World/UI draw-space handling: world commands follow `cameraPos` and
  `cameraZoom`; UI commands from `withUi`, diagnostics, and immediate UI stay
  fixed to the logical view.
- Runtime smoke test through `tests/sdl_smoke.nim` with `SDL_VIDEODRIVER=dummy`.
- Runtime GPU smoke tests through `tests/sdl_gpu_smoke.nim`,
  `tests/sdl_gpu_sprite_smoke.nim`, and `tests/sdl_gpu_text_smoke.nim`; local
  macOS runs report Cocoa + Metal.
- Runtime audio smoke test through `tests/sdl_audio_smoke.nim` with
  `SDL_AUDIODRIVER=dummy`; the test generates a temporary WAV and confirms the
  SDL audio stream path opens. The same audio smoke has also been run through
  `-d:nimaUseSdlGpu` with native video and dummy audio.
- Full example compile pass through `nimble sdlExamples` and
  `nimble sdlGpuExamples`.

SDL_GPU now has the first native runtime path and a Metal/MSL shader path for
core 2D primitives. It is still not production-complete:
shadercross-built SPIR-V/DXIL, broader batched buffers, render textures/post
passes, and runtime validation of native ImGui on Linux/Vulkan and
Windows/D3D12 are still pending.

Local SDL3 status: Homebrew SDL3 `3.4.10` is available and
`pkg-config --modversion sdl3` resolves.

## Backend Choice

Use SDL_GPU for the production renderer instead of SDL_Renderer.

Reasons:

- Cross-platform GPU model with modern backends: Metal on macOS, Vulkan on
  Linux, Direct3D 12 on Windows.
- Better long-term fit for batching, custom shaders, render textures, post
  processing, light passes, particles, and text atlases.
- Matches the direction proven by Nim SDL projects: Fau uses `pkg/sdl3` for its
  SDL backend, while `nim2d` proves SDL_GPU is viable from Nim.
- Keeps SDL_Renderer as a bootstrap/fallback backend while SDL_GPU is being
  built.

Nima should not vendor `libsdl-org/SDL` as a submodule. Native SDL3 libraries
are supplied by the developer machine or release bundle.

## Responsibilities

The backend owns low-level platform state:

```text
SdlGpuBackend
  sdl3.Window / SDL_Window
  sdl3.SDL_GPUDevice
  swapchain ownership
  SDL event pump
  render pipelines
  GPU buffers
  texture cache
  samplers
  frame command buffer
```

The engine owns game state:

```text
Engine
  scene stack
  input snapshot
  time and frame counters
  asset manager
  draw recorder
  perf counters
```

Boundary rule: SDL handles and GPU resources do not leak into `nima/prelude`.

## Frame Flow

Per frame:

1. Poll SDL events.
2. Update input state from keyboard, mouse, gamepad, window, and quit events.
3. Compute `tick`, `time`, and `frame`.
4. Enter engine facade scope.
5. Apply pending scene queue so initial scene `init` runs inside facade scope.
6. Run top scene `update`.
7. Run scene `draw` and record draw commands.
8. Apply scene queue at a safe boundary.
9. Submit recorded frame to the active SDL renderer.
10. Present.
11. Reset per-frame input edges and draw recorder.

## Rendering Flow

The renderer should mirror Roast2D's recorder model:

```text
drawRect / draw / drawText / drawLine
  -> DrawCommand
  -> FrameRecorder
  -> batch and sort by pass, pipeline, texture, z
  -> SDL_GPU command buffer
  -> SDL_GPU render pass
  -> swapchain texture
```

Current SDL_Renderer bootstrap pass:

- Clears the logical render target.
- Sorts recorded commands by Z and insertion order.
- Converts Nima +Y-up world coordinates into SDL logical renderer coordinates.
- Applies the engine camera to world commands and leaves UI commands unshifted.
- Caches SDL textures for loaded image texture handles and releases them on
  backend shutdown.
- Uses `SDL_RenderGeometry` for filled regular polygons.
- Uses `SDL_RenderGeometry` for transformed solid rectangles when
  `Transform.angle` is non-zero.
- Uses parallel SDL lines for bootstrap line thickness and segments dashed or
  dotted line patterns before submission.
- Uses runtime-loaded SDL3_ttf for `Text.withFont(...)` when the native
  library is present. Glyphs are packed into a per-font-size atlas texture and
  tinted per draw command; `SDL_RenderDebugText` remains the no-font/fallback
  path.
- Uses runtime-loaded SDL3_image as a texture decode fallback after
  `stb_image` fails.
- Updates logical window size and DPI scale from SDL window metrics.

Current SDL_GPU scaffold pass:

- Creates an SDL_GPU device and claims the SDL window.
- Acquires the swapchain texture each frame and clears it with the first
  full-view background rect when present.
- Sorts recorded commands by Z and insertion order.
- On Metal, renders `drawRect` commands through an embedded MSL solid-quad
  graphics pipeline. Consecutive sorted `drawRect` commands are batched into
  one transient vertex buffer, one render pass, and one primitive draw while
  preserving Z/order semantics. Non-MSL backends fall back to cached 1x1 GPU
  color texture blits; rotated solid rects then use the scanline blit path used
  by polygons.
- Uploads decoded RGBA textures into `SDL_GPUTexture` objects and renders
  `Sprite` commands through an embedded MSL textured-quad graphics pipeline on
  Metal, including source rectangles, tint, flip, and `Transform.angle`
  rotation. Consecutive sorted sprites with the same texture handle are batched
  into one vertex buffer, one sampler binding, and one primitive draw. Non-MSL
  backends fall back to `SDL_BlitGPUTexture`, including source rectangles,
  CPU-tinted texture variants cached by `(texture, rgba8)`, and basic flip
  mode; that fallback cannot rotate textured quads.
- Uses the same SDL3_image fallback surface path as SDL_Renderer before GPU
  texture upload, so fallback image formats work in both SDL backends.
- Renders solid/dashed/dotted lines, filled circles, filled regular polygons,
  and polygon outline commands as generated triangle meshes through the solid
  MSL pipeline on Metal. Non-MSL backends retain the shaderless blit-based
  rasterizer fallback.
- Renders `drawText` with runtime-loaded SDL3_ttf glyph atlases when
  `Text.withFont(...)` is used. On Metal, glyph quads share the existing sprite
  pipeline and submit one draw per text command. Otherwise the backend draws
  SDL debug text into software surfaces, uploads those surfaces to GPU textures,
  and blits them into the swapchain. This also powers the built-in immediate
  ImGui text path.
- Uses a small local ABI fix for SDL_GPU swapchain/render-pass/blit structs
  because the current Nim `sdl3` package represents some GPU handle fields as
  pointer-to-pointer where SDL expects a handle pointer.
- Updates `Perf.batches` from the SDL_GPU submission loop so diagnostics can
  display the last rendered batch count.
- When built with `-d:nimaUseNativeImgui`, starts a final UI render pass with
  `SDL_GPU_LOADOP_LOAD` and submits Dear ImGui draw data through the official
  SDL_GPU ImGui backend.
- Does not yet ship SPIR-V/DXIL shader blobs for non-Metal shader-backed
  sprite/text rotation.

Current SDL audio bridge:

- Scans `engine.audio.instances` after each frame step.
- Opens SDL audio stream lazily for loaded `.wav` clips.
- For non-WAV clips, tries runtime-loaded SDL3_mixer and plays through a mixer
  track when available.
- Applies master, bus, and per-instance volume through SDL stream gain or
  SDL3_mixer track gain.
- Mirrors pause/resume/stop state from the engine.
- Requeues looped WAV clips while the stream drains.
- Skips unsupported formats or missing optional mixer libraries without failing
  the window loop.

Target SDL_GPU passes:

- `World`: camera-transformed game coordinates.
- `Ui`: pixel or virtual-screen coordinates.

Future passes:

- `Light2D`: ambient and additive light pass.
- `Post`: render-to-texture then fullscreen shader.

## Coordinate Conversion

Public coordinates are bottom-left positive Y up. SDL_GPU viewport and texture
coordinates use top-left positive Y down in important places. Nima must hide
this by owning projection matrices.

Required behavior:

- World projection maps virtual world coordinates to SDL_GPU clip space.
- UI projection maps UI coordinates consistently without user-side Y flipping.
- Texture source rectangles use pixel-space top-left convention internally, but
  sprite anchors remain public bottom-left/world-friendly semantics.

## GPU Resources

Create and cache:

- Default rect pipeline.
- Textured sprite pipeline.
- Line pipeline or line mesh builder.
- Circle/polygon pipeline or generated meshes.
- Default sampler.
- Per-texture `SDL_GPUTexture`.
- Dynamic vertex/index transfer buffers.

Resource uploads should happen before render pass work when possible. Avoid
creating and releasing GPU resources inside hot per-frame loops.

SDL_GPU resources can be bound by in-flight command buffers. Use SDL_GPU cycling
rules for dynamic buffers and render targets, or keep ring-buffered resources in
Nima's backend.

## Shader Strategy

SDL_GPU requires backend-compatible shader formats. V1 should ship precompiled
shader blobs:

- SPIR-V for Vulkan.
- MSL for Metal.
- DXIL or compatible Direct3D 12 format when supported by the chosen toolchain.

Use SDL_shadercross as the offline shader build path. Runtime shader
cross-compilation is optional and should not be required for normal users.

Nima package layout reserves:

```text
assets/shaders/source/*.hlsl
assets/shaders/compiled/msl/*.msl
assets/shaders/compiled/spirv/*.spv
assets/shaders/compiled/dxil/*.dxil
tools/compile_shaders.nim
```

The current package includes the HLSL sources and the compile tool. The tool
uses the official SDL_shadercross CLI:

```sh
shadercross assets/shaders/source/quad.vert.hlsl -s HLSL -d MSL -t vertex -e main -o assets/shaders/compiled/msl/quad.vert.msl
```

`nimble shaders` skips cleanly when `shadercross` is not installed. Runtime
still uses the embedded MSL path on Metal until packaged shader blob loading is
enabled in the SDL_GPU backend.

## Text and Images

Recommended staged approach:

1. V1 textures: load PNG and common image formats through the Nim `stb_image`
   package and upload decoded RGBA pixels into SDL textures or SDL_GPU textures.
2. V1 text: `Text.withFont(...)` uses runtime-loaded SDL3_ttf and per-font-size
   glyph atlas caching in both SDL backends.
3. Current `measureText`, `layoutText`, and `drawTextLayout` APIs still use
   deterministic backend-neutral heuristic metrics.
4. Later text: richer shaping can be added behind the same `Text` API.

Text must use an atlas cache. Recreating glyph textures per frame is not
acceptable.

## Input Mapping

SDL events feed Nima input:

- SDL keyboard scancodes map to `KeyCode`.
- SDL text-input events append UTF-8 text to `InputState.textInput` for the
  current frame; SDL backends start text input on the window during runtime.
- Mouse button and motion events update `MouseButton` and `mousePos`.
- Mouse wheel events update frame scroll delta.
- Gamepad add/remove events open and close SDL gamepads.
- Gamepad buttons map to `GamepadButton`.
- Gamepad axes map to normalized `GamepadAxis` values in `[-1, 1]` and pass
  through the Nima deadzone before actions read them.

Use physical key identity for game actions by default. Text input should be a
separate API later.

Current SDL_Renderer and SDL_GPU paths initialize `SDL_INIT_GAMEPAD`, open
existing gamepads at startup, and also open hot-plugged gamepads from
`SDL_EVENT_GAMEPAD_ADDED`. Public action bindings stay backend-neutral:

```nim
bindAction(moveLeft, key(kcLeft))
bindAction(moveLeft, gamepadButton(gpbDpadLeft))
bindAction(moveLeft, gamepadAxis(gpaLeftX, gadNegative))
```

## Error Handling

Backend init failures should raise a Nima exception with SDL's last error text.

Examples:

- SDL initialization failed.
- Window creation failed.
- GPU device creation failed.
- Window cannot be claimed by GPU device.
- Swapchain texture acquisition failed.
- Required shader format is not available.

Per-frame recoverable failures should be logged and surfaced through diagnostics
where possible. Device loss policy can be designed after the first backend is
running.

## Diagnostics

Expose a `Perf` snapshot:

```nim
type Perf* = object
  fps*: float32
  drawCalls*: int
  batches*: int
  resourceUploads*: int
  assetsLoaded*: int
  assetsPending*: int
  frameMs*: float32
  updateMs*: float32
  drawMs*: float32
  presentMs*: float32
```

Built-in diagnostics overlay is optional after text works.

## References

- SDL3 GPU API: https://wiki.libsdl.org/SDL3/CategoryGPU
- SDL3 migration notes: https://wiki.libsdl.org/SDL3/README-migration
- SDL_shadercross: https://github.com/libsdl-org/SDL_shadercross
- Fau SDL backend reference: `/Users/jjy/Workspace/fau/src/fau/backend/sdlcore.nim`
- Nim `sdl3` package: https://github.com/transmutrix/nim-sdl3
- Nim2D SDL3/SDL_GPU engine: https://github.com/nim2d/nim2d
