import std/[dynlib, os, times]
import ./[color, draw, facade, math, scene, transform]

const
  HotReloadApiVersion* = 1'u32
  HotReloadLoadSymbol* = "nimaHotReloadLoad"
  HotReloadUnloadSymbol* = "nimaHotReloadUnload"
  HotReloadUpdateSymbol* = "nimaHotReloadUpdate"
  HotReloadDrawSymbol* = "nimaHotReloadDraw"

type
  HotReloadDrawRectProc* = proc(r, g, b, a, x, y, z, w, h: cfloat) {.cdecl.}
  HotReloadDrawTextProc* = proc(text: cstring, size, r, g, b, a, x, y, z: cfloat) {.cdecl.}
  HotReloadTimeProc* = proc(): cfloat {.cdecl.}
  HotReloadFrameProc* = proc(): uint64 {.cdecl.}
  HotReloadLogProc* = proc(message: cstring) {.cdecl.}

  HotReloadApi* {.bycopy.} = object
    version*: uint32
    drawRect*: HotReloadDrawRectProc
    drawText*: HotReloadDrawTextProc
    time*: HotReloadTimeProc
    tick*: HotReloadTimeProc
    frame*: HotReloadFrameProc
    log*: HotReloadLogProc

  HotReloadLoadProc* = proc(api: ptr HotReloadApi) {.cdecl.}
  HotReloadUnloadProc* = proc() {.cdecl.}
  HotReloadUpdateProc* = proc() {.cdecl.}
  HotReloadDrawProc* = proc() {.cdecl.}

  HotReloadScene* = ref object of Scene
    sourcePath*: string
    loadedPath*: string
    lastError*: string
    reloads*: int
    library: LibHandle
    loadProc: HotReloadLoadProc
    unloadProc: HotReloadUnloadProc
    updateProc: HotReloadUpdateProc
    drawProc: HotReloadDrawProc
    lastMtime: Time
    api: HotReloadApi

proc hotReloadLibraryName*(base = "hotreload_game"): string =
  when defined(macosx):
    "lib" & base & ".dylib"
  elif defined(windows):
    base & ".dll"
  else:
    "lib" & base & ".so"

proc hostDrawRect(r, g, b, a, x, y, z, w, h: cfloat) {.cdecl.} =
  drawRect(rgba(r.float32, g.float32, b.float32, a.float32),
           vec2(w.float32, h.float32),
           transform(vec3(x.float32, y.float32, z.float32)))

proc hostDrawText(textValue: cstring, size, r, g, b, a, x, y, z: cfloat) {.cdecl.} =
  if textValue.isNil:
    return
  drawText(text($textValue, size.float32,
                rgba(r.float32, g.float32, b.float32, a.float32)),
           transform(vec3(x.float32, y.float32, z.float32)))

proc hostTime(): cfloat {.cdecl.} = time().cfloat
proc hostTick(): cfloat {.cdecl.} = tick().cfloat
proc hostFrame(): uint64 {.cdecl.} = frame()

proc hostLog(message: cstring) {.cdecl.} =
  if message.isNil:
    echo "[Nima hotreload]"
  else:
    echo "[Nima hotreload] ", $message

proc initHotReloadApi*(): HotReloadApi =
  HotReloadApi(version: HotReloadApiVersion,
               drawRect: hostDrawRect,
               drawText: hostDrawText,
               time: hostTime,
               tick: hostTick,
               frame: hostFrame,
               log: hostLog)

proc loadedLibraryCopy(path: string): string =
  let (dir, name, ext) = path.splitFile
  let stamp = $epochTime().int64 & "_" & $getCurrentProcessId()
  getTempDir() / "nima_hotreload_" & stamp & "_" & name & ext

proc unload(scene: HotReloadScene) =
  if scene.unloadProc != nil:
    scene.unloadProc()
  scene.loadProc = nil
  scene.unloadProc = nil
  scene.updateProc = nil
  scene.drawProc = nil
  if scene.library != nil:
    unloadLib(scene.library)
    scene.library = nil
  if scene.loadedPath.len > 0 and fileExists(scene.loadedPath):
    try:
      removeFile(scene.loadedPath)
    except OSError:
      discard
  scene.loadedPath = ""

proc resolveSymbol[T](library: LibHandle, name: string): T =
  let raw = library.symAddr(name)
  if raw.isNil:
    raise newException(ValueError, "missing symbol " & name)
  cast[T](raw)

proc tryLoad(scene: HotReloadScene) =
  scene.lastError = ""
  if not fileExists(scene.sourcePath):
    scene.lastError = "library not found: " & scene.sourcePath
    return

  let nextPath = loadedLibraryCopy(scene.sourcePath)
  copyFile(scene.sourcePath, nextPath)
  let library = loadLib(nextPath)
  if library == nil:
    scene.lastError = "load failed: " & nextPath
    return

  try:
    let loadProc = resolveSymbol[HotReloadLoadProc](library, HotReloadLoadSymbol)
    let updateProc = resolveSymbol[HotReloadUpdateProc](library, HotReloadUpdateSymbol)
    let drawProc = resolveSymbol[HotReloadDrawProc](library, HotReloadDrawSymbol)
    let unloadProc = cast[HotReloadUnloadProc](library.symAddr(HotReloadUnloadSymbol))
    scene.unload()
    scene.library = library
    scene.loadedPath = nextPath
    scene.loadProc = loadProc
    scene.unloadProc = unloadProc
    scene.updateProc = updateProc
    scene.drawProc = drawProc
    scene.lastMtime = getLastModificationTime(scene.sourcePath)
    inc scene.reloads
    scene.loadProc(addr scene.api)
    echo "[Nima hotreload] loaded ", scene.sourcePath
  except CatchableError as err:
    unloadLib(library)
    scene.lastError = err.msg

proc maybeReload(scene: HotReloadScene) =
  if not fileExists(scene.sourcePath):
    return
  let mtime = getLastModificationTime(scene.sourcePath)
  if scene.library == nil or mtime != scene.lastMtime:
    scene.tryLoad()

proc hotReloadScene*(libraryPath: string): HotReloadScene =
  HotReloadScene(sourcePath: libraryPath, api: initHotReloadApi())

method init*(scene: HotReloadScene) =
  if scene.api.version == 0:
    scene.api = initHotReloadApi()
  scene.tryLoad()

method update*(scene: HotReloadScene) =
  scene.maybeReload()
  if scene.updateProc != nil:
    scene.updateProc()

method draw*(scene: HotReloadScene) =
  drawRect(rgb(0.025, 0.03, 0.04), viewSize(), transform(vec3(0, 0, -1)))
  if scene.drawProc != nil:
    scene.drawProc()
  else:
    drawText(text("Hot reload library missing", 24, Yellow),
             transform(vec3(-180, 24, 0.1)))
    if scene.lastError.len > 0:
      drawText(text(scene.lastError, 14, rgba(1, 0.5, 0.35, 1)),
               transform(vec3(-180, -12, 0.1)))

  let label = "reloads: " & $scene.reloads
  drawText(text(label, 14, rgba(0.75, 0.85, 1, 1)),
           transform(vec3(-viewSize().x * 0.5'f32 + 18, viewSize().y * 0.5'f32 - 32, 0.2)))

method cleanup*(scene: HotReloadScene) =
  scene.unload()
