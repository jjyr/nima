# Packaging SDL3 for Nima

Nima should use the Nimble `sdl3` package for SDL3 bindings, following the
shape used by Fau. SDL C libraries are provided by the developer or release
package, not by a git submodule in this repository.

Current repository state follows this: `nima.nimble` declares
`requires "sdl3 >= 1.1.0"` and `requires "stb_image >= 2.5"`; there is no
`deps/SDL3` submodule.

Local validation state:

- Homebrew SDL3 is installed at `/opt/homebrew/opt/sdl3`.
- `pkg-config --modversion sdl3` returns `3.4.10`.
- `config.nims` adds Homebrew library paths and rpaths for macOS so the
  `pkg/sdl3` dynlib loader can find `libSDL3.dylib`.
- `tests/sdl_smoke.nim` runs under `SDL_VIDEODRIVER=dummy` and exits after one
  frame.
- `tests/sdl_gpu_smoke.nim`, `tests/sdl_gpu_sprite_smoke.nim`, and
  `tests/sdl_gpu_text_smoke.nim` build with `-d:nimaUseSdlGpu` and run locally
  on macOS using Cocoa + Metal. They open a native window, so they are not dummy
  video smoke tests.
- `tests/sdl_audio_smoke.nim` runs under dummy video/audio, generates a
  temporary WAV, and exercises the SDL audio stream bridge.
- `pkg-config` currently finds `sdl3` only. Homebrew formulas
  `sdl3_ttf`, `sdl3_image`, and `sdl3_mixer` are optional add-ons and may not
  be linked into the default `pkg-config` search path.
- SDL3_ttf, SDL3_image, and SDL3_mixer are loaded dynamically at runtime when
  present. Missing add-ons do not break startup: text falls back to SDL debug
  text, image loading falls back to `stb_image`, and audio keeps the SDL core
  WAV path.
- Native Dear ImGui is opt-in through `-d:nimaUseNativeImgui`. It vendors
  CImGui/Dear ImGui source and compiles C++ into the game executable; it does
  not add a separate Dear ImGui runtime library.

## Package Baseline

Target package metadata:

```nim
# nima.nimble
version       = "0.1.0"
author        = "TBD"
description   = "A Nim-native 2D game engine inspired by Roast2D"
license       = "MIT"
srcDir        = "src"

requires "nim >= 2.0.4"
requires "sdl3 >= 1.1.0"
requires "stb_image >= 2.5"
```

Rationale:

- Fau imports SDL as `import pkg/sdl3` in `src/fau/backend/sdlcore.nim`.
- Nimble registry package `sdl3` points to `https://github.com/transmutrix/nim-sdl3`.
- `sdl3` package version `1.1.0` requires Nim `>= 2.0.4`.
- The package exposes SDL_GPU APIs including `SDL_CreateGPUDevice`,
  `SDL_ClaimWindowForGPUDevice`, `SDL_AcquireGPUCommandBuffer`, and
  `SDL_CreateGPUShader`.
- Nima should not vendor `libsdl-org/SDL` as a submodule.
- `stb_image` handles PNG/JPEG/BMP/TGA-class texture loading in Nim.
  SDL3_image is optional and used only as a fallback for formats outside
  `stb_image` support, such as WebP/AVIF/TIFF when the system library supports
  them.

Optional native runtime libraries:

```text
SDL3_ttf     -> real UTF-8/CJK text rendering through Text.withFont(...)
SDL3_image   -> fallback image decode for formats not covered by stb_image
SDL3_mixer   -> OGG/MP3/FLAC/etc. playback through optional dynamic binding
Box2D        -> physics, package/binding still undecided
```

Native Dear ImGui build requirements:

```text
pkg-config sdl3      -> SDL3 C flags/libs for Dear ImGui SDL backends
C++ compiler/linker  -> compiles vendored Dear ImGui/CImGui sources
```

Example:

```sh
nim c -d:nimaUseSdl -d:nimaUseNativeImgui examples/native_imgui_demo.nim
nim c -d:nimaUseSdlGpu -d:nimaUseNativeImgui examples/native_imgui_demo.nim
```

## SDL C Runtime

The Nim `sdl3` package is a binding. It does not remove the need for SDL3 C
libraries at compile/runtime.

Expected local setup:

- macOS: install or build SDL3 C library locally.
- Linux: install SDL3 development package if available, otherwise build SDL3
  from source outside this repo.
