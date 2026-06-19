import std/[algorithm, math as stdmath, strutils, tables]
import pkg/sdl3
import ../[assets, color, draw, engine, facade, image, input, math, scene, transform]
import ./[sdlaudio, sdlimage, sdlttf]

when defined(nimaUseNativeImgui):
  import ../imgui_native as nativeimgui

type
  SdlPresentation* = enum
    spDisabled, spStretch, spLetterbox, spOverscan, spIntegerScale

  SdlBackendError* = object of CatchableError

  TextureCache = Table[uint32, SDL_Texture]

  TextTexture = object
    texture: SDL_Texture
    width: float32
    height: float32

  TextTextureCache = Table[string, TextTexture]
  GlyphTexture = object
    texture: SDL_Texture
    generation: uint32

  GlyphTextureCache = Table[string, GlyphTexture]

  SdlGamepads = Table[SDL_JoystickID, SDL_Gamepad]

  SdlRendererRuntime = ref object
    window: SDL_Window
    renderer: SDL_Renderer
    engine: Engine
    textureCache: TextureCache
    textCache: TextTextureCache
    glyphCache: GlyphTextureCache
    imageLoader: SdlImageState
    ttf: SdlTtfState
    sdlAudio: SdlAudioState
    gamepads: SdlGamepads
    lastTicks: uint64
    vsync: bool

when defined(emscripten):
  proc emscriptenSetMainLoop(callback: proc() {.cdecl.}, fps: cint,
                             simulateInfiniteLoop: bool) {.importc: "emscripten_set_main_loop".}
  proc emscriptenCancelMainLoop() {.importc: "emscripten_cancel_main_loop".}

  var emscriptenRuntime: SdlRendererRuntime

proc sdlError(message: string): ref SdlBackendError =
  let detail = $SDL_GetError()
  if detail.len > 0:
    newException(SdlBackendError, message & ": " & detail)
  else:
    newException(SdlBackendError, message)

proc checkSdl(ok: bool, message: string) =
  if not ok:
    raise sdlError(message)

proc toSdlPresentation(mode: SdlPresentation): SDL_RendererLogicalPresentation =
  case mode
  of spDisabled: SDL_LOGICAL_PRESENTATION_DISABLED
  of spStretch: SDL_LOGICAL_PRESENTATION_STRETCH
  of spLetterbox: SDL_LOGICAL_PRESENTATION_LETTERBOX
  of spOverscan: SDL_LOGICAL_PRESENTATION_OVERSCAN
  of spIntegerScale: SDL_LOGICAL_PRESENTATION_INTEGER_SCALE

proc toKeyCode(scancode: SDL_Scancode): KeyCode =
  case scancode
  of SDL_SCANCODE_A: kcA
  of SDL_SCANCODE_B: kcB
  of SDL_SCANCODE_C: kcC
  of SDL_SCANCODE_D: kcD
  of SDL_SCANCODE_E: kcE
  of SDL_SCANCODE_F: kcF
  of SDL_SCANCODE_G: kcG
  of SDL_SCANCODE_H: kcH
  of SDL_SCANCODE_I: kcI
  of SDL_SCANCODE_J: kcJ
  of SDL_SCANCODE_K: kcK
  of SDL_SCANCODE_L: kcL
  of SDL_SCANCODE_M: kcM
  of SDL_SCANCODE_N: kcN
  of SDL_SCANCODE_O: kcO
  of SDL_SCANCODE_P: kcP
  of SDL_SCANCODE_Q: kcQ
  of SDL_SCANCODE_R: kcR
  of SDL_SCANCODE_S: kcS
  of SDL_SCANCODE_T: kcT
  of SDL_SCANCODE_U: kcU
  of SDL_SCANCODE_V: kcV
  of SDL_SCANCODE_W: kcW
  of SDL_SCANCODE_X: kcX
  of SDL_SCANCODE_Y: kcY
  of SDL_SCANCODE_Z: kcZ
  of SDL_SCANCODE_0: kcDigit0
  of SDL_SCANCODE_1: kcDigit1
  of SDL_SCANCODE_2: kcDigit2
  of SDL_SCANCODE_3: kcDigit3
  of SDL_SCANCODE_4: kcDigit4
  of SDL_SCANCODE_5: kcDigit5
  of SDL_SCANCODE_6: kcDigit6
  of SDL_SCANCODE_7: kcDigit7
  of SDL_SCANCODE_8: kcDigit8
  of SDL_SCANCODE_9: kcDigit9
  of SDL_SCANCODE_ESCAPE: kcEscape
  of SDL_SCANCODE_SPACE: kcSpace
  of SDL_SCANCODE_RETURN: kcEnter
  of SDL_SCANCODE_BACKSPACE: kcBackspace
  of SDL_SCANCODE_TAB: kcTab
  of SDL_SCANCODE_LEFT: kcLeft
  of SDL_SCANCODE_RIGHT: kcRight
  of SDL_SCANCODE_UP: kcUp
  of SDL_SCANCODE_DOWN: kcDown
  of SDL_SCANCODE_LSHIFT: kcLeftShift
  of SDL_SCANCODE_LCTRL: kcLeftCtrl
  of SDL_SCANCODE_LALT: kcLeftAlt
  of SDL_SCANCODE_RSHIFT: kcRightShift
  of SDL_SCANCODE_RCTRL: kcRightCtrl
  of SDL_SCANCODE_RALT: kcRightAlt
  else: kcInvalid

