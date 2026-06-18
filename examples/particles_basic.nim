import std/math as stdmath
import nima/prelude

type
  Action = enum
    spawn, burst

  ParticlesBasic = ref object of Scene
    emitter: ParticleEmitterId
    hasEmitter: bool

method init(scene: ParticlesBasic) =
  bindAction(spawn, key(kcSpace))
  bindAction(burst, key(kcB))
  let config = ParticleEmitterConfig(
    position: vec2(0, 0),
    z: 0.3,
    maxParticles: 2000,
    spawnRate: 220,
    lifetime: particleRange(0.35, 0.95),
    speed: particleRange(80, 220),
    direction: vec2(0, 1),
    spreadRadians: stdmath.PI.float32,
    acceleration: vec2(0, -260),
    damping: 0.97,
    sizeStart: 6,
    sizeEnd: 1,
    colorStart: rgba8(255, 220, 90, 240),
    colorEnd: rgba8(255, 80, 20, 0),
    sprite: defaultParticleSprite()
  )
  scene.emitter = particlesCreateEmitter(config)
  scene.hasEmitter = true
  discard particlesSetEmitterActive(scene.emitter, false)

method update(scene: ParticlesBasic) =
  if not scene.hasEmitter:
    return
  discard particlesSetEmitterPosition(scene.emitter, mousePos())
  discard particlesSetEmitterActive(scene.emitter, actionDown(spawn))
  if actionJustPressed(burst):
    discard particlesEmit(scene.emitter, 80)

method draw(scene: ParticlesBasic) =
  let view = viewSize()
  drawRect(rgb(0.04, 0.05, 0.08), view, transform(vec3(0, 0, -1)))
  drawCircle(mousePos().extend(0.9), 4, White)
  let alive = if scene.hasEmitter: particlesAliveCount(scene.emitter) else: 0
  drawText(text("Particles\nHold SPACE emit\nB burst\nAlive: " & $alive &
                " Emitters: " & $particlesEmitterCount(), 18, White),
           transform(vec3(-view.x * 0.5'f32 + 18, view.y * 0.5'f32 - 18, 2)), vec2(0, 1))

method cleanup(scene: ParticlesBasic) =
  if scene.hasEmitter:
    discard particlesRemoveEmitter(scene.emitter)
  particlesClear()

when isMainModule:
  run app(title = "Particles Basic", size = ivec2(960, 540),
          scene = ParticlesBasic(), scaleMode = ScaleMode(kind: smFit, virtualSize: vec2(960, 540)))