- Windows: use prebuilt SDL3 development package and ship `SDL3.dll` with the
  executable.

Nima should fail fast with a clear error if SDL3 headers or dynamic library are
not available.

## Import Pattern

Backend modules import the package directly:

```nim
import pkg/sdl3
```

Nima public modules must not re-export raw SDL types from `nima/prelude`.
Backend-only escape hatches can be added later if needed:

```nim
proc getSdlWindow*(): sdl3.Window
```

This mirrors Fau's `getSdlWindow*()` but should stay outside the normal game
API.

## User Project Config

The recommended user project structure:

```text
mygame/
  mygame.nimble
  config.nims
  src/mygame.nim
  assets/
```

Minimal `mygame.nimble`:

```nim
version = "0.1.0"
srcDir = "src"

requires "nim >= 2.0.4"
requires "nima >= 0.1.0"
```

Minimal `config.nims`, modeled after Fau's platform linker choices:

```nim
--gc:arc

when defined(Windows):
  switch("passL", "-static-libstdc++ -static-libgcc")

when defined(MacOSX):
  switch("clang.linkerexe", "g++")
else:
  switch("gcc.linkerexe", "g++")
```

When `-d:nimaUseNativeImgui` is used, keep the C++ linker setting. The bridge
compiles C++ sources from `src/nima/native_imgui/private/cimgui`.

If SDL3 is installed in a custom location, user config can add include and link
paths:

```nim
import std/os

if existsEnv("SDL3_PREFIX"):
  let prefix = getEnv("SDL3_PREFIX")
  switch("passC", "-I" & prefix / "include")
  switch("passL", "-L" & prefix / "lib")
```

## Windows Packaging

Follow Fau's Windows cross-compile shape:

```nim
const builds = [
  (name: "win64", os: "windows", cpu: "amd64",
   args: "--gcc.exe:x86_64-w64-mingw32-gcc --gcc.linkerexe:x86_64-w64-mingw32-g++"),
]
```

Build command pattern:

```sh
nim --cpu:amd64 --os:windows --app:gui \
  --gcc.exe:x86_64-w64-mingw32-gcc \
  --gcc.linkerexe:x86_64-w64-mingw32-g++ \
  -d:danger -o:build/mygame-win64.exe c src/mygame.nim
```

Release bundle must include:

```text
mygame-win64.exe
SDL3.dll
SDL3_ttf.dll        # optional, required only for Text.withFont real glyphs
SDL3_image.dll      # optional, required only for image fallback formats
SDL3_mixer.dll      # optional, required only for non-WAV audio
assets/
```

Use the SDL3 DLL matching the compiler/runtime architecture. Do not assume the
Nim `sdl3` package ships native DLLs.

## Dynamic Linking

Default: dynamic link to SDL3.

Reasons:

- Matches `sdl3` package expectations.
- Keeps this repo small and avoids native binary vendoring.
- Works with Windows prebuilt DLLs and normal OS package managers.
- Static SDL3 can be revisited after the first release works on all target
  desktop platforms.

Distribution path:

- macOS: app bundle includes `libSDL3.dylib` or `SDL3.framework`.
- macOS with real fonts: also include `libSDL3_ttf.0.dylib` or an
  `SDL3_ttf.framework` equivalent if the app depends on `Text.withFont(...)`.
- macOS with image/audio add-ons: include `libSDL3_image.0.dylib` for fallback
  image formats and `libSDL3_mixer.0.dylib` for OGG/MP3/FLAC-style playback.
- Windows: ship `SDL3.dll` beside executable; ship `SDL3_ttf.dll` when using
  real font rendering, `SDL3_image.dll` when using image fallback formats, and
  `SDL3_mixer.dll` when using non-WAV audio.
- Linux: use system SDL3 for development; release via AppImage/Flatpak or
  bundled `.so` files if needed. Include `libSDL3_ttf.so.0` only when font
  rendering is required. Include `libSDL3_image.so.0` and `libSDL3_mixer.so.0`
  only when those optional runtime paths are required.

## Compile Commands

Development:

```sh
nimble install -y
nim c -d:nimaUseSdl -r examples/breakout.nim
```

Release:

```sh
nim c -d:release --opt:speed src/mygame.nim
```

With explicit SDL prefix:

```sh
SDL3_PREFIX=/opt/sdl3 nim c -r examples/breakout.nim
```

Headless SDL smoke:

