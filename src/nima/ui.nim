import std/[sequtils, strutils, unicode]
import ./[color, draw, facade, math, transform]

type
  UiRect* = Rect

  Insets* = object
    left*, right*, top*, bottom*: float32

  ContentAlign* = enum
    caTopLeft, caTop, caTopRight,
    caLeft, caCenter, caRight,
    caBottomLeft, caBottom, caBottomRight

  PanelStyle* = object
    fill*: Color
    border*: Color
    borderThickness*: float32

  ButtonStyle* = object
    fill*: Color
    hoverFill*: Color
    textColor*: Color
    textSize*: float32

  LabelStyle* = object
    color*: Color
    size*: float32
    align*: ContentAlign

  Panel* = object
    bounds*: UiRect
    style*: PanelStyle

  Button* = object
    bounds*: UiRect
    label*: string
    style*: ButtonStyle

  Label* = object
    bounds*: UiRect
    content*: string
    style*: LabelStyle

proc uiRect*(min, max: Vec2): UiRect = rect(min, max)
proc uiRectFromCenterSize*(center, size: Vec2): UiRect =
  rect(center - size * 0.5'f32, center + size * 0.5'f32)

proc insets*(all: float32): Insets =
  Insets(left: all, right: all, top: all, bottom: all)

proc insets*(horizontal, vertical: float32): Insets =
  Insets(left: horizontal, right: horizontal, top: vertical, bottom: vertical)

proc insets*(left, right, top, bottom: float32): Insets =
  Insets(left: left, right: right, top: top, bottom: bottom)

proc inset*(bounds: UiRect, value: Insets): UiRect =
  rect(vec2(bounds.min.x + value.left, bounds.min.y + value.bottom),
       vec2(bounds.max.x - value.right, bounds.max.y - value.top))

