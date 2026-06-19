# Cross-Platform Support

Nima targets one public game API across web, macOS, Linux, and Windows. Game
code should import `nima/prelude` and avoid platform-specific SDL, browser, or
OS handles unless it is intentionally writing backend integration code.

## Backend Strategy

```text
Target       Platform layer        Renderer            Status
macOS        SDL3                  SDL_Renderer        Implemented, locally verified by compile smoke
macOS        SDL3                  SDL_GPU / Metal     Implemented, locally verified by smoke compile
Linux        SDL3                  SDL_Renderer        Implemented, Docker artifact build and dummy runtime smoke verified
Linux        SDL3                  SDL_GPU / Vulkan    Scaffold present, runtime/shader parity pending
Windows      SDL3                  SDL_Renderer        Implemented, MinGW cross compile verified
Windows      SDL3                  SDL_GPU / D3D12     Scaffold present, DXIL/runtime validation pending
Web          Emscripten + SDL3     SDL_Renderer/WebGL  Implemented, examples build and browser-smoke verified
Headless     None                  Draw recorder       Implemented, locally verified
```

SDL_Renderer is the portable bootstrap backend. SDL_GPU is the production
desktop direction for Metal, Vulkan, and Direct3D 12. Web currently uses
SDL_Renderer through Emscripten because SDL_GPU shader/package support needs a
separate web pass.

## Public API Rules

- `nima/prelude` does not expose raw SDL, OS, browser, or GPU handles.
- Game callbacks read normalized input through Nima input APIs.
- Draw APIs record backend-independent commands.
- Asset APIs use logical paths and configured asset roots.
- Platform-specific build options live in `config.nims`, `nima.nimble`, and
  `tools/platform_examples.nim`, not in user scenes.

## Build Defines

```text
Define                 Meaning
nimaUseSdl             Use SDL3 + SDL_Renderer backend
nimaUseSdlGpu          Use SDL3 + SDL_GPU backend
nimaUseNativeImgui     Compile vendored CImGui/Dear ImGui bridge
emscripten             Use Emscripten web target; config.nims also enables nimaUseSdl
nimaWindowsConsole     Keep Windows console subsystem instead of -mwindows
```

Invalid web combinations fail at compile time:

- `-d:emscripten -d:nimaUseSdlGpu`
- `-d:emscripten -d:nimaUseNativeImgui`

## Example Commands

Headless compile/run:

```sh
nim c -r examples/breakout.nim
nimble examples
```

Desktop SDL_Renderer:

```sh
nim c -d:nimaUseSdl -r examples/breakout.nim
nimble sdlExamples
```

Desktop SDL_GPU:

```sh
nim c -d:nimaUseSdlGpu -r examples/breakout.nim
nimble sdlGpuExamples
```

Web with Emscripten:

```sh
nimble sdl3Emscripten
export SDL3_EMSCRIPTEN_PREFIX=<sdl3-emscripten-prefix>
NIMA_EXAMPLE=breakout nimble webExample
nimble webExamples
python3 -m http.server 8000 -d build/web/breakout
```

Output:

```text
build/web/<example>/index.html
build/web/<example>/index.js
build/web/<example>/index.wasm
build/web/<example>/index.data
```

Windows cross compile with MinGW:

```sh
NIMA_EXAMPLE=breakout nimble windowsExample
nimble windowsExamples
```

Output:

```text
build/windows/<example>/<example>.exe
build/windows/<example>/assets/
```

Set `SDL3_WINDOWS_DLL_DIR=<dir>` before the Windows package task to copy
`SDL3.dll` and optional SDL add-on DLLs beside the executable. Without that,
the generated `.exe` still needs `SDL3.dll` on the target machine's `PATH` or
next to the executable.

Linux native build:

```sh
nimble linuxExamples
```

Linux build from a non-Linux host through Docker:

```sh
NIMA_TARGET=linux NIMA_EXAMPLE=breakout NIMA_PLATFORM_ARGS=--package nimble platformExamples
nimble linuxExamples
NIMA_TARGET=linux NIMA_PLATFORM_ARGS=--check-tools nimble platformExamples
```

The Docker path uses `tools/linux.Dockerfile`. The image copies the source tree
using `.dockerignore`, builds inside Linux, writes artifacts to a temporary
`/out` mount, then copies `build/linux/<example>/` back to the host. This avoids
macOS protected-folder bind mount read failures. It builds packages but does not
run GUI windows inside the container. To run examples, use a Linux desktop with
SDL3 installed or ship `libSDL3.so` beside the binary. Set
`SDL3_LINUX_LIB_DIR=<dir>` when packaging if local Linux SDL3 `.so` files should
be copied into `build/linux/<example>/`.

## Platform Packaging

macOS:

- Install SDL3 locally for development.
- Release bundles should include `libSDL3.dylib` or `SDL3.framework`.
- If using real font/image/audio add-ons, bundle SDL3_ttf, SDL3_image, and
  SDL3_mixer too.
- Assets belong in `Contents/Resources/assets` for `.app` bundles.

