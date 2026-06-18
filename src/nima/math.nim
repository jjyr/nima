import std/math as stdmath

type
  Vec2* = object
    x*, y*: float32

  Vec3* = object
    x*, y*, z*: float32

  IVec2* = object
    x*, y*: int32

  Rect* = object
    min*, max*: Vec2

proc vec2*[T, U: SomeNumber](x: T, y: U): Vec2 =
  Vec2(x: x.float32, y: y.float32)

proc vec2*[T: SomeNumber](v: T): Vec2 =
  vec2(v, v)

proc vec3*[T, U, V: SomeNumber](x: T, y: U, z: V): Vec3 =
  Vec3(x: x.float32, y: y.float32, z: z.float32)

proc ivec2*[T, U: SomeInteger](x: T, y: U): IVec2 =
  IVec2(x: x.int32, y: y.int32)

proc `+`*(a, b: Vec2): Vec2 = vec2(a.x + b.x, a.y + b.y)
proc `-`*(a, b: Vec2): Vec2 = vec2(a.x - b.x, a.y - b.y)
proc `-`*(a: Vec2): Vec2 = vec2(-a.x, -a.y)
proc `*`*(a: Vec2, b: float32): Vec2 = vec2(a.x * b, a.y * b)
proc `*`*(b: float32, a: Vec2): Vec2 = a * b
proc `/`*(a: Vec2, b: float32): Vec2 = vec2(a.x / b, a.y / b)

proc `+`*(a, b: Vec3): Vec3 = vec3(a.x + b.x, a.y + b.y, a.z + b.z)
proc `-`*(a, b: Vec3): Vec3 = vec3(a.x - b.x, a.y - b.y, a.z - b.z)
proc `*`*(a: Vec3, b: float32): Vec3 = vec3(a.x * b, a.y * b, a.z * b)

proc xy*(v: Vec3): Vec2 = vec2(v.x, v.y)
proc extend*(v: Vec2, z: float32): Vec3 = vec3(v.x, v.y, z)
proc length*(v: Vec2): float32 = stdmath.sqrt(v.x * v.x + v.y * v.y)
proc normalized*(v: Vec2): Vec2 =
  let len = v.length
  if len <= 0'f32: vec2(0, 0) else: v / len

proc minScalar(a, b: float32): float32 =
  if a < b: a else: b

proc maxScalar(a, b: float32): float32 =
  if a > b: a else: b

proc clamp*(value, minValue, maxValue: float32): float32 =
  let lo = minScalar(minValue, maxValue)
  let hi = maxScalar(minValue, maxValue)
  if value < lo: lo
  elif value > hi: hi
  else: value

proc lerp*(a, b, t: float32): float32 =
  a + (b - a) * t

proc min*(a, b: Vec2): Vec2 = vec2(minScalar(a.x, b.x), minScalar(a.y, b.y))
proc max*(a, b: Vec2): Vec2 = vec2(maxScalar(a.x, b.x), maxScalar(a.y, b.y))

proc rect*(min, max: Vec2): Rect = Rect(min: min, max: max)
proc rectCenterRadius*(center: Vec2, radius: float32): Rect =
  Rect(min: center - vec2(radius), max: center + vec2(radius))

proc center*(r: Rect): Vec2 = (r.min + r.max) * 0.5'f32
proc size*(r: Rect): Vec2 = r.max - r.min
proc contains*(r: Rect, p: Vec2): bool =
  p.x >= r.min.x and p.y >= r.min.y and p.x <= r.max.x and p.y <= r.max.y

proc overlaps*(a, b: Rect): bool =
  not (a.min.x > b.max.x or a.max.x < b.min.x or
       a.min.y > b.max.y or a.max.y < b.min.y)

proc overlap*(a, b: Rect): Vec2 =
  (a.max - b.min).min(b.max - a.min)

const
  Vec2Zero* = Vec2(x: 0, y: 0)
  Vec2One* = Vec2(x: 1, y: 1)
  Vec3Zero* = Vec3(x: 0, y: 0, z: 0)
