import ./[color, draw, math, transform]

type
  DiagnosticsState* = object
    enabled*: bool
    position*: Vec2
    refreshInterval*: float32
    elapsed*: float32
    cachedText*: string

proc initDiagnosticsState*(): DiagnosticsState =
  DiagnosticsState(position: vec2(16, 16), refreshInterval: 0.5'f32)

proc setEnabled*(state: var DiagnosticsState, enabled: bool) =
  state.enabled = enabled

proc setPosition*(state: var DiagnosticsState, position: Vec2) =
  state.position = position

proc setRefreshInterval*(state: var DiagnosticsState, seconds: float32) =
  if seconds < 0.05'f32:
    state.refreshInterval = 0.05'f32
  else:
    state.refreshInterval = seconds

proc update*(state: var DiagnosticsState, dt: float32, frame: uint64,
             fps: float32, drawCalls, batches: int) =
  if not state.enabled:
    return
  state.elapsed += dt
  if state.cachedText.len == 0 or state.elapsed >= state.refreshInterval:
    state.elapsed = 0
    state.cachedText = "Nima diagnostics\nfps: " & $fps.int &
      "\nframe: " & $frame & "\ndraw: " & $drawCalls &
      "\nbatches: " & $batches

proc drawOverlay*(state: DiagnosticsState, recorder: var FrameRecorder, view: Vec2) =
  if not state.enabled or state.cachedText.len == 0:
    return
  let previous = recorder.pushSpace(dsUi)
  defer: recorder.popSpace(previous)
  let pos = vec3(-view.x * 0.5'f32 + state.position.x,
                 view.y * 0.5'f32 - state.position.y, 900)
  recorder.drawRect(rgba(0, 0, 0, 0.72), vec2(220, 104), transform(pos + vec3(110, -52, 0)))
  recorder.drawText(text(state.cachedText, 16, White), transform(pos), vec2(0, 1))
