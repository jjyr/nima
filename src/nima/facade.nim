import std/strutils
import ./[assets, atlas, audio, color, diagnostics, draw, ecs, engine, imgui, input, light2d, map, math, particles, physics, prefab, scene, transform]

var currentEngine {.threadvar.}: ptr Engine

proc activeEngine(): ptr Engine =
  if currentEngine.isNil:
    raise newException(ValueError, "nima facade used outside engine scope")
  currentEngine

proc withEngineScope*[T](engine: var Engine, body: proc(): T): T =
  let previous = currentEngine
  currentEngine = addr engine
  try:
    result = body()
  finally:
    currentEngine = previous

proc withEngine*[T](body: proc(engine: var Engine): T): T =
  body(activeEngine()[])

proc time*(): float32 = withEngine(proc(engine: var Engine): float32 = engine.time)
proc tick*(): float32 = withEngine(proc(engine: var Engine): float32 = engine.tick)
proc timeScale*(): float32 = withEngine(proc(engine: var Engine): float32 = engine.timeScale)
proc setTimeScale*(scale: float32) =
  discard withEngine(proc(engine: var Engine): bool =
    engine.timeScale = if scale < 0'f32: 0'f32 else: scale
    true
  )
proc frame*(): uint64 = withEngine(proc(engine: var Engine): uint64 = engine.frame)
proc viewSize*(): Vec2 = withEngine(proc(engine: var Engine): Vec2 = engine.viewSize)
proc screenSize*(): Vec2 = withEngine(proc(engine: var Engine): Vec2 = engine.screenSize)
proc dpiScale*(): float32 = withEngine(proc(engine: var Engine): float32 = engine.dpiScale)
proc dpiScaleFactor*(): float32 = dpiScale()
proc perf*(): Perf = withEngine(proc(engine: var Engine): Perf = engine.perf)
proc exit*() = discard withEngine(proc(engine: var Engine): bool = engine.requestExit(); true)

proc cameraPos*(): Vec2 =
  withEngine(proc(engine: var Engine): Vec2 = engine.cameraPos)

proc setCameraPos*(pos: Vec2) =
  discard withEngine(proc(engine: var Engine): bool = engine.cameraPos = pos; true)

proc cameraZoom*(): float32 =
  withEngine(proc(engine: var Engine): float32 = engine.cameraZoom)

proc setCameraZoom*(zoom: float32) =
  discard withEngine(proc(engine: var Engine): bool =
    engine.cameraZoom = if zoom <= 0.01'f32: 0.01'f32 else: zoom
    true
  )

proc worldToScreen*(pos: Vec2): Vec2 =
  withEngine(proc(engine: var Engine): Vec2 =
    (pos - engine.cameraPos) * engine.cameraZoom)

proc screenToWorld*(pos: Vec2): Vec2 =
  withEngine(proc(engine: var Engine): Vec2 =
    pos / engine.cameraZoom + engine.cameraPos)

proc uiWantsPointerInput*(): bool =
  withEngine(proc(engine: var Engine): bool = engine.imgui.wantsPointerInput)

proc uiWantsKeyboardInput*(): bool =
  withEngine(proc(engine: var Engine): bool = engine.imgui.wantsKeyboardInput)

proc setScene*(scene: Scene) =
  discard withEngine(proc(engine: var Engine): bool = engine.queueSetScene(scene); true)

proc replaceScene*(scene: Scene) =
  discard withEngine(proc(engine: var Engine): bool = engine.queueReplaceScene(scene); true)

proc pushScene*(scene: Scene, payload: ScenePayload = nil) =
  discard withEngine(proc(engine: var Engine): bool = engine.queuePushScene(scene, payload); true)

proc popScene*(payload: ScenePayload = nil) =
  discard withEngine(proc(engine: var Engine): bool = engine.queuePopScene(payload); true)

proc takeScenePayload*[T](): T =
  withEngine(proc(engine: var Engine): T = takeScenePayload[T](engine))

proc reloadImportedAssets*(): int =
  withEngine(proc(engine: var Engine): int = engine.reloadImportedAssets())

proc setImportedAssetsAutoReload*(enabled: bool) =
  discard withEngine(proc(engine: var Engine): bool =
    engine.setImportedAssetsAutoReload(enabled)
    true
  )

proc importedAssetsAutoReload*(): bool =
  withEngine(proc(engine: var Engine): bool = engine.importedAssetsAutoReloadEnabled())

proc bindAction*[A: enum](action: A, source: InputSource) =
  discard withEngine(proc(engine: var Engine): bool = engine.input.bindAction(action, source); true)

proc setActionSources*[A: enum](action: A, sources: openArray[InputSource]) =
  discard withEngine(proc(engine: var Engine): bool = engine.input.setActionSources(action, sources); true)

proc clearAction*[A: enum](action: A) =
  discard withEngine(proc(engine: var Engine): bool = engine.input.clearAction(action); true)

proc actionDown*[A: enum](action: A): bool =
  withEngine(proc(engine: var Engine): bool = engine.input.actionDown(action))

