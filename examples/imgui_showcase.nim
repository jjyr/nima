import nima/prelude

type Showcase = ref object of Scene
  counter: int
  slider: float32
  enabled: bool
  radioChoice: int
  comboIndex: int
  singleLine: string
  multiLine: string
  color: Color
  progress: float32
  listOpen: bool
  treeOpen: bool

method init(scene: Showcase) =
  scene.slider = 0.5
  scene.enabled = true
  scene.singleLine = "Hello Nima"
  scene.multiLine = "This is a multi-line text box.\nASCII input works today."
  scene.color = rgba(0.47, 0.78, 0.39, 1)
  scene.progress = 0.2
  imgui(proc() =
    let view = viewSize()
    if imguiBeginPanel(vec2(0, 0), view.x, 48, rgba(0.06, 0.07, 0.09, 0.96)):
      if imguiButton("New", 64):
        scene.counter = 0
      imguiSameLine(8)
      discard imguiButton("File", 64)
      imguiSameLine(8)
      discard imguiButton("View", 64)
      imguiEnd()

    if imguiBegin("Controls", vec2(16, 64), 310, 360):
      if imguiButton("Increment counter"):
        inc scene.counter
      imguiText("Counter: " & $scene.counter)
      imguiSeparator()
      discard imguiCheckbox("Enable progress", scene.enabled)
      discard imguiRadioValue("Option A", scene.radioChoice, 0)
      discard imguiRadioValue("Option B", scene.radioChoice, 1)
      discard imguiRadioValue("Option C", scene.radioChoice, 2)
      discard imguiCombo("Fruit", scene.comboIndex, ["Apple", "Banana", "Orange", "Grape"])
      discard imguiSliderFloat("Progress speed", scene.slider, 0, 1)
      discard imguiDragInt("Drag counter", scene.counter)
      imguiEnd()

    if imguiBeginPanel(vec2(350, 64), 420, 600):
      imguiText("Egui Showcase")
      imguiSeparator()
      discard imguiInputText("Single line", scene.singleLine)
      discard imguiInputTextMultiline("Multi line", scene.multiLine, 3)
      discard imguiColorEdit4("Color", scene.color)
      imguiProgressBar(scene.progress, $(int(scene.progress * 100)) & "%")
      imguiSeparator()
      if imguiCollapsingHeader("Scrollable list", scene.listOpen):
        discard
      if scene.listOpen:
        imguiIndent()
        for i in 0..<8:
          imguiText("Item #" & $i)
        imguiUnindent()
      if imguiCollapsingHeader("Tree structure", scene.treeOpen):
        discard
      if scene.treeOpen:
        imguiIndent()
        imguiText("Parent A")
        imguiIndent()
        imguiText("Child A1")
        imguiText("Child A2")
        imguiUnindent()
        imguiText("Parent B")
        imguiIndent()
        imguiText("Child B1")
        imguiText("Child B2")
        imguiUnindent()
        imguiUnindent()
      imguiEnd()
  )

method update(scene: Showcase) =
  if scene.enabled:
    scene.progress = (scene.progress + tick() * scene.slider).clamp(0, 1)
    if scene.progress >= 1:
      scene.progress = 0

method draw(scene: Showcase) =
  let view = viewSize()
  drawRect(rgb(0.04, 0.05, 0.07), view, transform(vec3(0, 0, -1)))
  drawRect(scene.color, vec2(360, 220), transform(vec3(190, 20, 0)))
  drawText(text("ImGui Showcase", 28, White), transform(vec3(190, 80, 0.2)))
  drawText(text("Built-in immediate debug UI path", 18, rgb(0.92, 0.94, 0.98)),
           transform(vec3(190, 42, 0.2)))
  drawText(text("Single: " & scene.singleLine, 16, White),
           transform(vec3(190, 6, 0.2)))

when isMainModule:
  run app(title = "ImGui Showcase", size = ivec2(1280, 720), scene = Showcase(),
          resizable = true,
          scaleMode = ScaleMode(kind: smFit, virtualSize: vec2(1280, 720)))
