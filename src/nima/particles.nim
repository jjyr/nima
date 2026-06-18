import std/math as stdmath
import ./[color, draw, math, transform]

type
  ParticleEmitterId* = distinct uint32

  ParticleRange* = object
    min*, max*: float32

  ParticleTexture* = enum
    ptDefaultWhite

  ParticleSprite* = object
    texture*: ParticleTexture
    size*: IVec2

  ParticleEmitterConfig* = object
    position*: Vec2
    z*: float32
    maxParticles*: int
    spawnRate*: float32
    lifetime*: ParticleRange
    speed*: ParticleRange
    direction*: Vec2
    spreadRadians*: float32
    acceleration*: Vec2
    damping*: float32
    sizeStart*, sizeEnd*: float32
    colorStart*, colorEnd*: Color
    sprite*: ParticleSprite

  Particle* = object
    emitter*: ParticleEmitterId
    pos*, vel*: Vec2
    age*, lifetime*: float32
    acceleration*: Vec2
    damping*: float32
    sizeStart*, sizeEnd*: float32
    colorStart*, colorEnd*: Color
    z*: float32

  ParticleEmitter* = object
    id*: ParticleEmitterId
    config*: ParticleEmitterConfig
    active*: bool
    carry*: float32

  ParticleState* = object
    nextId*: uint32
    seed*: uint32
    emitters*: seq[ParticleEmitter]
    particles*: seq[Particle]

proc `==`*(a, b: ParticleEmitterId): bool = uint32(a) == uint32(b)

proc particleRange*(min, max: float32): ParticleRange =
  ParticleRange(min: min, max: max)

proc defaultParticleSprite*(): ParticleSprite =
  ParticleSprite(texture: ptDefaultWhite, size: ivec2(4, 4))

proc initParticleState*(): ParticleState =
  ParticleState(nextId: 1, seed: 0x12345678'u32)

proc rand01(state: var ParticleState): float32 =
  state.seed = state.seed * 1664525'u32 + 1013904223'u32
  ((state.seed shr 8) and 0x00FF_FFFF'u32).float32 / 0x0100_0000.float32

proc sample(state: var ParticleState, range: ParticleRange): float32 =
  range.min + (range.max - range.min) * state.rand01()

proc rotated(v: Vec2, angle: float32): Vec2 =
  let c = stdmath.cos(angle).float32
  let s = stdmath.sin(angle).float32
  vec2(v.x * c - v.y * s, v.x * s + v.y * c)

proc findEmitter(state: var ParticleState, id: ParticleEmitterId): int =
  for i, emitter in state.emitters:
    if emitter.id == id:
      return i
  -1

proc createEmitter*(state: var ParticleState, config: ParticleEmitterConfig): ParticleEmitterId =
  result = ParticleEmitterId(state.nextId)
  inc state.nextId
  var cfg = config
  if cfg.maxParticles <= 0:
    cfg.maxParticles = 256
  if cfg.direction.length <= 0'f32:
    cfg.direction = vec2(0, 1)
  cfg.direction = cfg.direction.normalized
  if cfg.damping <= 0'f32:
    cfg.damping = 1'f32
  if cfg.sprite.size.x == 0 or cfg.sprite.size.y == 0:
    cfg.sprite = defaultParticleSprite()
  state.emitters.add ParticleEmitter(id: result, config: cfg)

proc setEmitterActive*(state: var ParticleState, id: ParticleEmitterId, active: bool): bool =
  let i = state.findEmitter(id)
  if i < 0: return false
  state.emitters[i].active = active
  true

proc setEmitterPosition*(state: var ParticleState, id: ParticleEmitterId, position: Vec2): bool =
  let i = state.findEmitter(id)
  if i < 0: return false
  state.emitters[i].config.position = position
  true

proc emitOne(state: var ParticleState, id: ParticleEmitterId, config: ParticleEmitterConfig) =
  if state.particles.len >= config.maxParticles:
    state.particles.delete(0)
  let angle = (state.rand01() - 0.5'f32) * config.spreadRadians
  let dir = config.direction.rotated(angle).normalized
  state.particles.add Particle(
    emitter: id,
    pos: config.position,
    vel: dir * state.sample(config.speed),
    age: 0,
    lifetime: state.sample(config.lifetime),
    acceleration: config.acceleration,
    damping: config.damping,
    sizeStart: config.sizeStart,
    sizeEnd: config.sizeEnd,
    colorStart: config.colorStart,
    colorEnd: config.colorEnd,
    z: config.z
  )

proc emit*(state: var ParticleState, id: ParticleEmitterId, count: int): bool =
  let i = state.findEmitter(id)
  if i < 0: return false
  let cfg = state.emitters[i].config
  for _ in 0..<count:
    state.emitOne(id, cfg)
  true

proc update*(state: var ParticleState, dt: float32) =
  for i in 0..<state.emitters.len:
    if state.emitters[i].active and state.emitters[i].config.spawnRate > 0'f32:
      state.emitters[i].carry += state.emitters[i].config.spawnRate * dt
      let count = state.emitters[i].carry.int
      state.emitters[i].carry -= count.float32
      let cfg = state.emitters[i].config
      let id = state.emitters[i].id
      for _ in 0..<count:
        state.emitOne(id, cfg)

  var live: seq[Particle] = @[]
  for particle in state.particles.mitems:
    particle.age += dt
    if particle.age < particle.lifetime:
      particle.vel = particle.vel + particle.acceleration * dt
      particle.vel = particle.vel * particle.damping
      particle.pos = particle.pos + particle.vel * dt
      live.add particle
  state.particles = live

proc aliveCount*(state: ParticleState, id: ParticleEmitterId): int =
  for particle in state.particles:
    if particle.emitter == id:
      inc result

proc emitterCount*(state: ParticleState): int = state.emitters.len

proc removeEmitter*(state: var ParticleState, id: ParticleEmitterId): bool =
  let i = state.findEmitter(id)
  if i < 0: return false
  state.emitters.delete(i)
  true

proc clear*(state: var ParticleState) =
  state.emitters.setLen 0
  state.particles.setLen 0

proc mix(a, b, t: float32): float32 = a + (b - a) * t

proc mix(a, b: Color, t: float32): Color =
  rgba(mix(a.r, b.r, t), mix(a.g, b.g, t), mix(a.b, b.b, t), mix(a.a, b.a, t))

proc draw*(state: ParticleState, recorder: var FrameRecorder) =
  for particle in state.particles:
    let t = if particle.lifetime <= 0'f32: 1'f32 else: particle.age / particle.lifetime
    let size = mix(particle.sizeStart, particle.sizeEnd, t)
    recorder.drawRect(mix(particle.colorStart, particle.colorEnd, t),
                      vec2(size, size), transform(particle.pos.extend(particle.z)))
