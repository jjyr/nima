import std/math as stdmath
import nima/prelude

type
  Action = enum
    toggleOverlay, faster, slower, moveLeft, moveRight, moveUp, moveDown

  DiagnosticsDemo = ref object of Scene
    overlayPos: Vec2
    phase: float32

method init(scene: DiagnosticsDemo) =
  scene.overlayPos = vec2(16, 16)
  bindAction(toggleOverlay, key(kcT))
  bindAction(faster, key(kcE))
  bindAction(slower, key(kcQ))
  bindAction(moveLeft, key(kcLeft))
  bindAction(moveRight, key(kcRight))
  bindAction(moveUp, key(kcUp))
  bindAction(moveDown, key(kcDown))
  setDiagnosticsOverlay(true)
  setDiagnosticsOverlayPosition(scene.overlayPos)
  setDiagnosticsOverlayRefreshInterval(0.5)

method update(scene: DiagnosticsDemo) =
  scene.phase += tick()
  if actionJustPressed(toggleOverlay):
    setDiagnosticsOverlay(not diagnosticsOverlayEnabled())
  if actionJustPressed(faster):
    setDiagnosticsOverlayRefreshInterval(diagnosticsOverlayRefreshInterval() - 0.05'f32)
  if actionJustPressed(slower):
    setDiagnosticsOverlayRefreshInterval(diagnosticsOverlayRefreshInterval() + 0.05'f32)

  let speed = 260'f32 * tick()
  if actionDown(moveLeft): scene.overlayPos.x -= speed
  if actionDown(moveRight): scene.overlayPos.x += speed
  if actionDown(moveUp): scene.overlayPos.y -= speed
  if actionDown(moveDown): scene.overlayPos.y += speed
  setDiagnosticsOverlayPosition(scene.overlayPos)

method draw(scene: DiagnosticsDemo) =
  let view = viewSize()
  drawRect(rgb(0.08, 0.10, 0.13), view, transform(vec3(0, 0, -1)))
  for i in 0..<36:
    let t = scene.phase * 0.9'f32 + i.float32 * 0.19'f32
    let x = stdmath.cos(t).float32 * (120'f32 + (i mod 5).float32 * 28'f32)
    let y = stdmath.sin(t * 1.3'f32).float32 * (70'f32 + (i mod 4).float32 * 24'f32)
    drawCircle(vec3(x, y, 0.1), 8'f32 + (i mod 6).float32, rgba(0.3, 0.55, 0.9, 0.72))
  drawText(text("T toggle  E faster  Q slower  arrows move", 18, White),
           transform(vec3(-view.x * 0.5'f32 + 16, -view.y * 0.5'f32 + 24, 2)), vec2(0, 0))

method cleanup(scene: DiagnosticsDemo) =
  setDiagnosticsOverlay(false)

when isMainModule:
  run app(title = "Diagnostics Overlay", size = ivec2(960, 540),
          scene = DiagnosticsDemo(), scaleMode = ScaleMode(kind: smFit, virtualSize: vec2(960, 540)))
