# Cross-Platform Strategy

Nima targets desktop cross-platform support first: macOS, Linux, and Windows.
The public API should stay portable even while backend details differ.

## Supported Targets

V1 required:

- macOS 13 or newer on Apple Silicon and Intel where SDL3 GPU backend supports
  Metal.
- Linux x86_64 with SDL3 and Vulkan-capable drivers.
- Windows 10 or newer with SDL3 and Direct3D 12 support.

V1 not required:

- Web/WASM.
- iOS, Android, consoles.
- Terminal rendering.

The API should avoid choices that block these future targets, but implementation
does not need to support them yet.

## Platform Backend Matrix

```text
Platform  Window/Event  GPU backend       Library install
macOS     SDL3          Metal             local SDL3 dylib/framework
Linux     SDL3          Vulkan            system SDL3 package or local build
Windows   SDL3          Direct3D 12       prebuilt SDL3 DLL package
```

SDL_GPU can also expose different drivers depending on hardware and SDL build
options. Nima should log the selected driver during startup.

Current local validation:

- SDL_Renderer smoke runs headless with dummy video.
- SDL_GPU smoke runs on macOS Cocoa + Metal through `-d:nimaUseSdlGpu`.
- Native Dear ImGui compile smoke passes on macOS for SDL_Renderer and SDL_GPU
  builds through `-d:nimaUseNativeImgui`.
- Linux Vulkan and Windows Direct3D 12 runtime validation are still pending.

## Public API Portability Rules

- No OS-specific handles in `nima/prelude`.
- No backend shader format names in common draw APIs.
- No path separator assumptions. Use Nim path utilities internally.
- No user-side coordinate flipping.
- No direct SDL event types in game callbacks.
- No reliance on global current working directory beyond documented asset root
  resolution.

## Filesystem and Assets

Default development layout:

```text
project/
  assets/
  src/
  config.nims
```

Asset root resolution:

1. App-specified asset root.
2. `assets/` next to current working directory.
3. Platform bundle resource path, when packaged.

Current implementation supports configurable roots through `app(...,
assetRoots = [...])` and direct `setAssetRoots`/`addAssetRoot` APIs. Bundle
resource path probing is still a packaging milestone.

For distribution:

- macOS app bundle: place assets under `Contents/Resources/assets`.
- Windows portable folder: place assets next to executable or under `assets/`.
- Linux package: place assets in app data directory or next to executable for
  portable builds.

The asset manager should expose the resolved root in diagnostics.

## Window and DPI

SDL3 separates logical window size and pixel size. Nima should track both:

```nim
type WindowMetrics* = object
  logicalSize*: IVec2
  pixelSize*: IVec2
  dpiScale*: float32
```

Rules:

- `screenSize()` returns logical size by default.
- `viewSize()` returns virtual game size after scale mode.
- GPU swapchain uses pixel size.
- Mouse positions are converted into view coordinates before facade access.
- Resize events update scale mode and projection before the next draw.

## Input Differences

Keyboard layouts and text input differ by platform. For game actions:

- Use physical scancodes for `KeyCode` where possible.
- Keep text input separate from action input.
- Normalize mouse wheel direction to positive Y up in public API.
- Treat gamepad names and ids as unstable; actions bind to abstract gamepad
  buttons and axes.
- Current implementation supports `AnyGamepad` for portable single-player
  bindings and SDL instance ids for explicit device selection. Axis values are
  normalized before game code sees them.

## Build and Link Differences

macOS:

- Use the Nimble `sdl3` package for bindings and a local SDL3 C library.
- Distribution should set rpaths or bundle SDL dylibs/frameworks.
- Metal shader blobs must be available.
- Current local toolchain check: Nim 2.2.10, Nimble 0.22.2, CMake 4.3.3, Apple
  clang 17, GNU Make 3.81. Ninja is not installed.
- Current local SDL check: Homebrew SDL3 `3.4.10` is visible through
  `pkg-config --modversion sdl3`; SDL dummy smoke runs with the software
  renderer.
- Native Dear ImGui uses vendored C++ source and the local C++ toolchain. It
  needs `pkg-config sdl3` at compile time.

Linux:

- Use package-manager SDL3 if available; otherwise build SDL3 outside this repo.
- Vulkan runtime and drivers must be present.

Windows:

- Follow Fau's current Windows build direction: MinGW cross compiler
  `x86_64-w64-mingw32-gcc/g++` and linker flags
  `-static-libstdc++ -static-libgcc`.
- Ship prebuilt `SDL3.dll` beside executable.
- Direct3D 12 shader blobs must be available.

## Rendering Tests

Portable testing layers:

1. Pure unit tests for math, rects, transforms, colors, and input state.
2. Recorder tests that assert draw calls produce expected commands without SDL.
3. Backend init smoke tests per OS.
4. Optional offscreen render snapshot tests after SDL_GPU readback exists.

Future CI should not require a visible desktop session for unit and recorder
tests. CI files are out of scope for the current documentation pass.

## Future Web/WASM Notes

Do not expose web-only API in v1. If web support becomes a goal:

- Revisit SDL3 web support and Nim C-to-WASM toolchain state.
- Keep app construction separate from platform entrypoints.
- Avoid runtime dynamic linking assumptions.
- Rework asset loading for async/browser fetch.

## References

- SDL3 GPU backend/system requirements: https://wiki.libsdl.org/SDL3/CategoryGPU
- SDL3 migration and platform notes: https://wiki.libsdl.org/SDL3/README-migration
- Roast2D local cross-platform reference: `~/Workspace/roast2d/AGENTS.md`
