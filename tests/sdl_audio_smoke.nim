import std/os
import nima/prelude

type AudioSmoke = ref object of Scene
  clip: Handle[AudioClip]
  started: bool

proc putU16LE(data: var string, value: uint16) =
  data.add char(value and 0xff)
  data.add char((value shr 8) and 0xff)

proc putU32LE(data: var string, value: uint32) =
  data.add char(value and 0xff)
  data.add char((value shr 8) and 0xff)
  data.add char((value shr 16) and 0xff)
  data.add char((value shr 24) and 0xff)

proc writeSilentWav(path: string) =
  const
    sampleRate = 8000'u32
    dataLen = 800'u32
  var data = ""
  data.add "RIFF"
  data.putU32LE(36'u32 + dataLen)
  data.add "WAVEfmt "
  data.putU32LE(16)
  data.putU16LE(1)
  data.putU16LE(1)
  data.putU32LE(sampleRate)
  data.putU32LE(sampleRate)
  data.putU16LE(1)
  data.putU16LE(8)
  data.add "data"
  data.putU32LE(dataLen)
  for _ in 0..<dataLen.int:
    data.add char(128)
  writeFile(path, data)

method init(scene: AudioSmoke) =
  let path = getTempDir() / "nima_sdl_audio_smoke.wav"
  writeSilentWav(path)
  scene.clip = loadAudio(path)

method update(scene: AudioSmoke) =
  if not scene.started:
    discard audioPlay(scene.clip, defaultAudioPlayParams().withVolume(0.2))
    scene.started = true
  if frame() > 4:
    exit()

method draw(scene: AudioSmoke) =
  drawRect(rgb(0.03, 0.04, 0.06), viewSize(), transform(vec3(0, 0, -1)))
  drawText(text("SDL audio smoke", 18, White), transform(vec3(-120, 30, 0)))

when isMainModule:
  run app(title = "SDL Audio Smoke", size = ivec2(320, 240), scene = AudioSmoke(),
          scaleMode = ScaleMode(kind: smFit, virtualSize: vec2(320, 240)))