proc toMouseButton(button: uint8): MouseButton =
  case int(button)
  of SDL_BUTTON_LEFT: mbLeft
  of SDL_BUTTON_MIDDLE: mbMiddle
  of SDL_BUTTON_RIGHT: mbRight
  of SDL_BUTTON_X1: mbBack
  of SDL_BUTTON_X2: mbForward
  else: mbLeft

proc isKnownMouseButton(button: uint8): bool =
  case int(button)
  of SDL_BUTTON_LEFT, SDL_BUTTON_MIDDLE, SDL_BUTTON_RIGHT, SDL_BUTTON_X1, SDL_BUTTON_X2: true
  else: false

proc toGamepadButton(button: uint8): GamepadButton =
  case SDL_GamepadButton(button.cint)
  of SDL_GAMEPAD_BUTTON_SOUTH: gpbSouth
  of SDL_GAMEPAD_BUTTON_EAST: gpbEast
  of SDL_GAMEPAD_BUTTON_WEST: gpbWest
  of SDL_GAMEPAD_BUTTON_NORTH: gpbNorth
  of SDL_GAMEPAD_BUTTON_BACK: gpbBack
  of SDL_GAMEPAD_BUTTON_GUIDE: gpbGuide
  of SDL_GAMEPAD_BUTTON_START: gpbStart
  of SDL_GAMEPAD_BUTTON_LEFT_STICK: gpbLeftStick
  of SDL_GAMEPAD_BUTTON_RIGHT_STICK: gpbRightStick
  of SDL_GAMEPAD_BUTTON_LEFT_SHOULDER: gpbLeftShoulder
  of SDL_GAMEPAD_BUTTON_RIGHT_SHOULDER: gpbRightShoulder
  of SDL_GAMEPAD_BUTTON_DPAD_UP: gpbDpadUp
  of SDL_GAMEPAD_BUTTON_DPAD_DOWN: gpbDpadDown
  of SDL_GAMEPAD_BUTTON_DPAD_LEFT: gpbDpadLeft
  of SDL_GAMEPAD_BUTTON_DPAD_RIGHT: gpbDpadRight
  of SDL_GAMEPAD_BUTTON_MISC1: gpbMisc1
  of SDL_GAMEPAD_BUTTON_RIGHT_PADDLE1: gpbRightPaddle1
  of SDL_GAMEPAD_BUTTON_LEFT_PADDLE1: gpbLeftPaddle1
  of SDL_GAMEPAD_BUTTON_RIGHT_PADDLE2: gpbRightPaddle2
  of SDL_GAMEPAD_BUTTON_LEFT_PADDLE2: gpbLeftPaddle2
  of SDL_GAMEPAD_BUTTON_TOUCHPAD: gpbTouchpad
  else: gpbInvalid

proc toGamepadAxis(axis: uint8): GamepadAxis =
  case SDL_GamepadAxis(axis.cint)
  of SDL_GAMEPAD_AXIS_LEFTX: gpaLeftX
  of SDL_GAMEPAD_AXIS_LEFTY: gpaLeftY
  of SDL_GAMEPAD_AXIS_RIGHTX: gpaRightX
  of SDL_GAMEPAD_AXIS_RIGHTY: gpaRightY
  of SDL_GAMEPAD_AXIS_LEFT_TRIGGER: gpaLeftTrigger
  of SDL_GAMEPAD_AXIS_RIGHT_TRIGGER: gpaRightTrigger
  else: gpaInvalid

proc normalizeGamepadAxis(value: int16): float32 =
  if value < 0:
    max(-1'f32, value.float32 / 32768'f32)
  else:
    min(1'f32, value.float32 / 32767'f32)

proc openGamepad(gamepads: var SdlGamepads, input: var InputState,
                 id: SDL_JoystickID) =
  if gamepads.hasKey(id) or not SDL_IsGamepad(id):
    return
  let pad = SDL_OpenGamepad(id)
  if pad.isNil:
    return
  gamepads[id] = pad
  input.setGamepadConnected(id.int32, true)
  let name = SDL_GetGamepadName(pad)
  if name.isNil:
    echo "[Nima] SDL gamepad ", $id, " connected"
  else:
    echo "[Nima] SDL gamepad ", $id, " connected: ", $name

