# Nima Engine Implementation Plan

> Primary execution skill: `execute-plan`

**Goal:** Build the first runnable Nima 2D engine slice with Nim-native APIs and an SDL3 backend.

**Non-Goals:** Full Roast2D parity, web/terminal/mobile support, editor tooling, production asset pipeline, rich text shaping, full physics, and CI setup.

**Execution Context:** Current branch `codex/engine-core` in
`/Users/jjy/Documents/nima`.

**Key References:**

- `docs/specs/core-api-and-structures.md`
- `docs/sdl3-backend.md`
- `docs/packaging-sdl3.md`
- `docs/cross-platform.md`
- `docs/fau-reference.md`
- Local Fau reference: `/Users/jjy/Workspace/fau`
- Local Roast2D reference: `/Users/jjy/Workspace/roast2d`

**Verification Gate:**

- `nimble test`
- `nim c --nimcache:nimcache/window_smoke_run -r examples/window_smoke.nim`
- `nim c --nimcache:nimcache/breakout_run -r examples/breakout.nim`
- `nim c --nimcache:nimcache/breakout_release -d:release examples/breakout.nim`
- `nim c --nimcache:nimcache/sdl_smoke -d:nimaUseSdl tests/sdl_smoke.nim`
- `SDL_VIDEODRIVER=dummy tests/sdl_smoke`
- `nim c --nimcache:nimcache/sdl_audio_smoke -d:nimaUseSdl tests/sdl_audio_smoke.nim`
- `SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy tests/sdl_audio_smoke`
- `nim c --nimcache:nimcache/breakout_sdl_release -d:nimaUseSdl -d:release examples/breakout.nim`

Current local state: Nim 2.2.10 and Nimble 0.22.2 are installed. Homebrew
SDL3 is installed and `pkg-config --modversion sdl3` returns `3.4.10`. Nima
uses Nimble package `sdl3 >= 1.1.0`; native SDL3 C libraries come from the
developer machine or release bundle.

## Current Implementation Snapshot

Completed in this slice:

- Nim package scaffold, prelude exports, ARC config, and Homebrew SDL rpaths.
- Core math, color, transform, handle, scene stack, facade, input, and draw
  recorder APIs.
- SDL3 window/event loop and SDL_Renderer bootstrap backend behind
  `-d:nimaUseSdl`.
- Rendering for rects, image-backed sprite handles with placeholder fallback,
  lines, circles, filled polygons, polygon outlines, and SDL debug text.
- Transform geometry now exposes exact quad corners and bounds. SDL_Renderer
  renders non-zero `Transform.angle` rects with `SDL_RenderGeometry`; SDL_GPU
  uses embedded MSL shader pipelines on Metal for solid quads and textured
  sprites, including sprite rotation.
- Engine systems: diagnostics, particles, light2d overlay, audio state,
  simple AABB physics, prefab instances, atlas clips, camera/UI draw-space, and
  immediate debug UI widgets.
- Added Roast2D-shaped `map` and deterministic `tween` modules. `breakout`
  now uses tweened camera shake on paddle/brick hits.
- Explicit-geometry UI helpers now cover panels, buttons, labels, insets, rows,
  columns, and content alignment.
- Text APIs include `measureText`, `layoutText`, and `drawTextLayout` with
  deterministic heuristic metrics. `Text.withFont(...)` renders through
  runtime-loaded SDL3_ttf glyph atlases when available.
- Draw APIs include line batches plus solid/dashed/dotted line patterns.
- ImGui-style debug UI now exposes pointer/keyboard capture through
  `uiWantsPointerInput()` and `uiWantsKeyboardInput()`, with showcase widgets
  for buttons, checkbox, radio, combo, sliders, drag int, ASCII text input,
  collapsing headers, indentation, color edit, separators, progress bars,
  panel layout, same-line layout, and fixed-width button rows.
- Input now covers keyboard, mouse, scroll, gamepad buttons, normalized gamepad
  axes, deadzone, `AnyGamepad` bindings, and SDL gamepad hotplug.
