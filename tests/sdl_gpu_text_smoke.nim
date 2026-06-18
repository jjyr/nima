import nima/prelude

type TextScene = ref object of Scene
  value: float32
  checked: bool

method init(scene: TextScene) =
  scene.checked = true
  imgui(proc() =
    if imguiBegin("GPU UI", vec2(16, 16), 220):
      imguiText("SDL_GPU text")
      discard imguiCheckbox("Enabled", scene.checked)
      discard imguiSliderFloat("Value", scene.value, 0, 1)
      imguiProgressBar(scene.value, "progress")
      imguiEnd()
  )

method update(scene: TextScene) =
  scene.value = 0.5
  exit()

method draw(scene: TextScene) =
  drawRect(rgb(0.03, 0.04, 0.06), viewSize(), transform(vec3(0, 0, -1)))
  drawText(text("Nima SDL_GPU Text", 24, White), transform(vec3(-130, 42, 0)))
  drawText(text("debug font bootstrap", 14, rgb(0.75, 0.82, 0.9)),
           transform(vec3(-130, 8, 0)))

when isMainModule:
  run app(TextScene(), title = "Nima SDL_GPU Text Smoke", size = ivec2(480, 270),
          scaleMode = ScaleMode(kind: smFit, virtualSize: vec2(480, 270)))
