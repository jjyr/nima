import nima/prelude

type Shapes = ref object of Scene

method draw(scene: Shapes) =
  drawRect(rgb(0.06, 0.07, 0.08), viewSize(), transform(vec3(0, 0, -1)))
  drawRect(Red, vec2(120, 80), transform(vec3(-180, 80, 0)))
  drawCircle(vec3(0, 80, 0), 54, Blue)
  drawLine(vec2(-240, -80), vec2(240, -80), 4, Green)
  drawLineEx(line(vec2(-240, -120), vec2(240, -120), 3, Yellow), 0.2,
             dashedLinePattern(24, 12), frame().float32 * 1.5'f32)
  drawLineEx(line(vec2(-240, -155), vec2(240, -155), 4, White), 0.2,
             dottedLinePattern(18), 0)
  drawPoly(vec3(180, 80, 0), 6, 64, 0, Yellow)
  drawPolyLines(vec3(180, 80, 0.1), 6, 64, 0, 3, White)

when isMainModule:
  run app(title = "Shapes", size = ivec2(800, 600), scene = Shapes())
