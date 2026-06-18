import std/[hashes, os, tables]

type
  Handle*[T] = object
    id*: uint32

  Texture* = ref object
    path*: string
    resolvedPath*: string
    loaded*: bool

  Font* = ref object
    path*: string
    resolvedPath*: string
    loaded*: bool

  AudioClip* = ref object
    path*: string
    resolvedPath*: string
    loaded*: bool

  Prefab* = ref object
    path*: string
    resolvedPath*: string
    loaded*: bool

var nextHandleId = 1'u32
var textures = initTable[uint32, Texture]()
var fonts = initTable[uint32, Font]()
var audioClips = initTable[uint32, AudioClip]()
var prefabs = initTable[uint32, Prefab]()
var roots = @["assets"]

proc newHandle*[T](): Handle[T] =
  result = Handle[T](id: nextHandleId)
  inc nextHandleId

proc isValid*[T](handle: Handle[T]): bool = handle.id != 0
proc `==`*[T](a, b: Handle[T]): bool = a.id == b.id
proc hash*[T](handle: Handle[T]): Hash = hash(handle.id)

proc assetRoots*(): seq[string] = @roots

proc setAssetRoots*(paths: openArray[string]) =
  roots.setLen 0
  for path in paths:
    if path.len > 0:
      roots.add path

proc addAssetRoot*(path: string) =
  if path.len > 0:
    roots.add path

proc clearAssetRoots*() =
  roots.setLen 0

proc resolveAssetPath*(path: string): string =
  if path.len == 0:
    return ""
  if fileExists(path):
    return path
  for root in roots:
    let candidate = root / path
    if fileExists(candidate):
      return candidate
  ""

proc loadTexture*(path: string): Handle[Texture] =
  result = newHandle[Texture]()
  let resolved = resolveAssetPath(path)
  textures[result.id] = Texture(path: path, resolvedPath: resolved, loaded: resolved.len > 0)

proc loadFont*(path: string): Handle[Font] =
  result = newHandle[Font]()
  let resolved = resolveAssetPath(path)
  fonts[result.id] = Font(path: path, resolvedPath: resolved, loaded: resolved.len > 0)

proc loadAudio*(path: string): Handle[AudioClip] =
  result = newHandle[AudioClip]()
  let resolved = resolveAssetPath(path)
  audioClips[result.id] = AudioClip(path: path, resolvedPath: resolved, loaded: resolved.len > 0)

proc loadPrefab*(path: string): Handle[Prefab] =
  result = newHandle[Prefab]()
  let resolved = resolveAssetPath(path)
  prefabs[result.id] = Prefab(path: path, resolvedPath: resolved, loaded: resolved.len > 0)

proc textureAsset*(handle: Handle[Texture]): Texture =
  textures.getOrDefault(handle.id)

proc fontAsset*(handle: Handle[Font]): Font =
  fonts.getOrDefault(handle.id)

proc audioAsset*(handle: Handle[AudioClip]): AudioClip =
  audioClips.getOrDefault(handle.id)

proc prefabAsset*(handle: Handle[Prefab]): Prefab =
  prefabs.getOrDefault(handle.id)

proc isLoaded*[T](handle: Handle[T]): bool =
  when T is Texture:
    textures.hasKey(handle.id) and textures[handle.id].loaded
  elif T is Font:
    fonts.hasKey(handle.id) and fonts[handle.id].loaded
  elif T is AudioClip:
    audioClips.hasKey(handle.id) and audioClips[handle.id].loaded
  elif T is Prefab:
    prefabs.hasKey(handle.id) and prefabs[handle.id].loaded
  else:
    handle.isValid