Linux:

- Use distro SDL3 packages for development when available.
- For releases, prefer AppImage/Flatpak or bundle `.so` files next to the app.
- Validate Vulkan drivers separately when using `nimaUseSdlGpu`.

Windows:

- Cross compile with `x86_64-w64-mingw32-gcc/g++` or build on Windows.
- Nima uses `--app:console` plus linker `-mwindows` for cross builds, because
  `--app:gui` on macOS creates a macOS `.app` wrapper.
- `config.nims` passes `-static`, `-static-libstdc++`, and `-static-libgcc` so
  MinGW support libraries such as `libwinpthread-1.dll` are not required.
- Ship `SDL3.dll` beside the executable.
- Ship optional `SDL3_ttf.dll`, `SDL3_image.dll`, and `SDL3_mixer.dll` only
  when examples/games need those runtime paths.

Web:

- Install Emscripten and ensure `emcc` is on `PATH`.
- Build SDL3 for Emscripten separately and set
  `SDL3_EMSCRIPTEN_PREFIX=<prefix>` where `<prefix>/lib/libSDL3.a` exists.
- `nimble sdl3Emscripten` can build SDL3 from `libsdl-org/SDL` into
  `build/sdl3-emscripten-prefix`.
- `config.nims` maps `-d:emscripten` to `emcc`, enables `nimaUseSdl`, disables
  Nim threads for normal static hosting, attaches `tools/web_shell.html`, links
  the SDL3 static library, and preloads `assets@/assets`.
- `tools/platform_examples.nim` creates a repo-local Emscripten LLVM shim when
  Homebrew provides `clang` and `wasm-ld` in different directories.
- `tools/web_shell.html` owns canvas sizing and browser audio unlock.
- Browser audio still requires user gesture before playback.

## Asset Loading

Default lookup order:

1. Explicit `assetRoots` from `app(...)`.
2. `assets/` relative to the current working directory.
3. Platform package resource locations, when packaging helpers are added.

For web, examples preload `assets/` into Emscripten's virtual filesystem at
`/assets`. Existing Nima asset paths continue to work because the default root
is `assets`.

## Current Verification

Verified locally on macOS:

- `nim c --nimcache:nimcache/platform_tests_final -r tests/all.nim`
- `nim c --nimcache:nimcache/platform_check_sdl_final -d:nimaUseSdl examples/window_smoke.nim`
- `nim c --nimcache:nimcache/platform_check_gpu_final -d:nimaUseSdlGpu tests/sdl_gpu_smoke.nim`
- `HOME=/private/tmp/nimble-home nimble webExamples`
- `HOME=/private/tmp/nimble-home nimble windowsExamples`
- `HOME=/private/tmp/nimble-home nimble linuxExamples`
- Linux Docker runtime smoke:
  `docker run --rm -e SDL_VIDEODRIVER=dummy -e SDL_AUDIODRIVER=dummy -w /workspace nima-linux-builder sh -c 'nim c --nimcache:nimcache/linux_sdl_smoke -d:nimaUseSdl -r tests/sdl_smoke.nim'`
- Web browser smoke for `build/web/breakout` using Playwright against a local
  static server. The page title was `Breakout`, console contained only the SDL
  startup log, and the screenshot showed live Breakout rendering.

Artifacts verified:

- 18 web-supported examples produce `index.html`, `index.js`, `index.wasm`,
  and `index.data`. `hotreload` is excluded from web by design.
- 19 Windows examples cross compile to PE32+ GUI `.exe` files under
  `build/windows/<example>/`.
- 19 Linux examples build through Docker to ELF 64-bit Linux aarch64 binaries
  under `build/linux/<example>/` on the current Apple Silicon macOS host. Each
  package includes an `assets/` directory.

Not yet verified in this workspace:

- Linux runtime on a real Linux desktop with SDL3 installed.
- SDL_GPU Vulkan/D3D12 shader parity beyond the existing backend scaffold.
- Windows runtime execution on an actual Windows machine with `SDL3.dll`.

## Implementation Notes

- `src/nima/backend/sdlrenderer.nim` has a browser-safe frame pump using
  `emscripten_set_main_loop` when `-d:emscripten` is active.
- `src/nima/backend/sdlgpu.nim` remains desktop-only for now.
- `nima.nimble` provides host, web, Windows, and Linux example tasks.
- `tools/platform_examples.nim` centralizes target-specific example builds and
  package directory creation.
- `tools/build_sdl3_emscripten.sh` builds the SDL3 web static library used by
  `nimble webExample` and `nimble webExamples`.
- `tools/linux.Dockerfile` defines the optional non-Linux host builder for
  Linux example artifacts.
- `config.nims` centralizes compiler/linker flags for macOS, Windows, and web.

## References

- SDL3 Emscripten notes: https://wiki.libsdl.org/SDL3/README-emscripten
- SDL3 GPU requirements: https://wiki.libsdl.org/SDL3/CategoryGPU
- Fau web/build pattern: `src/fau/tools/fauproject.nim` in the Fau repository