- SDL backend WAV playback bridge through `SDL_AudioStream`, including pause,
  resume, stop, loop refill, and volume sync.
- Optional SDL3_mixer dynamic loading for non-WAV audio clips such as OGG/MP3,
  with shared audio sync code used by both SDL_Renderer and SDL_GPU.
- Asset handles track original path, resolved path, and loaded status.
- `stb_image` backs texture/image decoding for PNG/JPEG/BMP/TGA-class assets.
  SDL3_image is dynamically loaded as a fallback when present.
- Asset roots are configurable through `app(..., assetRoots = [...])` and
  direct asset module APIs.
- Imported asset reload refreshes loaded atlas JSON descriptors and prefab JSON
  templates; auto-reload polls their mtimes each frame when enabled.
- Physics includes cuboid/ball collider shapes, collider offsets, layer
  filtering, point query, AABB overlap, sorted raycast, and body removal.
- Atlas can load JSON frame/clip descriptors with generated fallback frames.
- Prefab can load JSON and RON-like template defaults for tag, size, and color,
  and supports `PrefabPatchOp` add/replace/remove calls for tag, sprite size,
  and sprite color.
- Roast2D counterpart examples: `atlas_basic`, `audio_basic`, `blink`,
  `breakout`, `diagnostics_overlay`, `hex`, `hotreload`, `imgui_cjk`,
  `imgui_overlay`, `imgui_showcase`, `light2d_basic`, `particles_basic`,
  `physics_basic`, `prefab_basic`, `scene_stack`, `shapes`, `text_test`, and
  `ui_layout`.
  `breakout` demonstrates keyboard plus gamepad action bindings and tweened
  camera shake.

Deferred:

- SDL_GPU production renderer work beyond the first Metal/MSL pipeline:
  shadercross-built SPIR-V/DXIL blobs, ring-buffered/broader batched buffers,
  render textures, and post passes.
- Native Dear ImGui follow-up: drag/drop and docking wrappers,
  clipboard/gamepad nav, and Linux/Windows runtime validation.
- Public audio capability queries and richer mixer controls.
- Full Aseprite compatibility for Roast2D imported atlas assets.
- CI.

---

## Task 1: Scaffold Nim Package

**Objective:** Create a buildable Nim package with module skeleton and docs aligned to the spec.

**Files:**

- Create: `nima.nimble`
- Create: `config.nims`
- Create: `src/nima.nim`
- Create: `src/nima/prelude.nim`
- Create: `tests/all.nim`

**Context Notes:**

- Require Nim `>= 2.0.4`.
- Declare `requires "sdl3 >= 1.1.0"` and `requires "stb_image >= 2.5"`
  explicitly.
- Do not add SDL as a git submodule.
- Keep SDL3_image, SDL3_ttf, SDL3_mixer, and Box2D out of the initial required
  dependency list.

**Steps:**

1. Add package metadata and Nimble tasks: `test`, `examples`, and later `shaders`.
2. Add top-level module exports with no SDL types exposed.
3. Add placeholder test suite that imports `nima/prelude`.
4. Add `config.nims` with ARC GC and Fau-style platform linker choices:
   `-static-libstdc++ -static-libgcc` on Windows, `g++` linker for C++-linked builds where needed.

**Verification:**

- Run: `nimble test`
- Expect: package imports and placeholder tests pass.

**Done When:**

- Package can be imported as `import nima/prelude`.

## Task 2: Implement Core Value Types

**Objective:** Implement public math, color, transform, rect, and handle types.

**Files:**

- Create: `src/nima/math.nim`
- Create: `src/nima/color.nim`
- Create: `src/nima/transform.nim`
- Create: `src/nima/assets.nim`
- Create: `tests/core_types_test.nim`

**Context Notes:**

- Preserve Roast2D coordinate semantics: +Y up, Z as draw order.
- Keep math dependency-free for the public API.

**Steps:**

1. Implement `Vec2`, `Vec3`, `IVec2`, `Rect`, constructors, and common ops.
2. Implement `Color` helpers and constants.
3. Implement `Transform` with position, scale, angle, and bounds helper.
4. Implement typed `Handle[T]` ids and basic equality/hash support.
5. Add unit tests for geometry, transform bounds, color byte conversion, and handles.

