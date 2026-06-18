import std/[os, tables]
import ./[draw, input, math, scene]
import ./atlas as atlasmod
import ./audio as audiomod
import ./diagnostics as diagnosticsmod
import ./imgui as imguimod
import ./light2d as light2dmod
import ./particles as particlesmod
import ./physics as physicsmod
import ./prefab as prefabmod

type
  Perf* = object
    fps*: float32
    drawCalls*: int
    batches*: int
    resourceUploads*: int
    assetsLoaded*: int
    assetsPending*: int
    frameMs*: float32
    updateMs*: float32
    drawMs*: float32
    presentMs*: float32

  SceneCommandKind = enum
    sckSet, sckReplace, sckPush, sckPop

  SceneStackEntry = object
    scene: Scene
    payload: ScenePayload

  SceneCommand = object
    kind: SceneCommandKind
    scene: Scene
    payload: ScenePayload

  Engine* = object
    timeReal*: float32
    time*: float32
    timeScale*: float32
    tick*: float32
    frame*: uint64
    perf*: Perf
    input*: InputState
    recorder*: FrameRecorder
    imgui*: imguimod.ImGuiState
    atlas*: atlasmod.AtlasState
    audio*: audiomod.AudioState
    diagnostics*: diagnosticsmod.DiagnosticsState
    particles*: particlesmod.ParticleState
    light2d*: light2dmod.Light2DState
    physics*: physicsmod.PhysicsState
    prefabs*: prefabmod.PrefabState
    viewSize*: Vec2
    screenSize*: Vec2
    dpiScale*: float32
    cameraPos*: Vec2
    cameraZoom*: float32
    importedAssetsAutoReload*: bool
    exitRequested*: bool
    importedAssetMtimes: Table[string, string]
    sceneStack: seq[SceneStackEntry]
    sceneQueue: seq[SceneCommand]

proc initEngine*(initialScene: Scene = nil, viewSize = vec2(800, 600)): Engine =
  result.timeScale = 1'f32
  result.input = initInputState()
  result.imgui = imguimod.initImGuiState()
  result.atlas = atlasmod.initAtlasState()
  result.audio = audiomod.initAudioState()
  result.diagnostics = diagnosticsmod.initDiagnosticsState()
  result.particles = particlesmod.initParticleState()
  result.light2d = light2dmod.initLight2DState()
  result.physics = physicsmod.initPhysicsState()
  result.prefabs = prefabmod.initPrefabState()
  result.viewSize = viewSize
  result.screenSize = viewSize
  result.dpiScale = 1
  result.cameraZoom = 1
  result.importedAssetMtimes = initTable[string, string]()
  if initialScene != nil:
    result.sceneQueue.add SceneCommand(kind: sckSet, scene: initialScene)

proc assetMtime(path: string): string =
  if fileExists(path):
    $getLastModificationTime(path)
  else:
    ""

proc collectImportedAssetMtimes(engine: Engine): Table[string, string] =
  result = initTable[string, string]()
  for path in atlasmod.atlasWatchedPaths(engine.atlas):
    result[path] = assetMtime(path)
  for path in prefabmod.prefabWatchedPaths(engine.prefabs):
    result[path] = assetMtime(path)

proc reloadImportedAssets*(engine: var Engine): int =
  result += atlasmod.reloadImportedAtlases(engine.atlas)
  result += prefabmod.reloadPrefabTemplates(engine.prefabs)
  engine.importedAssetMtimes = engine.collectImportedAssetMtimes()

proc setImportedAssetsAutoReload*(engine: var Engine, enabled: bool) =
  engine.importedAssetsAutoReload = enabled
  engine.importedAssetMtimes = engine.collectImportedAssetMtimes()

proc importedAssetsAutoReloadEnabled*(engine: Engine): bool =
  engine.importedAssetsAutoReload

proc pollImportedAssetsAutoReload(engine: var Engine) =
  if not engine.importedAssetsAutoReload:
    return
  let current = engine.collectImportedAssetMtimes()
  if engine.importedAssetMtimes.len == 0:
    engine.importedAssetMtimes = current
    return
  var changed = false
  if current.len != engine.importedAssetMtimes.len:
    changed = true
  else:
    for path, mtime in current:
      if engine.importedAssetMtimes.getOrDefault(path) != mtime:
        changed = true
        break
  if changed:
    discard engine.reloadImportedAssets()

