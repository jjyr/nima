# Remaining Information to Collect

This file tracks facts still needed before or during implementation.

## Already Confirmed

- Nim compiler is installed: `2.2.10` on macOS arm64.
- Nimble is installed: `0.22.2`.
- Fau is cloned locally at `/Users/jjy/Workspace/fau`.
- Nima should not vendor `libsdl-org/SDL` as a submodule.
- Nimble registry package `sdl3` points to `https://github.com/transmutrix/nim-sdl3`.
- Nim `sdl3` package version `1.1.0` requires Nim `>= 2.0.4`.
- `sdl3` exposes required SDL_GPU symbols including `SDL_CreateGPUDevice`,
  `SDL_ClaimWindowForGPUDevice`, `SDL_AcquireGPUCommandBuffer`, and
  `SDL_CreateGPUShader`.
- `pkg-config sdl3` is available locally after Homebrew install and reports
  SDL3 `3.4.10`.
- Local C/C++ build tools exist: CMake `4.3.3`, Apple clang `17.0.0`, GNU Make
  `3.81`.
- Ninja is not installed locally.
- Pure/headless Nima core now compiles and tests: math, color, transform,
  input, scene stack, draw recorder, facade scope, ImGui layer lifecycle, and
  immediate widget mouse behavior.
- Camera helpers and `withUi` draw-space handling are implemented and tested.
- DPI scale is tracked in `Engine` and filled from
  `SDL_GetWindowDisplayScale` in the SDL bootstrap backend.
- UI capture helpers are present: `uiWantsPointerInput` and
  `uiWantsKeyboardInput`.
- Built-in ImGui-style debug UI now covers the Roast2D egui showcase surface:
  button, checkbox, radio, combo, slider, drag int, ASCII text input,
  collapsing headers, indentation, color edit, separator, progress bar,
  panel layout, same-line layout, and fixed-width button rows.
- Explicit-geometry UI helpers are present for panels, buttons, labels, insets,
  rows, columns, and content alignment.
- Text measurement/layout facade is present with heuristic metrics:
  `measureText`, `layoutText`, and `drawTextLayout`.
- SDL_Renderer and SDL_GPU now support optional SDL3_ttf glyph atlases through
  runtime dynamic loading. `Text.withFont(...)` renders real UTF-8/CJK glyphs
  when SDL3_ttf is present; missing SDL3_ttf falls back to SDL debug text
  without breaking startup.
- Draw API supports line batches and solid/dashed/dotted line patterns; the SDL
  bootstrap approximates thickness with parallel lines.
- Imported asset reload is present for loaded atlas JSON descriptors and prefab
  JSON templates, including mtime polling when auto-reload is enabled.
- Physics query parity now includes layer-filtered point query, AABB overlap,
  sorted raycast, body removal, cuboid/ball collider shapes, and collider
  offsets.
- Atlas descriptors can load JSON frame/clip metadata with a generated fallback.
- Prefab templates can load JSON defaults for tag, size, and color.
- Asset handles track original path, resolved path, and loaded status.
- Texture decode uses the Nim `stb_image` package. The public
  `loadImageRgba` helper decodes PNG and other stb-supported formats to RGBA,
  and both SDL_Renderer and SDL_GPU texture paths consume that decoded data.
- SDL_Renderer and SDL_GPU try runtime-loaded SDL3_image as a fallback when
  `stb_image` cannot decode a loaded texture. The fallback surface is converted
  to RGBA32 before upload.
- SDL_Renderer bootstrap can render loaded image texture handles with tint,
  source rects, rotated transforms, and fallback placeholders.
- SDL audio bridge can play loaded WAV clips through `SDL_AudioStream`, sync
  pause/resume/stop/volume, and passes a dummy audio smoke test.
- SDL3_mixer is dynamically loaded when present and used for non-WAV clips such
  as OGG/MP3/FLAC. Missing SDL3_mixer marks that instance unsupported without
  failing the window loop.
- Roast2D counterpart examples compile in headless mode and with
  `-d:nimaUseSdl`: `atlas_basic`, `audio_basic`, `blink`, `breakout`,
  `diagnostics_overlay`, `hex`, `hotreload`, `imgui_cjk`, `imgui_overlay`,
  `imgui_showcase`, `light2d_basic`, `particles_basic`, `physics_basic`,
  `prefab_basic`, `scene_stack`, `shapes`, `text_test`, `ui_layout`, and
  `window_smoke`.
- The same examples compile with `-d:nimaUseSdlGpu`; runtime visual parity is
  not complete because non-Metal shader blobs, richer text shaping, and several
  GPU batching details are still missing.
- Native Dear ImGui is implemented as an opt-in CImGui/Dear ImGui bridge
  behind `-d:nimaUseNativeImgui`, with SDL_Renderer and SDL_GPU backend
  compile smokes and a `native_imgui_demo` example. The typed helper surface now
  covers common windows, widgets, menus, tabs, tables, popups, tooltips,
  disabled scopes, indentation, clipboard access, and keyboard/gamepad
  navigation toggles.
