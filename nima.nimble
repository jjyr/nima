version       = "0.1.0"
author        = "TBD"
description   = "A Nim-native 2D game engine"
license       = "MIT"
srcDir        = "src"

requires "nim >= 2.0.4"
requires "sdl3 >= 1.1.0"
requires "stb_image >= 2.5"

task test, "Run unit tests":
  exec "nim c -r tests/all.nim"

const exampleNames = [
  "window_smoke",
  "shapes",
  "scene_stack",
  "imgui_overlay",
  "diagnostics_overlay",
  "particles_basic",
  "light2d_basic",
  "audio_basic",
  "physics_basic",
  "prefab_basic",
  "atlas_basic",
  "text_test",
  "ui_layout",
  "breakout",
  "blink",
  "hex",
  "hotreload",
  "imgui_showcase",
  "imgui_cjk"
]

task examples, "Build representative examples":
  for name in exampleNames:
    exec "nim c --nimcache:nimcache/examples_" & name & " examples/" & name & ".nim"

task sdlExamples, "Build representative examples with SDL backend":
  for name in exampleNames:
    exec "nim c --nimcache:nimcache/sdl_" & name & " -d:nimaUseSdl examples/" & name & ".nim"

task sdlGpuSmoke, "Build SDL_GPU smoke test":
  exec "nim c --nimcache:nimcache/sdl_gpu_smoke -d:nimaUseSdlGpu tests/sdl_gpu_smoke.nim"
  exec "nim c --nimcache:nimcache/sdl_gpu_sprite_smoke -d:nimaUseSdlGpu tests/sdl_gpu_sprite_smoke.nim"
  exec "nim c --nimcache:nimcache/sdl_gpu_text_smoke -d:nimaUseSdlGpu tests/sdl_gpu_text_smoke.nim"

task sdlGpuExamples, "Build representative examples with SDL_GPU backend":
  for name in exampleNames:
    exec "nim c --nimcache:nimcache/sdl_gpu_" & name & " -d:nimaUseSdlGpu examples/" & name & ".nim"

task nativeImguiSmoke, "Build native Dear ImGui bridge smoke test":
  exec "nim c --nimcache:nimcache/native_imgui -d:nimaUseNativeImgui tests/native_imgui_compile.nim"
  exec "nim c --nimcache:nimcache/native_imgui_sdl -d:nimaUseSdl -d:nimaUseNativeImgui examples/native_imgui_demo.nim"
  exec "nim c --nimcache:nimcache/native_imgui_gpu -d:nimaUseSdlGpu -d:nimaUseNativeImgui examples/native_imgui_demo.nim"

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

task shaders, "Compile built-in shaders":
  exec "nim c --nimcache:nimcache/shaders -r tools/compile_shaders.nim"
