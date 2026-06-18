import std/math as stdmath

type
  Color* = object
    r*, g*, b*, a*: float32

proc clamp01(v: float32): float32 =
  if v < 0'f32:
    0'f32
  elif v > 1'f32:
    1'f32
  else:
    v

proc rgba*[T, U, V, W: SomeNumber](r: T, g: U, b: V, a: W): Color =
  Color(r: r.float32, g: g.float32, b: b.float32, a: a.float32)

proc rgb*[T, U, V: SomeNumber](r: T, g: U, b: V): Color =
  rgba(r, g, b, 1)

proc rgba8*(r, g, b, a: uint8): Color =
  rgba(r.float32 / 255'f32, g.float32 / 255'f32, b.float32 / 255'f32, a.float32 / 255'f32)

proc rgb8*(r, g, b: uint8): Color = rgba8(r, g, b, 255'u8)

proc withAlpha*(c: Color, a: float32): Color =
  Color(r: c.r, g: c.g, b: c.b, a: clamp01(a))

proc toRgba8*(c: Color): array[4, uint8] =
  [
    uint8(stdmath.round(clamp01(c.r) * 255'f32)),
    uint8(stdmath.round(clamp01(c.g) * 255'f32)),
    uint8(stdmath.round(clamp01(c.b) * 255'f32)),
    uint8(stdmath.round(clamp01(c.a) * 255'f32))
  ]

const
  White* = Color(r: 1, g: 1, b: 1, a: 1)
  Black* = Color(r: 0, g: 0, b: 0, a: 1)
  Red* = Color(r: 1, g: 0, b: 0, a: 1)
  Green* = Color(r: 0, g: 1, b: 0, a: 1)
  Blue* = Color(r: 0, g: 0, b: 1, a: 1)
  Yellow* = Color(r: 1, g: 1, b: 0, a: 1)
  Transparent* = Color(r: 0, g: 0, b: 0, a: 0)
