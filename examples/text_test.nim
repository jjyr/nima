import nima/prelude

type TextTest = ref object of Scene

method draw(scene: TextTest) =
  let view = viewSize()
  let preview = text("Layout once, draw many", 30, White)
  let layout = layoutText(preview)
  let measured = measureText(preview)
  drawRect(rgb(0.04, 0.05, 0.07), view, transform(vec3(0, 0, -1)))
  drawText(text("Text Test", 32, Yellow), transform(vec3(-360, 240, 1)), vec2(0, 1))
  drawText(text("Size 18: layout is recorder-based today", 18, White), transform(vec3(-360, 180, 1)), vec2(0, 1))
  drawText(text("Size 24: Text.withFont uses SDL3_ttf glyph atlas when available", 24, rgb(0.7, 0.9, 1)),
           transform(vec3(-360, 130, 1)), vec2(0, 1))
  drawTextLayout(layout, transform(vec3(-measured.x * 0.5, 60, 1)), vec2(0, 0.5))
  drawText(text("Measured: " & $measured.x.int & " x " & $measured.y.int, 16, rgb(0.8, 0.82, 0.86)),
           transform(vec3(0, 20, 1)), vec2(0.5, 0.5))
  drawText(text("Measure/layout still deterministic and backend-neutral", 20, rgb(0.9, 0.8, 0.5)),
           transform(vec3(-360, -30, 1)), vec2(0, 1))

when isMainModule:
  run app(title = "Text Test", size = ivec2(800, 600), scene = TextTest())
