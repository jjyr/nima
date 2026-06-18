import std/[hashes, sets, tables, typetraits]
import ./math

type
  KeyCode* = enum
    kcInvalid, kcA, kcB, kcC, kcD, kcE, kcF, kcG, kcH, kcI, kcJ, kcK, kcL,
    kcM, kcN, kcO, kcP, kcQ, kcR, kcS, kcT, kcU, kcV, kcW, kcX, kcY, kcZ,
    kcDigit0, kcDigit1, kcDigit2, kcDigit3, kcDigit4, kcDigit5, kcDigit6,
    kcDigit7, kcDigit8, kcDigit9, kcEscape, kcSpace, kcEnter, kcBackspace,
    kcTab, kcLeft, kcRight, kcUp, kcDown, kcLeftShift, kcLeftCtrl, kcLeftAlt,
    kcRightShift, kcRightCtrl, kcRightAlt

  MouseButton* = enum
    mbLeft, mbMiddle, mbRight, mbBack, mbForward

  GamepadButton* = enum
    gpbInvalid, gpbSouth, gpbEast, gpbWest, gpbNorth, gpbBack, gpbGuide,
    gpbStart, gpbLeftStick, gpbRightStick, gpbLeftShoulder, gpbRightShoulder,
    gpbDpadUp, gpbDpadDown, gpbDpadLeft, gpbDpadRight, gpbMisc1,
    gpbRightPaddle1, gpbLeftPaddle1, gpbRightPaddle2, gpbLeftPaddle2,
    gpbTouchpad

  GamepadAxis* = enum
    gpaInvalid, gpaLeftX, gpaLeftY, gpaRightX, gpaRightY, gpaLeftTrigger,
    gpaRightTrigger

  GamepadAxisDir* = enum
    gadNegative, gadPositive

  InputSourceKind* = enum
    iskKey, iskMouse, iskGamepadButton, iskGamepadAxis

  InputSource* = object
    gamepad*: int32
    case kind*: InputSourceKind
    of iskKey:
      keyCode*: KeyCode
    of iskMouse:
      mouseButton*: MouseButton
    of iskGamepadButton:
      gamepadButton*: GamepadButton
    of iskGamepadAxis:
      gamepadAxis*: GamepadAxis
      gamepadAxisDir*: GamepadAxisDir
      gamepadAxisThreshold*: float32

  GamepadButtonKey = object
    gamepad: int32
    button: GamepadButton

  GamepadAxisKey = object
    gamepad: int32
    axis: GamepadAxis

  InputState* = object
    keysDown, keysPressed, keysReleased: HashSet[KeyCode]
    mouseDown, mousePressed, mouseReleased: HashSet[MouseButton]
    gamepadsConnected: HashSet[int32]
    gamepadButtonsDown, gamepadButtonsPressed, gamepadButtonsReleased: HashSet[GamepadButtonKey]
    gamepadAxes, gamepadPrevAxes: Table[GamepadAxisKey, float32]
    actions: Table[string, seq[InputSource]]
    mousePosition*: Vec2
    scrollDelta*: Vec2
    textInput*: string
    gamepadDeadzone*: float32

const
  AnyGamepad* = -1'i32

proc hash(key: GamepadButtonKey): Hash =
  result = !$hash((key.gamepad.int, ord(key.button)))

proc hash(key: GamepadAxisKey): Hash =
  result = !$hash((key.gamepad.int, ord(key.axis)))

proc key*(code: KeyCode): InputSource =
  InputSource(kind: iskKey, gamepad: AnyGamepad, keyCode: code)

proc mouse*(button: MouseButton): InputSource =
  InputSource(kind: iskMouse, gamepad: AnyGamepad, mouseButton: button)

proc gamepadButton*(button: GamepadButton, gamepad = AnyGamepad): InputSource =
  InputSource(kind: iskGamepadButton, gamepad: gamepad, gamepadButton: button)

