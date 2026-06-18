import std/os
import nima/prelude

type HostSmoke = ref object of Scene
  host: HotReloadScene

method init(scene: HostSmoke) =
  scene.host = hotReloadScene(getCurrentDir() / "examples" / hotReloadLibraryName())
  scene.host.init()

method update(scene: HostSmoke) =
  scene.host.update()
  if frame() > 2:
    exit()

method draw(scene: HostSmoke) =
  scene.host.draw()

method cleanup(scene: HostSmoke) =
  if scene.host != nil:
    scene.host.cleanup()

when isMainModule:
  if not fileExists(getCurrentDir() / "examples" / hotReloadLibraryName()):
    quit("run `nimble hotreloadLib` first", 1)
  runHeadless(app(HostSmoke()), frames = 8)