proc openExistingGamepads(gamepads: var SdlGamepads, input: var InputState) =
  var count: cint
  let ids = SDL_GetGamepads(count)
  if ids.isNil:
    return
  defer: SDL_free(cast[pointer](ids))
  for i in 0..<count.int:
    gamepads.openGamepad(input, ids[i])

proc closeGamepad(gamepads: var SdlGamepads, input: var InputState,
                  id: SDL_JoystickID) =
  if gamepads.hasKey(id):
    let pad = gamepads[id]
    if not pad.isNil:
      SDL_CloseGamepad(pad)
    gamepads.del id
  input.setGamepadConnected(id.int32, false)

proc closeGamepads(gamepads: var SdlGamepads, input: var InputState) =
  var ids: seq[SDL_JoystickID]
  for id in gamepads.keys:
    ids.add id
  for id in ids:
    gamepads.closeGamepad(input, id)

proc renderToWorld(x, y: cfloat, view: Vec2): Vec2 =
  vec2(x.float32 - view.x * 0.5'f32, view.y * 0.5'f32 - y.float32)

proc project(pos: Vec2, command: DrawCommand, engine: Engine): Vec2 =
  case command.space
  of dsWorld: (pos - engine.cameraPos) * engine.cameraZoom
  of dsUi: pos

proc projectSize(size: Vec2, command: DrawCommand, engine: Engine): Vec2 =
  case command.space
  of dsWorld: size * engine.cameraZoom
  of dsUi: size

proc projectBounds(bounds: Rect, command: DrawCommand, engine: Engine): Rect =
  let c = project(bounds.center, command, engine)
  let s = projectSize(bounds.size, command, engine)
  rect(c - s * 0.5'f32, c + s * 0.5'f32)

