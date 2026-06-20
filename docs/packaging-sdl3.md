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
- `config.nims` enables SDL_GPU by default for desktop builds unless
  `nimaHeadless` or another backend define is passed.
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
- Native Dear ImGui is opt-in through `-d:nimaUseNativeImgui`. It uses the
  CImGui git submodule at `src/nima/native_imgui/private/cimgui` and compiles
  C++ into the game executable; it does not add a separate Dear ImGui runtime
  library.
- Web examples build with Emscripten and a separately built SDL3 static
  library. The local `nimble webExamples` check emits 18 web bundles; `hotreload`
  is excluded from web by design.
- Windows examples cross compile with MinGW. The local `nimble windowsExamples`
  check emits 19 PE32+ GUI executables under `build/windows/<example>/`.
- Linux example builds are implemented for Linux hosts and through
  `tools/linux.Dockerfile` from non-Linux hosts. The local
  `nimble linuxExamples` check emits 19 ELF 64-bit Linux aarch64 binaries under
  `build/linux/<example>/` on the current Apple Silicon macOS host.
- A Linux Docker dummy-video runtime smoke now runs `tests/sdl_smoke.nim` with
  `SDL_VIDEODRIVER=dummy` and `SDL_AUDIODRIVER=dummy`, confirming the container
  can load SDL3 through the `libSDL3.so` name expected by the Nim binding.

## Package Baseline

Target package metadata:

```nim
# nima.nimble
version       = "0.1.0"
author        = "TBD"
description   = "A Nim-native 2D game engine inspired by raylib and fau"
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
C++ compiler/linker  -> compiles CImGui/Dear ImGui submodule sources
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
  switch("passL", "-static")
  switch("passL", "-static-libstdc++ -static-libgcc")
  when not defined(nimaWindowsConsole):
    switch("passL", "-mwindows")

when defined(MacOSX):
  switch("clang.linkerexe", "g++")
else:
  switch("gcc.linkerexe", "g++")
```

When `-d:nimaUseNativeImgui` is used, keep the C++ linker setting. The bridge
compiles C++ sources from the CImGui submodule at
`src/nima/native_imgui/private/cimgui`, including its nested Dear ImGui
submodule. Initialize it before native ImGui builds:

```sh
nimble submodules
# or:
git submodule update --init --recursive
```

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
nim --cpu:amd64 --os:windows --app:console \
  --gcc.exe:x86_64-w64-mingw32-gcc \
  --gcc.linkerexe:x86_64-w64-mingw32-g++ \
  -d:nimaUseSdl -o:build/windows/mygame/mygame.exe c src/mygame.nim