proc splitTop*(bounds: UiRect, height: float32, gap = 0'f32): tuple[top, rest: UiRect] =
  let topMinY = bounds.max.y - height
  result.top = rect(vec2(bounds.min.x, topMinY), bounds.max)
  result.rest = rect(bounds.min, vec2(bounds.max.x, topMinY - gap))

proc splitBottom*(bounds: UiRect, height: float32, gap = 0'f32): tuple[bottom, rest: UiRect] =
  let bottomMaxY = bounds.min.y + height
  result.bottom = rect(bounds.min, vec2(bounds.max.x, bottomMaxY))
  result.rest = rect(vec2(bounds.min.x, bottomMaxY + gap), bounds.max)

proc splitLeft*(bounds: UiRect, width: float32, gap = 0'f32): tuple[left, rest: UiRect] =
  let leftMaxX = bounds.min.x + width
  result.left = rect(bounds.min, vec2(leftMaxX, bounds.max.y))
  result.rest = rect(vec2(leftMaxX + gap, bounds.min.y), bounds.max)

proc splitRight*(bounds: UiRect, width: float32, gap = 0'f32): tuple[right, rest: UiRect] =
  let rightMinX = bounds.max.x - width
  result.right = rect(vec2(rightMinX, bounds.min.y), bounds.max)
  result.rest = rect(bounds.min, vec2(rightMinX - gap, bounds.max.y))

proc rowsEqual*(bounds: UiRect, count: int, gap = 0'f32): seq[UiRect] =
  if count <= 0:
    return
  let h = (bounds.size.y - gap * (count - 1).float32) / count.float32
  for i in 0..<count:
    let yMax = bounds.max.y - i.float32 * (h + gap)
    result.add rect(vec2(bounds.min.x, yMax - h), vec2(bounds.max.x, yMax))

proc columns*(bounds: UiRect, widths: openArray[float32], gap = 0'f32): seq[UiRect] =
  var x = bounds.min.x
  for width in widths:
    result.add rect(vec2(x, bounds.min.y), vec2(x + width, bounds.max.y))
    x += width + gap

proc columnsEqual*(bounds: UiRect, count: int, gap = 0'f32): seq[UiRect] =
  if count <= 0:
    return
  let w = (bounds.size.x - gap * (count - 1).float32) / count.float32
  var x = bounds.min.x
  for _ in 0..<count:
    result.add rect(vec2(x, bounds.min.y), vec2(x + w, bounds.max.y))
    x += w + gap

proc cardPanelStyle*(): PanelStyle =
  PanelStyle(fill: rgba(0.12, 0.14, 0.18, 0.96),
             border: rgba(0.32, 0.36, 0.44, 0.9),
             borderThickness: 1)

proc filledButtonStyle*(fill: Color): ButtonStyle =
  ButtonStyle(fill: fill, hoverFill: fill.withAlpha(0.84),
              textColor: White, textSize: 16)

proc defaultLabelStyle*(): LabelStyle =
  LabelStyle(color: White, size: 16, align: caCenter)

proc withAlign*(style: LabelStyle, align: ContentAlign): LabelStyle =
  result = style
  result.align = align

proc withSize*(style: LabelStyle, size: float32): LabelStyle =
  result = style
  result.size = size

proc withColor*(style: LabelStyle, color: Color): LabelStyle =
  result = style
  result.color = color

proc panel*(bounds: UiRect, style = cardPanelStyle()): Panel =
  Panel(bounds: bounds, style: style)

proc button*(bounds: UiRect, label: string, style: ButtonStyle): Button =
  Button(bounds: bounds, label: label, style: style)

proc label*(bounds: UiRect, content: string,
            style = defaultLabelStyle()): Label =
  Label(bounds: bounds, content: content, style: style)

proc draw*(panel: Panel, z = 0'f32) =
  drawRect(panel.style.fill, panel.bounds.size, transform(panel.bounds.center.extend(z)))
  if panel.style.borderThickness > 0'f32 and panel.style.border.a > 0'f32:
    let b = panel.bounds
    let t = panel.style.borderThickness
    drawLine(vec2(b.min.x, b.min.y), vec2(b.max.x, b.min.y), t, panel.style.border, z + 0.01)
    drawLine(vec2(b.max.x, b.min.y), vec2(b.max.x, b.max.y), t, panel.style.border, z + 0.01)
    drawLine(vec2(b.max.x, b.max.y), vec2(b.min.x, b.max.y), t, panel.style.border, z + 0.01)
    drawLine(vec2(b.min.x, b.max.y), vec2(b.min.x, b.min.y), t, panel.style.border, z + 0.01)

proc draw*(button: Button, mouse: Vec2, z = 0'f32): bool =
  result = button.bounds.contains(mouse)
  let fill = if result: button.style.hoverFill else: button.style.fill
  drawRect(fill, button.bounds.size, transform(button.bounds.center.extend(z)))
  drawText(text(button.label, button.style.textSize, button.style.textColor),
           transform(button.bounds.center.extend(z + 0.01)))

proc labelPoint(bounds: UiRect, align: ContentAlign): tuple[pos, anchor: Vec2] =
  case align
  of caTopLeft:
    (vec2(bounds.min.x, bounds.max.y), vec2(0, 1))
  of caTop:
    (vec2(bounds.center.x, bounds.max.y), vec2(0.5, 1))
  of caTopRight:
    (bounds.max, vec2(1, 1))
  of caLeft:
    (vec2(bounds.min.x, bounds.center.y), vec2(0, 0.5))
  of caCenter:
    (bounds.center, vec2(0.5, 0.5))
  of caRight:
    (vec2(bounds.max.x, bounds.center.y), vec2(1, 0.5))
  of caBottomLeft:
    (bounds.min, vec2(0, 0))
  of caBottom:
    (vec2(bounds.center.x, bounds.min.y), vec2(0.5, 0))
  of caBottomRight:
    (vec2(bounds.max.x, bounds.min.y), vec2(1, 0))

proc runeWidth(rune: Rune, size: float32): float32 =
  let code = int32(rune)
  if code == 9:
    size * 1.2'f32
  elif code == 32:
    size * 0.35'f32
  elif code >= 0x2E80:
    size
  else:
    size * 0.58'f32

proc textWidth(content: string, size: float32): float32 =
  for rune in content.runes:
    result += rune.runeWidth(size)

proc pushWrappedLine(lines: var seq[string], line: var string) =
  lines.add line.strip()
  line.setLen 0

proc breakLongToken(lines: var seq[string], token: string,
                    maxWidth, size: float32) =
  var line = ""
  var width = 0'f32
  for rune in token.runes:
    let rw = rune.runeWidth(size)
    if line.len > 0 and width + rw > maxWidth:
      lines.add line
      line.setLen 0
      width = 0
    line.add $rune
    width += rw
  if line.len > 0:
    lines.add line

proc wrapText(content: string, maxWidth, size: float32): seq[string] =
  if maxWidth <= 0'f32:
    return
  for paragraph in content.splitLines():
    if paragraph.len == 0:
      result.add ""
      continue
    var line = ""
    for token in strutils.splitWhitespace(paragraph):
      if token.textWidth(size) > maxWidth:
        if line.len > 0:
          result.pushWrappedLine(line)
        result.breakLongToken(token, maxWidth, size)
        continue
      let candidate = if line.len == 0: token else: line & " " & token
      if candidate.textWidth(size) <= maxWidth:
        line = candidate
      else:
        result.pushWrappedLine(line)
        line = token
    if line.len > 0:
      result.pushWrappedLine(line)

proc fitEllipsis(line: string, maxWidth, size: float32): string =
  const suffix = "..."
  if suffix.textWidth(size) > maxWidth:
    return ""
  result = line.strip(chars = {' ', '.'})
  while result.len > 0 and (result & suffix).textWidth(size) > maxWidth:
    let runes = result.runes.toSeq()
    if runes.len <= 1:
      result.setLen 0
      break
    result.setLen(0)
    for i in 0 ..< runes.len - 1:
      result.add $runes[i]
    result = result.strip()
  result.add suffix

proc horizontalAnchor(align: ContentAlign): tuple[x: float32, anchorX: float32] =
  case align
  of caTopRight, caRight, caBottomRight:
    (1'f32, 1'f32)
  of caTop, caCenter, caBottom:
    (0.5'f32, 0.5'f32)
  else:
    (0'f32, 0'f32)

proc verticalMode(align: ContentAlign): float32 =
  case align
  of caBottomLeft, caBottom, caBottomRight:
    0'f32
  of caLeft, caCenter, caRight:
    0.5'f32
  else:
    1'f32

proc draw*(label: Label, z = 0'f32) =
  let lineHeight = max(1'f32, label.style.size * 1.18'f32)
  let maxLines = max(1, int(label.bounds.size.y / lineHeight))
  var lines = wrapText(label.content, label.bounds.size.x, label.style.size)
  if lines.len == 0:
    return
  if lines.len > maxLines:
    lines.setLen(maxLines)
    lines[maxLines - 1] = fitEllipsis(lines[maxLines - 1], label.bounds.size.x,
                                      label.style.size)

  let totalHeight = lineHeight * lines.len.float32
  let h = label.style.align.horizontalAnchor()
  let x = label.bounds.min.x + label.bounds.size.x * h.x
  let v = label.style.align.verticalMode()
  let topY =
    if v == 1'f32:
      label.bounds.max.y
    elif v == 0'f32:
      label.bounds.min.y + totalHeight
    else:
      label.bounds.center.y + totalHeight * 0.5'f32

  for i, line in lines:
    let y = topY - i.float32 * lineHeight
    drawText(text(line, label.style.size, label.style.color),
             transform(vec3(x, y, z)), vec2(h.anchorX, 1))
