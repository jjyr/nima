import std/[base64, os]
import std/math as stdmath
import nima/prelude

type SpriteScene = ref object of Scene
  texture: Handle[Texture]

proc writeProbePng(path: string) =
  writeFile(path, decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII="))

method init(scene: SpriteScene) =
  scene.texture = loadTexture("gpu_probe.png")

method update(scene: SpriteScene) =
  exit()

method draw(scene: SpriteScene) =
  drawRect(rgb(0.02, 0.02, 0.03), viewSize(), transform(vec3(0, 0, -1)))
  draw(sprite(scene.texture, ivec2(64, 64)), transform(vec3(-76, 0, 0)))
  var red = sprite(scene.texture, ivec2(64, 64))
  red.color = rgba(1, 0.35, 0.35, 1)
  draw(red, transform(vec3(0, 0, 0), angle = stdmath.PI.float32 * 0.18'f32))
  var blue = sprite(scene.texture, ivec2(64, 64))
  blue.color = rgba(0.35, 0.55, 1, 0.65)
  draw(blue, transform(vec3(76, 0, 0)))

when isMainModule:
  let root = getTempDir() / "nima_gpu_sprite_smoke"
  createDir(root)
  writeProbePng(root / "gpu_probe.png")
  run app(SpriteScene(), title = "Nima SDL_GPU Sprite Smoke", size = ivec2(320, 180),
          scaleMode = ScaleMode(kind: smFit, virtualSize: vec2(320, 180)),
          assetRoots = [root])