proc actionUp*[A: enum](action: A): bool =
  withEngine(proc(engine: var Engine): bool = engine.input.actionUp(action))

proc actionJustPressed*[A: enum](action: A): bool =
  withEngine(proc(engine: var Engine): bool = engine.input.actionJustPressed(action))

proc actionJustReleased*[A: enum](action: A): bool =
  withEngine(proc(engine: var Engine): bool = engine.input.actionJustReleased(action))

proc mousePos*(): Vec2 = withEngine(proc(engine: var Engine): Vec2 = engine.input.mousePosition)
proc mouseScroll*(): Vec2 = withEngine(proc(engine: var Engine): Vec2 = engine.input.scrollDelta)
proc textInput*(): string = withEngine(proc(engine: var Engine): string = engine.input.textInput)
proc mouseDown*(button: MouseButton): bool =
  withEngine(proc(engine: var Engine): bool = engine.input.down(mouse(button)))
proc mouseJustPressed*(button: MouseButton): bool =
  withEngine(proc(engine: var Engine): bool = engine.input.justPressed(mouse(button)))
proc mouseJustReleased*(button: MouseButton): bool =
  withEngine(proc(engine: var Engine): bool = engine.input.justReleased(mouse(button)))

proc setGamepadDeadzone*(deadzone: float32) =
  discard withEngine(proc(engine: var Engine): bool = engine.input.setGamepadDeadzone(deadzone); true)

proc gamepadDeadzone*(): float32 =
  withEngine(proc(engine: var Engine): float32 = engine.input.gamepadDeadzone)

proc connectedGamepads*(): seq[int32] =
  withEngine(proc(engine: var Engine): seq[int32] = engine.input.connectedGamepads())

proc gamepadButtonDown*(button: GamepadButton, gamepad = AnyGamepad): bool =
  withEngine(proc(engine: var Engine): bool = engine.input.gamepadButtonDown(button, gamepad))

proc gamepadButtonJustPressed*(button: GamepadButton, gamepad = AnyGamepad): bool =
  withEngine(proc(engine: var Engine): bool = engine.input.gamepadButtonJustPressed(button, gamepad))

proc gamepadButtonJustReleased*(button: GamepadButton, gamepad = AnyGamepad): bool =
  withEngine(proc(engine: var Engine): bool = engine.input.gamepadButtonJustReleased(button, gamepad))

proc gamepadAxisValue*(axis: GamepadAxis, gamepad = AnyGamepad): float32 =
  withEngine(proc(engine: var Engine): float32 = engine.input.gamepadAxisValue(axis, gamepad))

proc draw*(sprite: Sprite, transform: Transform) =
  discard withEngine(proc(engine: var Engine): bool = engine.recorder.draw(sprite, transform); true)

