import std/os
import nima/prelude

type
  Action = enum
    quit

  HotReloadHost = ref object of Scene
    host: HotReloadScene

method init(scene: HotReloadHost) =
  bindAction(quit, key(kcEscape))
  scene.host = hotReloadScene(getCurrentDir() / "examples" / hotReloadLibraryName())
  scene.host.init()

method update(scene: HotReloadHost) =
  if actionJustPressed(quit):
    exit()
  scene.host.update()

method draw(scene: HotReloadHost) =
  scene.host.draw()
  discard withUi(proc(): bool =
    let half = viewSize() * 0.5'f32
    drawText(text("Dynamic Hot Reload", 24, Yellow),
             transform(vec3(-half.x + 16, half.y - 28, 2)), vec2(0, 1))
    drawText(text("Build: nimble hotreloadLib", 14, White),
             transform(vec3(-half.x + 16, half.y - 56, 2)), vec2(0, 1))
    drawText(text("Edit examples/hotreload_game.nim, rebuild dylib, host reloads by mtime.", 14,
                  rgb(0.78, 0.82, 0.9)),
             transform(vec3(-half.x + 16, half.y - 78, 2)), vec2(0, 1))
    drawText(text("ESC quits", 14, rgb(0.75, 0.9, 0.75)),
             transform(vec3(-half.x + 16, half.y - 100, 2)), vec2(0, 1))
    true
  )

method cleanup(scene: HotReloadHost) =
  if scene.host != nil:
    scene.host.cleanup()

when isMainModule:
  run app(title = "Nima Dynamic Hot Reload", size = ivec2(960, 540),
          scene = HotReloadHost(), resizable = true,
          scaleMode = ScaleMode(kind: smFit, virtualSize: vec2(960, 540)))