**Verification:**

- Run: `nimble test`
- Expect: all pure unit tests pass without SDL.

**Done When:**

- Core value types are stable enough for scene and drawing APIs.

## Task 3: Add Scene, Engine, and Facade Runtime

**Objective:** Build engine lifecycle without rendering backend dependency.

**Files:**

- Create: `src/nima/scene.nim`
- Create: `src/nima/engine.nim`
- Create: `src/nima/facade.nim`
- Create: `src/nima/app.nim`
- Create: `tests/scene_runtime_test.nim`

**Context Notes:**

- Facade procs should fail clearly outside engine scope.
- Scene commands should apply at frame-safe boundaries.

**Steps:**

1. Define `Scene` base methods and scene stack entry.
2. Define `Engine` time, frame, exit flag, scene stack, scene queue, and input placeholder.
3. Implement current-engine scope for facade procs.
4. Implement `setScene`, `replaceScene`, `pushScene`, `popScene`, and payload base type.
5. Add headless frame stepping API for tests.

**Verification:**

- Run: `nimble test`
- Expect: scene lifecycle order, stack pause/resume, and facade scope tests pass.

**Done When:**

- A scene can run headlessly through init/update/draw lifecycle.

## Task 4: Implement Input Model

**Objective:** Add frame-stable input state and action bindings.

**Files:**

- Create: `src/nima/input.nim`
- Modify: `src/nima/engine.nim`
- Modify: `src/nima/facade.nim`
- Create: `tests/input_test.nim`

**Context Notes:**

- Action bindings are keyed by enum type and enum value.
- SDL event mapping happens later in backend task.

**Steps:**

1. Implement `KeyCode`, `MouseButton`, `InputSource`, and key/mouse constructors.
2. Track down, just pressed, just released, mouse position, and scroll delta.
3. Add action binding APIs and facade wrappers.
4. Add tests for action isolation across enum types and per-frame edge reset.

**Verification:**

- Run: `nimble test`
- Expect: input unit tests pass without SDL.

**Done When:**

- Game code can use action APIs in headless tests.

## Task 5: Build Draw Recorder

**Objective:** Record immediate draw calls into backend-neutral frame commands.

**Files:**

- Create: `src/nima/draw.nim`
- Modify: `src/nima/facade.nim`
- Modify: `src/nima/engine.nim`
- Create: `tests/draw_recorder_test.nim`

**Context Notes:**

- Do not call SDL in draw facade procs.
- Keep command data simple and serializable for tests.

**Steps:**

1. Define `Sprite`, `Text`, `Line`, `DrawCommand`, and `FrameRecorder`.
2. Implement `drawRect`, `draw`, `drawLine`, `drawCircle`, `drawText`, and `drawPoly` as recorder writes.
3. Add sorting keys for pass, texture id, and Z while preserving deterministic order.
4. Add tests that assert command contents from facade calls.

**Verification:**

- Run: `nimble test`
- Expect: recorder tests pass without SDL.

**Done When:**

- Scenes can produce complete backend-neutral draw frames.

## Task 6: Add SDL3 Window and Event Backend

**Objective:** Create SDL3 window through `pkg/sdl3`, run event loop, and feed input state.

**Files:**

- Create: `src/nima/backend/sdlgpu.nim`
- Modify: `src/nima/app.nim`
- Modify: `src/nima/input.nim`
- Create: `examples/window_smoke.nim`

**Context Notes:**

- Use `import pkg/sdl3`.
- Follow Fau's event boundary: map SDL scancodes/buttons/events into Nima enums and snapshots.
- Keep raw SDL types out of `nima/prelude`.

**Steps:**

1. Initialize SDL video subsystem.
2. Create a window from `App`.
3. Poll events and map quit, resize, keyboard, mouse, and wheel events.
4. Convert high-DPI mouse coordinates into Nima +Y-up view coordinates.
5. Update `WindowMetrics` and engine input snapshots.
6. Run scene lifecycle in the real app loop.

