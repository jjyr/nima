import std/math as stdmath
import ./math

type
  Transform* = object
    pos*: Vec3
    scale*: Vec2
    angle*: float32

proc transform*(pos: Vec3, scale = Vec2One, angle = 0'f32): Transform =
  Transform(pos: pos, scale: scale, angle: angle)

proc withPos*(t: Transform, pos: Vec3): Transform =
  result = t
  result.pos = pos

proc withScale*(t: Transform, scale: Vec2): Transform =
  result = t
  result.scale = scale

proc withAngle*(t: Transform, angle: float32): Transform =
  result = t
  result.angle = angle

proc corners*(t: Transform, anchor, size: Vec2): array[4, Vec2] =
  let left = -size.x * anchor.x * t.scale.x
  let right = size.x * (1'f32 - anchor.x) * t.scale.x
  let bottom = -size.y * anchor.y * t.scale.y
  let top = size.y * (1'f32 - anchor.y) * t.scale.y
  let c = stdmath.cos(t.angle).float32
  let s = stdmath.sin(t.angle).float32
  let origin = t.pos.xy
  let local = [
    vec2(left, bottom),
    vec2(right, bottom),
    vec2(right, top),
    vec2(left, top)
  ]
  for i, p in local:
    result[i] = origin + vec2(p.x * c - p.y * s, p.x * s + p.y * c)

proc bounds*(t: Transform, anchor, size: Vec2): Rect =
  let points = t.corners(anchor, size)
  var minP = points[0]
  var maxP = points[0]
  for i in 1..<points.len:
    minP = min(minP, points[i])
    maxP = max(maxP, points[i])
  rect(minP, maxP)