```sh
SDL_VIDEODRIVER=dummy nim c -d:nimaUseSdl -r tests/sdl_smoke.nim
SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy nim c -d:nimaUseSdl -r tests/sdl_audio_smoke.nim
```

SDL_GPU smoke:

```sh
nim c -d:nimaUseSdlGpu -r tests/sdl_gpu_smoke.nim
nim c -d:nimaUseSdlGpu -r tests/sdl_gpu_sprite_smoke.nim
nim c -d:nimaUseSdlGpu -r tests/sdl_gpu_text_smoke.nim
```

Regenerate shaders:

```sh
nimble shaders
```

The `shaders` task uses `tools/compile_shaders.nim`, which shells out to the
official `shadercross` CLI from SDL_shadercross. It skips cleanly when
`shadercross` is missing, because normal package consumers should receive
compiled shader blobs instead of needing the shader compiler.

## Nima Package Tasks

Recommended Nimble tasks:

```nim
const exampleNames = [
  "window_smoke", "shapes", "scene_stack", "imgui_overlay",
  "diagnostics_overlay", "particles_basic", "light2d_basic", "audio_basic",
  "physics_basic", "prefab_basic", "atlas_basic", "text_test", "ui_layout",
  "breakout", "blink", "hex", "imgui_showcase", "imgui_cjk"
]

task examples, "Build and run examples":
  for name in exampleNames:
    exec "nim c --nimcache:nimcache/examples_" & name & " examples/" & name & ".nim"

task sdlExamples, "Build examples with SDL backend":
  for name in exampleNames:
    exec "nim c --nimcache:nimcache/sdl_" & name & " -d:nimaUseSdl examples/" & name & ".nim"

task sdlGpuSmoke, "Build SDL_GPU smoke test":
  exec "nim c --nimcache:nimcache/sdl_gpu_smoke -d:nimaUseSdlGpu tests/sdl_gpu_smoke.nim"
  exec "nim c --nimcache:nimcache/sdl_gpu_sprite_smoke -d:nimaUseSdlGpu tests/sdl_gpu_sprite_smoke.nim"
  exec "nim c --nimcache:nimcache/sdl_gpu_text_smoke -d:nimaUseSdlGpu tests/sdl_gpu_text_smoke.nim"

task sdlGpuExamples, "Build examples with SDL_GPU backend":
  for name in exampleNames:
    exec "nim c --nimcache:nimcache/sdl_gpu_" & name & " -d:nimaUseSdlGpu examples/" & name & ".nim"

task hotreloadLib, "Build dynamic hot reload example library":
  when defined(macosx):
    exec "nim c --nimcache:nimcache/hotreload_lib --app:lib --out:examples/libhotreload_game.dylib examples/hotreload_game.nim"
  elif defined(windows):
    exec "nim c --nimcache:nimcache/hotreload_lib --app:lib --out:examples/hotreload_game.dll examples/hotreload_game.nim"
  else:
    exec "nim c --nimcache:nimcache/hotreload_lib --app:lib --out:examples/libhotreload_game.so examples/hotreload_game.nim"

task hotreloadSmoke, "Build hot reload library and run headless smoke":
  when defined(macosx):
    exec "nim c --nimcache:nimcache/hotreload_lib --app:lib --out:examples/libhotreload_game.dylib examples/hotreload_game.nim"
  elif defined(windows):
    exec "nim c --nimcache:nimcache/hotreload_lib --app:lib --out:examples/hotreload_game.dll examples/hotreload_game.nim"
  else:
    exec "nim c --nimcache:nimcache/hotreload_lib --app:lib --out:examples/libhotreload_game.so examples/hotreload_game.nim"
  exec "nim c --nimcache:nimcache/hotreload_smoke -r tests/hotreload_smoke.nim"

task test, "Run unit tests":
  exec "nim c -r tests/all.nim"

task shaders, "Compile built-in shaders":
  exec "nim c --nimcache:nimcache/shaders -r tools/compile_shaders.nim"
```

CI is intentionally out of scope for the current documentation pass.

## References

- Fau SDL backend: `/Users/jjy/Workspace/fau/src/fau/backend/sdlcore.nim`
- Fau project generator Windows build args: `/Users/jjy/Workspace/fau/src/fau/tools/fauproject.nim`
- Nim `sdl3` package: https://github.com/transmutrix/nim-sdl3
- SDL3 build and migration notes: https://wiki.libsdl.org/SDL3/README-migration
