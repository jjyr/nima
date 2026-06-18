import std/math as stdmath
import nima/prelude

const
  MapRadius = 4'i32
  HexRadius = 48'f32
  HexSides = 6'u32
  HexRotation = 0.5235988'f32
  Sqrt3 = 1.7320508'f32

type
  HexTile = object
    axial: IVec2
    color: Color

  HexScene = ref object of Scene
    tiles: seq[HexTile]
    hovered: int
    coordText: string

proc axialToWorld(axial: IVec2): Vec2 =
  let q = axial.x.float32
  let r = axial.y.float32
  vec2(HexRadius * Sqrt3 * (q + 0.5'f32 * r),
       HexRadius * 1.5'f32 * r)

proc hexDistance(a, b: IVec2): int32 =
  let dq = abs(a.x - b.x)
  let dr = abs(a.y - b.y)
  let ds = abs(a.x + a.y - b.x - b.y)
  (dq + dr + ds) div 2

proc cubeRound(q, r: float32): IVec2 =
  let s = -q - r
  var rq = stdmath.round(q).int32
  var rr = stdmath.round(r).int32
  let rs = stdmath.round(s).int32
  let qDiff = abs(rq.float32 - q)
  let rDiff = abs(rr.float32 - r)
  let sDiff = abs(rs.float32 - s)
  if qDiff > rDiff and qDiff > sDiff:
    rq = -rr - rs
  elif rDiff > sDiff:
    rr = -rq - rs
  ivec2(rq, rr)

proc worldToAxial(pos: Vec2): IVec2 =
  let q = ((Sqrt3 / 3'f32) * pos.x - (1'f32 / 3'f32) * pos.y) / HexRadius
  let r = (2'f32 / 3'f32 * pos.y) / HexRadius
  cubeRound(q, r)

proc center(tile: HexTile): Vec2 = axialToWorld(tile.axial)

proc generateTiles(): seq[HexTile] =
  for q in -MapRadius..MapRadius:
    let rMin = max(-MapRadius, -q - MapRadius)
    let rMax = min(MapRadius, -q + MapRadius)
    for r in rMin..rMax:
      let axial = ivec2(q, r)
      let dist = hexDistance(axial, ivec2(0, 0)).float32 / MapRadius.float32
      let height = 1 - dist
      result.add HexTile(axial: axial,
        color: rgb(0.18 + 0.30 * height, 0.30 + 0.25 * height, 0.20 + 0.20 * height))

proc drawTile(tile: HexTile, hovered: bool) =
  var fill = tile.color
  if hovered:
    fill = rgb((fill.r + 0.20).clamp(0, 1), (fill.g + 0.20).clamp(0, 1),
               (fill.b + 0.10).clamp(0, 1))
  drawPoly(tile.center.extend(0.1), HexSides, HexRadius, HexRotation,
           fill.withAlpha(if hovered: 0.95 else: 0.70))
  drawPolyLines(tile.center.extend(if hovered: 0.4 else: 0.2), HexSides,
                HexRadius, HexRotation, if hovered: 4 else: 2,
                if hovered: Yellow else: rgb(0.2, 0.28, 0.35))

method init(scene: HexScene) =
  scene.tiles = generateTiles()
  scene.hovered = -1
  scene.coordText = "Move mouse to choose hex"

method update(scene: HexScene) =
  let axial = worldToAxial(mousePos())
  scene.hovered = -1
  for i, tile in scene.tiles:
    if tile.axial == axial:
      scene.hovered = i
      let s = -axial.x - axial.y
      scene.coordText = "Hex: q=" & $axial.x & " r=" & $axial.y & " s=" & $s
      return
  scene.coordText = "Move mouse to choose hex"

method draw(scene: HexScene) =
  let view = viewSize()
  drawRect(rgb(0.05, 0.06, 0.09), view, transform(vec3(0, 0, -0.9)))
  for i, tile in scene.tiles:
    drawTile(tile, i == scene.hovered)
  if scene.hovered >= 0:
    let tile = scene.tiles[scene.hovered]
    drawText(text($tile.axial.x & ", " & $tile.axial.y, 14, White),
             transform(tile.center.extend(0.5)))
  let half = view * 0.5'f32
  drawText(text("Nima Hex Map", 24, White),
           transform(vec3(-half.x + 20, half.y - 20, 0.95)), vec2(0, 1))
  drawText(text("q, r, s coordinates", 16, rgb(0.78, 0.80, 0.84)),
           transform(vec3(-half.x + 20, half.y - 50, 0.95)), vec2(0, 1))
  drawText(text(scene.coordText, 18, White),
           transform(vec3(-half.x + 20, half.y - 80, 0.95)), vec2(0, 1))

when isMainModule:
  run app(title = "Hex Map", size = ivec2(960, 720), scene = HexScene(),
          resizable = true,
          scaleMode = ScaleMode(kind: smFit, virtualSize: vec2(960, 720)))
