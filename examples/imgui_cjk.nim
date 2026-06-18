import nima/prelude

type CjkDemo = ref object of Scene
  showPanel: bool
  progress: float32
  inputText: string
  font: Handle[Font]
  fontPath: string

proc findCjkFont(): tuple[font: Handle[Font], path: string] =
  const candidates = [
    "/System/Library/Fonts/Hiragino Sans GB.ttc",
    "/System/Library/Fonts/STHeiti Medium.ttc",
    "/System/Library/Fonts/Supplemental/Songti.ttc",
    "/Library/Fonts/NotoSansCJK-Regular.ttc",
    "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
    "/usr/share/fonts/truetype/noto/NotoSansCJK-Regular.ttc",
    "C:\\Windows\\Fonts\\msyh.ttc",
    "C:\\Windows\\Fonts\\simsun.ttc",
    "fonts/NotoSansCJK-Regular.ttc"
  ]
  for path in candidates:
    let font = loadFont(path)
    if font.isLoaded:
      return (font, path)

method init(scene: CjkDemo) =
  scene.showPanel = true
  scene.inputText = "你好，世界！在这里输入中文……"
  let found = findCjkFont()
  scene.font = found.font
  scene.fontPath = found.path
  if scene.font.isLoaded:
    setImguiFont(scene.font)
  imgui(proc() =
    if imguiBegin("CJK 字体示例", vec2(16, 16), 430, 260):
      if scene.font.isLoaded:
        imguiText("字体: " & scene.fontPath)
      else:
        imguiText("未找到 CJK 字体；请安装 Noto Sans CJK 或系统中文字体")
      imguiSeparator()
      discard imguiCheckbox("显示文本", scene.showPanel)
      imguiText("你好，世界")
      imguiText("中文调试文本")
      discard imguiInputTextMultiline("输入", scene.inputText, 3)
      imguiProgressBar(scene.progress, "进度")
      imguiEnd()
  )

method update(scene: CjkDemo) =
  scene.progress = (scene.progress + tick() * 0.25'f32).clamp(0, 1)
  if scene.progress >= 1:
    scene.progress = 0

method draw(scene: CjkDemo) =
  drawRect(rgb(0.04, 0.05, 0.07), viewSize(), transform(vec3(0, 0, -1)))
  if scene.showPanel and scene.font.isLoaded:
    drawText(text("你好，世界！Nima CJK font path.", 24, White).withFont(scene.font),
             transform(vec3(0, 20, 0)))
    drawText(text("Input: " & scene.inputText, 16, rgb(0.78, 0.82, 0.88)).withFont(scene.font),
             transform(vec3(0, -20, 0)))
  elif scene.showPanel:
    drawText(text("CJK font not loaded. Install SDL3_ttf and a CJK font.", 18, White),
             transform(vec3(0, 0, 0)))

when isMainModule:
  run app(title = "ImGui CJK", size = ivec2(800, 600), scene = CjkDemo(),
          resizable = true)