proc worldToRender(pos: Vec2, view: Vec2): SDL_FPoint =
  SDL_FPoint(x: (pos.x + view.x * 0.5'f32).cfloat,
             y: (view.y * 0.5'f32 - pos.y).cfloat)

proc rectToRender(bounds: Rect, view: Vec2): SDL_FRect =
  SDL_FRect(
    x: (bounds.min.x + view.x * 0.5'f32).cfloat,
    y: (view.y * 0.5'f32 - bounds.max.y).cfloat,
    w: (bounds.max.x - bounds.min.x).cfloat,
    h: (bounds.max.y - bounds.min.y).cfloat
  )

proc rectToSdl(rect: Rect): SDL_FRect =
  SDL_FRect(x: rect.min.x.cfloat, y: rect.min.y.cfloat,
            w: rect.size.x.cfloat, h: rect.size.y.cfloat)

proc setColor(renderer: SDL_Renderer, color: Color) =
  discard SDL_SetRenderDrawColorFloat(renderer, color.r.cfloat, color.g.cfloat,
                                      color.b.cfloat, color.a.cfloat)

proc toSdlColor(color: Color): SDL_FColor =
  SDL_FColor(r: color.r.cfloat, g: color.g.cfloat, b: color.b.cfloat,
             a: color.a.cfloat)

proc isZeroAngle(angle: float32): bool =
  angle > -0.00001'f32 and angle < 0.00001'f32

proc radiansToDegrees(angle: float32): cdouble =
  (angle * 180'f32 / stdmath.PI.float32).cdouble

proc textureFromPixels(renderer: SDL_Renderer, image: var ImagePixels): SDL_Texture =
  if image.pixels.len == 0:
    return nil
  let surface = SDL_CreateSurfaceFrom(image.width.cint, image.height.cint,
                                      SDL_PIXELFORMAT_RGBA32,
                                      unsafeAddr image.pixels[0],
                                      (image.width * 4).cint)
  if surface.isNil:
    return nil
  defer: SDL_DestroySurface(surface)
  result = SDL_CreateTextureFromSurface(renderer, surface)

proc textureFor(renderer: SDL_Renderer, cache: var TextureCache,
                imageLoader: var SdlImageState,
                handle: Handle[Texture]): SDL_Texture =
  if handle.id == 0:
    return nil
  if cache.hasKey(handle.id):
    return cache[handle.id]
  let asset = textureAsset(handle)
  if asset.isNil or not asset.loaded:
    return nil
  var image: ImagePixels
  try:
    image = loadImageRgba(asset.resolvedPath)
  except ImageLoadError:
    discard
  result = textureFromPixels(renderer, image)
  if result.isNil:
    let surface = imageLoader.loadImageSurfaceRgba(asset.resolvedPath)
    if not surface.isNil:
      defer: SDL_DestroySurface(surface)
      result = SDL_CreateTextureFromSurface(renderer, surface)
  if not result.isNil:
    discard SDL_SetTextureBlendMode(result, SDL_BLENDMODE_BLEND)
    cache[handle.id] = result

proc colorKey(color: Color): uint32 =
  let bytes = color.toRgba8
  (bytes[0].uint32 shl 24) or
    (bytes[1].uint32 shl 16) or
    (bytes[2].uint32 shl 8) or
    bytes[3].uint32

proc textTextureKey(text: Text): string =
  let fontId = if text.hasFont: text.font.id else: 0'u32
  text.content & "\0" & $text.size & "\0" & $text.color.colorKey & "\0" & $fontId

proc textureFor(renderer: SDL_Renderer, cache: var TextTextureCache,
                ttf: var SdlTtfState, text: Text): TextTexture =
  if text.content.len == 0:
    return
  let key = text.textTextureKey
  if cache.hasKey(key):
    return cache[key]

  let surface = ttf.renderTextSurface(text)
  if surface.isNil:
    return
  defer: SDL_DestroySurface(surface)

  let texture = SDL_CreateTextureFromSurface(renderer, surface)
  if texture.isNil:
    return
  discard SDL_SetTextureBlendMode(texture, SDL_BLENDMODE_BLEND)
  result = TextTexture(texture: texture, width: surface.w.float32,
                       height: surface.h.float32)
  cache[key] = result

proc textureFor(renderer: SDL_Renderer, cache: var GlyphTextureCache,
                atlas: SdlGlyphAtlas): SDL_Texture =
  if atlas.isNil or atlas.surface.isNil:
    return nil
  var cached = cache.getOrDefault(atlas.key)
  let needsCreate = cached.texture.isNil
  if needsCreate:
    cached.texture = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_RGBA32,
                                       SDL_TEXTUREACCESS_STATIC,
                                       atlas.width, atlas.height)
    if cached.texture.isNil:
      return nil
    discard SDL_SetTextureBlendMode(cached.texture, SDL_BLENDMODE_BLEND)
  if needsCreate or cached.generation != atlas.generation:
    discard SDL_UpdateTexture(cached.texture, nil,
      cast[ptr uint8](atlas.surface.pixels), atlas.surface.pitch)
    cached.generation = atlas.generation
  cache[atlas.key] = cached
  cached.texture

proc updateMetrics(engine: var Engine, window: SDL_Window) =
  var w, h: cint
  if SDL_GetWindowSize(window, w, h):
    engine.screenSize = vec2(w.float32, h.float32)
  let scale = SDL_GetWindowDisplayScale(window).float32
  engine.dpiScale = if scale > 0'f32: scale else: 1'f32

proc processEvents(engine: var Engine, window: SDL_Window, renderer: SDL_Renderer,
                   gamepads: var SdlGamepads) =
  var event: SDL_Event
  while SDL_PollEvent(event):
    when defined(nimaUseNativeImgui):
      nativeimgui.nativeImguiProcessEvent(event)
    discard SDL_ConvertEventToRenderCoordinates(renderer, event)
    case event.`type`
    of SDL_EVENT_QUIT, SDL_EVENT_WINDOW_CLOSE_REQUESTED:
      engine.requestExit()
    of SDL_EVENT_WINDOW_RESIZED, SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED:
      engine.updateMetrics(window)
    of SDL_EVENT_KEY_DOWN, SDL_EVENT_KEY_UP:
      let code = toKeyCode(event.key.scancode)
      if code != kcInvalid:
        engine.input.setKeyDown(code, event.key.down)
    of SDL_EVENT_TEXT_INPUT:
      if not event.text.text.isNil:
        engine.input.addTextInput($event.text.text)
    of SDL_EVENT_MOUSE_MOTION:
      engine.input.setMousePos(renderToWorld(event.motion.x, event.motion.y, engine.viewSize))
    of SDL_EVENT_MOUSE_BUTTON_DOWN, SDL_EVENT_MOUSE_BUTTON_UP:
      if isKnownMouseButton(event.button.button):
        engine.input.setMousePos(renderToWorld(event.button.x, event.button.y, engine.viewSize))
        engine.input.setMouseDown(toMouseButton(event.button.button), event.button.down)
    of SDL_EVENT_MOUSE_WHEEL:
      var dy = event.wheel.y.float32
      if event.wheel.direction == SDL_MOUSEWHEEL_FLIPPED:
        dy = -dy
      engine.input.addScroll(vec2(event.wheel.x.float32, dy))
      engine.input.setMousePos(renderToWorld(event.wheel.mouse_x, event.wheel.mouse_y, engine.viewSize))
    of SDL_EVENT_GAMEPAD_ADDED:
      gamepads.openGamepad(engine.input, event.gdevice.which)
    of SDL_EVENT_GAMEPAD_REMOVED:
      gamepads.closeGamepad(engine.input, event.gdevice.which)
    of SDL_EVENT_GAMEPAD_BUTTON_DOWN, SDL_EVENT_GAMEPAD_BUTTON_UP:
      engine.input.setGamepadButtonDown(event.gbutton.which.int32,
        toGamepadButton(event.gbutton.button), event.gbutton.down)
    of SDL_EVENT_GAMEPAD_AXIS_MOTION:
      engine.input.setGamepadAxisValue(event.gaxis.which.int32,
        toGamepadAxis(event.gaxis.axis), normalizeGamepadAxis(event.gaxis.value))
    else:
      discard

proc drawFilledCircle(renderer: SDL_Renderer, command: DrawCommand, engine: Engine) =
  let radius = command.radius * (if command.space == dsWorld: engine.cameraZoom else: 1'f32)
  if radius <= 0'f32:
    return
  setColor(renderer, command.color)
  let c = worldToRender(project(command.center.xy, command, engine), engine.viewSize)
  let r = radius.int
  for y in -r..r:
    let yf = y.float32
    let span = stdmath.sqrt(radius * radius - yf * yf)
    discard SDL_RenderLine(renderer, c.x - span.cfloat, c.y + yf.cfloat,
                           c.x + span.cfloat, c.y + yf.cfloat)

proc drawPolyOutline(renderer: SDL_Renderer, command: DrawCommand, engine: Engine) =
  let sides = command.sides
  let radius = command.radius * (if command.space == dsWorld: engine.cameraZoom else: 1'f32)
  if sides < 3 or radius <= 0'f32:
    return
  setColor(renderer, command.color)
  var points = newSeq[SDL_FPoint](sides.int + 1)
  for i in 0..sides.int:
    let t = command.rotation + (i.float32 / sides.float32) * (2'f32 * stdmath.PI.float32)
    let c = project(command.center.xy, command, engine)
    let p = vec2(c.x + stdmath.cos(t).float32 * radius,
                 c.y + stdmath.sin(t).float32 * radius)
    points[i] = worldToRender(p, engine.viewSize)
  discard SDL_RenderLines(renderer, points)

proc drawFilledPoly(renderer: SDL_Renderer, command: DrawCommand, engine: Engine) =
  let sides = command.sides
  let radius = command.radius * (if command.space == dsWorld: engine.cameraZoom else: 1'f32)
  if sides < 3 or radius <= 0'f32:
    return
  let center = project(command.center.xy, command, engine)
  let centerPoint = worldToRender(center, engine.viewSize)
  let sdlColor = command.color.toSdlColor()
  var vertices = newSeq[SDL_Vertex](sides.int + 1)
  vertices[0] = SDL_Vertex(position: centerPoint, color: sdlColor,
                           tex_coord: SDL_FPoint(x: 0, y: 0))
  for i in 0..<sides.int:
    let t = command.rotation + (i.float32 / sides.float32) * (2'f32 * stdmath.PI.float32)
    let p = vec2(center.x + stdmath.cos(t).float32 * radius,
                 center.y + stdmath.sin(t).float32 * radius)
    vertices[i + 1] = SDL_Vertex(position: worldToRender(p, engine.viewSize), color: sdlColor,
                                 tex_coord: SDL_FPoint(x: 0, y: 0))

  var indices = newSeq[cint](sides.int * 3)
  for i in 0..<sides.int:
    indices[i * 3] = 0
    indices[i * 3 + 1] = (i + 1).cint
    indices[i * 3 + 2] = (if i == sides.int - 1: 1 else: i + 2).cint
  discard SDL_RenderGeometry(renderer, nil, vertices, indices)

proc drawFilledQuad(renderer: SDL_Renderer, command: DrawCommand, engine: Engine,
                    color: Color, size, anchor: Vec2) =
  if command.transform.angle.isZeroAngle:
    setColor(renderer, color)
    discard SDL_RenderFillRect(renderer, rectToRender(
      projectBounds(command.transform.bounds(anchor, size), command, engine),
      engine.viewSize))
    return

  let points = command.transform.corners(anchor, size)
  let sdlColor = color.toSdlColor()
  var vertices = newSeq[SDL_Vertex](4)
  for i in 0..<4:
    vertices[i] = SDL_Vertex(
      position: worldToRender(project(points[i], command, engine), engine.viewSize),
      color: sdlColor,
      tex_coord: SDL_FPoint(x: 0, y: 0)
    )
  var indices = newSeq[cint](6)
  indices[0] = 0
  indices[1] = 1
  indices[2] = 2
  indices[3] = 0
  indices[4] = 2
  indices[5] = 3
  discard SDL_RenderGeometry(renderer, nil, vertices, indices)

proc drawLineSegment(renderer: SDL_Renderer, a, b: Vec2, thickness: float32,
                     view: Vec2) =
  let pa = worldToRender(a, view)
  let pb = worldToRender(b, view)
  let dx = pb.x - pa.x
  let dy = pb.y - pa.y
  let len = stdmath.sqrt(dx * dx + dy * dy)
  if len <= 0.0001'f32:
    discard SDL_RenderPoint(renderer, pa.x, pa.y)
    return
  let nx = -dy / len
  let ny = dx / len
  let count = max(1, thickness.round.int)
  let base = (count.float32 - 1'f32) * 0.5'f32
  for i in 0..<count:
    let o = i.float32 - base
    discard SDL_RenderLine(renderer, pa.x + nx * o, pa.y + ny * o,
                           pb.x + nx * o, pb.y + ny * o)

proc drawPatternedLine(renderer: SDL_Renderer, command: DrawCommand, engine: Engine) =
  setColor(renderer, command.line.color)
  let a = project(command.line.start, command, engine)
  let b = project(command.line.stop, command, engine)
  let delta = b - a
  let len = delta.length
  if len <= 0.0001'f32:
    return
  let dir = delta / len
  case command.line.pattern.kind
  of lpkSolid:
    drawLineSegment(renderer, a, b, command.line.thickness, engine.viewSize)
  of lpkDashed, lpkDotted:
    let dash =
      case command.line.pattern.kind
      of lpkDashed: max(0.01'f32, command.line.pattern.dashLength)
      of lpkDotted: max(0.01'f32, command.line.pattern.spacing * 0.5'f32)
      else: 1'f32
    let gap =
      case command.line.pattern.kind
      of lpkDashed: max(0.01'f32, command.line.pattern.gapLength)
      of lpkDotted: max(0.01'f32, command.line.pattern.spacing * 0.5'f32)
      else: 1'f32
    let period = dash + gap
    var current = -command.line.patternOffset
    while current < len:
      let startD = max(0'f32, current)
      let endD = min(len, current + dash)
      if startD < endD:
        drawLineSegment(renderer, a + dir * startD, a + dir * endD,
                        command.line.thickness, engine.viewSize)
      current += period

proc spriteFlip(sprite: Sprite): SDL_FlipMode =
  if sprite.flipX:
    SDL_FLIP_HORIZONTAL
  elif sprite.flipY:
    SDL_FLIP_VERTICAL
  else:
    SDL_FLIP_NONE

proc drawTextTexture(renderer: SDL_Renderer, command: DrawCommand, engine: Engine,
                     textTexture: TextTexture) =
  if textTexture.texture.isNil:
    return
  let p = worldToRender(project(command.transform.pos.xy, command, engine), engine.viewSize)
  var dst = SDL_FRect(
    x: (p.x - textTexture.width * command.anchor.x).cfloat,
    y: (p.y - textTexture.height * (1'f32 - command.anchor.y)).cfloat,
    w: textTexture.width.cfloat,
    h: textTexture.height.cfloat
  )
  discard SDL_RenderTexture(renderer, textTexture.texture, nil, addr dst)

proc drawGlyphRun(renderer: SDL_Renderer, command: DrawCommand, engine: Engine,
                  ttf: var SdlTtfState, glyphCache: var GlyphTextureCache): bool =
  let run = ttf.layoutGlyphRun(command.text)
  if run.atlas.isNil:
    return false
  let texture = textureFor(renderer, glyphCache, run.atlas)
  if texture.isNil:
    return false
  discard SDL_SetTextureColorModFloat(texture, command.text.color.r.cfloat,
                                      command.text.color.g.cfloat,
                                      command.text.color.b.cfloat)
  discard SDL_SetTextureAlphaModFloat(texture, command.text.color.a.cfloat)

  let p = worldToRender(project(command.transform.pos.xy, command, engine),
                        engine.viewSize)
  let origin = vec2(p.x.float32 - run.size.x * command.anchor.x,
                    p.y.float32 - run.size.y * (1'f32 - command.anchor.y))
  for glyph in run.glyphs:
    var src = SDL_FRect(x: glyph.src.min.x.cfloat,
                        y: glyph.src.min.y.cfloat,
                        w: glyph.src.size.x.cfloat,
                        h: glyph.src.size.y.cfloat)
    let dstMin = origin + glyph.dst.min
    var dst = SDL_FRect(x: dstMin.x.cfloat,
                        y: dstMin.y.cfloat,
                        w: glyph.dst.size.x.cfloat,
                        h: glyph.dst.size.y.cfloat)
    discard SDL_RenderTexture(renderer, texture, addr src, addr dst)
  true

proc debugTextSize(content: string): Vec2 =
  let lines = content.splitLines()
  var maxChars = 0
  for line in lines:
    maxChars = max(maxChars, line.len)
  vec2(max(1, maxChars) * SDL_DEBUG_TEXT_FONT_CHARACTER_SIZE,
       max(1, lines.len) * SDL_DEBUG_TEXT_FONT_CHARACTER_SIZE)

proc drawDebugText(renderer: SDL_Renderer, command: DrawCommand, engine: Engine) =
  setColor(renderer, command.text.color)
  let p = worldToRender(project(command.transform.pos.xy, command, engine), engine.viewSize)
  let measured = debugTextSize(command.text.content)
  let x = p.x - measured.x * command.anchor.x
  let y = p.y - measured.y * (1'f32 - command.anchor.y)
  var cursorY = y
  for line in command.text.content.splitLines():
    discard SDL_RenderDebugText(renderer, x, cursorY, line.cstring)
    cursorY += SDL_DEBUG_TEXT_FONT_CHARACTER_SIZE.float32

proc drawCommand(renderer: SDL_Renderer, command: DrawCommand, engine: Engine,
                 textureCache: var TextureCache, textCache: var TextTextureCache,
                 glyphCache: var GlyphTextureCache, imageLoader: var SdlImageState,
                 ttf: var SdlTtfState) =
  case command.kind
  of dckRect:
    drawFilledQuad(renderer, command, engine, command.color, command.size, command.anchor)
  of dckSprite:
    let spriteSize = vec2(command.sprite.size.x.float32, command.sprite.size.y.float32)
    let texture = textureFor(renderer, textureCache, imageLoader,
                             command.sprite.texture)
    if texture.isNil:
      drawFilledQuad(renderer, command, engine, command.sprite.color, spriteSize,
                     command.sprite.anchor)
    else:
      discard SDL_SetTextureColorModFloat(texture, command.sprite.color.r.cfloat,
                                          command.sprite.color.g.cfloat,
                                          command.sprite.color.b.cfloat)
      discard SDL_SetTextureAlphaModFloat(texture, command.sprite.color.a.cfloat)
      var base = command.transform
      base.angle = 0
      let dst = rectToRender(projectBounds(base.bounds(command.sprite.anchor, spriteSize),
        command, engine), engine.viewSize)
      var srcRect = if command.sprite.hasSrc: command.sprite.src.rectToSdl else: SDL_FRect()
      var dstRect = dst
      let srcPtr = if command.sprite.hasSrc: addr srcRect else: nil
      var center = SDL_FPoint(x: (dstRect.w * command.sprite.anchor.x).cfloat,
                              y: (dstRect.h * (1'f32 - command.sprite.anchor.y)).cfloat)
      discard SDL_RenderTextureRotated(renderer, texture, srcPtr, addr dstRect,
                                       command.transform.angle.radiansToDegrees, addr center,
                                       command.sprite.spriteFlip)
  of dckLine:
    drawPatternedLine(renderer, command, engine)
  of dckCircle:
    drawFilledCircle(renderer, command, engine)
  of dckPoly:
    drawFilledPoly(renderer, command, engine)
  of dckPolyLines:
    drawPolyOutline(renderer, command, engine)
  of dckText:
    if not drawGlyphRun(renderer, command, engine, ttf, glyphCache):
      let cached = textureFor(renderer, textCache, ttf, command.text)
      if cached.texture.isNil:
        drawDebugText(renderer, command, engine)
      else:
        drawTextTexture(renderer, command, engine, cached)

proc renderFrame(renderer: SDL_Renderer, engine: var Engine, textureCache: var TextureCache,
                 textCache: var TextTextureCache, glyphCache: var GlyphTextureCache,
                 imageLoader: var SdlImageState, ttf: var SdlTtfState) =
  setColor(renderer, Black)
  discard SDL_RenderClear(renderer)

  var commands = engine.recorder.commands
  commands.sort(proc(a, b: DrawCommand): int =
    if a.z < b.z: -1
    elif a.z > b.z: 1
    elif a.order < b.order: -1
    elif a.order > b.order: 1
    else: 0
  )

  for command in commands:
    drawCommand(renderer, command, engine, textureCache, textCache,
                glyphCache, imageLoader, ttf)

  when defined(nimaUseNativeImgui):
    nativeimgui.renderNativeImguiSdlRenderer(renderer, engine.dpiScale)
    engine.imgui.wantsPointerInput =
      engine.imgui.wantsPointerInput or nativeimgui.nativeImguiWantsPointerInput()
    engine.imgui.wantsKeyboardInput =
      engine.imgui.wantsKeyboardInput or nativeimgui.nativeImguiWantsKeyboardInput()

  discard SDL_RenderPresent(renderer)

proc stepFrame(runtime: SdlRendererRuntime) =
  runtime.engine.processEvents(runtime.window, runtime.renderer, runtime.gamepads)
  let now = SDL_GetTicks()
  var dt = (now - runtime.lastTicks).float32 / 1000'f32
  runtime.lastTicks = now
  if dt <= 0'f32:
    dt = 1'f32 / 60'f32
  elif dt > 0.25'f32:
    dt = 0.25'f32

  runtime.engine.stepFrame(dt)
  runtime.sdlAudio.syncAudio(runtime.engine.audio)
  renderFrame(runtime.renderer, runtime.engine, runtime.textureCache,
              runtime.textCache, runtime.glyphCache, runtime.imageLoader,
              runtime.ttf)

  when not defined(emscripten):
    if not runtime.vsync:
      SDL_Delay(1)

when defined(emscripten):
  proc emscriptenFrame() {.cdecl.} =
    if emscriptenRuntime.isNil:
      emscriptenCancelMainLoop()
      return
    if emscriptenRuntime.engine.exitRequested:
      emscriptenCancelMainLoop()
      return
    discard withEngineScope(emscriptenRuntime.engine, proc(): bool =
      emscriptenRuntime.stepFrame()
      true
    )

proc shutdown(runtime: SdlRendererRuntime) =
  for _, texture in runtime.textureCache.mpairs:
    if not texture.isNil:
      SDL_DestroyTexture(texture)
  for _, texture in runtime.textCache.mpairs:
    if not texture.texture.isNil:
      SDL_DestroyTexture(texture.texture)
  for _, texture in runtime.glyphCache.mpairs:
    if not texture.texture.isNil:
      SDL_DestroyTexture(texture.texture)
  runtime.imageLoader.shutdown()
  runtime.ttf.shutdown()
  runtime.gamepads.closeGamepads(runtime.engine.input)
  runtime.sdlAudio.shutdown()
  when defined(nimaUseNativeImgui):
    nativeimgui.shutdownNativeImgui()

proc runSdl*(title: string, size: IVec2, viewSize: Vec2, presentation: SdlPresentation,
             initialScene: Scene, vsync, resizable, fullscreen, cursorVisible: bool) =
  checkSdl(SDL_Init(SDL_INIT_VIDEO or SDL_INIT_EVENTS or SDL_INIT_GAMEPAD), "SDL_Init failed")
  SDL_SetGamepadEventsEnabled(true)

  var window: SDL_Window = nil
  var renderer: SDL_Renderer = nil
  try:
    var flags = SDL_WINDOW_HIGH_PIXEL_DENSITY
    if resizable:
      flags = flags or SDL_WINDOW_RESIZABLE
    if fullscreen:
      flags = flags or SDL_WINDOW_FULLSCREEN

    window = SDL_CreateWindow(title.cstring, size.x.cint, size.y.cint, flags)
    if window.isNil:
      raise sdlError("SDL_CreateWindow failed")

    renderer = SDL_CreateRenderer(window, nil)
    if renderer.isNil:
      raise sdlError("SDL_CreateRenderer failed")

    discard SDL_SetRenderVSync(renderer, if vsync: 1 else: 0)
    discard SDL_SetRenderDrawBlendMode(renderer, SDL_BLENDMODE_BLEND)
    discard SDL_SetRenderLogicalPresentation(renderer, viewSize.x.cint, viewSize.y.cint,
                                             presentation.toSdlPresentation)
    if cursorVisible:
      discard SDL_ShowCursor()
    else:
      discard SDL_HideCursor()
    discard SDL_StartTextInput(window)

    echo "[Nima] SDL ", $SDL_GetVersion(), " video=", $SDL_GetCurrentVideoDriver(),
         " renderer=", $SDL_GetRendererName(renderer)

    when defined(nimaUseNativeImgui):
      nativeimgui.initNativeImguiForSdlRenderer(window, renderer, title)

    let runtime = SdlRendererRuntime(
      window: window,
      renderer: renderer,
      engine: initEngine(initialScene, viewSize),
      textureCache: initTable[uint32, SDL_Texture](),
      textCache: initTable[string, TextTexture](),
      glyphCache: initTable[string, GlyphTexture](),
      imageLoader: initSdlImageState(),
      ttf: initSdlTtfState(),
      sdlAudio: initSdlAudioState(),
      gamepads: initTable[SDL_JoystickID, SDL_Gamepad](),
      lastTicks: SDL_GetTicks(),
      vsync: vsync
    )
    runtime.engine.updateMetrics(window)
    runtime.gamepads.openExistingGamepads(runtime.engine.input)

    try:
      discard withEngineScope(runtime.engine, proc(): bool =
        when defined(emscripten):
          emscriptenRuntime = runtime
          emscriptenSetMainLoop(emscriptenFrame, 0, true)
        else:
          while not runtime.engine.exitRequested:
            runtime.stepFrame()
        true
      )
    finally:
      when not defined(emscripten):
        runtime.shutdown()
  finally:
    when not defined(emscripten):
      if not window.isNil:
        discard SDL_StopTextInput(window)
      if not renderer.isNil:
        SDL_DestroyRenderer(renderer)
      if not window.isNil:
        SDL_DestroyWindow(window)
      SDL_Quit()

proc sdlLinked*(): bool = true
