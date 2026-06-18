import nima/prelude

type
  Action = enum
    quit

  AtlasBasic = ref object of Scene
    atlas: AtlasHandle
    frames: seq[FrameId]
    index: int
    timer: float32

method init(scene: AtlasBasic) =
  bindAction(quit, key(kcEscape))
  scene.atlas = loadAtlas("atlas.demo")
  scene.frames = atlasClip(scene.atlas, "idle")
  let named = atlasFrameId(scene.atlas, "idle_0")
  if named != FrameId(0) and scene.frames.len == 0:
    scene.frames = @[named]

method update(scene: AtlasBasic) =
  if actionJustPressed(quit):
    exit()
  scene.timer += tick()
  if scene.frames.len > 0 and scene.timer >= 0.12'f32:
    scene.timer = 0
    scene.index = (scene.index + 1) mod scene.frames.len

method draw(scene: AtlasBasic) =
  drawRect(rgb(0.08, 0.09, 0.11), viewSize(), transform(vec3(0, 0, -1)))
  if scene.frames.len > 0:
    let color = case scene.index mod 3
      of 0: Red
      of 1: Green
      else: Blue
    discard drawAtlasFrame(scene.atlas, scene.frames[scene.index],
                           transform(vec3(0, 0, 0.2), scale = vec2(2, 2)), color)
  let size =
    if scene.frames.len > 0: atlasFrame(scene.atlas, scene.frames[scene.index]).size
    else: Vec2Zero
  discard withUi(proc(): bool =
    drawText(text("Atlas Basic\nJSON descriptor or generated fallback\nESC exit\nframes=" &
                  $scene.frames.len & " size=" & $size.x.int & "x" & $size.y.int, 18, White),
             transform(vec3(-250, 220, 2)), vec2(0, 1))
    true
  )

when isMainModule:
  run app(title = "Atlas Basic", size = ivec2(800, 600), scene = AtlasBasic())
