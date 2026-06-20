import std/os

--gc:arc
--hints:off
--path:"src"
--nimcache:"nimcache"

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
  switch("passL", "--shell-file tools/web_shell.html")
  switch("passL", "-sALLOW_MEMORY_GROWTH=1")
  switch("passL", "--preload-file assets@/assets")
  if existsEnv("SDL3_EMSCRIPTEN_PREFIX"):
    let prefix = getEnv("SDL3_EMSCRIPTEN_PREFIX")
    switch("passC", "-I" & prefix / "include")
    switch("passL", prefix / "lib" / "libSDL3.a")

when not defined(emscripten) and not defined(nimaHeadless) and
    not defined(nimaUseSdl) and not defined(nimaUseSdlGpu):
  switch("define", "nimaUseSdlGpu")

when defined(Windows):
  switch("passL", "-static")
  switch("passL", "-static-libstdc++ -static-libgcc")
  when not defined(nimaWindowsConsole):
    switch("passL", "-mwindows")

when not defined(emscripten):
  when defined(MacOSX):
    switch("clang.linkerexe", "g++")
    switch("passL", "-L/opt/homebrew/lib -Wl,-rpath,/opt/homebrew/lib")
    switch("passL", "-L/usr/local/lib -Wl,-rpath,/usr/local/lib")
  else:
    switch("gcc.linkerexe", "g++")
