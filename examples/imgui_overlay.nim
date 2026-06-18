import nima/prelude

type Overlay = ref object of Scene
  clicks: int
  enabled: bool
  speed: float32
  progress: float32

method init(scene: Overlay) =
  scene.enabled = true
  scene.speed = 0.45
  imgui(proc() =
    if imguiBegin("Nima Debug UI", vec2(16, 16), 280):
      imguiText("Immediate overlay layer")
      if imguiButton("Increment"):
        inc scene.clicks
      discard imguiCheckbox("Enabled", scene.enabled)
      discard imguiSliderFloat("Speed", scene.speed, 0, 1)
      imguiSeparator()
      imguiText("Clicks: " & $scene.clicks)
      imguiProgressBar(scene.progress, "Progress")
      imguiEnd()
  )

method update(scene: Overlay) =
  if scene.enabled:
    scene.progress = (scene.progress + tick() * scene.speed).clamp(0, 1)
    if scene.progress >= 1:
      scene.progress = 0

method draw(scene: Overlay) =
  drawRect(rgb(0.04, 0.05, 0.07), viewSize(), transform(vec3(0, 0, -1)))
  drawText(text("Nima immediate debug UI", 24, White), transform(vec3(0, 0, 0)))

when isMainModule:
  run app(title = "ImGui Overlay", size = ivec2(800, 600), scene = Overlay())
