# Running Nima Games on Web

Nima web builds use Emscripten plus SDL3's browser support. Game code still
uses `nima/prelude`; the web target changes compiler/linker settings, backend
selection, asset packaging, and how the final files are served.

## Current Web Stack

```text
Nim source -> Nim C backend -> Emscripten emcc -> WebAssembly + JavaScript
Nima API   -> SDL_Renderer backend -> SDL3 Emscripten video/input/audio
assets/    -> Emscripten virtual filesystem at /assets
```

Supported now:

- SDL_Renderer backend through `-d:emscripten`.
- Keyboard, mouse, text input, draw commands, textures, debug UI, and examples
  that do not need desktop-only behavior.
- Static hosting with `.html`, `.js`, `.wasm`, and `.data` files.

Not supported now:

- `-d:nimaUseSdlGpu` on web.
- `-d:nimaUseNativeImgui` on web.
- `hotreload` example on web.
- Browser autoplay audio before a user gesture.

Invalid combinations fail at compile time:

```sh
nim c -d:emscripten -d:nimaUseSdlGpu examples/breakout.nim
nim c -d:emscripten -d:nimaUseNativeImgui examples/native_imgui_demo.nim
```

## Required Tools

Install these before building web targets:

```text
Nim + Nimble
Emscripten: emcc, emcmake
CMake
Git
Python 3 or another static file server
```

Check tool availability:

```sh
nim -v
nimble -v
emcc -v
emcmake --version
cmake --version
git --version
```

## Build SDL3 for Emscripten

Nima links SDL3 as a static Emscripten library. Build it once from the repo
root:

```sh
cd <repo-path>
nimble sdl3Emscripten
```

Default output:

```text
build/sdl3-emscripten-prefix/
  include/
  lib/libSDL3.a
```

The Nima helper uses this default prefix automatically. If SDL3 was built
somewhere else, set:

```sh
export SDL3_EMSCRIPTEN_PREFIX=<sdl3-emscripten-prefix>
```

`<sdl3-emscripten-prefix>/lib/libSDL3.a` must exist.

## Run a Repository Example

Build and run `breakout`:

```sh
cd <repo-path>
nimble sdl3Emscripten
NIMA_EXAMPLE=breakout nimble webExample
python3 -m http.server 8000 -d build/web/breakout
```

Open:

```text
http://localhost:8000
```

Expected output files:

```text
build/web/breakout/index.html
build/web/breakout/index.js
build/web/breakout/index.wasm
build/web/breakout/index.data
```

Build another example:

```sh
NIMA_EXAMPLE=ui_layout nimble webExample
python3 -m http.server 8000 -d build/web/ui_layout
```

Build all web-supported examples:

```sh
nimble webExamples
```

`hotreload` is excluded from `webExamples` by design.

## Minimal Web-Safe Game

This same source can run on desktop SDL and web.

```nim
import nima/prelude

type Game = ref object of Scene

type Action = enum
  quit

method init(scene: Game) =
  bindAction(quit, key(kcEscape))

method update(scene: Game) =
  if actionJustPressed(quit):
    exit()

method draw(scene: Game) =
  drawRect(rgb(0.04, 0.05, 0.07), viewSize(),
           transform(vec3(0, 0, -1)))
  drawCircle(vec3(0, 0, 0), 40, Yellow)
  drawText(text("Nima Web", 28, White), transform(vec3(-82, 72, 0)))

when isMainModule:
  run app(Game(), title = "Nima Web", size = ivec2(800, 600))
```

Repository example build:

```sh
nim c -d:emscripten -o:build/web/my_game/index.html examples/my_game.nim
python3 -m http.server 8000 -d build/web/my_game
```

For repository examples, `config.nims` already:

- sets `emcc` as compiler and linker;
- disables Nim threads for static hosting;
- defines `nimaUseSdl`;
- attaches `tools/web_shell.html`;
- links `libSDL3.a`;
- preloads `assets@/assets`.

## User Project Setup

Recommended user project shape:

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

Minimal web-aware `config.nims`:

```nim
import std/os

--gc:arc

when defined(emscripten):
  --os:linux
  --cpu:i386
  --cc:clang
  --threads:off
  --clang.exe:emcc
  --clang.linkerexe:emcc
  --clang.cpp.exe:emcc
  --clang.cpp.linkerexe:emcc
  switch("define", "nimaUseSdl")
  switch("passL", "-sALLOW_MEMORY_GROWTH=1")
  switch("passL", "--preload-file assets@/assets")

  if existsEnv("NIMA_WEB_SHELL"):
    switch("passL", "--shell-file " & getEnv("NIMA_WEB_SHELL"))

  if existsEnv("SDL3_EMSCRIPTEN_PREFIX"):
    let prefix = getEnv("SDL3_EMSCRIPTEN_PREFIX")
    switch("passC", "-I" & prefix / "include")
    switch("passL", prefix / "lib" / "libSDL3.a")
```

Build command:

```sh
cd <mygame>
export SDL3_EMSCRIPTEN_PREFIX=<sdl3-emscripten-prefix>
export NIMA_WEB_SHELL=<repo-path>/tools/web_shell.html
nimble install -dy
nim c -d:emscripten -o:build/web/index.html src/mygame.nim
python3 -m http.server 8000 -d build/web
```

Open:

```text
http://localhost:8000
```

## Asset Rules

Use logical asset paths in game code:

```nim
let atlas = loadTexture("sprites/player.png")
let font = loadFont("fonts/NotoSansSC-Regular.otf", 24)
```

Put files under:

```text
assets/
  sprites/player.png
  fonts/NotoSansSC-Regular.otf
```

For web, `--preload-file assets@/assets` copies that folder into the browser
virtual filesystem. Nima's default asset root includes `assets`, so existing
asset paths keep working.

## Serving Rules

Do not open `index.html` through `file://`. WebAssembly and the `.data` preload
file need HTTP.

Use any static server:

```sh
python3 -m http.server 8000 -d build/web/breakout
```

Production hosting must serve these files together from the same directory:

```text
index.html
index.js
index.wasm
index.data
```

Normal static hosts are enough because Nima web builds currently disable Nim
threads. No SharedArrayBuffer headers are required for the default web target.

## Troubleshooting

`Required command not found: emcc`

- Install Emscripten and make sure `emcc` is on `PATH`.

`SDL3 Emscripten library not found`

- Run `nimble sdl3Emscripten`, or set `SDL3_EMSCRIPTEN_PREFIX` to a prefix that
  contains `lib/libSDL3.a`.

Browser shows a blank page and console mentions missing `.wasm` or `.data`

- Serve the build directory over HTTP.
- Make sure `index.html`, `index.js`, `index.wasm`, and `index.data` are in the
  same directory.

Assets missing in browser

- Keep assets under `assets/`.
- Keep `--preload-file assets@/assets` in `config.nims`.
- Use asset paths relative to `assets/`, not absolute host paths.

Audio does not start immediately

- Browser autoplay policy blocks audio until a click or key press. This is
  expected.