proc draw*(map: Map, offset = Vec2Zero, z = 0'f32) =
  discard withEngine(proc(engine: var Engine): bool = engine.recorder.draw(map, offset, z); true)

proc drawRect*(color: Color, size: Vec2, transform: Transform, anchor = vec2(0.5, 0.5)) =
  discard withEngine(proc(engine: var Engine): bool = engine.recorder.drawRect(color, size, transform, anchor); true)

proc drawLine*(start, stop: Vec2, thickness: float32, color: Color, z = 0'f32) =
  discard withEngine(proc(engine: var Engine): bool = engine.recorder.drawLine(start, stop, thickness, color, z); true)

proc drawLineEx*(line: Line, z: float32, pattern: LinePattern, offset = 0'f32) =
  discard withEngine(proc(engine: var Engine): bool =
    engine.recorder.drawLineEx(line, z, pattern, offset)
    true
  )

proc drawLines*(lines: openArray[Line], z = 0'f32) =
  let copy = @lines
  discard withEngine(proc(engine: var Engine): bool =
    engine.recorder.drawLines(copy, z)
    true
  )

proc drawCircle*(center: Vec3, radius: float32, color: Color) =
  discard withEngine(proc(engine: var Engine): bool = engine.recorder.drawCircle(center, radius, color); true)

proc drawText*(text: Text, transform: Transform, anchor = vec2(0.5, 0.5)) =
  discard withEngine(proc(engine: var Engine): bool = engine.recorder.drawText(text, transform, anchor); true)

proc drawTextLayout*(layout: LaidOutText, transform: Transform, anchor = vec2(0.5, 0.5)) =
  discard withEngine(proc(engine: var Engine): bool = engine.recorder.drawTextLayout(layout, transform, anchor); true)

proc drawPoly*(center: Vec3, sides: uint32, radius, rotation: float32, color: Color) =
  discard withEngine(proc(engine: var Engine): bool = engine.recorder.drawPoly(center, sides, radius, rotation, color); true)

proc drawPolyLines*(center: Vec3, sides: uint32, radius, rotation, thickness: float32, color: Color) =
  discard withEngine(proc(engine: var Engine): bool = engine.recorder.drawPolyLines(center, sides, radius, rotation, thickness, color); true)

proc withUi*[T](body: proc(): T): T =
  withEngine(proc(engine: var Engine): T =
    let previous = engine.recorder.pushSpace(dsUi)
    try:
      result = body()
    finally:
      engine.recorder.popSpace(previous)
  )

proc imgui*(layer: ImGuiLayer) =
  discard withEngine(proc(engine: var Engine): bool = engine.imgui.addLayer(layer); true)

proc setImguiFont*(font: Handle[Font]) =
  discard withEngine(proc(engine: var Engine): bool =
    engine.imgui.font = font
    true
  )

proc uiRectToWorld(rect: Rect, view: Vec2): Rect =
  let minWorld = vec2(-view.x * 0.5'f32 + rect.min.x,
                      view.y * 0.5'f32 - rect.max.y)
  let maxWorld = vec2(-view.x * 0.5'f32 + rect.max.x,
                      view.y * 0.5'f32 - rect.min.y)
  rect(minWorld, maxWorld)

proc uiPosToWorld(pos: Vec2, view: Vec2): Vec2 =
  vec2(-view.x * 0.5'f32 + pos.x, view.y * 0.5'f32 - pos.y)

proc imguiTextValue(engine: Engine, content: string, size: float32,
                    color: Color): Text =
  result = text(content, size, color)
  if engine.imgui.font.isValid:
    result = result.withFont(engine.imgui.font)

proc drawUiText(engine: var Engine, content: string, uiPos: Vec2,
                size: float32, color: Color, z: float32) =
  let value = engine.imguiTextValue(content, size, color)
  engine.recorder.drawText(value, transform(uiPos.uiPosToWorld(engine.viewSize).extend(z)),
                           vec2(0, 1))

proc drawUiTextWorld(engine: var Engine, content: string, worldPos: Vec2,
                     size: float32, color: Color, z: float32,
                     anchor = vec2(0, 0.5)) =
  engine.recorder.drawText(engine.imguiTextValue(content, size, color),
                           transform(worldPos.extend(z)), anchor)

proc imguiBegin*(title: string, pos = vec2(16, 16), width = 280'f32,
                 height = 220'f32): bool =
  withEngine(proc(engine: var Engine): bool =
    let previous = engine.recorder.pushSpace(dsUi)
    defer: engine.recorder.popSpace(previous)
    engine.imgui.beginWindow(pos, width, height)
    let panel = rect(pos, pos + vec2(width, height))
    let world = uiRectToWorld(panel, engine.viewSize)
    if world.contains(engine.input.mousePosition):
      engine.imgui.capturePointer()
    engine.recorder.drawRect(rgba(0.08, 0.09, 0.11, 0.94), world.size,
                             transform(world.center.extend(820)))
    engine.drawUiText(title, pos + vec2(10, 10), 16, Yellow, 821)
    true
  )

proc imguiBeginPanel*(pos = vec2(16, 16), width = 280'f32, height = 220'f32,
                      background = rgba(0.08, 0.09, 0.11, 0.94)): bool =
  withEngine(proc(engine: var Engine): bool =
    let previous = engine.recorder.pushSpace(dsUi)
    defer: engine.recorder.popSpace(previous)
    engine.imgui.beginPanel(pos, width, height)
    let panel = rect(pos, pos + vec2(width, height))
    let world = uiRectToWorld(panel, engine.viewSize)
    if world.contains(engine.input.mousePosition):
      engine.imgui.capturePointer()
    engine.recorder.drawRect(background, world.size, transform(world.center.extend(820)))
    true
  )

proc imguiEnd*() =
  discard withEngine(proc(engine: var Engine): bool = engine.imgui.endWindow(); true)

proc imguiText*(content: string) =
  discard withEngine(proc(engine: var Engine): bool =
    let previous = engine.recorder.pushSpace(dsUi)
    defer: engine.recorder.popSpace(previous)
    let item = engine.imgui.nextItemRect(20)
    engine.drawUiText(content, item.min, 14, White, 822)
    true
  )

proc imguiSeparator*() =
  discard withEngine(proc(engine: var Engine): bool =
    let previous = engine.recorder.pushSpace(dsUi)
    defer: engine.recorder.popSpace(previous)
    let item = engine.imgui.nextItemRect(10)
    let world = uiRectToWorld(rect(vec2(item.min.x, item.min.y + 4),
                                   vec2(item.max.x, item.min.y + 6)),
                              engine.viewSize)
    engine.recorder.drawRect(rgba(0.35, 0.37, 0.42, 1), world.size,
                             transform(world.center.extend(822)))
    true
  )

proc imguiButton*(label: string, width = 0'f32): bool =
  withEngine(proc(engine: var Engine): bool =
    let previous = engine.recorder.pushSpace(dsUi)
    defer: engine.recorder.popSpace(previous)
    let item = engine.imgui.nextItemRect(28, width)
    let world = uiRectToWorld(item, engine.viewSize)
    let hover = world.contains(engine.input.mousePosition)
    if hover:
      engine.imgui.capturePointer()
    let pressed = hover and engine.input.justPressed(mouse(mbLeft))
    engine.recorder.drawRect(if hover: rgba(0.25, 0.42, 0.85, 0.95) else: rgba(0.18, 0.26, 0.48, 0.95),
                             world.size, transform(world.center.extend(822)))
    engine.drawUiTextWorld(label, world.center, 14, White, 823, vec2(0.5, 0.5))
    pressed
  )

proc imguiSameLine*(spacing = 6'f32) =
  discard withEngine(proc(engine: var Engine): bool =
    engine.imgui.sameLine(spacing)
    true
  )

proc imguiSpacing*(height = 6'f32) =
  discard withEngine(proc(engine: var Engine): bool =
    engine.imgui.spacing(height)
    true
  )

proc imguiCheckbox*(label: string, value: var bool): bool =
  let engine = activeEngine()
  let previous = engine[].recorder.pushSpace(dsUi)
  defer: engine[].recorder.popSpace(previous)
  let item = engine[].imgui.nextItemRect(24)
  let boxUi = rect(item.min, item.min + vec2(18, 18))
  let boxWorld = uiRectToWorld(boxUi, engine[].viewSize)
  let itemWorld = uiRectToWorld(item, engine[].viewSize)
  let hover = itemWorld.contains(engine[].input.mousePosition)
  if hover:
    engine[].imgui.capturePointer()
  if hover and engine[].input.justPressed(mouse(mbLeft)):
    value = not value
    result = true
  engine[].recorder.drawRect(if value: Green else: rgba(0.2, 0.22, 0.25, 1),
                             boxWorld.size, transform(boxWorld.center.extend(822)))
  let labelPos = vec2(boxWorld.max.x + 8, boxWorld.center.y)
  engine[].drawUiTextWorld(label, labelPos, 14, White, 823)

proc imguiRadioButton*(label: string, active: bool): bool =
  let engine = activeEngine()
  let previous = engine[].recorder.pushSpace(dsUi)
  defer: engine[].recorder.popSpace(previous)
  let item = engine[].imgui.nextItemRect(24)
  let boxUi = rect(item.min, item.min + vec2(18, 18))
  let boxWorld = uiRectToWorld(boxUi, engine[].viewSize)
  let itemWorld = uiRectToWorld(item, engine[].viewSize)
  let hover = itemWorld.contains(engine[].input.mousePosition)
  if hover:
    engine[].imgui.capturePointer()
  result = hover and engine[].input.justPressed(mouse(mbLeft))
  engine[].recorder.drawRect(rgba(0.2, 0.22, 0.25, 1), boxWorld.size,
                             transform(boxWorld.center.extend(822)))
  if active:
    engine[].recorder.drawRect(Yellow, boxWorld.size * 0.5'f32,
                               transform(boxWorld.center.extend(823)))
  let labelPos = vec2(boxWorld.max.x + 8, boxWorld.center.y)
  engine[].drawUiTextWorld(label, labelPos, 14, White, 823)

proc imguiRadioValue*(label: string, value: var int, option: int): bool =
  result = imguiRadioButton(label, value == option)
  if result:
    value = option

proc imguiCombo*(label: string, current: var int, items: openArray[string]): bool =
  let engine = activeEngine()
  let previous = engine[].recorder.pushSpace(dsUi)
  defer: engine[].recorder.popSpace(previous)
  let item = engine[].imgui.nextItemRect(30)
  let world = uiRectToWorld(item, engine[].viewSize)
  let hover = world.contains(engine[].input.mousePosition)
  if hover:
    engine[].imgui.capturePointer()
  if items.len > 0:
    current = clamp(current, 0, items.len - 1)
  if hover and engine[].input.justPressed(mouse(mbLeft)) and items.len > 0:
    current = (current + 1) mod items.len
    result = true
  engine[].recorder.drawRect(if hover: rgba(0.22, 0.27, 0.34, 1) else: rgba(0.16, 0.18, 0.22, 1),
                             world.size, transform(world.center.extend(822)))
  let value = if items.len == 0: "" else: items[current]
  engine[].drawUiTextWorld(label & ": " & value, vec2(world.min.x + 8, world.center.y),
                           14, White, 823)

proc imguiDragInt*(label: string, value: var int, step = 1): bool =
  let engine = activeEngine()
  let previous = engine[].recorder.pushSpace(dsUi)
  defer: engine[].recorder.popSpace(previous)
  let item = engine[].imgui.nextItemRect(28)
  let world = uiRectToWorld(item, engine[].viewSize)
  let hover = world.contains(engine[].input.mousePosition)
  if hover:
    engine[].imgui.capturePointer()
  if hover and engine[].input.justPressed(mouse(mbLeft)):
    if engine[].input.down(key(kcLeftShift)) or engine[].input.down(key(kcRightShift)):
      value -= step
    else:
      value += step
    result = true
  engine[].recorder.drawRect(if hover: rgba(0.22, 0.27, 0.34, 1) else: rgba(0.16, 0.18, 0.22, 1),
                             world.size, transform(world.center.extend(822)))
  engine[].drawUiTextWorld(label & ": " & $value, vec2(world.min.x + 8, world.center.y),
                           14, White, 823)

proc appendInputText(engine: ptr Engine, value: var string, maxLen: int): bool =
  if engine[].input.textInput.len > 0:
    if value.len >= maxLen:
      return false
    let room = maxLen - value.len
    if engine[].input.textInput.len <= room:
      value.add engine[].input.textInput
      return true
    return false

  if value.len >= maxLen:
    return false
  let shifted = engine[].input.down(key(kcLeftShift)) or engine[].input.down(key(kcRightShift))
  for code in kcA..kcZ:
    if engine[].input.justPressed(key(code)):
      var c = char(ord('a') + ord(code) - ord(kcA))
      if shifted:
        c = char(ord('A') + ord(code) - ord(kcA))
      value.add c
      return true
  for code in kcDigit0..kcDigit9:
    if engine[].input.justPressed(key(code)):
      value.add char(ord('0') + ord(code) - ord(kcDigit0))
      return true
  if engine[].input.justPressed(key(kcSpace)):
    value.add ' '
    return true
  false

proc imguiInputText*(label: string, value: var string, maxLen = 256): bool =
  let engine = activeEngine()
  let previous = engine[].recorder.pushSpace(dsUi)
  defer: engine[].recorder.popSpace(previous)
  let item = engine[].imgui.nextItemRect(46)
  let itemWorld = uiRectToWorld(item, engine[].viewSize)
  let boxUi = rect(vec2(item.min.x, item.min.y + 18), item.max)
  let boxWorld = uiRectToWorld(boxUi, engine[].viewSize)
  let hover = itemWorld.contains(engine[].input.mousePosition)
  let id = "input:" & label
  if hover:
    engine[].imgui.capturePointer()
  if engine[].input.justPressed(mouse(mbLeft)):
    if hover:
      engine[].imgui.focusText(id)
    elif engine[].imgui.textFocused(id):
      engine[].imgui.clearTextFocus()
  let focused = engine[].imgui.textFocused(id)
  if focused:
    engine[].imgui.captureKeyboard()
    if engine[].input.justPressed(key(kcBackspace)) and value.len > 0:
      value.setLen(value.len - 1)
      result = true
    if appendInputText(engine, value, maxLen):
      result = true
  engine[].recorder.drawRect(if focused: rgba(0.18, 0.26, 0.42, 1) elif hover: rgba(0.2, 0.22, 0.26, 1) else: rgba(0.14, 0.15, 0.18, 1),
                             boxWorld.size, transform(boxWorld.center.extend(822)))
  engine[].drawUiText(label, item.min, 13, White, 823)
  let caret = if focused and (frame() mod 60 < 30): "|" else: ""
  engine[].drawUiText(value & caret, boxUi.min + vec2(6, 6), 14, White, 823)

proc imguiInputTextMultiline*(label: string, value: var string, rows = 4,
                              maxLen = 1024): bool =
  let engine = activeEngine()
  let previous = engine[].recorder.pushSpace(dsUi)
  defer: engine[].recorder.popSpace(previous)
  let item = engine[].imgui.nextItemRect(max(68'f32, rows.float32 * 24'f32 + 24'f32))
  let itemWorld = uiRectToWorld(item, engine[].viewSize)
  let boxUi = rect(vec2(item.min.x, item.min.y + 18), item.max)
  let boxWorld = uiRectToWorld(boxUi, engine[].viewSize)
  let hover = itemWorld.contains(engine[].input.mousePosition)
  let id = "multiline:" & label
  if hover:
    engine[].imgui.capturePointer()
  if engine[].input.justPressed(mouse(mbLeft)):
    if hover:
      engine[].imgui.focusText(id)
    elif engine[].imgui.textFocused(id):
      engine[].imgui.clearTextFocus()
  let focused = engine[].imgui.textFocused(id)
  if focused:
    engine[].imgui.captureKeyboard()
    if engine[].input.justPressed(key(kcEnter)) and value.len < maxLen:
      value.add '\n'
      result = true
    if engine[].input.justPressed(key(kcBackspace)) and value.len > 0:
      value.setLen(value.len - 1)
      result = true
    if appendInputText(engine, value, maxLen):
      result = true
  engine[].recorder.drawRect(if focused: rgba(0.18, 0.26, 0.42, 1) elif hover: rgba(0.2, 0.22, 0.26, 1) else: rgba(0.14, 0.15, 0.18, 1),
                             boxWorld.size, transform(boxWorld.center.extend(822)))
  engine[].drawUiText(label, item.min, 13, White, 823)
  engine[].drawUiText(value, boxUi.min + vec2(6, 6), 14, White, 823)

proc imguiCollapsingHeader*(label: string, open: var bool): bool =
  let engine = activeEngine()
  let previous = engine[].recorder.pushSpace(dsUi)
  defer: engine[].recorder.popSpace(previous)
  let item = engine[].imgui.nextItemRect(28)
  let world = uiRectToWorld(item, engine[].viewSize)
  let hover = world.contains(engine[].input.mousePosition)
  if hover:
    engine[].imgui.capturePointer()
  if hover and engine[].input.justPressed(mouse(mbLeft)):
    open = not open
    engine[].imgui.setHeaderOpen(label, open)
    result = true
  else:
    open = engine[].imgui.headerOpen(label, open)
  engine[].recorder.drawRect(if hover: rgba(0.22, 0.27, 0.34, 1) else: rgba(0.16, 0.18, 0.22, 1),
                             world.size, transform(world.center.extend(822)))
  engine[].drawUiTextWorld((if open: "v " else: "> ") & label,
                           vec2(world.min.x + 8, world.center.y), 14, White, 823)

proc imguiCollapsingHeader*(label: string, defaultOpen = false): bool =
  var open = defaultOpen
  discard imguiCollapsingHeader(label, open)
  open

proc imguiIndent*(width = 18'f32) =
  discard withEngine(proc(engine: var Engine): bool = engine.imgui.indent(width); true)

proc imguiUnindent*(width = 18'f32) =
  discard withEngine(proc(engine: var Engine): bool = engine.imgui.unindent(width); true)

proc imguiSliderFloat*(label: string, value: var float32, minValue, maxValue: float32): bool =
  let engine = activeEngine()
  let previous = engine[].recorder.pushSpace(dsUi)
  defer: engine[].recorder.popSpace(previous)
  let item = engine[].imgui.nextItemRect(42)
  value = clamp(value, minValue, maxValue)
  engine[].drawUiText(label & ": " & value.formatFloat(ffDecimal, 2),
                      item.min, 13, White, 823)
  let trackUi = rect(vec2(item.min.x, item.min.y + 26), vec2(item.max.x, item.min.y + 34))
  let trackWorld = uiRectToWorld(trackUi, engine[].viewSize)
  engine[].recorder.drawRect(rgba(0.2, 0.22, 0.25, 1), trackWorld.size,
                             transform(trackWorld.center.extend(822)))
  let denom = maxValue - minValue
  let t = if denom == 0'f32: 0'f32 else: clamp((value - minValue) / denom, 0, 1)
  let knobX = trackWorld.min.x + trackWorld.size.x * t
  engine[].recorder.drawRect(Yellow, vec2(8, 18),
                             transform(vec3(knobX, trackWorld.center.y, 823)))
  let hoverTrack = trackWorld.contains(engine[].input.mousePosition)
  if hoverTrack:
    engine[].imgui.capturePointer()
  if hoverTrack and engine[].input.down(mouse(mbLeft)):
    let nt = clamp((engine[].input.mousePosition.x - trackWorld.min.x) / trackWorld.size.x, 0, 1)
    value = minValue + (maxValue - minValue) * nt
    result = true

proc imguiColorEdit4*(label: string, value: var Color): bool =
  var r = value.r
  var g = value.g
  var b = value.b
  var a = value.a
  result = imguiSliderFloat(label & " R", r, 0, 1) or result
  result = imguiSliderFloat(label & " G", g, 0, 1) or result
  result = imguiSliderFloat(label & " B", b, 0, 1) or result
  result = imguiSliderFloat(label & " A", a, 0, 1) or result
  value = rgba(r, g, b, a)

proc imguiProgressBar*(fraction: float32, label = "") =
  discard withEngine(proc(engine: var Engine): bool =
    let previous = engine.recorder.pushSpace(dsUi)
    defer: engine.recorder.popSpace(previous)
    let item = engine.imgui.nextItemRect(24)
    let world = uiRectToWorld(item, engine.viewSize)
    let t = clamp(fraction, 0, 1)
    engine.recorder.drawRect(rgba(0.18, 0.19, 0.22, 1), world.size,
                             transform(world.center.extend(822)))
    let fillWidth = world.size.x * t
    if fillWidth > 0:
      let fill = rect(world.min, vec2(world.min.x + fillWidth, world.max.y))
      engine.recorder.drawRect(rgba(0.25, 0.62, 0.42, 1), fill.size,
                               transform(fill.center.extend(823)))
    if label.len > 0:
      engine.drawUiTextWorld(label, world.center, 13, White, 824, vec2(0.5, 0.5))
    true
  )

proc setDiagnosticsOverlay*(enabled: bool) =
  discard withEngine(proc(engine: var Engine): bool = engine.diagnostics.setEnabled(enabled); true)

proc diagnosticsOverlayEnabled*(): bool =
  withEngine(proc(engine: var Engine): bool = engine.diagnostics.enabled)

proc setDiagnosticsOverlayPosition*(position: Vec2) =
  discard withEngine(proc(engine: var Engine): bool = engine.diagnostics.setPosition(position); true)

proc diagnosticsOverlayPosition*(): Vec2 =
  withEngine(proc(engine: var Engine): Vec2 = engine.diagnostics.position)

proc setDiagnosticsOverlayRefreshInterval*(seconds: float32) =
  discard withEngine(proc(engine: var Engine): bool = engine.diagnostics.setRefreshInterval(seconds); true)

proc diagnosticsOverlayRefreshInterval*(): float32 =
  withEngine(proc(engine: var Engine): float32 = engine.diagnostics.refreshInterval)

proc particlesCreateEmitter*(config: ParticleEmitterConfig): ParticleEmitterId =
  withEngine(proc(engine: var Engine): ParticleEmitterId = engine.particles.createEmitter(config))

proc particlesSetEmitterActive*(id: ParticleEmitterId, active: bool): bool =
  withEngine(proc(engine: var Engine): bool = engine.particles.setEmitterActive(id, active))

proc particlesSetEmitterPosition*(id: ParticleEmitterId, position: Vec2): bool =
  withEngine(proc(engine: var Engine): bool = engine.particles.setEmitterPosition(id, position))

proc particlesEmit*(id: ParticleEmitterId, count: int): bool =
  withEngine(proc(engine: var Engine): bool = engine.particles.emit(id, count))

proc particlesAliveCount*(id: ParticleEmitterId): int =
  withEngine(proc(engine: var Engine): int = engine.particles.aliveCount(id))

proc particlesEmitterCount*(): int =
  withEngine(proc(engine: var Engine): int = engine.particles.emitterCount())

proc particlesRemoveEmitter*(id: ParticleEmitterId): bool =
  withEngine(proc(engine: var Engine): bool = engine.particles.removeEmitter(id))

proc particlesClear*() =
  discard withEngine(proc(engine: var Engine): bool = engine.particles.clear(); true)

proc light2dSetSettings*(settings: Light2DSettings) =
  discard withEngine(proc(engine: var Engine): bool = engine.light2d.settings = settings; true)

proc light2dSettings*(): Light2DSettings =
  withEngine(proc(engine: var Engine): Light2DSettings = engine.light2d.settings)

proc light2dSetEnabled*(enabled: bool) =
  discard withEngine(proc(engine: var Engine): bool = engine.light2d.settings.enabled = enabled; true)

proc light2dEnabled*(): bool =
  withEngine(proc(engine: var Engine): bool = engine.light2d.settings.enabled)

proc light2dAddLight*(light: Light2D): Light2DId =
  withEngine(proc(engine: var Engine): Light2DId = engine.light2d.addLight(light))

proc light2dSetLight*(id: Light2DId, light: Light2D): bool =
  withEngine(proc(engine: var Engine): bool = engine.light2d.setLight(id, light))

proc light2dAddOccluderRect*(rect: LightOccluder2DRect): LightOccluder2DId =
  withEngine(proc(engine: var Engine): LightOccluder2DId = engine.light2d.addOccluderRect(rect))

proc light2dRemoveOccluder*(id: LightOccluder2DId): bool =
  withEngine(proc(engine: var Engine): bool = engine.light2d.removeOccluder(id))

proc light2dLightCount*(): int =
  withEngine(proc(engine: var Engine): int = engine.light2d.lightCount())

proc light2dOccluderCount*(): int =
  withEngine(proc(engine: var Engine): int = engine.light2d.occluderCount())

proc light2dClear*() =
  discard withEngine(proc(engine: var Engine): bool = engine.light2d.clear(); true)

proc audioPlay*(clip: Handle[AudioClip], params = defaultAudioPlayParams()): AudioInstanceId =
  withEngine(proc(engine: var Engine): AudioInstanceId = engine.audio.play(clip, params))

proc audioPause*(id: AudioInstanceId): bool =
  withEngine(proc(engine: var Engine): bool = engine.audio.pause(id))

proc audioResume*(id: AudioInstanceId): bool =
  withEngine(proc(engine: var Engine): bool = engine.audio.resume(id))

proc audioStop*(id: AudioInstanceId): bool =
  withEngine(proc(engine: var Engine): bool = engine.audio.stop(id))

proc setAudioMasterVolume*(volume: float32) =
  discard withEngine(proc(engine: var Engine): bool = engine.audio.setMasterVolume(volume); true)

proc setAudioBusVolume*(bus: AudioBus, volume: float32) =
  discard withEngine(proc(engine: var Engine): bool = engine.audio.setBusVolume(bus, volume); true)

proc audioBusVolume*(bus: AudioBus): float32 =
  withEngine(proc(engine: var Engine): float32 = engine.audio.busVolume(bus))

proc audioInstance*(id: AudioInstanceId): AudioInstance =
  withEngine(proc(engine: var Engine): AudioInstance = engine.audio.instance(id))

proc audioInstanceCount*(): int =
  withEngine(proc(engine: var Engine): int = engine.audio.instanceCount())

proc audioActiveCount*(): int =
  withEngine(proc(engine: var Engine): int = engine.audio.activeCount())

proc physicsInsertBody*(ent: Ent, body: PhysicsBodyDesc,
                        collider: PhysicsColliderDesc): bool =
  withEngine(proc(engine: var Engine): bool = engine.physics.insertBody(ent, body, collider))

proc physicsSetBodyPose*(ent: Ent, pose: PhysicsBodyPose, resetVelocity = false): bool =
  withEngine(proc(engine: var Engine): bool = engine.physics.setBodyPose(ent, pose, resetVelocity))

proc physicsSyncedBodyPose*(ent: Ent): PhysicsBodyPose =
  withEngine(proc(engine: var Engine): PhysicsBodyPose = engine.physics.syncedBodyPose(ent))

proc physicsHasBody*(ent: Ent): bool =
  withEngine(proc(engine: var Engine): bool = engine.physics.hasBody(ent))

proc physicsRemoveBody*(ent: Ent): bool =
  withEngine(proc(engine: var Engine): bool = engine.physics.removeBody(ent))

proc physicsPointQuery*(point: Vec2, layers = physicsLayersAll()): seq[Ent] =
  withEngine(proc(engine: var Engine): seq[Ent] = engine.physics.pointQuery(point, layers))

proc physicsOverlapAabb*(bounds: Rect, layers = physicsLayersAll()): seq[Ent] =
  withEngine(proc(engine: var Engine): seq[Ent] = engine.physics.overlapAabb(bounds, layers))

proc physicsRaycast*(origin, direction: Vec2, maxDistance: float32,
                     layers = physicsLayersAll()): seq[PhysicsRaycastHit] =
  withEngine(proc(engine: var Engine): seq[PhysicsRaycastHit] =
    engine.physics.raycast(origin, direction, maxDistance, layers))

proc physicsTakeCollisionEvents*(): seq[PhysicsCollisionEvent] =
  withEngine(proc(engine: var Engine): seq[PhysicsCollisionEvent] = engine.physics.takeCollisionEvents())

proc physicsClear*() =
  discard withEngine(proc(engine: var Engine): bool = engine.physics.clear(); true)

proc spawnPrefab*(path: string, pos = vec2(0, 0), size = vec2(48, 48),
                  color = Yellow): Ent =
  withEngine(proc(engine: var Engine): Ent = engine.prefabs.spawnPrefab(path, pos, size, color))

proc spawnPrefabWith*(path: string, patchOps: openArray[PrefabPatchOp],
                      pos = vec2(0, 0), size = vec2(48, 48),
                      color = Yellow): Ent =
  let ops = @patchOps
  withEngine(proc(engine: var Engine): Ent =
    engine.prefabs.spawnPrefabWith(path, ops, pos, size, color))

proc preloadPrefab*(path: string): bool =
  withEngine(proc(engine: var Engine): bool = engine.prefabs.loadPrefabTemplate(path))

proc removePrefab*(ent: Ent): bool =
  withEngine(proc(engine: var Engine): bool = engine.prefabs.removePrefab(ent))

proc prefabTag*(ent: Ent): string =
  withEngine(proc(engine: var Engine): string = engine.prefabs.prefabTag(ent))

proc prefabInstance*(ent: Ent): PrefabInstance =
  withEngine(proc(engine: var Engine): PrefabInstance = engine.prefabs.prefabInstance(ent))

proc prefabInstanceCount*(): int =
  withEngine(proc(engine: var Engine): int = engine.prefabs.prefabInstanceCount())

proc setPrefabPose*(ent: Ent, pos: Vec2): bool =
  withEngine(proc(engine: var Engine): bool = engine.prefabs.setPrefabPose(ent, pos))

proc drawPrefab*(ent: Ent): bool =
  withEngine(proc(engine: var Engine): bool = engine.prefabs.drawPrefab(ent, engine.recorder))

proc clearPrefabs*() =
  discard withEngine(proc(engine: var Engine): bool = engine.prefabs.clear(); true)

proc loadAtlas*(name: string): AtlasHandle =
  withEngine(proc(engine: var Engine): AtlasHandle = engine.atlas.loadAtlas(name))

proc atlasClip*(atlas: AtlasHandle, clip: string): seq[FrameId] =
  withEngine(proc(engine: var Engine): seq[FrameId] = engine.atlas.atlasClip(atlas, clip))

proc atlasFrameId*(atlas: AtlasHandle, frame: string): FrameId =
  withEngine(proc(engine: var Engine): FrameId = engine.atlas.atlasFrameId(atlas, frame))

proc atlasFrame*(atlas: AtlasHandle, frame: FrameId): AtlasFrame =
  withEngine(proc(engine: var Engine): AtlasFrame = engine.atlas.atlasFrame(atlas, frame))

proc drawAtlasFrame*(atlas: AtlasHandle, frame: FrameId, transform: Transform,
                     tint = White): bool =
  withEngine(proc(engine: var Engine): bool =
    engine.atlas.drawAtlasFrame(atlas, frame, transform, tint, engine.recorder))
