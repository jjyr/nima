import std/[os, sets, strutils, tables]
import pkg/sdl3
import ../[assets, audio]
import ./sdlmixer

type
  SdlAudioPlaybackKind = enum
    sapNone, sapStream, sapMixer

  SdlAudioPlayback = object
    kind: SdlAudioPlaybackKind
    stream: SDL_AudioStream
    data: seq[uint8]
    looped: bool
    mixerPlayback: SdlMixerPlayback

  SdlAudioState* = object
    initialized: bool
    failedIds: HashSet[uint32]
    playbacks: Table[uint32, SdlAudioPlayback]
    mixer: SdlMixerState

proc initSdlAudioState*(): SdlAudioState =
  SdlAudioState(failedIds: initHashSet[uint32](),
                playbacks: initTable[uint32, SdlAudioPlayback](),
                mixer: initSdlMixerState())

proc destroy(audio: var SdlAudioState, playback: var SdlAudioPlayback) =
  case playback.kind
  of sapStream:
    if not playback.stream.isNil:
      SDL_DestroyAudioStream(playback.stream)
      playback.stream = nil
    playback.data.setLen 0
  of sapMixer:
    audio.mixer.destroy(playback.mixerPlayback)
  of sapNone:
    discard
  playback.kind = sapNone

proc shutdown*(audio: var SdlAudioState) =
  for _, playback in audio.playbacks.mpairs:
    audio.destroy(playback)
  audio.playbacks.clear()
  audio.mixer.shutdown()
  if audio.initialized:
    SDL_QuitSubSystem(SDL_INIT_AUDIO)
    audio.initialized = false

proc ensureAudio(audio: var SdlAudioState): bool =
  if audio.initialized:
    return true
  if not SDL_InitSubSystem(SDL_INIT_AUDIO):
    return false
  audio.initialized = true
  echo "[Nima] SDL audio=", $SDL_GetCurrentAudioDriver()
  true

proc feed(playback: var SdlAudioPlayback) =
  if playback.stream.isNil or playback.data.len == 0:
    return
  discard SDL_PutAudioStreamData(playback.stream, unsafeAddr playback.data[0],
                                 playback.data.len.cint)

proc openStreamPlayback(audio: var SdlAudioState, path: string,
                        item: AudioInstance,
                        playback: var SdlAudioPlayback): bool =
  if path.splitFile.ext.toLowerAscii() != ".wav":
    return false

  var spec: SDL_AudioSpec
  var raw: ptr uint8
  var rawLen: uint32
  if not SDL_LoadWAV(path.cstring, addr spec, raw, rawLen):
    return false
  defer:
    if not raw.isNil:
      SDL_free(raw)
  if raw.isNil or rawLen == 0:
    return false

  playback = SdlAudioPlayback(kind: sapStream, looped: item.params.looped)
  playback.data = newSeq[uint8](rawLen.int)
  copyMem(addr playback.data[0], raw, rawLen.int)
  playback.stream = SDL_OpenAudioDeviceStream(SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK,
                                              addr spec, nil, nil)
  if playback.stream.isNil:
    audio.destroy(playback)
    return false
  playback.feed()
  discard SDL_ResumeAudioStreamDevice(playback.stream)
  true

proc openMixerPlayback(audio: var SdlAudioState, path: string,
                       item: AudioInstance,
                       playback: var SdlAudioPlayback): bool =
  playback = SdlAudioPlayback(kind: sapMixer, looped: item.params.looped)
  if audio.mixer.openPlayback(path, item.params.looped, playback.mixerPlayback):
    return true
  audio.destroy(playback)
  false

proc openPlayback(audio: var SdlAudioState, item: AudioInstance): bool =
  let key = item.id.id
  if key in audio.failedIds:
    return false
  if not audio.ensureAudio():
    audio.failedIds.incl key
    return false
  let clip = audioAsset(item.clip)
  if clip.isNil or not clip.loaded:
    audio.failedIds.incl key
    return false

  let ext = clip.resolvedPath.splitFile.ext.toLowerAscii()
  var playback: SdlAudioPlayback
  let opened =
    if ext == ".wav":
      audio.openStreamPlayback(clip.resolvedPath, item, playback) or
        audio.openMixerPlayback(clip.resolvedPath, item, playback)
    else:
      audio.openMixerPlayback(clip.resolvedPath, item, playback)

  if not opened:
    audio.failedIds.incl key
    return false

  audio.playbacks[key] = playback
  true

proc syncAudio*(audio: var SdlAudioState, state: AudioState) =
  for item in state.instances:
    let key = item.id.id
    if item.stopped:
      if audio.playbacks.hasKey(key):
        var playback = audio.playbacks[key]
        audio.destroy(playback)
        audio.playbacks.del(key)
      continue

    if not audio.playbacks.hasKey(key):
      discard audio.openPlayback(item)
      if not audio.playbacks.hasKey(key):
        continue

    var playback = audio.playbacks[key]
    case playback.kind
    of sapStream:
      if playback.stream.isNil:
        continue
      discard SDL_SetAudioStreamGain(playback.stream,
        state.effectiveVolume(item).cfloat)
      if item.paused:
        discard SDL_PauseAudioStreamDevice(playback.stream)
      else:
        discard SDL_ResumeAudioStreamDevice(playback.stream)

      if not item.paused and playback.looped and playback.data.len > 0:
        let queued = SDL_GetAudioStreamQueued(playback.stream)
        if queued < (playback.data.len div 2).cint:
          playback.feed()

      if not item.paused and not playback.looped and
          SDL_GetAudioStreamQueued(playback.stream) == 0:
        audio.destroy(playback)
        audio.playbacks.del(key)
      else:
        audio.playbacks[key] = playback
    of sapMixer:
      discard audio.mixer.setGain(playback.mixerPlayback,
        state.effectiveVolume(item))
      if item.paused:
        discard audio.mixer.pause(playback.mixerPlayback)
      else:
        discard audio.mixer.resume(playback.mixerPlayback)

      if not item.paused and not playback.looped and
          not audio.mixer.playing(playback.mixerPlayback):
        audio.destroy(playback)
        audio.playbacks.del(key)
      else:
        audio.playbacks[key] = playback
    of sapNone:
      audio.playbacks.del(key)
