import std/[json, os, strutils, tables]
import ./[assets, color, draw, ecs, math, transform]

type
  PrefabTemplate* = object
    path*: string
    sourcePath*: string
    tag*: string
    size*: Vec2
    color*: Color

  PrefabInstance* = object
    ent*: Ent
    templatePath*: string
    tag*: string
    pos*: Vec2
    size*: Vec2
    color*: Color

  PrefabPatchOpKind* = enum
    ppoAdd, ppoReplace, ppoRemove

  PrefabPatchOp* = object
    kind*: PrefabPatchOpKind
    path*: string
    value*: JsonNode

  PrefabState* = object
    nextEnt*: uint32
    templates*: Table[string, PrefabTemplate]
    instances*: seq[PrefabInstance]

proc initPrefabState*(): PrefabState =
  PrefabState(nextEnt: 1000, templates: initTable[string, PrefabTemplate]())

proc parseVec2(node: JsonNode, fallback: Vec2): Vec2 =
  if not node.isNil and node.kind == JArray and node.len >= 2:
    vec2(node[0].getFloat.float32, node[1].getFloat.float32)
  else:
    fallback

proc parseColor(node: JsonNode, fallback: Color): Color =
  if not node.isNil and node.kind == JArray and node.len >= 3:
    rgba(node[0].getFloat.float32, node[1].getFloat.float32,
         node[2].getFloat.float32,
         if node.len >= 4: node[3].getFloat.float32 else: 1'f32)
  else:
    fallback

proc defaultTemplate(path: string): PrefabTemplate =
  PrefabTemplate(path: path, tag: path, size: vec2(48, 48), color: Yellow)

proc extractRonScalar(source, key: string): string =
  let needle = key & ":"
  let start = source.find(needle)
  if start < 0:
    return ""
  let quote = source.find('"', start + needle.len)
  if quote < 0:
    return ""
  let stop = source.find('"', quote + 1)
  if stop < 0:
    return ""
  source[quote + 1 ..< stop]

proc extractRonNumbers(source, key: string): seq[float32] =
  let needle = key & ":"
  let start = source.find(needle)
  if start < 0:
    return
  let openParen = source.find('(', start + needle.len)
  let openBracket = source.find('[', start + needle.len)
  var openAt = -1
  var closeChar = ')'
  if openParen >= 0 and (openBracket < 0 or openParen < openBracket):
    openAt = openParen
    closeChar = ')'
  elif openBracket >= 0:
    openAt = openBracket
    closeChar = ']'
  if openAt < 0:
    return
  let closeAt = source.find(closeChar, openAt + 1)
  if closeAt < 0:
    return
  for raw in source[openAt + 1 ..< closeAt].split(','):
    let part = raw.strip()
    if part.len > 0:
      try:
        result.add parseFloat(part).float32
      except ValueError:
        discard

proc parseJsonTemplate(path, sourcePath: string; root: JsonNode): PrefabTemplate =
  result = defaultTemplate(path)
  result.sourcePath = sourcePath
  result.tag = root{"tag"}.getStr(result.tag)
  result.size = parseVec2(root{"size"}, result.size)
  result.color = parseColor(root{"color"}, result.color)

  let components = root{"components"}
  if not components.isNil and components.kind == JObject:
    result.tag = components{"tag"}.getStr(result.tag)
    let sprite = components{"sprite"}
    if not sprite.isNil and sprite.kind == JObject:
      result.size = parseVec2(sprite{"size"}, result.size)
      result.color = parseColor(sprite{"color"}, result.color)

proc parseRonLikeTemplate(path, sourcePath, source: string): PrefabTemplate =
  result = defaultTemplate(path)
  result.sourcePath = sourcePath
  let tag = extractRonScalar(source, "tag")
  if tag.len > 0:
    result.tag = tag
  let size = extractRonNumbers(source, "size")
  if size.len >= 2:
    result.size = vec2(size[0], size[1])
  let color = extractRonNumbers(source, "color")
  if color.len >= 3:
    result.color = rgba(color[0], color[1], color[2],
                        if color.len >= 4: color[3] else: 1'f32)

proc resolvePrefabPath(path: string): string =
  if fileExists(path):
    return path
  let direct = resolveAssetPath(path)
  if direct.len > 0:
    return direct
  let prefabs = resolveAssetPath("prefabs" / path)
  if prefabs.len > 0:
    return prefabs
  ""

proc parsePrefabTemplate(path, sourcePath: string): PrefabTemplate =
  result = defaultTemplate(path)
  result.sourcePath = sourcePath
  if sourcePath.len > 0 and fileExists(sourcePath):
    let source = readFile(sourcePath)
    try:
      result = parseJsonTemplate(path, sourcePath, parseJson(source))
    except JsonParsingError:
      result = parseRonLikeTemplate(path, sourcePath, source)

proc prefabValue(value: string): JsonNode = %value
proc prefabValue(value: Vec2): JsonNode = %*[value.x, value.y]
proc prefabValue(value: Color): JsonNode = %*[value.r, value.g, value.b, value.a]

proc prefabAdd*(path: string; value: string): PrefabPatchOp =
  PrefabPatchOp(kind: ppoAdd, path: path, value: prefabValue(value))

proc prefabAdd*(path: string; value: Vec2): PrefabPatchOp =
  PrefabPatchOp(kind: ppoAdd, path: path, value: prefabValue(value))

proc prefabAdd*(path: string; value: Color): PrefabPatchOp =
  PrefabPatchOp(kind: ppoAdd, path: path, value: prefabValue(value))

proc prefabReplace*(path: string; value: string): PrefabPatchOp =
  PrefabPatchOp(kind: ppoReplace, path: path, value: prefabValue(value))

proc prefabReplace*(path: string; value: Vec2): PrefabPatchOp =
  PrefabPatchOp(kind: ppoReplace, path: path, value: prefabValue(value))

proc prefabReplace*(path: string; value: Color): PrefabPatchOp =
  PrefabPatchOp(kind: ppoReplace, path: path, value: prefabValue(value))

proc prefabRemove*(path: string): PrefabPatchOp =
  PrefabPatchOp(kind: ppoRemove, path: path)

proc patchPath(path: string): string =
  path.strip().toLowerAscii().replace("\\", "/")

proc pathMatches(path: string; keys: openArray[string]): bool =
  let normalized = patchPath(path)
  for key in keys:
    if normalized == key or normalized.endsWith(key):
      return true

proc applyPatch(tpl: var PrefabTemplate; op: PrefabPatchOp) =
  let replaceValue = op.kind in {ppoAdd, ppoReplace}
  if op.path.pathMatches(["/tag", "/components/tag"]):
    if replaceValue:
      tpl.tag = op.value.getStr(tpl.tag)
    else:
      tpl.tag = tpl.path
  elif op.path.pathMatches(["/size", "/components/sprite/size"]):
    if replaceValue:
      tpl.size = parseVec2(op.value, tpl.size)
    else:
      tpl.size = vec2(48, 48)
  elif op.path.pathMatches(["/color", "/components/sprite/color"]):
    if replaceValue:
      tpl.color = parseColor(op.value, tpl.color)
    else:
      tpl.color = Yellow

proc loadPrefabTemplate*(state: var PrefabState, path: string): bool =
  if state.templates.hasKey(path):
    return true
  state.templates[path] = parsePrefabTemplate(path, resolvePrefabPath(path))
  true

proc prefabTemplate*(state: PrefabState, path: string): PrefabTemplate =
  state.templates.getOrDefault(path, defaultTemplate(path))

proc patchedTemplate(state: var PrefabState; path: string;
                     patchOps: openArray[PrefabPatchOp]): PrefabTemplate =
  discard state.loadPrefabTemplate(path)
  result = state.prefabTemplate(path)
  for op in patchOps:
    result.applyPatch(op)

proc spawnPrefab*(state: var PrefabState, path: string, pos = vec2(0, 0),
                  size = vec2(48, 48), color = Yellow): Ent =
  let tpl = state.patchedTemplate(path, [])
  result = ent(state.nextEnt)
  inc state.nextEnt
  let finalSize = if size == vec2(48, 48): tpl.size else: size
  let finalColor = if color == Yellow: tpl.color else: color
  state.instances.add PrefabInstance(ent: result, templatePath: path,
                                     tag: tpl.tag, pos: pos,
                                     size: finalSize, color: finalColor)

proc spawnPrefabWith*(state: var PrefabState, path: string,
                      patchOps: openArray[PrefabPatchOp],
                      pos = vec2(0, 0), size = vec2(48, 48),
                      color = Yellow): Ent =
  let tpl = state.patchedTemplate(path, patchOps)
  result = ent(state.nextEnt)
  inc state.nextEnt
  let finalSize = if size == vec2(48, 48): tpl.size else: size
  let finalColor = if color == Yellow: tpl.color else: color
  state.instances.add PrefabInstance(ent: result, templatePath: path,
                                     tag: tpl.tag, pos: pos,
                                     size: finalSize, color: finalColor)

proc reloadPrefabTemplate*(state: var PrefabState, path: string): bool =
  if not state.templates.hasKey(path):
    return false
  let current = state.templates[path]
  let sourcePath =
    if current.sourcePath.len > 0: current.sourcePath else: resolvePrefabPath(path)
  if sourcePath.len == 0 or not fileExists(sourcePath):
    return false
  let fresh = parsePrefabTemplate(path, sourcePath)
  state.templates[path] = fresh
  for instance in state.instances.mitems:
    if instance.templatePath == path:
      instance.tag = fresh.tag
      instance.size = fresh.size
      instance.color = fresh.color
  true

proc reloadPrefabTemplates*(state: var PrefabState): int =
  var paths: seq[string]
  for path, tpl in state.templates:
    if tpl.sourcePath.len > 0:
      paths.add path
  for path in paths:
    if state.reloadPrefabTemplate(path):
      inc result

proc prefabWatchedPaths*(state: PrefabState): seq[string] =
  for _, tpl in state.templates:
    if tpl.sourcePath.len > 0:
      result.add tpl.sourcePath

proc removePrefab*(state: var PrefabState, ent: Ent): bool =
  for i, instance in state.instances:
    if instance.ent == ent:
      state.instances.delete(i)
      return true
  false

proc prefabTag*(state: PrefabState, ent: Ent): string =
  for instance in state.instances:
    if instance.ent == ent:
      return instance.tag
  ""

proc prefabInstance*(state: PrefabState, ent: Ent): PrefabInstance =
  for instance in state.instances:
    if instance.ent == ent:
      return instance
  PrefabInstance()

proc prefabInstanceCount*(state: PrefabState): int =
  state.instances.len

proc setPrefabPose*(state: var PrefabState, ent: Ent, pos: Vec2): bool =
  for instance in state.instances.mitems:
    if instance.ent == ent:
      instance.pos = pos
      return true
  false

proc drawPrefab*(state: PrefabState, ent: Ent, recorder: var FrameRecorder): bool =
  for instance in state.instances:
    if instance.ent == ent:
      recorder.drawRect(instance.color, instance.size, transform(instance.pos.extend(0.5)))
      return true
  false

proc clear*(state: var PrefabState) =
  state.instances.setLen 0