```

`config.nims` adds `-mwindows` unless `-d:nimaWindowsConsole` is set. This
keeps Windows examples as GUI-subsystem executables while avoiding macOS `.app`
bundles during cross compilation. It also passes `-static` and the usual MinGW
static runtime flags so `libwinpthread-1.dll` is not required.

Release bundle must include:

```text
mygame.exe
SDL3.dll
SDL3_ttf.dll        # optional, required only for Text.withFont real glyphs
SDL3_image.dll      # optional, required only for image fallback formats
SDL3_mixer.dll      # optional, required only for non-WAV audio
assets/
```

Use the SDL3 DLL matching the compiler/runtime architecture. Do not assume the
Nim `sdl3` package ships native DLLs.

Nima's helper copies runtime DLLs only when `SDL3_WINDOWS_DLL_DIR` is set:

```sh
SDL3_WINDOWS_DLL_DIR=<sdl3-windows-dll-dir> NIMA_EXAMPLE=breakout nimble windowsExample
```

## Web Packaging

Web builds use Emscripten and the SDL_Renderer backend. Build SDL3 for
Emscripten outside this repository, then set `SDL3_EMSCRIPTEN_PREFIX` to the
install prefix that contains `lib/libSDL3.a`. `config.nims` maps
`-d:emscripten` to `emcc`, enables `nimaUseSdl`, attaches
`tools/web_shell.html`, links that SDL3 static library, and preloads the
repository `assets/` directory into the browser virtual filesystem.
Nima disables Nim threads for web builds so normal static hosting works without
SharedArrayBuffer/cross-origin-isolation headers.

Build one example:

```sh
nimble sdl3Emscripten
export SDL3_EMSCRIPTEN_PREFIX=<sdl3-emscripten-prefix>
NIMA_EXAMPLE=breakout nimble webExample
```

Build all web-supported examples:

```sh
nimble sdl3Emscripten
export SDL3_EMSCRIPTEN_PREFIX=<sdl3-emscripten-prefix>
nimble webExamples
```

`nimble sdl3Emscripten` runs `tools/build_sdl3_emscripten.sh`. Override the
source, build, install prefix, repository, or ref with `SDL3_SRC`,
`SDL3_EMSCRIPTEN_BUILD_DIR`, `SDL3_EMSCRIPTEN_PREFIX`, `SDL3_REPO`, and
`SDL3_REF`.

On Homebrew Emscripten installs, `clang` and `wasm-ld` may live in different
formula directories. `tools/platform_examples.nim` and
`tools/build_sdl3_emscripten.sh` create a repo-local LLVM shim under
`build/emscripten/llvm-root` when needed.

Output layout:

```text
build/web/<example>/index.html
build/web/<example>/index.js
build/web/<example>/index.wasm
build/web/<example>/index.data
```

Serve with a static file server:

```sh
python3 -m http.server 8000 -d build/web/breakout
```

Current web exclusions:

- `hotreload`: browser builds do not support the desktop dynamic-library reload
  flow.
- `nimaUseSdlGpu`: SDL_GPU web support needs a separate shader/backend pass.
- `nimaUseNativeImgui`: the native Dear ImGui bridge is desktop-only for now.

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
  bundled `.so` files if needed. The Nim `sdl3` binding loads `libSDL3.so`, so
  Linux targets need either an SDL3 development package installed, an
  AppImage/Flatpak runtime that exposes that loader name, or a bundled
  `libSDL3.so` symlink next to the binary. Include `libSDL3_ttf.so.0` only when
  font rendering is required. Include `libSDL3_image.so.0` and
  `libSDL3_mixer.so.0` only when those optional runtime paths are required.
- Web: serve the generated `.html`, `.js`, `.wasm`, and `.data` files together
  from the same directory.

## Linux Docker Builder

`tools/linux.Dockerfile` provides the non-Linux host builder used by
`nimble linuxExamples`.

Important details:

- The image is based on `nimlang/nim:2.2.10`.
- `/opt/nim/bin` is added to `PATH`.
- Debian `libsdl3-dev` is installed so the image has both the SDL3 runtime and
  the `libSDL3.so` loader name expected by the Nim `sdl3` binding.
- `nimble install -dy` runs in the image layer from `nima.nimble`, so the
  `sdl3` and `stb_image` Nim packages are available before example builds.
- The source tree is copied into the image with `.dockerignore` excluding
  `build/`, `nimcache/`, `.git/`, and local binaries.
- The container writes build output to `/out`; the host tool mounts `/out` from
  a temporary directory and copies the resulting `linux/<example>/` packages
  back to the configured output root.
- Docker builds produce binaries for the Docker platform architecture. On the
  current Apple Silicon macOS host, default Docker output is Linux aarch64.

Build one packaged Linux example from macOS:

```sh
NIMA_TARGET=linux NIMA_EXAMPLE=breakout NIMA_PLATFORM_ARGS=--package nimble platformExamples
```

Build all packaged Linux examples:

```sh
nimble linuxExamples
```

## Compile Commands

Development:

```sh
nimble install -y
nim c -r examples/breakout.nim
nim c -d:nimaUseSdl -r examples/breakout.nim
nim c -d:nimaHeadless -r examples/breakout.nim
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

`nima.nimble` now delegates target-specific example builds to
`tools/platform_examples.nim`.

```sh
nimble examples
nimble headlessExamples
nimble sdlExamples
nimble sdlGpuExamples
NIMA_EXAMPLE=breakout nimble webExample
nimble webExamples
NIMA_EXAMPLE=breakout nimble windowsExample
nimble windowsExamples
nimble linuxExamples
NIMA_TARGET=linux NIMA_PLATFORM_ARGS=--check-tools nimble platformExamples
```

`platformExamples` accepts:

```text
NIMA_TARGET=headless|sdl|sdlgpu|web|windows|linux
NIMA_EXAMPLE=<name|comma-separated-list|all>
NIMA_PLATFORM_ARGS="--run --package --out:<dir> --check-tools"
```

CI is intentionally out of scope for the current documentation pass.

## References

- Fau SDL backend: `<fau-repo>/src/fau/backend/sdlcore.nim`
- Fau project generator Windows/web build args:
  `<fau-repo>/src/fau/tools/fauproject.nim`
- Nim `sdl3` package: https://github.com/transmutrix/nim-sdl3
- SDL3 build and migration notes: https://wiki.libsdl.org/SDL3/README-migration
