import std/math as stdmath
import nima/prelude

type
  Action = enum
    spawn, clearActors, quit

  PrefabBasic = ref object of Scene
    actors: seq[Ent]
    spawnAcc: float32
    total: int

proc spawnActor(scene: PrefabBasic) =
  let t = scene.total.float32
  let x = stdmath.sin(t * 1.7).float32 * 220
  let y = 170 + stdmath.cos(t * 1.1).float32 * 80
  let size = 38 + (scene.total mod 5).float32 * 8
  let color = rgba(0.3 + (scene.total mod 3).float32 * 0.2, 0.5, 0.9, 1)
  let e = spawnPrefab("prefabs/player.ron", vec2(x, y), vec2(size, size), color)
  scene.actors.add e
  inc scene.total

method init(scene: PrefabBasic) =
  bindAction(spawn, key(kcSpace))
  bindAction(clearActors, key(kcBackspace))
  bindAction(quit, key(kcEscape))
  discard preloadPrefab("prefabs/player.ron")

method update(scene: PrefabBasic) =
  if actionJustPressed(spawn):
    scene.spawnActor()
    scene.spawnAcc = 0
  if actionDown(spawn):
    scene.spawnAcc += tick()
    while scene.spawnAcc >= 0.08'f32:
      scene.spawnAcc -= 0.08'f32
      scene.spawnActor()
  else:
    scene.spawnAcc = 0
  if actionJustPressed(clearActors):
    for actor in scene.actors:
      discard removePrefab(actor)
    scene.actors.setLen 0
  if actionJustPressed(quit):
    exit()

method draw(scene: PrefabBasic) =
  drawRect(rgb(0.05, 0.06, 0.08), viewSize(), transform(vec3(0, 0, -1)))
  drawRect(rgb(0.35, 0.25, 0.18), vec2(560, 32), transform(vec3(0, -180, 0.1)))
  for actor in scene.actors:
    discard drawPrefab(actor)
  let lastTag = if scene.actors.len > 0: prefabTag(scene.actors[^1]) else: "none"
  discard withUi(proc(): bool =
    drawText(text("Prefab Basic\nHold SPACE spawn\nBACKSPACE clear  ESC exit\nlive=" &
                  $prefabInstanceCount() & " total=" & $scene.total & " last=" & lastTag, 18, White),
             transform(vec3(-320, 240, 2)), vec2(0, 1))
    true
  )

method cleanup(scene: PrefabBasic) =
  clearPrefabs()

when isMainModule:
  run app(title = "Prefab Basic", size = ivec2(800, 600), scene = PrefabBasic())
