import std/dynlib
import pkg/sdl3

type
  MixMixer = pointer
  MixAudio = pointer
  MixTrack = pointer

  MixInitProc = proc(): bool {.cdecl.}
  MixQuitProc = proc() {.cdecl.}
  MixCreateMixerDeviceProc = proc(devid: SDL_AudioDeviceID,
                                  spec: ptr SDL_AudioSpec): MixMixer {.cdecl.}
  MixDestroyMixerProc = proc(mixer: MixMixer) {.cdecl.}
  MixLoadAudioProc = proc(mixer: MixMixer, path: cstring,
                          predecode: bool): MixAudio {.cdecl.}
  MixDestroyAudioProc = proc(audio: MixAudio) {.cdecl.}
  MixCreateTrackProc = proc(mixer: MixMixer): MixTrack {.cdecl.}
  MixDestroyTrackProc = proc(track: MixTrack) {.cdecl.}
  MixSetTrackAudioProc = proc(track: MixTrack, audio: MixAudio): bool {.cdecl.}
  MixPlayTrackProc = proc(track: MixTrack, options: SDL_PropertiesID): bool {.cdecl.}
  MixStopTrackProc = proc(track: MixTrack, fadeOutFrames: int64): bool {.cdecl.}
  MixPauseTrackProc = proc(track: MixTrack): bool {.cdecl.}
  MixResumeTrackProc = proc(track: MixTrack): bool {.cdecl.}
  MixTrackPlayingProc = proc(track: MixTrack): bool {.cdecl.}
  MixSetTrackGainProc = proc(track: MixTrack, gain: cfloat): bool {.cdecl.}

  SdlMixerPlayback* = object
    audio: MixAudio
    track: MixTrack

  SdlMixerState* = object
    triedLoad: bool
    initialized: bool
    lib: LibHandle
    mixer: MixMixer
    mixInit: MixInitProc
    mixQuit: MixQuitProc
    mixCreateMixerDevice: MixCreateMixerDeviceProc
    mixDestroyMixer: MixDestroyMixerProc
    mixLoadAudio: MixLoadAudioProc
    mixDestroyAudio: MixDestroyAudioProc
    mixCreateTrack: MixCreateTrackProc
    mixDestroyTrack: MixDestroyTrackProc
    mixSetTrackAudio: MixSetTrackAudioProc
    mixPlayTrack: MixPlayTrackProc
    mixStopTrack: MixStopTrackProc
    mixPauseTrack: MixPauseTrackProc
    mixResumeTrack: MixResumeTrackProc
    mixTrackPlaying: MixTrackPlayingProc
    mixSetTrackGain: MixSetTrackGainProc

const
  MixPropPlayLoops = "SDL_mixer.play.loops"
  MixPropPlayHaltWhenExhausted = "SDL_mixer.play.halt_when_exhausted"

proc initSdlMixerState*(): SdlMixerState = SdlMixerState()

proc loadSymbol[T](lib: LibHandle, name: string): T =
  cast[T](symAddr(lib, name))

proc tryLoadLib(name: string): LibHandle =
  try:
    result = loadLib(name)
  except OSError:
    result = nil

