import std/[dynlib, math as stdmath, strutils, tables, unicode]
import pkg/sdl3
import ../[assets, color, draw, math]

type
  TtfFont = pointer

  TtfInitProc = proc(): bool {.cdecl.}
  TtfQuitProc = proc() {.cdecl.}
  TtfOpenFontProc = proc(file: cstring, ptSize: cfloat): TtfFont {.cdecl.}
  TtfCloseFontProc = proc(font: TtfFont) {.cdecl.}
  TtfRenderTextBlendedProc = proc(font: TtfFont, text: cstring,
                                  length: csize_t,
                                  color: SDL_Color): ptr SDL_Surface {.cdecl.}
  TtfRenderGlyphBlendedProc = proc(font: TtfFont, ch: uint32,
                                   color: SDL_Color): ptr SDL_Surface {.cdecl.}
  TtfGetGlyphMetricsProc = proc(font: TtfFont, ch: uint32, minx, maxx, miny,
                                maxy, advance: ptr cint): bool {.cdecl.}
  TtfGetGlyphKerningProc = proc(font: TtfFont, previousCh, ch: uint32,
                                kerning: ptr cint): bool {.cdecl.}
  TtfGetFontAscentProc = proc(font: TtfFont): cint {.cdecl.}
  TtfGetFontLineSkipProc = proc(font: TtfFont): cint {.cdecl.}

  SdlGlyphEntry* = object
    hasImage*: bool
    src*: Rect
    minx*, maxx*, miny*, maxy*, advance*: float32

  SdlGlyphPlacement* = object
    src*: Rect
    dst*: Rect

  SdlGlyphAtlas* = ref object
    key*: string
    surface*: ptr SDL_Surface
    width*, height*: cint
    generation*: uint32
    cursorX, cursorY, rowHeight: cint
    glyphs: Table[int32, SdlGlyphEntry]

  SdlGlyphRun* = object
    atlas*: SdlGlyphAtlas
    glyphs*: seq[SdlGlyphPlacement]
    size*: Vec2

  SdlTtfState* = object
    triedLoad: bool
    initialized: bool
    lib: LibHandle
    ttfInit: TtfInitProc
    ttfQuit: TtfQuitProc
    ttfOpenFont: TtfOpenFontProc
    ttfCloseFont: TtfCloseFontProc
    ttfRenderTextBlended: TtfRenderTextBlendedProc
    ttfRenderGlyphBlended: TtfRenderGlyphBlendedProc
    ttfGetGlyphMetrics: TtfGetGlyphMetricsProc
    ttfGetGlyphKerning: TtfGetGlyphKerningProc
    ttfGetFontAscent: TtfGetFontAscentProc
    ttfGetFontLineSkip: TtfGetFontLineSkipProc
    fonts: Table[string, TtfFont]
    atlases: Table[string, SdlGlyphAtlas]

proc initSdlTtfState*(): SdlTtfState =
  result.fonts = initTable[string, TtfFont]()
  result.atlases = initTable[string, SdlGlyphAtlas]()

proc loadSymbol[T](lib: LibHandle, name: string): T =
  cast[T](symAddr(lib, name))

proc tryLoadLib(name: string): LibHandle =
  try:
    result = loadLib(name)
  except OSError:
    result = nil

proc ensureLoaded(state: var SdlTtfState): bool =
  if state.initialized:
    return true
  if state.triedLoad:
    return false
  state.triedLoad = true

  const names = [
    "libSDL3_ttf.0.dylib",
    "libSDL3_ttf.dylib",
    "/opt/homebrew/opt/sdl3_ttf/lib/libSDL3_ttf.0.dylib",
    "/opt/homebrew/opt/sdl3_ttf/lib/libSDL3_ttf.dylib",
    "/usr/local/opt/sdl3_ttf/lib/libSDL3_ttf.0.dylib",
    "/usr/local/opt/sdl3_ttf/lib/libSDL3_ttf.dylib",
    "SDL3_ttf.dll",
    "libSDL3_ttf.so.0",
    "libSDL3_ttf.so"
  ]
  for name in names:
    state.lib = tryLoadLib(name)
    if not state.lib.isNil:
      break
  if state.lib.isNil:
    return false

  state.ttfInit = loadSymbol[TtfInitProc](state.lib, "TTF_Init")
  state.ttfQuit = loadSymbol[TtfQuitProc](state.lib, "TTF_Quit")
  state.ttfOpenFont = loadSymbol[TtfOpenFontProc](state.lib, "TTF_OpenFont")
  state.ttfCloseFont = loadSymbol[TtfCloseFontProc](state.lib, "TTF_CloseFont")
  state.ttfRenderTextBlended =
    loadSymbol[TtfRenderTextBlendedProc](state.lib, "TTF_RenderText_Blended")
  state.ttfRenderGlyphBlended =
    loadSymbol[TtfRenderGlyphBlendedProc](state.lib, "TTF_RenderGlyph_Blended")
  state.ttfGetGlyphMetrics =
    loadSymbol[TtfGetGlyphMetricsProc](state.lib, "TTF_GetGlyphMetrics")
  state.ttfGetGlyphKerning =
    loadSymbol[TtfGetGlyphKerningProc](state.lib, "TTF_GetGlyphKerning")
  state.ttfGetFontAscent =
    loadSymbol[TtfGetFontAscentProc](state.lib, "TTF_GetFontAscent")
  state.ttfGetFontLineSkip =
    loadSymbol[TtfGetFontLineSkipProc](state.lib, "TTF_GetFontLineSkip")

  if state.ttfInit.isNil or state.ttfQuit.isNil or state.ttfOpenFont.isNil or
      state.ttfCloseFont.isNil or state.ttfRenderTextBlended.isNil:
    unloadLib(state.lib)
    state.lib = nil
    return false

  if not state.ttfInit():
    unloadLib(state.lib)
    state.lib = nil
    return false

  state.initialized = true
  echo "[Nima] SDL3_ttf available"
  true

