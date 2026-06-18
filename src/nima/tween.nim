import std/math as stdmath
import ./[math, transform]

type
  TweenShake* = object
    amplitude*: float32
    frequency*: float32
    duration*: float32
    timer*: float32
    samples*: seq[Vec2]

  TweenRotationPunch* = object
    timer*: float32
    vibration*: float32
    samples*: seq[float32]

  Tween* = object
    lastOffset*: Vec2
    lastAngleOffset*: float32
    shakes*: seq[TweenShake]
    punches*: seq[TweenRotationPunch]

proc rotateAngle(angle, delta: float32): float32 =
  result = angle + delta
  let tau = (stdmath.PI * 2).float32
  while result > stdmath.PI.float32:
    result -= tau
  while result < -stdmath.PI.float32:
    result += tau

proc randUnit(seed: var uint32): float32 =
  seed = seed * 1664525'u32 + 1013904223'u32
  let bits = (seed shr 8) and 0x00FF_FFFF'u32
  (bits.float32 / 0x00FF_FFFF'u32.float32) * 2'f32 - 1'f32

proc tweenShake*(amplitude, duration, frequency: float32;
                 seed = 0xC0FFEE'u32): TweenShake =
  let count = max(2, int(duration * frequency) + 1)
  var s = if seed == 0'u32: 1'u32 else: seed
  result = TweenShake(amplitude: amplitude, frequency: frequency,
                      duration: max(0.0001'f32, duration),
                      timer: duration)
  result.samples = newSeq[Vec2](count)
  for i in 0..<count:
    result.samples[i] = vec2(randUnit(s), randUnit(s))

proc tweenRotationPunch*(direction: Vec2; duration, vibration,
                         elasticity: float32): TweenRotationPunch =
  let count = max(2, int(duration * vibration) + 1)
  var strength = direction.length()
  let baseAngle =
    if strength <= 0'f32: 0'f32 else: stdmath.arctan2(direction.y, direction.x).float32
  let decay = if count <= 1: 0'f32 else: strength / count.float32
  result = TweenRotationPunch(timer: duration, vibration: vibration)
  result.samples = newSeq[float32](count)
  for i in 0..<count:
    if i == count - 1:
      result.samples[i] = 0
    elif i == 0:
      result.samples[i] = baseAngle * strength
    elif (i mod 2) == 1:
      result.samples[i] = -baseAngle * strength * elasticity
    else:
      result.samples[i] = baseAngle * strength
    strength = max(0'f32, strength - decay)

proc initTween*(): Tween =
  Tween()

proc addShake*(tween: var Tween; shake: TweenShake) =
  tween.shakes.add shake

proc addShake*(tween: var Tween; amplitude, duration, frequency: float32;
               seed = 0xC0FFEE'u32) =
  tween.addShake(tweenShake(amplitude, duration, frequency, seed))

proc addRotationPunch*(tween: var Tween; punch: TweenRotationPunch) =
  tween.punches.add punch

proc addRotationPunch*(tween: var Tween; direction: Vec2; duration, vibration,
                       elasticity: float32) =
  tween.addRotationPunch(tweenRotationPunch(direction, duration, vibration,
                                            elasticity))

proc alive*(shake: TweenShake): bool = shake.timer > 0'f32
proc alive*(punch: TweenRotationPunch): bool = punch.timer > 0'f32
proc active*(tween: Tween): bool =
  tween.shakes.len > 0 or tween.punches.len > 0 or
    tween.lastOffset != Vec2Zero or tween.lastAngleOffset != 0'f32

proc update(shake: var TweenShake; dt: float32): Vec2 =
  shake.timer -= dt
  if shake.timer <= 0'f32 or shake.samples.len == 0:
    return Vec2Zero
  let s = max(0'f32, shake.timer * shake.frequency)
  let i0 = min(shake.samples.high, int(stdmath.floor(s)))
  let i1 = min(shake.samples.high, i0 + 1)
  let t = s - i0.float32
  let noise = shake.samples[i0] + (shake.samples[i1] - shake.samples[i0]) * t
  let decay = clamp(shake.timer / shake.duration, 0, 1)
  noise * shake.amplitude * decay

proc update(punch: var TweenRotationPunch; dt: float32): float32 =
  punch.timer -= dt
  if punch.timer <= 0'f32 or punch.samples.len == 0:
    return 0
  let s = max(0'f32, punch.timer * punch.vibration)
  let i0 = min(punch.samples.high, int(stdmath.floor(s)))
  let i1 = min(punch.samples.high, i0 + 1)
  let t = s - i0.float32
  lerp(punch.samples[i0], punch.samples[i1], t)

proc apply*(tween: var Tween; dt: float32; base: Transform): Transform =
  var offset = Vec2Zero
  var angleOffset = 0'f32

  var nextShakes: seq[TweenShake]
  for shake in tween.shakes.mitems:
    offset = offset + shake.update(dt)
    if shake.alive:
      nextShakes.add shake
  tween.shakes = nextShakes

  var nextPunches: seq[TweenRotationPunch]
  for punch in tween.punches.mitems:
    angleOffset = rotateAngle(angleOffset, punch.update(dt))
    if punch.alive:
      nextPunches.add punch
  tween.punches = nextPunches

  result = base
  let pos = base.pos.xy + offset - tween.lastOffset
  result.pos = pos.extend(base.pos.z)
  result.angle = rotateAngle(rotateAngle(base.angle, angleOffset),
                             -tween.lastAngleOffset)
  tween.lastOffset = offset
  tween.lastAngleOffset = angleOffset

proc reset*(tween: var Tween; base: Transform): Transform =
  result = base
  result.pos = (base.pos.xy - tween.lastOffset).extend(base.pos.z)
  result.angle = rotateAngle(base.angle, -tween.lastAngleOffset)
  tween.lastOffset = Vec2Zero
  tween.lastAngleOffset = 0
  tween.shakes.setLen 0
  tween.punches.setLen 0
