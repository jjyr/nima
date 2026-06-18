import std/math
import nima/hotreload

var
  api: ptr HotReloadApi
  elapsed: float32
  pulse: float32

proc nimaHotReloadLoad*(hostApi: ptr HotReloadApi) {.cdecl, exportc, dynlib.} =
  api = hostApi
  if api != nil and api.log != nil:
    api.log("game library loaded")

proc nimaHotReloadUnload*() {.cdecl, exportc, dynlib.} =
  if api != nil and api.log != nil:
    api.log("game library unloaded")
  api = nil

proc nimaHotReloadUpdate*() {.cdecl, exportc, dynlib.} =
  if api.isNil:
    return
  elapsed += api.tick().float32
  pulse = (sin(elapsed * 4'f32) + 1'f32) * 0.5'f32

proc nimaHotReloadDraw*() {.cdecl, exportc, dynlib.} =
  if api.isNil:
    return
  let wobble = sin(elapsed * 2'f32) * 80'f32
  api.drawRect(0.12, 0.18 + pulse * 0.25, 0.36, 1.0,
               wobble, 0, 0.2, 260, 150)
  api.drawRect(1.0, 0.82, 0.18, 1.0,
               -90 + wobble * 0.25, -8, 0.4, 46, 46)
  api.drawText("Edit examples/hotreload_game.nim", 24,
               1.0, 1.0, 1.0, 1.0,
               -210, 72, 0.8)
  api.drawText("Rebuild with: nimble hotreloadLib", 16,
               0.72, 0.84, 1.0, 1.0,
               -210, 36, 0.8)
  api.drawText(("Frame " & $api.frame()).cstring, 14,
               0.75, 0.95, 0.72, 1.0,
               -210, -56, 0.8)
