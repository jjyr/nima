import ./assets

type
  AudioBus* = enum
    abMaster, abMusic, abSfx

  AudioInstanceId* = distinct uint32

  AudioPlayParams* = object
    bus*: AudioBus
    volume*: float32
    looped*: bool

  AudioInstance* = object
    id*: AudioInstanceId
    clip*: Handle[AudioClip]
    params*: AudioPlayParams
    paused*: bool
    stopped*: bool

  AudioState* = object
    nextId*: uint32
    masterVolume*: float32
    musicVolume*: float32
    sfxVolume*: float32
    instances*: seq[AudioInstance]

proc `==`*(a, b: AudioInstanceId): bool = uint32(a) == uint32(b)

proc id*(id: AudioInstanceId): uint32 = uint32(id)

proc clamp01(value: float32): float32 =
  if value < 0'f32: 0'f32
  elif value > 1'f32: 1'f32
  else: value

proc defaultAudioPlayParams*(): AudioPlayParams =
  AudioPlayParams(bus: abMaster, volume: 1, looped: false)

proc withBus*(params: AudioPlayParams, bus: AudioBus): AudioPlayParams =
  result = params
  result.bus = bus

proc withVolume*(params: AudioPlayParams, volume: float32): AudioPlayParams =
  result = params
  result.volume = volume

proc looped*(params: AudioPlayParams): AudioPlayParams =
  result = params
  result.looped = true

proc initAudioState*(): AudioState =
  AudioState(nextId: 1, masterVolume: 1, musicVolume: 1, sfxVolume: 1)

proc play*(state: var AudioState, clip: Handle[AudioClip],
           params = defaultAudioPlayParams()): AudioInstanceId =
  result = AudioInstanceId(state.nextId)
  inc state.nextId
  var clean = params
  clean.volume = clamp01(clean.volume)
  state.instances.add AudioInstance(id: result, clip: clip, params: clean)

proc pause*(state: var AudioState, id: AudioInstanceId): bool =
  for instance in state.instances.mitems:
    if instance.id == id and not instance.stopped:
      instance.paused = true
      return true
  false

proc resume*(state: var AudioState, id: AudioInstanceId): bool =
  for instance in state.instances.mitems:
    if instance.id == id and not instance.stopped:
      instance.paused = false
      return true
  false

proc stop*(state: var AudioState, id: AudioInstanceId): bool =
  for instance in state.instances.mitems:
    if instance.id == id:
      instance.stopped = true
      return true
  false

proc setMasterVolume*(state: var AudioState, volume: float32) =
  state.masterVolume = clamp01(volume)

proc setBusVolume*(state: var AudioState, bus: AudioBus, volume: float32) =
  case bus
  of abMaster: state.masterVolume = clamp01(volume)
  of abMusic: state.musicVolume = clamp01(volume)
  of abSfx: state.sfxVolume = clamp01(volume)

proc busVolume*(state: AudioState, bus: AudioBus): float32 =
  case bus
  of abMaster: state.masterVolume
  of abMusic: state.musicVolume
  of abSfx: state.sfxVolume

proc instance*(state: AudioState, id: AudioInstanceId): AudioInstance =
  for item in state.instances:
    if item.id == id:
      return item
  AudioInstance()

proc instanceCount*(state: AudioState): int =
  state.instances.len

proc activeCount*(state: AudioState): int =
  for item in state.instances:
    if not item.stopped:
      inc result

proc effectiveVolume*(state: AudioState, instance: AudioInstance): float32 =
  clamp01(state.masterVolume * state.busVolume(instance.params.bus) * instance.params.volume)
