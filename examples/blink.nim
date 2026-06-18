import std/sets
import nima/prelude

const
  Size = vec2(20, 20)
  Gap = 10'f32
  Count = 400
  Cols = 20

type BlinkDemo = ref object of Scene
  timer: float32
  blinkTimers: seq[float32]
  visited: HashSet[(int, int)]
  queue: seq[(int, int)]

proc wrapCoord(value: int): int =
  let m = value mod Cols
  if m < 0: m + Cols else: m

proc blinkColor(value: float32): Color =
  let pulse = value.clamp(0, 1)
  rgba(0.12 + 0.70 * pulse, 0.28 + 0.45 * pulse, 0.80 + 0.18 * pulse, 1)

method init(scene: BlinkDemo) =
  scene.blinkTimers = newSeq[float32](Count)
  scene.visited = initHashSet[(int, int)]()
  scene.queue = @[(0, 0)]

method update(scene: BlinkDemo) =
  scene.timer += tick()
  while scene.timer > 0.1'f32:
    scene.timer -= 0.1'f32
    let wave = scene.queue
    scene.queue.setLen 0
    for (x, y) in wave:
      let index = x + y * Cols
      if index >= 0 and index < scene.blinkTimers.len:
        scene.blinkTimers[index] = 1
      scene.visited.incl((x, y))
      for delta in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
        let nx = wrapCoord(x + delta[0])
        let ny = wrapCoord(y + delta[1])
        if (nx, ny) notin scene.visited:
          scene.queue.add((nx, ny))

  if scene.queue.len == 0:
    scene.queue.add((0, 0))
    scene.visited.clear()

  for timer in scene.blinkTimers.mitems:
    timer = (timer - tick()).clamp(0, 1)

method draw(scene: BlinkDemo) =
  drawRect(rgb(0.03, 0.04, 0.07), viewSize(), transform(vec3(0, 0, -1)))
  let length = (Size.x + Gap) * Cols.float32 - Gap
  let start = vec2(-length * 0.5'f32 + Size.x * 0.5'f32,
                   length * 0.5'f32 - Size.y * 0.5'f32)
  for i in 0..<Count:
    let x = i mod Cols
    let y = i div Cols
    let pos = vec2(start.x + x.float32 * (Size.x + Gap),
                   start.y - y.float32 * (Size.y + Gap))
    drawRect(blinkColor(scene.blinkTimers[i]), Size, transform(pos.extend(0)))

when isMainModule:
  run app(title = "Blink", size = ivec2(800, 600), scene = BlinkDemo(),
          resizable = true)
