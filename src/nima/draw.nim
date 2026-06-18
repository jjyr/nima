import std/unicode
import ./[assets, color, math, transform]

type
  Sprite* = object
    texture*: Handle[Texture]
    src*: Rect
    hasSrc*: bool
    size*: IVec2
    color*: Color
    anchor*: Vec2
    flipX*, flipY*: bool

  Text* = object
    content*: string
    size*: float32
    color*: Color
    font*: Handle[Font]
    hasFont*: bool

  LaidOutText* = object
    text*: Text
    size*: Vec2

  Line* = object
    start*, stop*: Vec2
    thickness*: float32
    color*: Color
    pattern*: LinePattern
    patternOffset*: float32

  LinePatternKind* = enum
    lpkSolid, lpkDashed, lpkDotted

  LinePattern* = object
    kind*: LinePatternKind
    dashLength*: float32
    gapLength*: float32
    spacing*: float32

  DrawCommandKind* = enum
    dckSprite, dckRect, dckLine, dckCircle, dckText, dckPoly, dckPolyLines

  DrawSpace* = enum
    dsWorld, dsUi

  DrawCommand* = object
    kind*: DrawCommandKind
    space*: DrawSpace
    transform*: Transform
    color*: Color
    size*: Vec2
    anchor*: Vec2
    sprite*: Sprite
    text*: Text
    line*: Line
    center*: Vec3
    radius*: float32
    sides*: uint32
    rotation*: float32
    thickness*: float32
    z*: float32
    order*: uint64

  FrameRecorder* = object
    commands*: seq[DrawCommand]
    nextOrder*: uint64
    currentSpace*: DrawSpace

proc sprite*(texture: Handle[Texture], size: IVec2): Sprite =
  Sprite(texture: texture, size: size, color: White, anchor: vec2(0.5, 0.5))

proc withTile*(sprite: Sprite, tile: uint16, tileSize: Vec2, spacing = 0'f32, padding = 0'f32): Sprite =
  result = sprite
  let rawCols = int32((sprite.size.x.float32 - padding) / (tileSize.x + spacing))
  let cols = if rawCols < 1'i32: 1'i32 else: rawCols
  let row = int32(tile) div cols
  let col = int32(tile) mod cols
  let minPos = vec2(col.float32 * (tileSize.x + spacing) + padding,
                    row.float32 * (tileSize.y + spacing) + padding)
  result.src = rect(minPos, minPos + tileSize)
  result.hasSrc = true

proc text*(content: string, size: float32, color = White): Text =
  Text(content: content, size: size, color: color)

proc solidLinePattern*(): LinePattern =
  LinePattern(kind: lpkSolid)

proc dashedLinePattern*(dashLength, gapLength: float32): LinePattern =
  LinePattern(kind: lpkDashed, dashLength: dashLength, gapLength: gapLength)

proc dottedLinePattern*(spacing: float32): LinePattern =
  LinePattern(kind: lpkDotted, spacing: spacing)

proc line*(start, stop: Vec2, thickness: float32, color: Color): Line =
  Line(start: start, stop: stop, thickness: thickness, color: color,
       pattern: solidLinePattern())

proc withFont*(text: Text, font: Handle[Font]): Text =
  result = text
  result.font = font
  result.hasFont = font.isValid

proc glyphAdvance(rune: Rune, size: float32): float32 =
  let code = int32(rune)
  if code == 9:
    size * 1.2'f32
  elif code == 32:
    size * 0.35'f32
  elif code >= 0x2E80:
    size
  else:
    size * 0.58'f32

proc measureText*(text: Text): Vec2 =
  var lineWidth = 0'f32
  var maxWidth = 0'f32
  var lines = 1
  for rune in text.content.runes:
    if int32(rune) == 10:
      if lineWidth > maxWidth:
        maxWidth = lineWidth
      lineWidth = 0
      inc lines
    else:
      lineWidth += rune.glyphAdvance(text.size)
  if lineWidth > maxWidth:
    maxWidth = lineWidth
  vec2(maxWidth, text.size * 1.2'f32 * lines.float32)

proc layoutText*(text: Text): LaidOutText =
  LaidOutText(text: text, size: text.measureText())

proc clear*(recorder: var FrameRecorder) =
  recorder.commands.setLen 0
  recorder.nextOrder = 0
  recorder.currentSpace = dsWorld

proc pushSpace*(recorder: var FrameRecorder, space: DrawSpace): DrawSpace =
  result = recorder.currentSpace
  recorder.currentSpace = space

proc popSpace*(recorder: var FrameRecorder, previous: DrawSpace) =
  recorder.currentSpace = previous

proc push(recorder: var FrameRecorder, command: var DrawCommand) =
  command.space = recorder.currentSpace
  command.order = recorder.nextOrder
  inc recorder.nextOrder
  recorder.commands.add command

proc draw*(recorder: var FrameRecorder, sprite: Sprite, transform: Transform) =
  var cmd = DrawCommand(kind: dckSprite, sprite: sprite, transform: transform,
                        color: sprite.color, anchor: sprite.anchor, z: transform.pos.z)
  recorder.push cmd

proc drawRect*(recorder: var FrameRecorder, color: Color, size: Vec2,
               transform: Transform, anchor = vec2(0.5, 0.5)) =
  var cmd = DrawCommand(kind: dckRect, color: color, size: size, transform: transform,
                        anchor: anchor, z: transform.pos.z)
  recorder.push cmd

proc drawLine*(recorder: var FrameRecorder, start, stop: Vec2, thickness: float32,
               color: Color, z = 0'f32) =
  var cmd = DrawCommand(kind: dckLine, line: line(start, stop, thickness, color), z: z)
  recorder.push cmd

proc drawLineEx*(recorder: var FrameRecorder, line: Line, z: float32,
                 pattern: LinePattern, offset = 0'f32) =
  var styled = line
  styled.pattern = pattern
  styled.patternOffset = offset
  var cmd = DrawCommand(kind: dckLine, line: styled, z: z)
  recorder.push cmd

proc drawLines*(recorder: var FrameRecorder, lines: openArray[Line], z: float32) =
  for item in lines:
    var cmd = DrawCommand(kind: dckLine, line: item, z: z)
    recorder.push cmd

proc drawCircle*(recorder: var FrameRecorder, center: Vec3, radius: float32, color: Color) =
  var cmd = DrawCommand(kind: dckCircle, center: center, radius: radius,
                        color: color, z: center.z)
  recorder.push cmd

proc drawText*(recorder: var FrameRecorder, text: Text, transform: Transform,
               anchor = vec2(0.5, 0.5)) =
  var cmd = DrawCommand(kind: dckText, text: text, transform: transform,
                        anchor: anchor, color: text.color, z: transform.pos.z)
  recorder.push cmd

proc drawTextLayout*(recorder: var FrameRecorder, layout: LaidOutText,
                     transform: Transform, anchor = vec2(0.5, 0.5)) =
  recorder.drawText(layout.text, transform, anchor)

proc drawPoly*(recorder: var FrameRecorder, center: Vec3, sides: uint32,
               radius, rotation: float32, color: Color) =
  var cmd = DrawCommand(kind: dckPoly, center: center, sides: sides, radius: radius,
                        rotation: rotation, color: color, z: center.z)
  recorder.push cmd

proc drawPolyLines*(recorder: var FrameRecorder, center: Vec3, sides: uint32,
                    radius, rotation, thickness: float32, color: Color) =
  var cmd = DrawCommand(kind: dckPolyLines, center: center, sides: sides, radius: radius,
                        rotation: rotation, thickness: thickness, color: color, z: center.z)
  recorder.push cmd