proc topScene(engine: var Engine): Scene =
  if engine.sceneStack.len == 0: nil else: engine.sceneStack[^1].scene

proc queueSetScene*(engine: var Engine, scene: Scene, payload: ScenePayload = nil) =
  engine.sceneQueue.add SceneCommand(kind: sckSet, scene: scene, payload: payload)

proc queueReplaceScene*(engine: var Engine, scene: Scene, payload: ScenePayload = nil) =
  engine.sceneQueue.add SceneCommand(kind: sckReplace, scene: scene, payload: payload)

proc queuePushScene*(engine: var Engine, scene: Scene, payload: ScenePayload = nil) =
  engine.sceneQueue.add SceneCommand(kind: sckPush, scene: scene, payload: payload)

proc queuePopScene*(engine: var Engine, payload: ScenePayload = nil) =
  engine.sceneQueue.add SceneCommand(kind: sckPop, payload: payload)

proc installScene(engine: var Engine, scene: Scene, payload: ScenePayload = nil) =
  if scene == nil:
    return
  engine.sceneStack.add SceneStackEntry(scene: scene, payload: payload)
  scene.init()
  scene.onEnter()

proc cleanupTop(engine: var Engine) =
  if engine.sceneStack.len == 0:
    return
  let scene = engine.sceneStack[^1].scene
  scene.onExit()
  scene.cleanup()
  engine.sceneStack.setLen(engine.sceneStack.len - 1)

proc applySceneQueue*(engine: var Engine) =
  for command in engine.sceneQueue:
    case command.kind
    of sckSet:
      while engine.sceneStack.len > 0:
        engine.cleanupTop()
      engine.installScene(command.scene, command.payload)
    of sckReplace:
      engine.cleanupTop()
      engine.installScene(command.scene, command.payload)
    of sckPush:
      let current = engine.topScene()
      if current != nil:
        current.onPause()
      engine.installScene(command.scene, command.payload)
    of sckPop:
      engine.cleanupTop()
      if engine.sceneStack.len > 0:
        engine.sceneStack[^1].payload = command.payload
        engine.sceneStack[^1].scene.onResume()
  engine.sceneQueue.setLen 0

proc takeScenePayload*[T](engine: var Engine): T =
  if engine.sceneStack.len == 0:
    return default(T)
  let payload = engine.sceneStack[^1].payload
  if payload != nil:
    engine.sceneStack[^1].payload = nil
    return cast[T](payload)
  default(T)

proc requestExit*(engine: var Engine) =
  engine.exitRequested = true

proc stepFrame*(engine: var Engine, dt = 1'f32 / 60'f32) =
  engine.tick = dt * engine.timeScale
  engine.timeReal += dt
  engine.time += engine.tick
  engine.recorder.clear()
  engine.applySceneQueue()
  engine.pollImportedAssetsAutoReload()
  let scene = engine.topScene()
  if scene != nil:
    scene.update()
  physicsmod.update(engine.physics, engine.tick)
  particlesmod.update(engine.particles, engine.tick)
  engine.perf.fps = if dt > 0'f32: 1'f32 / dt else: 0'f32
  engine.perf.frameMs = dt * 1000'f32
  if scene != nil:
    scene.draw()
  particlesmod.draw(engine.particles, engine.recorder)
  light2dmod.drawOverlay(engine.light2d, engine.recorder, engine.viewSize)
  imguimod.runLayers(engine.imgui)
  diagnosticsmod.update(engine.diagnostics, engine.tick, engine.frame,
                        engine.perf.fps, engine.recorder.commands.len,
                        engine.perf.batches)
  diagnosticsmod.drawOverlay(engine.diagnostics, engine.recorder, engine.viewSize)
  engine.applySceneQueue()
  engine.perf.drawCalls = engine.recorder.commands.len
  inc engine.frame
  engine.input.endFrame()