- Roast2D-shaped `map` and deterministic `tween` modules are implemented.
  `breakout` uses tweened camera shake. Prefab loading accepts JSON and
  RON-like tag/size/color templates plus patch operations for common Roast2D
  `/components/...` paths.
- SDL runtime smoke passes with `SDL_VIDEODRIVER=dummy`.
- SDL audio runtime smoke passes with
  `SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy`.
- Gamepad input is implemented in the core action model and SDL bootstrap:
  SDL gamepad hotplug, button events, normalized axis events, deadzone, and
  `AnyGamepad` bindings.
- UTF-8 text input is implemented through SDL `SDL_EVENT_TEXT_INPUT`,
  `InputState.textInput`, `textInput()`, and focused immediate ImGui text
  widgets. This covers CJK/IME input paths at the engine event level.
- SDL_GPU mirrors the SDL gamepad hotplug, button, and axis event bridge.
- Current local Homebrew/pkg-config check only finds `sdl3`; the optional
  add-on formulas use Homebrew names `sdl3_ttf`, `sdl3_image`, and
  `sdl3_mixer` and may not appear in the default `pkg-config` path. Nima loads
  the corresponding dynamic libraries by normal library name plus common
  Homebrew fallback paths.
- SDL_GPU smoke backend compiles with `-d:nimaUseSdlGpu` and runs locally on
  macOS using Cocoa + Metal. It currently supports swapchain clear, MSL
  shader-backed solid rectangles and textured sprites, batched consecutive
  solid rectangles and same-texture sprites, transformed sprite rotation,
  PNG/BMP/etc. sprite upload, source rects, tint, flip, shader-backed
  solid/dashed/dotted thick lines, filled circles, filled regular polygons,
  polygon outlines, and SDL3_ttf glyph-atlas text. No-font text still uses SDL
  debug-font software surfaces uploaded to GPU textures.
- SDL GPU backend audio sync has been verified with `SDL_AUDIODRIVER=dummy`
  using the same WAV smoke test as the SDL_Renderer bootstrap path.
- Dynamic code hot reload now has a Nim host scene, reloadable dylib example,
  and `nimble hotreloadSmoke` verification. Current API is intentionally small:
  reloadable libraries draw through host callbacks instead of importing the
  engine facade directly.
- The Nim `sdl3` package GPU bindings need local ABI caution: some GPU structs
  expose handle fields as pointer-to-pointer. Nima's SDL_GPU scaffold uses
  narrow local fixed structs for swapchain acquire, render pass target info,
  and blit info.

## Need Before SDL_GPU Feature Parity

- Keep the current SDL_Renderer bootstrap as a visual fallback until the GPU
  path has feature parity for core primitives.
- Confirm shader toolchain:
  `shadercross` CLI location, HLSL-to-MSL/SPIR-V/DXIL output quality, and how
  DXIL blobs are produced on non-Windows developer machines. The current local
  machine does not expose `shadercross`; Nima uses embedded MSL for the first
  Metal shader path and ships `tools/compile_shaders.nim` as the offline build
  entry point.
- Extend shader-backed batching beyond consecutive solid rectangles and
  same-texture sprites to aggregate line/circle/polygon/text mesh submissions
  into fewer transient buffers and render passes.
- Decide whether to upstream or locally wrap fixes for Nim `sdl3` SDL_GPU
  handle-field ABI mismatches.

## Need Before Asset/Text Features

- Decide whether image write/resizing features belong in Nima v1. Image read
  support is currently handled through `stb_image` with optional SDL3_image
  fallback.
- Decide whether to add richer shaping and metric APIs on top of the current
  SDL3_ttf glyph-atlas cache. Current `measureText` remains heuristic.
- Decide whether to expose audio format capability queries in the public API.
  The backend now has SDL core WAV plus optional SDL3_mixer dynamic playback,
  but game code cannot yet ask which formats are supported.
- Decide whether the current vendored CImGui bridge should remain local,
  become a submodule, or be replaced by a managed Nim ImGui package after SDL
  GPU backend coverage is stronger.
- Decide whether atlas should keep JSON as the Nim-native authoring format or
  add full Aseprite/Roast2D imported package compatibility. Prefab now supports
  JSON and a pragmatic RON-like field subset; full RON schema parity remains a
  later asset-pipeline task.

## Need Before Windows Packaging

- Confirm MinGW toolchain availability:
  `x86_64-w64-mingw32-gcc` and `x86_64-w64-mingw32-g++`.
- Choose SDL3 Windows dev package version and document where `SDL3.dll` comes
  from.
- Decide release bundle layout and whether post-build copy scripts are needed.

## Deferred

- CI is intentionally not planned yet.
- Web/WASM is not part of v1.
