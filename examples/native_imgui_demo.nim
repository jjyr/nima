import std/math
import nima/prelude
import nima/imgui_native

type NativeImGuiDemo = ref object of Scene
  counter: int
  showDemo: bool
  enabled: bool
  speed: float32
  mode: int
  fruit: int
  title: string
  notes: string
  tint: Color

method init(scene: NativeImGuiDemo) =
  scene.enabled = true
  scene.speed = 0.5
  scene.title = "Nima"
  scene.notes = "Native Dear ImGui"
  scene.tint = rgba(0.2, 0.55, 0.95, 0.9)
  nativeImguiSetNavigation(keyboard = true, gamepad = true)
  nativeImgui(proc() =
    if nativeImguiBeginMainMenuBar():
      if nativeImguiBeginMenu("File"):
        if nativeImguiMenuItem("Increment"):
          inc scene.counter
        discard nativeImguiMenuItem("Quit")
        nativeImguiEndMenu()
      if nativeImguiBeginMenu("View"):
        discard nativeImguiCheckbox("Show demo", scene.showDemo)
        nativeImguiEndMenu()
      nativeImguiEndMainMenuBar()

    nativeImguiSetNextWindow(imvec2(20, 42), imvec2(380, 420))
    if nativeImguiBegin("Native Dear ImGui"):
      nativeImguiText("CImGui + SDL3 backend")
      if nativeImguiButton("Increment", imvec2(120, 0)):
        inc scene.counter
        nativeImguiOpenPopup("increment-popup")
      nativeImguiSameLine()
      nativeImguiText("Counter: " & $scene.counter)
      if nativeImguiBeginTooltip():
        nativeImguiText("Native ImGui tooltip")
        nativeImguiEndTooltip()
      if nativeImguiBeginPopup("increment-popup"):
        nativeImguiText("Counter changed")
        nativeImguiEndPopup()
      nativeImguiSeparator()
      discard nativeImguiCheckbox("Enabled", scene.enabled)
      nativeImguiBeginDisabled(not scene.enabled)
      discard nativeImguiSliderFloat("Speed", scene.speed, 0, 1)
      nativeImguiEndDisabled()
      discard nativeImguiSliderInt("Mode", scene.mode, 0, 2)
      discard nativeImguiCombo("Fruit", scene.fruit,
        ["Apple", "Banana", "Orange", "Grape"])
      discard nativeImguiInputText("Title", scene.title)
      nativeImguiSameLine()
      if nativeImguiButton("Copy", imvec2(72, 0)):
        nativeImguiSetClipboardText(scene.title)
      discard nativeImguiInputTextMultiline("Notes", scene.notes,
        imvec2(0, 70), flags = ImGuiInputTextFlags_AllowTabInput)
      discard nativeImguiColorEdit4("Tint", scene.tint)
      nativeImguiProgressBar((sin(time()) * 0.5 + 0.5).float32, "pulse")
      if nativeImguiCollapsingHeader("Tree", true):
        if nativeImguiTreeNode("Parent A"):
          nativeImguiIndent()
          nativeImguiText("Child A1")
          nativeImguiText("Child A2")
          nativeImguiUnindent()
          nativeImguiTreePop()
      if nativeImguiBeginTable("stats-table", 2):
        nativeImguiTableSetupColumn("Metric")
        nativeImguiTableSetupColumn("Value")
        nativeImguiTableHeadersRow()
        nativeImguiTableNextRow()
        discard nativeImguiTableNextColumn()
        nativeImguiText("Counter")
        discard nativeImguiTableNextColumn()
        nativeImguiText($scene.counter)
        nativeImguiTableNextRow()
        discard nativeImguiTableNextColumn()
        nativeImguiText("Mode")
        discard nativeImguiTableNextColumn()
        nativeImguiText($scene.mode)
        nativeImguiEndTable()
      nativeImguiEnd()

    nativeImguiSetNextWindow(imvec2(420, 42), imvec2(300, 220))
    if nativeImguiBegin("Tabs"):
      if nativeImguiBeginTabBar("native-tabs"):
        if nativeImguiBeginTabItem("State"):
          nativeImguiText("Title: " & scene.title)
          nativeImguiText("Clipboard: " & nativeImguiClipboardText())
          nativeImguiText("Notes length: " & $scene.notes.len)
          nativeImguiEndTabItem()
        if nativeImguiBeginTabItem("Options"):
          discard nativeImguiRadioValue("Mode A", scene.mode, 0)
          discard nativeImguiRadioValue("Mode B", scene.mode, 1)
          discard nativeImguiRadioValue("Mode C", scene.mode, 2)
          nativeImguiEndTabItem()
        nativeImguiEndTabBar()
      nativeImguiEnd()

    if scene.showDemo:
      igShowDemoWindow(addr scene.showDemo)
  )

method cleanup(scene: NativeImGuiDemo) =
  clearNativeImguiLayers()

method draw(scene: NativeImGuiDemo) =
  drawRect(rgb(0.08, 0.09, 0.11), viewSize(), transform(vec3(0, 0, -1)))
  drawRect(scene.tint, vec2(140, 80),
           transform(vec3(0, 0, 0), angle = time() * scene.speed))

when isMainModule:
  run app(NativeImGuiDemo(), title = "Nima Native ImGui", size = ivec2(960, 540),
          scaleMode = ScaleMode(kind: smFit, virtualSize: vec2(960, 540)))
