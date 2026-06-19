# Nima

Nima is a Nim-native 2D game engine inspired by raylib and fau. It keeps the
public API small and Nim-friendly while using SDL3 for desktop windows, input,
audio, and rendering.

Repository: [jjyr/nima](https://github.com/jjyr/nima)

Current scope:

- Scene lifecycle and global facade APIs.
- +Y-up 2D drawing for rectangles, sprites, lines, circles, polygons, text, and
  UI-space overlays.
- Keyboard, mouse, text input, and gamepad action bindings.
- Texture, font, audio, atlas, prefab, map, tween, particle, light, physics,
  diagnostics, and hot-reload slices.
- Built-in immediate debug UI plus optional native Dear ImGui integration.
- SDL_Renderer bootstrap backend, SDL_GPU backend, and Emscripten web builds.

## File Structure

```text
assets/
  shaders/                 Built-in HLSL sources and compiled-shader folders.
docs/
  *.md                     Design notes for SDL3, packaging, cross-platform,
                           ImGui, hot reload, and API specs.
  web-platform.md          Web build, hosting, and user-project setup guide.
examples/
  *.nim                    Runnable gameplay, rendering, UI, and ImGui examples.
src/
  nima.nim                 Top-level package module.
  nima/prelude.nim         Main game-facing import.
  nima/*.nim               Core engine modules.
  nima/backend/            SDL3 renderer, GPU, audio, image, mixer, and TTF.
  nima/native_imgui/       Optional native CImGui/Dear ImGui bridge.
tests/
  *.nim                    Unit and backend smoke tests.
tools/
  compile_shaders.nim      Optional SDL_shadercross shader build helper.
  platform_examples.nim    Cross-target example build/package helper.
  build_sdl3_emscripten.sh SDL3 static-library builder for web.
  linux.Dockerfile         Optional Linux example builder from non-Linux hosts.
.dockerignore              Keeps Docker Linux builder context small.
```

## Backends

Nima has these main build modes:

```sh
nim c -r examples/breakout.nim
```

Headless/default mode. Useful for tests and compile checks. It records draw
commands but does not open an SDL window.

```sh
nim c -d:nimaUseSdl -r examples/breakout.nim
```

SDL_Renderer backend. This is the simplest runtime path and the recommended
first backend when trying examples.

```sh
nim c -d:nimaUseSdlGpu -r examples/breakout.nim
```

SDL_GPU backend. On macOS it uses Metal with embedded MSL shaders for core 2D
primitives. Vulkan and Direct3D 12 shader packaging are planned through
`tools/compile_shaders.nim` and SDL_shadercross.

Native Dear ImGui is opt-in:

```sh
nimble submodules
nim c -d:nimaUseSdl -d:nimaUseNativeImgui -r examples/native_imgui_demo.nim
nim c -d:nimaUseSdlGpu -d:nimaUseNativeImgui -r examples/native_imgui_demo.nim
```

`nimble submodules` initializes git submodules. Native Dear ImGui uses the CImGui
submodule at `src/nima/native_imgui/private/cimgui`; the nested Dear ImGui
submodule must also be present.

## SDL3 Setup

On macOS with Homebrew:

```sh
brew install sdl3
```

Optional add-ons:

```sh
brew install sdl3_ttf sdl3_image sdl3_mixer
```

`sdl3_ttf` is required for real UTF-8/CJK font rendering through
`Text.withFont(...)` and `setImguiFont(...)`. Without it, Nima falls back to SDL
debug text.

## Running Examples

From the repository root:

```sh
cd <repo-path>
```

Run a small smoke window:

```sh
nim c -d:nimaUseSdl -r examples/window_smoke.nim
```

Run gameplay and rendering examples:

```sh
nim c -d:nimaUseSdl -r examples/breakout.nim
nim c -d:nimaUseSdl -r examples/shapes.nim
nim c -d:nimaUseSdl -r examples/ui_layout.nim
nim c -d:nimaUseSdl -r examples/imgui_showcase.nim
nim c -d:nimaUseSdl -r examples/imgui_cjk.nim
```

Run the same examples through SDL_GPU:

```sh
nim c -d:nimaUseSdlGpu -r examples/breakout.nim
nim c -d:nimaUseSdlGpu -r examples/shapes.nim
nim c -d:nimaUseSdlGpu -r examples/ui_layout.nim
```

Batch build examples:

```sh
nimble examples
nimble sdlExamples
nimble sdlGpuExamples
nimble submodules
nimble nativeImguiSmoke
```

Build browser examples with Emscripten:

```sh
nimble sdl3Emscripten
export SDL3_EMSCRIPTEN_PREFIX=<sdl3-emscripten-prefix>
NIMA_EXAMPLE=breakout nimble webExample
nimble webExamples
python3 -m http.server 8000 -d build/web/breakout
```

Cross-compile Windows examples with MinGW:

```sh
NIMA_EXAMPLE=breakout nimble windowsExample
nimble windowsExamples
```

Windows packages are emitted under `build/windows/<example>/`. Put `SDL3.dll`
next to the executable before running on Windows, or set
`SDL3_WINDOWS_DLL_DIR=<sdl3-windows-dll-dir>` before the package task to copy
known DLLs.

Build Linux examples on a Linux host:

```sh
nimble linuxExamples
```

Build Linux examples from a non-Linux host with Docker:

```sh
NIMA_TARGET=linux NIMA_EXAMPLE=breakout NIMA_PLATFORM_ARGS=--package nimble platformExamples
nimble linuxExamples
NIMA_TARGET=linux NIMA_PLATFORM_ARGS=--check-tools nimble platformExamples
```

Linux packages are emitted under `build/linux/<example>/`. Install SDL3 on the
target Linux machine or set `SDL3_LINUX_LIB_DIR=<sdl3-linux-lib-dir>` before
packaging to copy local SDL3 shared libraries. Docker builds use the Docker
platform architecture by default.

Run tests:

```sh
nim c --nimcache:nimcache/test -r tests/all.nim
SDL_VIDEODRIVER=dummy nim c --nimcache:nimcache/sdl_smoke -d:nimaUseSdl -r tests/sdl_smoke.nim
```

## Minimal App

```nim
import nima/prelude

type Game = ref object of Scene

method draw(scene: Game) =
  drawRect(rgb(0.04, 0.05, 0.07), viewSize(), transform(vec3(0, 0, -1)))
  drawCircle(vec3(0, 0, 0), 32, Yellow)

when isMainModule:
  run app(Game(), title = "Nima", size = ivec2(800, 600))
```
