import nima/prelude

type Smoke = ref object of Scene

method update(scene: Smoke) =
  discard

method draw(scene: Smoke) =
  drawRect(rgb(0.08, 0.09, 0.11), viewSize(), transform(vec3(0, 0, -1)))
  drawText(text("Nima window smoke", 24, White), transform(vec3(0, 0, 0)))

when isMainModule:
  run app(title = "Window Smoke", size = ivec2(800, 600), scene = Smoke())
