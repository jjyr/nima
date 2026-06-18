import nima/prelude

const VolumeStep = 0.1'f32

type
  Action = enum
    toggleMusic, stopMusic, playSfx, musicVolUp, musicVolDown, sfxVolUp, sfxVolDown

  AudioBasic = ref object of Scene
    musicClip: Handle[AudioClip]
    sfxClip: Handle[AudioClip]
    musicInstance: AudioInstanceId
    hasMusicInstance: bool
    musicPaused: bool
    musicVolume: float32
    sfxVolume: float32

proc toggle(scene: AudioBasic) =
  if not scene.hasMusicInstance:
    scene.musicInstance = audioPlay(scene.musicClip,
      defaultAudioPlayParams().withBus(abMusic).withVolume(scene.musicVolume).looped())
    scene.hasMusicInstance = true
    scene.musicPaused = false
  elif scene.musicPaused:
    discard audioResume(scene.musicInstance)
    scene.musicPaused = false
  else:
    discard audioPause(scene.musicInstance)
    scene.musicPaused = true

proc stop(scene: AudioBasic) =
  if scene.hasMusicInstance:
    discard audioStop(scene.musicInstance)
  scene.hasMusicInstance = false
  scene.musicPaused = false

method init(scene: AudioBasic) =
  bindAction(toggleMusic, key(kcM))
  bindAction(stopMusic, key(kcS))
  bindAction(playSfx, key(kcSpace))
  bindAction(musicVolUp, key(kcUp))
  bindAction(musicVolDown, key(kcDown))
  bindAction(sfxVolUp, key(kcRight))
  bindAction(sfxVolDown, key(kcLeft))
  scene.musicVolume = 0.8
  scene.sfxVolume = 1
  scene.musicClip = loadAudio("audio/bgm.wav")
  scene.sfxClip = loadAudio("audio/click.wav")
  setAudioMasterVolume(1)
  setAudioBusVolume(abMusic, scene.musicVolume)
  setAudioBusVolume(abSfx, scene.sfxVolume)

method update(scene: AudioBasic) =
  if actionJustPressed(toggleMusic): scene.toggle()
  if actionJustPressed(stopMusic): scene.stop()
  if actionJustPressed(playSfx):
    discard audioPlay(scene.sfxClip, defaultAudioPlayParams().withBus(abSfx).withVolume(scene.sfxVolume))
  if actionJustPressed(musicVolUp):
    scene.musicVolume = min(1'f32, scene.musicVolume + VolumeStep)
    setAudioBusVolume(abMusic, scene.musicVolume)
  if actionJustPressed(musicVolDown):
    scene.musicVolume = max(0'f32, scene.musicVolume - VolumeStep)
    setAudioBusVolume(abMusic, scene.musicVolume)
  if actionJustPressed(sfxVolUp):
    scene.sfxVolume = min(1'f32, scene.sfxVolume + VolumeStep)
    setAudioBusVolume(abSfx, scene.sfxVolume)
  if actionJustPressed(sfxVolDown):
    scene.sfxVolume = max(0'f32, scene.sfxVolume - VolumeStep)
    setAudioBusVolume(abSfx, scene.sfxVolume)

method draw(scene: AudioBasic) =
  let status = if not scene.hasMusicInstance: "stopped" elif scene.musicPaused: "paused" else: "playing"
  drawRect(rgb(0.06, 0.07, 0.10), viewSize(), transform(vec3(0, 0, -1)))
  drawText(text("Audio Basic\nM toggle music: " & status &
    "\nS stop  SPACE sfx\nUp/Down music volume: " & $scene.musicVolume &
    "\nLeft/Right sfx volume: " & $scene.sfxVolume &
    "\nWAV uses SDL core; OGG/MP3 use optional SDL3_mixer when present.", 18, White),
    transform(vec3(-300, 120, 0.2)), vec2(0, 1))

method cleanup(scene: AudioBasic) =
  scene.stop()

when isMainModule:
  run app(title = "Audio Basic", size = ivec2(960, 540),
          scene = AudioBasic(), scaleMode = ScaleMode(kind: smFit, virtualSize: vec2(960, 540)))
