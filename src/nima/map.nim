import std/math as stdmath
import ./[draw, math, transform]

type
  Tile* = object
    tileId*: uint16
    dst*: Vec2
    flipX*, flipY*: bool

  Map* = object
    name*: string
    size*: IVec2
    tileSize*: float32
    distance*: float32
    foreground*: bool
    tileset*: Sprite
    data*: seq[Tile]

proc tile*(tileId: uint16; dst: Vec2; flipX = false; flipY = false): Tile =
  Tile(tileId: tileId, dst: dst, flipX: flipX, flipY: flipY)

proc map*(name: string; size: IVec2; tileSize: float32;
          tileset: Sprite; data: openArray[Tile];
          distance = 1'f32; foreground = false): Map =
  Map(name: name, size: size, tileSize: tileSize, distance: distance,
      foreground: foreground, tileset: tileset, data: @data)

proc bounds*(map: Map): Vec2 =
  vec2(map.tileSize * map.size.x.float32, map.tileSize * map.size.y.float32)

proc tileIndex*(map: Map; x, y: int): int =
  if x < 0 or y < 0 or x >= map.size.x.int or y >= map.size.y.int:
    -1
  else:
    y * map.size.x.int + x

proc tileAt*(map: Map; x, y: int): Tile =
  let index = map.tileIndex(x, y)
  if index < 0 or index >= map.data.len:
    Tile()
  else:
    map.data[index]

proc worldToTile*(map: Map; world: Vec2): IVec2 =
  ivec2(int32(stdmath.floor(world.x / map.tileSize)),
        int32(stdmath.floor(world.y / map.tileSize)))

proc draw*(recorder: var FrameRecorder; map: Map; offset = Vec2Zero;
           z = 0'f32) =
  for item in map.data:
    var sprite = map.tileset.withTile(item.tileId, vec2(map.tileSize, map.tileSize))
    sprite.flipX = item.flipX
    sprite.flipY = item.flipY
    sprite.anchor = vec2(0, 0)
    recorder.draw(sprite, transform((item.dst + offset).extend(z)))