**Verification:**

- Run: `nim c -r examples/window_smoke.nim`
- Expect: window opens, close event exits cleanly, key/mouse logs work if enabled.

**Done When:**

- A scene updates from an SDL3 window loop.

## Task 7: Implement SDL_GPU Basic Renderer

**Objective:** Render rectangles and textured sprites through SDL_GPU.

**Files:**

- Modify: `src/nima/backend/sdlgpu.nim`
- Create: `src/nima/backend/shaders.nim`
- Create: `assets/shaders/source/basic2d.vert.glsl`
- Create: `assets/shaders/source/basic2d.frag.glsl`
- Create: `examples/rects.nim`

**Context Notes:**

- The Nim `sdl3` package exposes SDL_GPU symbols required for device, shader, command buffer, and swapchain work.
- Ship compiled shader blobs with the package.
- Keep coordinate conversion inside backend projection.

**Steps:**

1. Create SDL_GPU device and claim the window.
2. Select shader format supported by the device.
3. Create rect/sprite graphics pipeline, sampler, dynamic buffers, and swapchain render pass.
4. Convert recorder commands into batched vertices.
5. Submit command buffer and present.
6. Track draw calls, batches, uploads, and present time.

**Verification:**

- Run: `nim c -r examples/rects.nim`
- Expect: colored rectangles render in correct +Y-up positions.

**Done When:**

- Core draw API produces visible SDL_GPU output.

**Status:** Partially complete. The current SDL_GPU backend creates the device,
claims the window, clears/presents the swapchain, uploads textures, and renders
rects and sprites through embedded MSL graphics pipelines on Metal. The sprite
pipeline supports source rectangles, tint, flip, and rotation. Lines,
dashed/dotted line segments, filled circles, filled regular polygons, and
polygon outlines are generated as solid triangle meshes on the same MSL
pipeline, with shaderless blit/raster fallback on non-MSL backends.
Cross-platform shader blobs, ring-buffered/broader batching, render
textures/post passes, and richer text shaping remain pending. Native Dear ImGui
draw data is integrated behind `-d:nimaUseNativeImgui`.

## Task 8: Add Texture Assets and Sprite Example

**Objective:** Load textures and render sprites through handles.

**Files:**

- Modify: `src/nima/assets.nim`
- Modify: `src/nima/backend/sdlgpu.nim`
- Create: `examples/sprites.nim`
- Add: `examples/assets/` sample texture

**Context Notes:**

- Image loading now uses `stb_image` first and optional SDL3_image fallback
  when the native add-on library is available.

**Steps:**

1. Resolve asset root.
2. Load image bytes and create/upload SDL_GPU texture.
3. Cache texture resources by handle id.
4. Implement `Sprite.src`, anchor, tint color, and flip flags.
5. Add sprite example.

**Verification:**

- Run: `nim c -r examples/sprites.nim`
- Expect: sprite renders with correct anchor, src rect, and tint.

**Done When:**

- Texture-backed sprites work through public handles.

## Task 9: Add Breakout Example

**Objective:** Prove Nima's core API with a small game similar to Roast2D's breakout.

**Files:**

- Create: `examples/breakout.nim`
- Add: `examples/assets/` if needed

**Context Notes:**

- Use facade-first style only.
- Do not require audio, physics, text, or particles for the first version.

**Steps:**

1. Implement player, ball, bricks, and collision in user code.
2. Use action bindings for movement and quit.
3. Use `drawRect` for all gameplay visuals.
4. Keep constants and code readable as API documentation.

**Verification:**

- Run: `nim c -r examples/breakout.nim`
- Expect: playable breakout loop with stable frame timing and input.

**Done When:**

- Breakout demonstrates app, scene, input, update, draw, and SDL_GPU render path.

## Next Step

Continue the SDL_GPU renderer milestone: shadercross toolchain, SPIR-V/DXIL
shader blobs, ring-buffered dynamic buffers, render textures/post passes, and
Linux/Windows native ImGui runtime validation.