proc shutdown*(state: var SdlTtfState) =
  for _, atlas in state.atlases.mpairs:
    if not atlas.isNil and not atlas.surface.isNil:
      SDL_DestroySurface(atlas.surface)
      atlas.surface = nil
  state.atlases.clear()
  if state.ttfCloseFont != nil:
    for _, font in state.fonts.mpairs:
      if not font.isNil:
        state.ttfCloseFont(font)
  state.fonts.clear()
  if state.initialized and state.ttfQuit != nil:
    state.ttfQuit()
  state.initialized = false
  if not state.lib.isNil:
    unloadLib(state.lib)
    state.lib = nil

proc available*(state: var SdlTtfState): bool =
  state.ensureLoaded()

proc fontKey(path: string, size: float32): string =
  path & "\0" & size.formatFloat(ffDecimal, 2)

proc openFont(state: var SdlTtfState, text: Text): TtfFont =
  if not text.hasFont or not state.ensureLoaded():
    return nil
  let font = fontAsset(text.font)
  if font.isNil or not font.loaded or font.resolvedPath.len == 0:
    return nil
  let key = fontKey(font.resolvedPath, text.size)
  if state.fonts.hasKey(key):
    return state.fonts[key]
  result = state.ttfOpenFont(font.resolvedPath.cstring, text.size.cfloat)
  if not result.isNil:
    state.fonts[key] = result

proc toSdlColor(color: Color): SDL_Color =
  let bytes = color.toRgba8
  SDL_Color(r: bytes[0], g: bytes[1], b: bytes[2], a: bytes[3])

