import nima/prelude

type AutoClose = ref object of Scene

method update(scene: AutoClose) =
  exit()

method draw(scene: AutoClose) =
  drawRect(rgb(0.08, 0.09, 0.11), viewSize(), transform(vec3(0, 0, -1)))
  drawRect(Yellow, vec2(96, 48), transform(vec3(0, 0, 0)))

when isMainModule:
  run app(AutoClose(), title = "Nima SDL Smoke", size = ivec2(320, 180),
          scaleMode = ScaleMode(kind: smFit, virtualSize: vec2(320, 180)))
