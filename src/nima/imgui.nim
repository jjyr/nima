import std/tables
import ./assets
import ./math

type
  ImGuiLayer* = proc() {.closure.}
  ImGuiState* = object
    layers*: seq[ImGuiLayer]
    inWindow*: bool
    wantsPointerInput*: bool
    wantsKeyboardInput*: bool
    cursor*: Vec2
    windowPos*: Vec2
    windowWidth*: float32
    windowHeight*: float32
    itemHeight*: float32
    indent*: float32
    lastItemMin*: Vec2
    lastItemMax*: Vec2
    focusedTextId*: string
    font*: Handle[Font]
    openHeaders*: Table[string, bool]

proc initImGuiState*(): ImGuiState =
  result.openHeaders = initTable[string, bool]()

proc addLayer*(state: var ImGuiState, layer: ImGuiLayer) =
  state.layers.add layer

proc clearLayers*(state: var ImGuiState) =
  state.layers.setLen 0

proc resetFrame*(state: var ImGuiState) =
  state.wantsPointerInput = false
  state.wantsKeyboardInput = false

proc capturePointer*(state: var ImGuiState) =
  state.wantsPointerInput = true

proc captureKeyboard*(state: var ImGuiState) =
  state.wantsKeyboardInput = true

proc runLayers*(state: var ImGuiState) =
  state.resetFrame()
  for layer in state.layers:
    if layer != nil:
      layer()

proc beginPanel*(state: var ImGuiState, pos: Vec2, width, height: float32,
                 titleBarHeight = 0'f32) =
  state.inWindow = true
  state.windowPos = pos
  state.windowWidth = width
  state.windowHeight = height
  state.itemHeight = 24
  state.indent = 0
  state.cursor = pos + vec2(10, 10 + titleBarHeight)
  state.lastItemMin = state.cursor
  state.lastItemMax = state.cursor

proc beginWindow*(state: var ImGuiState, pos: Vec2, width, height: float32) =
  state.beginPanel(pos, width, height, 24)

proc endWindow*(state: var ImGuiState) =
  state.inWindow = false

proc nextItemRect*(state: var ImGuiState, height = 24'f32, width = 0'f32): Rect =
  let minPos = state.cursor + vec2(state.indent, 0)
  let itemWidth = if width > 0'f32: width else: state.windowWidth - 20 - state.indent
  result = rect(minPos, minPos + vec2(itemWidth, height))
  state.lastItemMin = result.min
  state.lastItemMax = result.max
  state.cursor.y += height + 6

proc sameLine*(state: var ImGuiState, spacing = 6'f32) =
  state.cursor = vec2(state.lastItemMax.x + spacing, state.lastItemMin.y)

proc spacing*(state: var ImGuiState, height = 6'f32) =
  state.cursor.y += height

proc indent*(state: var ImGuiState, width = 18'f32) =
  state.indent += width

proc unindent*(state: var ImGuiState, width = 18'f32) =
  state.indent = max(0'f32, state.indent - width)

proc headerOpen*(state: var ImGuiState, id: string, defaultOpen = false): bool =
  state.openHeaders.getOrDefault(id, defaultOpen)

proc setHeaderOpen*(state: var ImGuiState, id: string, open: bool) =
  state.openHeaders[id] = open

proc focusText*(state: var ImGuiState, id: string) =
  state.focusedTextId = id
  state.captureKeyboard()

proc textFocused*(state: ImGuiState, id: string): bool =
  state.focusedTextId == id

proc clearTextFocus*(state: var ImGuiState) =
  state.focusedTextId = ""