proc lineHeight(text: Text): cint =
  max(1, stdmath.ceil(text.size * 1.25'f32).int).cint

proc fontAscent(state: SdlTtfState, font: TtfFont, text: Text): cint =
  if not state.ttfGetFontAscent.isNil:
    result = state.ttfGetFontAscent(font)
  if result <= 0:
    result = stdmath.ceil(text.size).int.cint

proc fontLineSkip(state: SdlTtfState, font: TtfFont, text: Text): cint =
  if not state.ttfGetFontLineSkip.isNil:
    result = state.ttfGetFontLineSkip(font)
  if result <= 0:
    result = text.lineHeight

proc atlasFor(state: var SdlTtfState, key: string): SdlGlyphAtlas =
  if state.atlases.hasKey(key):
    return state.atlases[key]
  result = SdlGlyphAtlas(
    key: key,
    width: 2048,
    height: 2048,
    cursorX: 1,
    cursorY: 1,
    rowHeight: 0,
    glyphs: initTable[int32, SdlGlyphEntry]()
  )
  result.surface = SDL_CreateSurface(result.width, result.height,
                                     SDL_PIXELFORMAT_RGBA32)
  if result.surface.isNil:
    return nil
  discard SDL_ClearSurface(result.surface, 0, 0, 0, 0)
  state.atlases[key] = result

proc fallbackAdvance(ch: int32, text: Text): float32 =
  if ch == 9:
    text.size * 1.2'f32
  elif ch == 32:
    text.size * 0.35'f32
  elif ch >= 0x2E80:
    text.size
  else:
    text.size * 0.58'f32

proc ensureGlyph(state: var SdlTtfState, atlas: SdlGlyphAtlas, font: TtfFont,
                 text: Text, ch: int32): SdlGlyphEntry =
  if atlas.isNil:
    return
  if atlas.glyphs.hasKey(ch):
    return atlas.glyphs[ch]

  var minx, maxx, miny, maxy, advance: cint
  if not state.ttfGetGlyphMetrics.isNil and
      state.ttfGetGlyphMetrics(font, ch.uint32, addr minx, addr maxx, addr miny,
                               addr maxy, addr advance):
    result.minx = minx.float32
    result.maxx = maxx.float32
    result.miny = miny.float32
    result.maxy = maxy.float32
    result.advance = advance.float32
  else:
    result.advance = fallbackAdvance(ch, text)

  if result.advance <= 0'f32:
    result.advance = fallbackAdvance(ch, text)

  if ch == 32 or ch == 9 or state.ttfRenderGlyphBlended.isNil:
    atlas.glyphs[ch] = result
    return result

  let white = SDL_Color(r: 255, g: 255, b: 255, a: 255)
  let glyphSurface = state.ttfRenderGlyphBlended(font, ch.uint32, white)
  if glyphSurface.isNil:
    atlas.glyphs[ch] = result
    return result
  defer: SDL_DestroySurface(glyphSurface)

  let padding: cint = 1
  let w = glyphSurface.w
  let h = glyphSurface.h
  if w <= 0 or h <= 0 or w + padding * 2 > atlas.width:
    atlas.glyphs[ch] = result
    return result

  if atlas.cursorX + w + padding > atlas.width:
    atlas.cursorX = padding
    atlas.cursorY += atlas.rowHeight + padding
    atlas.rowHeight = 0
  if atlas.cursorY + h + padding > atlas.height:
    atlas.glyphs[ch] = result
    return result

  discard SDL_SetSurfaceBlendMode(glyphSurface, SDL_BLENDMODE_BLEND)
  var dst = SDL_Rect(x: atlas.cursorX, y: atlas.cursorY, w: w, h: h)
  discard SDL_BlitSurface(glyphSurface, nil, atlas.surface, addr dst)
  result.hasImage = true
  result.src = rect(vec2(dst.x, dst.y), vec2(dst.x + dst.w, dst.y + dst.h))
  atlas.cursorX += w + padding
  atlas.rowHeight = max(atlas.rowHeight, h)
  inc atlas.generation
  atlas.glyphs[ch] = result

proc layoutGlyphRun*(state: var SdlTtfState, text: Text): SdlGlyphRun =
  if text.content.len == 0:
    return
  let font = state.openFont(text)
  if font.isNil or state.ttfRenderGlyphBlended.isNil or
      state.ttfGetGlyphMetrics.isNil:
    return
  let asset = fontAsset(text.font)
  if asset.isNil:
    return
  let key = fontKey(asset.resolvedPath, text.size)
  let atlas = state.atlasFor(key)
  if atlas.isNil:
    return

  result.atlas = atlas
  let ascent = state.fontAscent(font, text).float32
  let lineSkip = state.fontLineSkip(font, text).float32
  var x = 0'f32
  var y = 0'f32
  var maxWidth = 0'f32
  var previous = 0'i32

  for rune in text.content.runes:
    let ch = int32(rune)
    if ch == 13:
      continue
    if ch == 10:
      maxWidth = max(maxWidth, x)
      x = 0
      y += lineSkip
      previous = 0
      continue

    if previous != 0 and not state.ttfGetGlyphKerning.isNil:
      var kern: cint
      if state.ttfGetGlyphKerning(font, previous.uint32, ch.uint32, addr kern):
        x += kern.float32

    let glyph = state.ensureGlyph(atlas, font, text, ch)
    if glyph.hasImage:
      let gx = x + glyph.minx
      let gy = y + ascent - glyph.maxy
      result.glyphs.add SdlGlyphPlacement(
        src: glyph.src,
        dst: rect(vec2(gx, gy),
                  vec2(gx + glyph.src.size.x, gy + glyph.src.size.y))
      )
    x += glyph.advance
    previous = ch

  maxWidth = max(maxWidth, x)
  result.size = vec2(maxWidth, y + lineSkip)

proc renderTextSurface*(state: var SdlTtfState, text: Text): ptr SDL_Surface =
  if text.content.len == 0:
    return nil
  let font = state.openFont(text)
  if font.isNil:
    return nil

  var lines = text.content.splitLines()
  if lines.len == 0:
    lines.add ""

  var surfaces: seq[ptr SDL_Surface]
  var heights: seq[cint]
  var width: cint = 1
  var height: cint = 0
  let fallbackHeight = text.lineHeight
  let fg = text.color.toSdlColor

  for line in lines:
    if line.len == 0:
      surfaces.add nil
      heights.add fallbackHeight
      height += fallbackHeight
      continue

    let surface = state.ttfRenderTextBlended(font, line.cstring,
                                             line.len.csize_t, fg)
    surfaces.add surface
    if surface.isNil:
      heights.add fallbackHeight
      height += fallbackHeight
    else:
      width = max(width, surface.w)
      let h = max(fallbackHeight, surface.h)
      heights.add h
      height += h

  result = SDL_CreateSurface(width, max(1, height), SDL_PIXELFORMAT_RGBA32)
  if result.isNil:
    for surface in surfaces:
      if not surface.isNil:
        SDL_DestroySurface(surface)
    return nil

  discard SDL_ClearSurface(result, 0, 0, 0, 0)
  var y: cint = 0
  for i, surface in surfaces:
    if not surface.isNil:
      discard SDL_SetSurfaceBlendMode(surface, SDL_BLENDMODE_BLEND)
      var dst = SDL_Rect(x: 0, y: y, w: surface.w, h: surface.h)
      discard SDL_BlitSurface(surface, nil, result, addr dst)
      SDL_DestroySurface(surface)
    y += heights[i]