proc gamepadAxis*(axis: GamepadAxis, dir: GamepadAxisDir, gamepad = AnyGamepad,
                  threshold = 0.5'f32): InputSource =
  InputSource(kind: iskGamepadAxis, gamepad: gamepad, gamepadAxis: axis,
              gamepadAxisDir: dir, gamepadAxisThreshold: threshold)

proc initInputState*(): InputState =
  result.keysDown = initHashSet[KeyCode]()
  result.keysPressed = initHashSet[KeyCode]()
  result.keysReleased = initHashSet[KeyCode]()
  result.mouseDown = initHashSet[MouseButton]()
  result.mousePressed = initHashSet[MouseButton]()
  result.mouseReleased = initHashSet[MouseButton]()
  result.gamepadsConnected = initHashSet[int32]()
  result.gamepadButtonsDown = initHashSet[GamepadButtonKey]()
  result.gamepadButtonsPressed = initHashSet[GamepadButtonKey]()
  result.gamepadButtonsReleased = initHashSet[GamepadButtonKey]()
  result.gamepadAxes = initTable[GamepadAxisKey, float32]()
  result.gamepadPrevAxes = initTable[GamepadAxisKey, float32]()
  result.actions = initTable[string, seq[InputSource]]()
  result.mousePosition = Vec2Zero
  result.scrollDelta = Vec2Zero
  result.gamepadDeadzone = 0.2'f32

proc actionId[A: enum](action: A): string =
  name(type(action)) & ":" & $ord(action)

proc setKeyDown*(input: var InputState, code: KeyCode, down: bool) =
  if down:
    if code notin input.keysDown:
      input.keysPressed.incl code
    input.keysDown.incl code
  else:
    if code in input.keysDown:
      input.keysReleased.incl code
    input.keysDown.excl code

proc setMouseDown*(input: var InputState, button: MouseButton, down: bool) =
  if down:
    if button notin input.mouseDown:
      input.mousePressed.incl button
    input.mouseDown.incl button
  else:
    if button in input.mouseDown:
      input.mouseReleased.incl button
    input.mouseDown.excl button

proc setMousePos*(input: var InputState, pos: Vec2) =
  input.mousePosition = pos

proc addScroll*(input: var InputState, delta: Vec2) =
  input.scrollDelta = input.scrollDelta + delta

proc addTextInput*(input: var InputState, text: string) =
  input.textInput.add text

proc setGamepadDeadzone*(input: var InputState, deadzone: float32) =
  input.gamepadDeadzone = clamp(deadzone, 0, 0.99'f32)

proc connectedGamepads*(input: InputState): seq[int32] =
  for gamepad in input.gamepadsConnected:
    result.add gamepad

proc setGamepadConnected*(input: var InputState, gamepad: int32, connected: bool) =
  if connected:
    input.gamepadsConnected.incl gamepad
    return

  input.gamepadsConnected.excl gamepad
  var buttonsToDrop: seq[GamepadButtonKey]
  for key in input.gamepadButtonsDown:
    if key.gamepad == gamepad:
      input.gamepadButtonsReleased.incl key
      buttonsToDrop.add key
  for key in buttonsToDrop:
    input.gamepadButtonsDown.excl key

  var axesToDrop: seq[GamepadAxisKey]
  for key in input.gamepadAxes.keys:
    if key.gamepad == gamepad:
      axesToDrop.add key
  for key in axesToDrop:
    input.gamepadAxes.del key

proc setGamepadButtonDown*(input: var InputState, gamepad: int32,
                           button: GamepadButton, down: bool) =
  if button == gpbInvalid:
    return
  input.gamepadsConnected.incl gamepad
  let key = GamepadButtonKey(gamepad: gamepad, button: button)
  if down:
    if key notin input.gamepadButtonsDown:
      input.gamepadButtonsPressed.incl key
    input.gamepadButtonsDown.incl key
  else:
    if key in input.gamepadButtonsDown:
      input.gamepadButtonsReleased.incl key
    input.gamepadButtonsDown.excl key

proc setGamepadAxisValue*(input: var InputState, gamepad: int32,
                          axis: GamepadAxis, value: float32) =
  if axis == gpaInvalid:
    return
  input.gamepadsConnected.incl gamepad
  var v = clamp(value, -1, 1)
  if abs(v) < input.gamepadDeadzone:
    v = 0
  let key = GamepadAxisKey(gamepad: gamepad, axis: axis)
  if v == 0:
    input.gamepadAxes.del key
  else:
    input.gamepadAxes[key] = v

proc endFrame*(input: var InputState) =
  input.keysPressed.clear()
  input.keysReleased.clear()
  input.mousePressed.clear()
  input.mouseReleased.clear()
  input.gamepadButtonsPressed.clear()
  input.gamepadButtonsReleased.clear()
  input.gamepadPrevAxes = input.gamepadAxes
  input.scrollDelta = Vec2Zero
  input.textInput.setLen 0

proc buttonIn(keys: HashSet[GamepadButtonKey], gamepad: int32,
              button: GamepadButton): bool =
  if button == gpbInvalid:
    return false
  if gamepad != AnyGamepad:
    return GamepadButtonKey(gamepad: gamepad, button: button) in keys
  for key in keys:
    if key.button == button:
      return true
  false

proc axisValueFrom(values: Table[GamepadAxisKey, float32], gamepad: int32,
                   axis: GamepadAxis): float32 =
  if axis == gpaInvalid:
    return 0
  if gamepad != AnyGamepad:
    return values.getOrDefault(GamepadAxisKey(gamepad: gamepad, axis: axis), 0)
  for key, value in values:
    if key.axis == axis and abs(value) > abs(result):
      result = value

proc axisActive(value: float32, dir: GamepadAxisDir, threshold: float32): bool =
  let t = clamp(abs(threshold), 0, 1)
  case dir
  of gadNegative: value <= -t
  of gadPositive: value >= t

proc axisActive(input: InputState, source: InputSource): bool =
  input.gamepadAxes.axisValueFrom(source.gamepad, source.gamepadAxis)
    .axisActive(source.gamepadAxisDir, source.gamepadAxisThreshold)

proc axisWasActive(input: InputState, source: InputSource): bool =
  input.gamepadPrevAxes.axisValueFrom(source.gamepad, source.gamepadAxis)
    .axisActive(source.gamepadAxisDir, source.gamepadAxisThreshold)

proc gamepadAxisValue*(input: InputState, axis: GamepadAxis,
                       gamepad = AnyGamepad): float32 =
  input.gamepadAxes.axisValueFrom(gamepad, axis)

proc gamepadButtonDown*(input: InputState, button: GamepadButton,
                        gamepad = AnyGamepad): bool =
  input.gamepadButtonsDown.buttonIn(gamepad, button)

proc gamepadButtonJustPressed*(input: InputState, button: GamepadButton,
                               gamepad = AnyGamepad): bool =
  input.gamepadButtonsPressed.buttonIn(gamepad, button)

proc gamepadButtonJustReleased*(input: InputState, button: GamepadButton,
                                gamepad = AnyGamepad): bool =
  input.gamepadButtonsReleased.buttonIn(gamepad, button)

proc down*(input: InputState, source: InputSource): bool =
  case source.kind
  of iskKey: source.keyCode in input.keysDown
  of iskMouse: source.mouseButton in input.mouseDown
  of iskGamepadButton: input.gamepadButtonDown(source.gamepadButton, source.gamepad)
  of iskGamepadAxis: input.axisActive(source)

proc justPressed*(input: InputState, source: InputSource): bool =
  case source.kind
  of iskKey: source.keyCode in input.keysPressed
  of iskMouse: source.mouseButton in input.mousePressed
  of iskGamepadButton: input.gamepadButtonJustPressed(source.gamepadButton, source.gamepad)
  of iskGamepadAxis: input.axisActive(source) and not input.axisWasActive(source)

proc justReleased*(input: InputState, source: InputSource): bool =
  case source.kind
  of iskKey: source.keyCode in input.keysReleased
  of iskMouse: source.mouseButton in input.mouseReleased
  of iskGamepadButton: input.gamepadButtonJustReleased(source.gamepadButton, source.gamepad)
  of iskGamepadAxis: (not input.axisActive(source)) and input.axisWasActive(source)

proc bindAction*[A: enum](input: var InputState, action: A, source: InputSource) =
  let id = actionId(action)
  input.actions.mgetOrPut(id, @[]).add source

proc setActionSources*[A: enum](input: var InputState, action: A, sources: openArray[InputSource]) =
  input.actions[actionId(action)] = @sources

proc clearAction*[A: enum](input: var InputState, action: A) =
  input.actions.del actionId(action)

proc actionDown*[A: enum](input: InputState, action: A): bool =
  for source in input.actions.getOrDefault(actionId(action)):
    if input.down(source):
      return true
  false

proc actionUp*[A: enum](input: InputState, action: A): bool =
  not input.actionDown(action)

proc actionJustPressed*[A: enum](input: InputState, action: A): bool =
  for source in input.actions.getOrDefault(actionId(action)):
    if input.justPressed(source):
      return true
  false

proc actionJustReleased*[A: enum](input: InputState, action: A): bool =
  for source in input.actions.getOrDefault(actionId(action)):
    if input.justReleased(source):
      return true
  false
