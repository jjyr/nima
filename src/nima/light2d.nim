import ./[color, draw, math, transform]

type
  Light2DId* = distinct uint32
  LightOccluder2DId* = distinct uint32

  Light2D* = object
    position*: Vec2
    radius*: float32
    color*: Color
    intensity*: float32
    softness*: float32

  LightOccluder2DRect* = object
    center*: Vec2
    size*: Vec2
    rotation*: float32

  Light2DSettings* = object
    enabled*: bool
    overlayZ*: float32
    ambient*: Color
    shadowColor*: Color
    shadowLength*: float32

  LightEntry = object
    id: Light2DId
    light: Light2D

  OccluderEntry = object
    id: LightOccluder2DId
    rect: LightOccluder2DRect

  Light2DState* = object
    nextLightId*: uint32
    nextOccluderId*: uint32
    settings*: Light2DSettings
    lights: seq[LightEntry]
    occluders: seq[OccluderEntry]

proc `==`*(a, b: Light2DId): bool = uint32(a) == uint32(b)
proc `==`*(a, b: LightOccluder2DId): bool = uint32(a) == uint32(b)

proc defaultLight2DSettings*(): Light2DSettings =
  Light2DSettings(enabled: false, overlayZ: 760, ambient: rgba(0, 0, 0, 0.7),
                  shadowColor: rgba(0, 0, 0, 0.9), shadowLength: 1000)

proc initLight2DState*(): Light2DState =
  Light2DState(nextLightId: 1, nextOccluderId: 1, settings: defaultLight2DSettings())

proc addLight*(state: var Light2DState, light: Light2D): Light2DId =
  result = Light2DId(state.nextLightId)
  inc state.nextLightId
  state.lights.add LightEntry(id: result, light: light)

proc setLight*(state: var Light2DState, id: Light2DId, light: Light2D): bool =
  for entry in state.lights.mitems:
    if entry.id == id:
      entry.light = light
      return true
  false

proc addOccluderRect*(state: var Light2DState, rect: LightOccluder2DRect): LightOccluder2DId =
  result = LightOccluder2DId(state.nextOccluderId)
  inc state.nextOccluderId
  state.occluders.add OccluderEntry(id: result, rect: rect)

proc removeOccluder*(state: var Light2DState, id: LightOccluder2DId): bool =
  for i, entry in state.occluders:
    if entry.id == id:
      state.occluders.delete(i)
      return true
  false

proc clear*(state: var Light2DState) =
  state.lights.setLen 0
  state.occluders.setLen 0
  state.settings = defaultLight2DSettings()

proc lightCount*(state: Light2DState): int = state.lights.len
proc occluderCount*(state: Light2DState): int = state.occluders.len

proc drawOverlay*(state: Light2DState, recorder: var FrameRecorder, view: Vec2) =
  if not state.settings.enabled:
    return
  recorder.drawRect(state.settings.ambient, view,
                    transform(vec3(0, 0, state.settings.overlayZ)))
  for entry in state.lights:
    let c = entry.light.color.withAlpha(entry.light.color.a * entry.light.intensity * 0.25'f32)
    recorder.drawCircle(entry.light.position.extend(state.settings.overlayZ + 0.1'f32),
                        entry.light.radius, c)
