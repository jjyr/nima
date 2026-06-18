import nima/prelude

type AutoClose = ref object of Scene

method update(scene: AutoClose) =
  exit()

method draw(scene: AutoClose) =
  drawRect(rgb(0.04, 0.06, 0.08), viewSize(), transform(vec3(0, 0, -1)))
  drawRect(Green, vec2(96, 48), transform(vec3(0, 0, 0)))

when isMainModule:
  run app(AutoClose(), title = "Nima SDL_GPU Smoke", size = ivec2(320, 180),
          scaleMode = ScaleMode(kind: smFit, virtualSize: vec2(320, 180)))
