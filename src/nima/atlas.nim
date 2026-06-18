import std/[hashes, json, os, tables]
import ./[assets, color, draw, math, transform]

type
  AtlasHandle* = distinct uint32
  FrameId* = distinct uint32

  AtlasFrame* = object
    id*: FrameId
    name*: string
    size*: Vec2
    color*: Color

  AtlasData* = object
    handle*: AtlasHandle
    name*: string
    sourcePath*: string
    frames*: Table[string, FrameId]
    frameData*: Table[FrameId, AtlasFrame]
    clips*: Table[string, seq[FrameId]]

  AtlasState* = object
    nextId*: uint32
    nextFrameId*: uint32
    atlases*: Table[AtlasHandle, AtlasData]
    names*: Table[string, AtlasHandle]

proc `==`*(a, b: AtlasHandle): bool = uint32(a) == uint32(b)
proc `==`*(a, b: FrameId): bool = uint32(a) == uint32(b)
proc hash*(id: AtlasHandle): Hash = hash(uint32(id))
proc hash*(id: FrameId): Hash = hash(uint32(id))

proc initAtlasState*(): AtlasState =
  AtlasState(nextId: 1, nextFrameId: 1,
             atlases: initTable[AtlasHandle, AtlasData](),
             names: initTable[string, AtlasHandle]())

proc parseVec2(node: JsonNode, fallback: Vec2): Vec2 =
  if node.kind == JArray and node.len >= 2:
    vec2(node[0].getFloat.float32, node[1].getFloat.float32)
  else:
    fallback

proc parseColor(node: JsonNode, fallback: Color): Color =
  if node.kind == JArray and node.len >= 3:
    rgba(node[0].getFloat.float32, node[1].getFloat.float32,
         node[2].getFloat.float32,
         if node.len >= 4: node[3].getFloat.float32 else: 1'f32)
  else:
    fallback

proc allocFrame(state: var AtlasState, data: var AtlasData, name: string,
                size: Vec2, color: Color): FrameId =
  result = FrameId(state.nextFrameId)
  inc state.nextFrameId
  data.frames[name] = result
  data.frameData[result] = AtlasFrame(id: result, name: name, size: size, color: color)

proc defaultAtlas(state: var AtlasState, handle: AtlasHandle, name: string): AtlasData =
  result = AtlasData(handle: handle, name: name,
    frames: initTable[string, FrameId](),
    frameData: initTable[FrameId, AtlasFrame](),
    clips: initTable[string, seq[FrameId]]())
  let colors = [Red, Green, Blue, Yellow]
  for i in 0..<4:
    let id = state.allocFrame(result, "idle_" & $i,
                              vec2(48 + i.float32 * 12, 48 + i.float32 * 12),
                              colors[i])
    result.clips.mgetOrPut("idle", @[]).add id

proc loadAtlasFile(state: var AtlasState, handle: AtlasHandle, name, path: string): AtlasData =
  let root = parseFile(path)
  result = AtlasData(handle: handle, name: name,
    sourcePath: path,
    frames: initTable[string, FrameId](),
    frameData: initTable[FrameId, AtlasFrame](),
    clips: initTable[string, seq[FrameId]]())
  if root.hasKey("frames") and root["frames"].kind == JArray:
    for frame in root["frames"]:
      let frameName = frame{"name"}.getStr("")
      if frameName.len == 0:
        continue
      let size = parseVec2(frame{"size"}, vec2(48, 48))
      let color = parseColor(frame{"color"}, White)
      discard state.allocFrame(result, frameName, size, color)
  if root.hasKey("clips") and root["clips"].kind == JObject:
    for clipName, framesNode in root["clips"]:
      if framesNode.kind != JArray:
        continue
      for frameNode in framesNode:
        let frameName = frameNode.getStr("")
        if result.frames.hasKey(frameName):
          result.clips.mgetOrPut(clipName, @[]).add result.frames[frameName]
  if result.clips.len == 0 and result.frames.len > 0:
    for _, id in result.frames:
      result.clips.mgetOrPut("idle", @[]).add id

proc candidatePath(name: string): string =
  if fileExists(name):
    return name
  for path in [
    "atlas" / name & ".json",
    name & ".json",
    name
  ]:
    let resolved = resolveAssetPath(path)
    if resolved.len > 0:
      return resolved
  ""

proc loadAtlas*(state: var AtlasState, name: string): AtlasHandle =
  if state.names.hasKey(name):
    return state.names[name]
  result = AtlasHandle(state.nextId)
  inc state.nextId
  let path = candidatePath(name)
  let data =
    if path.len > 0: state.loadAtlasFile(result, name, path)
    else: state.defaultAtlas(result, name)
  state.atlases[result] = data
  state.names[name] = result

proc atlasSourcePath*(state: AtlasState, atlas: AtlasHandle): string =
  if not state.atlases.hasKey(atlas):
    return ""
  state.atlases[atlas].sourcePath

proc reloadAtlas*(state: var AtlasState, atlas: AtlasHandle): bool =
  if not state.atlases.hasKey(atlas):
    return false
  let current = state.atlases[atlas]
  if current.sourcePath.len == 0 or not fileExists(current.sourcePath):
    return false
  state.atlases[atlas] = state.loadAtlasFile(atlas, current.name, current.sourcePath)
  true

proc reloadImportedAtlases*(state: var AtlasState): int =
  var handles: seq[AtlasHandle]
  for handle, data in state.atlases:
    if data.sourcePath.len > 0:
      handles.add handle
  for handle in handles:
    if state.reloadAtlas(handle):
      inc result

proc atlasWatchedPaths*(state: AtlasState): seq[string] =
  for _, data in state.atlases:
    if data.sourcePath.len > 0:
      result.add data.sourcePath

proc atlasClip*(state: AtlasState, atlas: AtlasHandle, clip: string): seq[FrameId] =
  if not state.atlases.hasKey(atlas):
    return @[]
  state.atlases[atlas].clips.getOrDefault(clip)

proc atlasFrameId*(state: AtlasState, atlas: AtlasHandle, frame: string): FrameId =
  if not state.atlases.hasKey(atlas):
    return FrameId(0)
  state.atlases[atlas].frames.getOrDefault(frame, FrameId(0))

proc atlasFrame*(state: AtlasState, atlas: AtlasHandle, frame: FrameId): AtlasFrame =
  if not state.atlases.hasKey(atlas):
    return AtlasFrame()
  state.atlases[atlas].frameData.getOrDefault(frame)

proc drawAtlasFrame*(state: AtlasState, atlas: AtlasHandle, frame: FrameId,
                     transform: Transform, tint: Color,
                     recorder: var FrameRecorder): bool =
  let data = state.atlasFrame(atlas, frame)
  if uint32(data.id) == 0:
    return false
  recorder.drawRect(rgba(data.color.r * tint.r, data.color.g * tint.g,
                         data.color.b * tint.b, data.color.a * tint.a),
                    data.size, transform)
  true