proc ensureLoaded(state: var SdlMixerState): bool =
  if state.initialized:
    return true
  if state.triedLoad:
    return false
  state.triedLoad = true

  const names = [
    "libSDL3_mixer.0.dylib",
    "libSDL3_mixer.dylib",
    "/opt/homebrew/opt/sdl3_mixer/lib/libSDL3_mixer.0.dylib",
    "/opt/homebrew/opt/sdl3_mixer/lib/libSDL3_mixer.dylib",
    "/usr/local/opt/sdl3_mixer/lib/libSDL3_mixer.0.dylib",
    "/usr/local/opt/sdl3_mixer/lib/libSDL3_mixer.dylib",
    "SDL3_mixer.dll",
    "libSDL3_mixer.so.0",
    "libSDL3_mixer.so"
  ]
  for name in names:
    state.lib = tryLoadLib(name)
    if not state.lib.isNil:
      break
  if state.lib.isNil:
    return false

  state.mixInit = loadSymbol[MixInitProc](state.lib, "MIX_Init")
  state.mixQuit = loadSymbol[MixQuitProc](state.lib, "MIX_Quit")
  state.mixCreateMixerDevice =
    loadSymbol[MixCreateMixerDeviceProc](state.lib, "MIX_CreateMixerDevice")
  state.mixDestroyMixer =
    loadSymbol[MixDestroyMixerProc](state.lib, "MIX_DestroyMixer")
  state.mixLoadAudio = loadSymbol[MixLoadAudioProc](state.lib, "MIX_LoadAudio")
  state.mixDestroyAudio =
    loadSymbol[MixDestroyAudioProc](state.lib, "MIX_DestroyAudio")
  state.mixCreateTrack = loadSymbol[MixCreateTrackProc](state.lib, "MIX_CreateTrack")
  state.mixDestroyTrack =
    loadSymbol[MixDestroyTrackProc](state.lib, "MIX_DestroyTrack")
  state.mixSetTrackAudio =
    loadSymbol[MixSetTrackAudioProc](state.lib, "MIX_SetTrackAudio")
  state.mixPlayTrack = loadSymbol[MixPlayTrackProc](state.lib, "MIX_PlayTrack")
  state.mixStopTrack = loadSymbol[MixStopTrackProc](state.lib, "MIX_StopTrack")
  state.mixPauseTrack = loadSymbol[MixPauseTrackProc](state.lib, "MIX_PauseTrack")
  state.mixResumeTrack =
    loadSymbol[MixResumeTrackProc](state.lib, "MIX_ResumeTrack")
  state.mixTrackPlaying =
    loadSymbol[MixTrackPlayingProc](state.lib, "MIX_TrackPlaying")
  state.mixSetTrackGain =
    loadSymbol[MixSetTrackGainProc](state.lib, "MIX_SetTrackGain")

  if state.mixInit.isNil or state.mixQuit.isNil or
      state.mixCreateMixerDevice.isNil or state.mixDestroyMixer.isNil or
      state.mixLoadAudio.isNil or state.mixDestroyAudio.isNil or
      state.mixCreateTrack.isNil or state.mixDestroyTrack.isNil or
      state.mixSetTrackAudio.isNil or state.mixPlayTrack.isNil or
      state.mixStopTrack.isNil or state.mixPauseTrack.isNil or
      state.mixResumeTrack.isNil or state.mixTrackPlaying.isNil or
      state.mixSetTrackGain.isNil:
    unloadLib(state.lib)
    state.lib = nil
    return false

  if not state.mixInit():
    unloadLib(state.lib)
    state.lib = nil
    return false

  state.mixer = state.mixCreateMixerDevice(SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK, nil)
  if state.mixer.isNil:
    state.mixQuit()
    unloadLib(state.lib)
    state.lib = nil
    return false

  state.initialized = true
  echo "[Nima] SDL3_mixer available"
  true

proc available*(state: var SdlMixerState): bool =
  state.ensureLoaded()

proc destroy*(state: var SdlMixerState, playback: var SdlMixerPlayback) =
  if state.initialized and not playback.track.isNil:
    discard state.mixStopTrack(playback.track, 0)
    state.mixDestroyTrack(playback.track)
    playback.track = nil
  if state.initialized and not playback.audio.isNil:
    state.mixDestroyAudio(playback.audio)
    playback.audio = nil

proc shutdown*(state: var SdlMixerState) =
  if state.initialized and not state.mixer.isNil:
    state.mixDestroyMixer(state.mixer)
    state.mixer = nil
  if state.initialized and state.mixQuit != nil:
    state.mixQuit()
  state.initialized = false
  if not state.lib.isNil:
    unloadLib(state.lib)
    state.lib = nil

proc openPlayback*(state: var SdlMixerState, path: string, looped: bool,
                   playback: var SdlMixerPlayback): bool =
  if path.len == 0 or not state.ensureLoaded():
    return false

  playback.audio = state.mixLoadAudio(state.mixer, path.cstring, false)
  if playback.audio.isNil:
    return false

  playback.track = state.mixCreateTrack(state.mixer)
  if playback.track.isNil:
    state.destroy(playback)
    return false

  if not state.mixSetTrackAudio(playback.track, playback.audio):
    state.destroy(playback)
    return false

  let props = SDL_CreateProperties()
  if props == 0:
    state.destroy(playback)
    return false
  defer: SDL_DestroyProperties(props)
  discard SDL_SetNumberProperty(props, MixPropPlayLoops.cstring,
    (if looped: -1'i64 else: 0'i64))
  discard SDL_SetBooleanProperty(props, MixPropPlayHaltWhenExhausted.cstring, true)

  if not state.mixPlayTrack(playback.track, props):
    state.destroy(playback)
    return false
  true

proc setGain*(state: var SdlMixerState, playback: SdlMixerPlayback,
              gain: float32): bool =
  state.initialized and not playback.track.isNil and
    state.mixSetTrackGain(playback.track, gain.cfloat)

proc pause*(state: var SdlMixerState, playback: SdlMixerPlayback): bool =
  state.initialized and not playback.track.isNil and
    state.mixPauseTrack(playback.track)

proc resume*(state: var SdlMixerState, playback: SdlMixerPlayback): bool =
  state.initialized and not playback.track.isNil and
    state.mixResumeTrack(playback.track)

proc playing*(state: var SdlMixerState, playback: SdlMixerPlayback): bool =
  state.initialized and not playback.track.isNil and
    state.mixTrackPlaying(playback.track)
