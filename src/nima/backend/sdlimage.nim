import std/dynlib
import pkg/sdl3

type
  ImgLoadProc = proc(file: cstring): ptr SDL_Surface {.cdecl.}

  SdlImageState* = object
    triedLoad: bool
    initialized: bool
    lib: LibHandle
    imgLoad: ImgLoadProc

proc initSdlImageState*(): SdlImageState = SdlImageState()

proc loadSymbol[T](lib: LibHandle, name: string): T =
  cast[T](symAddr(lib, name))

proc tryLoadLib(name: string): LibHandle =
  try:
    result = loadLib(name)
  except OSError:
    result = nil

proc ensureLoaded(state: var SdlImageState): bool =
  if state.initialized:
    return true
  if state.triedLoad:
    return false
  state.triedLoad = true

  const names = [
    "libSDL3_image.0.dylib",
    "libSDL3_image.dylib",
    "/opt/homebrew/opt/sdl3_image/lib/libSDL3_image.0.dylib",
    "/opt/homebrew/opt/sdl3_image/lib/libSDL3_image.dylib",
    "/usr/local/opt/sdl3_image/lib/libSDL3_image.0.dylib",
    "/usr/local/opt/sdl3_image/lib/libSDL3_image.dylib",
    "SDL3_image.dll",
    "libSDL3_image.so.0",
    "libSDL3_image.so"
  ]
  for name in names:
    state.lib = tryLoadLib(name)
    if not state.lib.isNil:
      break
  if state.lib.isNil:
    return false

  state.imgLoad = loadSymbol[ImgLoadProc](state.lib, "IMG_Load")
  if state.imgLoad.isNil:
    unloadLib(state.lib)
    state.lib = nil
    return false

  state.initialized = true
  echo "[Nima] SDL3_image available"
  true

proc available*(state: var SdlImageState): bool =
  state.ensureLoaded()

proc shutdown*(state: var SdlImageState) =
  state.initialized = false
  if not state.lib.isNil:
    unloadLib(state.lib)
    state.lib = nil

proc loadImageSurfaceRgba*(state: var SdlImageState,
                           path: string): ptr SDL_Surface =
  if path.len == 0 or not state.ensureLoaded():
    return nil
  let source = state.imgLoad(path.cstring)
  if source.isNil:
    return nil
  defer: SDL_DestroySurface(source)
  result = SDL_ConvertSurface(source, SDL_PIXELFORMAT_RGBA32)
