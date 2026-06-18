import std/[base64, math as stdmath, os, unittest]
import nima/prelude

type
  InitAction = enum
    iaJump

  TestScene = ref object of Scene
    inits: int
    updates: int
    draws: int

  ScopeInitScene = ref object of Scene
    inited: bool

  OverlayScene = ref object of Scene
    overlayTicks: int
  WidgetScene = ref object of Scene
    clicked: bool
    checked: bool
    value: float32
    choice: int
    textValue: string

  StackPayload = ref object of ScenePayload
    bonus: int

  StackParent = ref object of Scene
    updates: int
    resumed: bool
    bonus: int

  StackChild = ref object of Scene

  DiagnosticsScene = ref object of Scene
  ParticleScene = ref object of Scene
    emitter: ParticleEmitterId
  LightScene = ref object of Scene
  RuntimeSystemsScene = ref object of Scene
    audioInstance: AudioInstanceId
    body: Ent
    prefab: Ent
    atlas: AtlasHandle
    frameId: FrameId

proc closeEnough(a, b: float32): bool =
  let diff = a - b
  (if diff < 0'f32: -diff else: diff) < 0.0001'f32

proc closeEnough(a, b: Vec2): bool =
  closeEnough(a.x, b.x) and closeEnough(a.y, b.y)

method init(scene: TestScene) =
  inc scene.inits

method update(scene: TestScene) =
  inc scene.updates

method draw(scene: TestScene) =
  inc scene.draws
  drawRect(Red, vec2(10, 10), transform(vec3(0, 0, 0)))

method init(scene: ScopeInitScene) =
  scene.inited = true
  bindAction(iaJump, key(kcSpace))

method init(scene: OverlayScene) =
  imgui(proc() =
    inc scene.overlayTicks
  )

method init(scene: WidgetScene) =
  scene.value = 0.25
  imgui(proc() =
    if imguiBegin("Tools", vec2(16, 16), 180):
      imguiText("Hello")
      scene.clicked = scene.clicked or imguiButton("Click")
      discard imguiCheckbox("Enabled", scene.checked)
      discard imguiSliderFloat("Speed", scene.value, 0, 1)
      imguiSeparator()
      imguiProgressBar(scene.value, "Progress")
      imguiEnd()
  )

method update(scene: StackParent) =
  inc scene.updates
  if scene.updates == 1:
    pushScene(StackChild(), StackPayload(bonus: 7))
  elif scene.resumed:
    let payload = takeScenePayload[StackPayload]()
    if payload != nil:
      scene.bonus = payload.bonus

method onResume(scene: StackParent) =
  scene.resumed = true

method update(scene: StackChild) =
  popScene(StackPayload(bonus: 7))

method init(scene: DiagnosticsScene) =
  setDiagnosticsOverlay(true)
  setDiagnosticsOverlayRefreshInterval(0.05)

method draw(scene: DiagnosticsScene) =
  drawRect(Black, viewSize(), transform(vec3(0, 0, -1)))

method init(scene: ParticleScene) =
  scene.emitter = particlesCreateEmitter(ParticleEmitterConfig(
    position: vec2(0, 0),
    z: 0.1,
    maxParticles: 16,
    spawnRate: 0,
    lifetime: particleRange(1, 1),
    speed: particleRange(10, 10),
    direction: vec2(0, 1),
    spreadRadians: 0,
    acceleration: vec2(0, 0),
    damping: 1,
    sizeStart: 4,
    sizeEnd: 2,
    colorStart: White,
    colorEnd: Transparent,
    sprite: defaultParticleSprite()
  ))
  discard particlesEmit(scene.emitter, 3)

method init(scene: LightScene) =
  light2dSetSettings(Light2DSettings(enabled: true, overlayZ: 760,
    ambient: rgba(0, 0, 0, 0.5), shadowColor: Black, shadowLength: 1000))
  discard light2dAddOccluderRect(LightOccluder2DRect(center: vec2(0, 0), size: vec2(10, 10)))
  discard light2dAddLight(Light2D(position: vec2(0, 0), radius: 20,
                                  color: White, intensity: 1, softness: 0.5))

method init(scene: RuntimeSystemsScene) =
  let clip = loadAudio("audio/test.ogg")
  scene.audioInstance = audioPlay(clip, defaultAudioPlayParams().withBus(abSfx).withVolume(0.5))
  scene.body = ent(77)
  discard physicsInsertBody(scene.body,
    PhysicsBodyDesc(kind: pbDynamic, position: vec2(0, 20), velocity: vec2(0, 0), gravityScale: 1),
    physicsCollider(cuboid(vec2(5, 5))))
  scene.prefab = spawnPrefab("prefabs/test.ron", vec2(10, 10), vec2(12, 12), Red)
  scene.atlas = loadAtlas("atlas.test")
  scene.frameId = atlasClip(scene.atlas, "idle")[0]

method draw(scene: RuntimeSystemsScene) =
  discard drawPrefab(scene.prefab)
  discard drawAtlasFrame(scene.atlas, scene.frameId, transform(vec3(30, 10, 0.2)), Blue)

suite "core value types":
  test "rect contains and overlaps":
    let a = rect(vec2(0, 0), vec2(10, 10))
    let b = rect(vec2(5, 5), vec2(15, 15))
    check a.contains(vec2(1, 1))
    check a.overlaps(b)
    check a.center == vec2(5, 5)

  test "color byte conversion":
    check rgba8(255, 128, 0, 255).toRgba8 == [255'u8, 128'u8, 0'u8, 255'u8]

  test "transform bounds":
    let b = transform(vec3(0, 0, 0)).bounds(vec2(0.5, 0.5), vec2(10, 20))
    check b.min == vec2(-5, -10)
    check b.max == vec2(5, 10)

  test "transform corners and rotated bounds":
    let t = transform(vec3(0, 0, 0), angle = stdmath.PI.float32 * 0.5'f32)
    let corners = t.corners(vec2(0.5, 0.5), vec2(10, 20))
    check corners[0].closeEnough(vec2(10, -5))
    check corners[1].closeEnough(vec2(10, 5))
    check corners[2].closeEnough(vec2(-10, 5))
    check corners[3].closeEnough(vec2(-10, -5))
    let b = t.bounds(vec2(0.5, 0.5), vec2(10, 20))
    check b.min.closeEnough(vec2(-10, -5))
    check b.max.closeEnough(vec2(10, 5))

  test "tween applies and resets transient transform offsets":
    var tween = initTween()
    let base = transform(vec3(10, 20, 0), angle = 0)
    tween.addShake(8, 1, 6, seed = 42)
    tween.addRotationPunch(vec2(0, 1), duration = 1, vibration = 6, elasticity = 0.5)
    let shaken = tween.apply(0.1, base)
    check tween.active
    check not shaken.pos.xy.closeEnough(base.pos.xy)
    check shaken.angle != base.angle
    let reset = tween.reset(shaken)
    check reset.pos.xy.closeEnough(base.pos.xy)
    check reset.angle.closeEnough(base.angle)
    check not tween.active

  test "text layout estimates size and records layout draw":
    let preview = text("Hello\n世界", 20, White)
    let measured = measureText(preview)
    check measured.x >= 40
    check measured.y == 48
    var engine = initEngine()
    discard withEngineScope(engine, proc(): bool =
      drawTextLayout(layoutText(preview), transform(Vec3Zero))
      check engine.recorder.commands.len == 1
      check engine.recorder.commands[0].kind == dckText
      true
    )

  test "asset handles track resolved load status":
    let path = getTempDir() / "nima_asset_probe.txt"
    writeFile(path, "ok")
    let texture = loadTexture(path)
    check texture.isLoaded
    check texture.textureAsset.resolvedPath == path
    let missing = loadAudio("missing/audio.wav")
    check missing.isValid
    check not missing.isLoaded

  test "asset roots resolve packaged relative paths":
    let root = getTempDir() / "nima_assets_root"
    createDir(root)
    let path = root / "hero.bmp"
    writeFile(path, "bmp")
    setAssetRoots([root])
    check resolveAssetPath("hero.bmp") == path
    let texture = loadTexture("hero.bmp")
    check texture.isLoaded
    check texture.textureAsset.resolvedPath == path
    setAssetRoots(["assets"])

  test "image loader decodes png to rgba pixels":
    let path = getTempDir() / "nima_probe.png"
    writeFile(path, decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII="))
    let image = loadImageRgba(path)
    check image.width == 1
    check image.height == 1
    check image.pixels.len == 4

  test "map bounds, tile lookup, and draw commands":
    let tileset = sprite(newHandle[Texture](), ivec2(64, 32))
    let level = map("demo", ivec2(2, 2), 16, tileset, [
      tile(0, vec2(0, 0)),
      tile(1, vec2(16, 0), flipX = true),
      tile(2, vec2(0, 16), flipY = true),
      tile(3, vec2(16, 16))
    ])
    check level.bounds == vec2(32, 32)
    check level.tileIndex(1, 1) == 3
    check level.tileIndex(2, 0) == -1
    check level.tileAt(1, 0).tileId == 1
    check level.worldToTile(vec2(17, 3)) == ivec2(1, 0)
    var recorder: FrameRecorder
    recorder.draw(level, offset = vec2(4, 5), z = 0.7)
    check recorder.commands.len == 4
    check recorder.commands[1].kind == dckSprite
    check recorder.commands[1].sprite.hasSrc
    check recorder.commands[1].sprite.flipX
    check recorder.commands[2].sprite.flipY
    check recorder.commands[3].transform.pos == vec3(20, 21, 0.7)

suite "input":
  type Action = enum left, right

  test "action edges reset":
    var input = initInputState()
    input.bindAction(left, key(kcLeft))
    input.setKeyDown(kcLeft, true)
    check input.actionDown(left)
    check not input.actionUp(left)
    check input.actionJustPressed(left)
    input.endFrame()
    check input.actionDown(left)
    check not input.actionJustPressed(left)

  test "gamepad button actions use button edges":
    var input = initInputState()
    input.bindAction(left, gamepadButton(gpbDpadLeft))
    input.setGamepadButtonDown(3, gpbDpadLeft, true)
    check input.actionDown(left)
    check input.actionJustPressed(left)
    check input.gamepadButtonDown(gpbDpadLeft)
    input.endFrame()
    check input.actionDown(left)
    check not input.actionJustPressed(left)
    input.setGamepadButtonDown(3, gpbDpadLeft, false)
    check input.actionJustReleased(left)

  test "gamepad axis actions honor deadzone and threshold":
    var input = initInputState()
    input.setGamepadDeadzone(0.25)
    input.bindAction(left, gamepadAxis(gpaLeftX, gadNegative, threshold = 0.5))
    input.setGamepadAxisValue(7, gpaLeftX, -0.2)
    check input.gamepadAxisValue(gpaLeftX) == 0
    check not input.actionDown(left)
    input.setGamepadAxisValue(7, gpaLeftX, -0.75)
    check input.actionDown(left)
    check input.actionJustPressed(left)
    input.endFrame()
    check input.actionDown(left)
    check not input.actionJustPressed(left)
    input.setGamepadAxisValue(7, gpaLeftX, -0.1)
    check input.actionJustReleased(left)

  test "text input accumulates for one frame":
    var input = initInputState()
    input.addTextInput("你")
    input.addTextInput("好")
    check input.textInput == "你好"
    input.endFrame()
    check input.textInput == ""

suite "engine":
  test "headless frame runs scene and records draw":
    let scene = TestScene()
    var engine = initEngine(scene)
    discard withEngineScope(engine, proc(): bool =
      engine.stepFrame()
      true
    )
    check scene.inits == 1
    check scene.updates == 1
    check scene.draws == 1
    check engine.recorder.commands.len == 1

  test "line batch and pattern APIs record commands":
    var engine = initEngine()
    discard withEngineScope(engine, proc(): bool =
      let a = line(vec2(0, 0), vec2(10, 0), 2, Red)
      let b = line(vec2(0, 2), vec2(10, 2), 3, Blue)
      drawLines([a, b], 0.2)
      drawLineEx(line(vec2(0, 4), vec2(10, 4), 1, Yellow), 0.3,
                 dashedLinePattern(4, 2), 1)
      check engine.recorder.commands.len == 3
      check engine.recorder.commands[2].line.pattern.kind == lpkDashed
      check engine.recorder.commands[2].line.patternOffset == 1
      true
    )

  test "scene init runs inside facade scope":
    let scene = ScopeInitScene()
    var engine = initEngine(scene)
    discard withEngineScope(engine, proc(): bool =
      engine.stepFrame()
      true
    )
    check scene.inited

  test "scene stack returns payload":
    let scene = StackParent()
    var engine = initEngine(scene)
    discard withEngineScope(engine, proc(): bool =
      engine.stepFrame()
      engine.stepFrame()
      engine.stepFrame()
      true
    )
    check scene.resumed
    check scene.bonus == 7

  test "facade fails outside engine scope":
    expect ValueError:
      discard time()

  test "camera conversion and ui draw space":
    var engine = initEngine()
    discard withEngineScope(engine, proc(): bool =
      setCameraPos(vec2(10, -5))
      setCameraZoom(2)
      check cameraPos() == vec2(10, -5)
      check cameraZoom() == 2
      check dpiScaleFactor() == 1
      setTimeScale(0.5)
      check timeScale() == 0.5
      check worldToScreen(vec2(12, -3)) == vec2(4, 4)
      check screenToWorld(vec2(4, 4)) == vec2(12, -3)
      drawRect(Red, vec2(10, 10), transform(vec3(0, 0, 0)))
      discard withUi(proc(): bool =
        drawText(text("HUD", 12, White), transform(vec3(0, 0, 1)))
        true
      )
      check engine.recorder.commands[0].space == dsWorld
      check engine.recorder.commands[1].space == dsUi
      true
    )

suite "imgui":
  test "registered overlay layer runs each frame":
    let scene = OverlayScene()
    var engine = initEngine(scene)
    discard withEngineScope(engine, proc(): bool =
      engine.stepFrame()
      engine.stepFrame()
      true
    )
    check scene.overlayTicks == 2

  test "immediate widgets record draw and handle mouse state":
    var engine = initEngine()
    var checked = false
    var value = 0.25'f32
    discard withEngineScope(engine, proc(): bool =
      engine.input.setMousePos(vec2(-294, 236))
      engine.input.setMouseDown(mbLeft, true)
      discard imguiBegin("Tools", vec2(16, 16), 180)
      check imguiButton("Click")
      check uiWantsPointerInput()
      imguiEnd()
      check engine.recorder.commands.len >= 4
      for command in engine.recorder.commands:
        check command.space == dsUi

      engine.input.endFrame()
      engine.recorder.clear()
      engine.input.setMouseDown(mbLeft, false)
      engine.input.setMousePos(vec2(-294, 236))
      engine.input.setMouseDown(mbLeft, true)
      discard imguiBegin("Tools", vec2(16, 16), 180)
      check imguiCheckbox("Enabled", checked)
      imguiEnd()
      check checked

      engine.input.endFrame()
      engine.recorder.clear()
      engine.input.setMouseDown(mbLeft, false)
      engine.input.setMousePos(vec2(-215, 224))
      engine.input.setMouseDown(mbLeft, true)
      discard imguiBegin("Tools", vec2(16, 16), 180)
      check imguiSliderFloat("Speed", value, 0, 1)
      imguiEnd()
      check value > 0.95'f32
      true
    )

  test "immediate advanced widgets edit scalar choices and text":
    var engine = initEngine()
    var choice = 0
    var combo = 0
    var textValue = ""
    var open = false
    discard withEngineScope(engine, proc(): bool =
      discard imguiBegin("Tools", vec2(16, 16), 240, 360)

      engine.input.setMousePos(vec2(-282, 233))
      engine.input.setMouseDown(mbLeft, true)
      check imguiRadioValue("Mode B", choice, 1)
      check choice == 1

      engine.input.endFrame()
      engine.recorder.clear()
      engine.input.setMouseDown(mbLeft, false)
      engine.input.setMousePos(vec2(-282, 203))
      engine.input.setMouseDown(mbLeft, true)
      check imguiCombo("Fruit", combo, ["Apple", "Banana", "Orange"])
      check combo == 1

      engine.input.endFrame()
      engine.recorder.clear()
      engine.input.setMouseDown(mbLeft, false)
      engine.input.setMousePos(vec2(-282, 167))
      engine.input.setMouseDown(mbLeft, true)
      check imguiCollapsingHeader("Tree", open)
      check open

      engine.input.endFrame()
      engine.recorder.clear()
      engine.input.setMouseDown(mbLeft, false)
      engine.input.setMousePos(vec2(-282, 127))
      engine.input.setMouseDown(mbLeft, true)
      discard imguiInputText("Name", textValue)
      check uiWantsKeyboardInput()

      engine.input.endFrame()
      engine.recorder.clear()
      engine.input.setMouseDown(mbLeft, false)
      engine.input.setKeyDown(kcA, true)
      check imguiInputText("Name", textValue)
      check textValue == "a"

      engine.input.endFrame()
      engine.recorder.clear()
      engine.input.setKeyDown(kcA, false)
      engine.input.setKeyDown(kcBackspace, true)
      check imguiInputText("Name", textValue)
      check textValue == ""

      engine.input.endFrame()
      engine.recorder.clear()
      engine.input.setKeyDown(kcBackspace, false)
      engine.input.addTextInput("你")
      check imguiInputText("Name", textValue)
      check textValue == "你"
      imguiEnd()
      true
    )

  test "immediate panels support same-line fixed-width items":
    var engine = initEngine()
    discard withEngineScope(engine, proc(): bool =
      engine.input.setMousePos(vec2(-360, 276))
      engine.input.setMouseDown(mbLeft, true)
      discard imguiBeginPanel(vec2(0, 0), 220, 48)
      check imguiButton("New", 60)
      imguiSameLine(4)
      check not imguiButton("View", 60)
      imguiEnd()
      check uiWantsPointerInput()

      engine.input.endFrame()
      engine.recorder.clear()
      engine.input.setMouseDown(mbLeft, false)
      engine.input.setMousePos(vec2(-296, 276))
      engine.input.setMouseDown(mbLeft, true)
      discard imguiBeginPanel(vec2(0, 0), 220, 48)
      check not imguiButton("New", 60)
      imguiSameLine(4)
      check imguiButton("View", 60)
      imguiEnd()
      true
    )

  test "immediate ui text can use configured font handle":
    let path = getTempDir() / "nima_ui_font_probe.ttf"
    writeFile(path, "not-a-real-font")
    let font = loadFont(path)
    var engine = initEngine()
    discard withEngineScope(engine, proc(): bool =
      setImguiFont(font)
      discard imguiBeginPanel(vec2(0, 0), 220, 80)
      imguiText("你好")
      imguiEnd()
      var found = false
      for command in engine.recorder.commands:
        if command.kind == dckText and command.text.content == "你好":
          found = true
          check command.text.hasFont
          check command.text.font == font
      check found
      true
    )

suite "ui layout":
  test "rect helpers split rows and columns":
    let root = uiRectFromCenterSize(Vec2Zero, vec2(400, 200))
    check root.size == vec2(400, 200)
    let inner = root.inset(insets(10))
    check inner.min == vec2(-190, -90)
    check inner.max == vec2(190, 90)
    let split = inner.splitTop(40, 5)
    check split.top.size == vec2(380, 40)
    check split.rest.max.y == 45
    let cols = split.top.columns([100'f32, 120], 8)
    check cols.len == 2
    check cols[0].size == vec2(100, 40)
    check cols[1].min.x == cols[0].max.x + 8
    let rows = split.rest.rowsEqual(2, 5)
    check rows.len == 2
    check rows[0].size.y == rows[1].size.y

  test "panel button and label draw through recorder":
    var engine = initEngine()
    discard withEngineScope(engine, proc(): bool =
      let root = uiRectFromCenterSize(Vec2Zero, vec2(200, 100))
      panel(root).draw(0.1)
      check button(root.inset(insets(20)), "OK", filledButtonStyle(Blue)).draw(Vec2Zero, 0.2)
      label(root, "Hello", defaultLabelStyle().withAlign(caBottomRight)).draw(0.3)
      check engine.recorder.commands.len >= 6
      true
    )

suite "engine systems":
  test "diagnostics overlay records draw commands":
    let scene = DiagnosticsScene()
    var engine = initEngine(scene)
    discard withEngineScope(engine, proc(): bool =
      engine.stepFrame()
      true
    )
    check engine.recorder.commands.len >= 3

  test "particles emit and draw":
    let scene = ParticleScene()
    var engine = initEngine(scene)
    var alive = 0
    discard withEngineScope(engine, proc(): bool =
      engine.stepFrame()
      alive = particlesAliveCount(scene.emitter)
      true
    )
    check alive == 3
    check engine.recorder.commands.len >= 3

  test "light2d stores lights and overlays":
    let scene = LightScene()
    var engine = initEngine(scene)
    var lights = 0
    var occluders = 0
    discard withEngineScope(engine, proc(): bool =
      engine.stepFrame()
      lights = light2dLightCount()
      occluders = light2dOccluderCount()
      true
    )
    check lights == 1
    check occluders == 1
    check engine.recorder.commands.len >= 2

  test "audio physics prefab atlas facade APIs work":
    let scene = RuntimeSystemsScene()
    var engine = initEngine(scene)
    var pose: PhysicsBodyPose
    var tag = ""
    var paused = false
    var active = 0
    var instancePaused = false
    discard withEngineScope(engine, proc(): bool =
      engine.stepFrame()
      pose = physicsSyncedBodyPose(scene.body)
      tag = prefabTag(scene.prefab)
      paused = audioPause(scene.audioInstance)
      active = audioActiveCount()
      instancePaused = audioInstance(scene.audioInstance).paused
      true
    )
    check paused
    check active == 1
    check instancePaused
    check pose.position.y < 20
    check tag == "prefabs/test.ron"
    check engine.recorder.commands.len >= 2

  test "physics query APIs return stable entities":
    let scene = RuntimeSystemsScene()
    var engine = initEngine(scene)
    discard withEngineScope(engine, proc(): bool =
      engine.stepFrame()
      let pose = physicsSyncedBodyPose(scene.body)
      let pointHits = physicsPointQuery(pose.position)
      check scene.body in pointHits
      let overlaps = physicsOverlapAabb(rect(vec2(-10, 0), vec2(10, 30)))
      check scene.body in overlaps
      let hits = physicsRaycast(vec2(0, 80), vec2(0, -1), 200)
      check hits.len >= 1
      check hits[0].ent == scene.body
      check physicsRemoveBody(scene.body)
      check not physicsHasBody(scene.body)
      true
    )

  test "physics layer filters constrain queries and collisions":
    let layerA = physicsLayers(0b0001'u32, uint32.high)
    let layerB = physicsLayers(0b0010'u32, uint32.high)
    let queryA = physicsLayers(uint32.high, 0b0001'u32)
    let queryB = physicsLayers(uint32.high, 0b0010'u32)
    let actorA = ent(201)
    let actorB = ent(202)
    let floor = ent(203)
    var engine = initEngine()
    discard withEngineScope(engine, proc(): bool =
      discard physicsInsertBody(actorA,
        PhysicsBodyDesc(kind: pbStatic, position: vec2(-10, 0), rotation: 0),
        physicsCollider(cuboid(vec2(5, 5))).withLayers(layerA))
      discard physicsInsertBody(actorB,
        PhysicsBodyDesc(kind: pbStatic, position: vec2(10, 0), rotation: 0),
        physicsCollider(cuboid(vec2(5, 5))).withLayers(layerB))
      check actorA in physicsPointQuery(vec2(-10, 0), queryA)
      check actorA notin physicsPointQuery(vec2(-10, 0), queryB)
      check actorB in physicsOverlapAabb(rect(vec2(0, -8), vec2(20, 8)), queryB)
      check actorA notin physicsOverlapAabb(rect(vec2(0, -8), vec2(20, 8)), queryB)
      let hits = physicsRaycast(vec2(-30, 0), vec2(1, 0), 80, queryB)
      check hits.len == 1
      check hits[0].ent == actorB

      discard physicsInsertBody(floor,
        PhysicsBodyDesc(kind: pbStatic, position: vec2(0, -20), rotation: 0),
        physicsCollider(cuboid(vec2(30, 4))).withLayers(physicsLayers(0b0100'u32, 0b0100'u32)))
      let falling = ent(204)
      discard physicsInsertBody(falling,
        PhysicsBodyDesc(kind: pbDynamic, position: vec2(0, -12), velocity: vec2(0, -80), gravityScale: 0),
        physicsCollider(cuboid(vec2(4, 4))).withLayers(physicsLayers(0b0001'u32, 0b0001'u32)))
      engine.stepFrame(1'f32 / 60'f32)
      check physicsTakeCollisionEvents().len == 0
      true
    )

  test "physics ball and collider offset participate in queries":
    var engine = initEngine()
    let offsetBall = ent(301)
    discard withEngineScope(engine, proc(): bool =
      discard physicsInsertBody(offsetBall,
        PhysicsBodyDesc(kind: pbStatic, position: vec2(10, 10), rotation: 0),
        physicsCollider(ball(6)).withOffset(vec2(20, 0)))
      check offsetBall in physicsPointQuery(vec2(30, 10))
      check offsetBall notin physicsPointQuery(vec2(10, 10))
      let hits = physicsRaycast(vec2(0, 10), vec2(1, 0), 60)
      check hits.len == 1
      check hits[0].ent == offsetBall
      true
    )

  test "atlas json descriptors create named clips":
    let scene = RuntimeSystemsScene()
    let path = getTempDir() / "nima_atlas_descriptor.json"
    writeFile(path, """{
      "frames": [
        {"name": "idle_a", "size": [20, 30], "color": [1, 0, 0, 1]},
        {"name": "idle_b", "size": [40, 50], "color": [0, 1, 0, 1]}
      ],
      "clips": {"idle": ["idle_a", "idle_b"]}
    }""")
    var engine = initEngine(scene)
    discard withEngineScope(engine, proc(): bool =
      engine.stepFrame()
      let atlas = loadAtlas(path)
      let frames = atlasClip(atlas, "idle")
      check frames.len == 2
      check atlasFrameId(atlas, "idle_b") == frames[1]
      let frame = atlasFrame(atlas, frames[1])
      check frame.size == vec2(40, 50)
      check drawAtlasFrame(atlas, frames[1], transform(vec3(0, 0, 0)), White)
      true
    )

  test "prefab json templates drive spawned instances":
    let path = getTempDir() / "nima_prefab_template.json"
    writeFile(path, """{
      "tag": "enemy",
      "size": [32, 44],
      "color": [0.2, 0.4, 0.8, 1]
    }""")
    var engine = initEngine()
    discard withEngineScope(engine, proc(): bool =
      check preloadPrefab(path)
      let actor = spawnPrefab(path, vec2(5, 7))
      let instance = prefabInstance(actor)
      check prefabTag(actor) == "enemy"
      check instance.size == vec2(32, 44)
      check instance.color == rgba(0.2, 0.4, 0.8, 1)
      check prefabInstanceCount() == 1
      check drawPrefab(actor)
      true
    )

  test "prefab ron-like templates and patch ops drive spawned instances":
    let path = getTempDir() / "nima_prefab_template.ron"
    writeFile(path, """(
      schema_version: 1,
      components: (
        tag: "player",
        sprite: (
          size: (24, 36),
          color: (0.1, 0.2, 0.3, 1.0),
        ),
      ),
    )""")
    var engine = initEngine()
    discard withEngineScope(engine, proc(): bool =
      check preloadPrefab(path)
      let actor = spawnPrefab(path)
      check prefabTag(actor) == "player"
      check prefabInstance(actor).size == vec2(24, 36)
      check prefabInstance(actor).color == rgba(0.1, 0.2, 0.3, 1)

      let patched = spawnPrefabWith(path, [
        prefabReplace("/components/tag", "patched"),
        prefabReplace("/components/sprite/size", vec2(40, 52)),
        prefabReplace("/components/sprite/color", rgba(0.8, 0.7, 0.2, 1))
      ])
      check prefabTag(patched) == "patched"
      check prefabInstance(patched).size == vec2(40, 52)
      check prefabInstance(patched).color == rgba(0.8, 0.7, 0.2, 1)

      let removed = spawnPrefabWith(path, [prefabRemove("/components/sprite/color")])
      check prefabInstance(removed).color == Yellow
      true
    )

  test "imported asset reload refreshes atlas descriptors and prefab templates":
    let atlasPath = getTempDir() / "nima_reload_atlas.json"
    writeFile(atlasPath, """{
      "frames": [{"name": "idle_a", "size": [20, 30], "color": [1, 0, 0, 1]}],
      "clips": {"idle": ["idle_a"]}
    }""")
    let prefabPath = getTempDir() / "nima_reload_prefab.json"
    writeFile(prefabPath, """{
      "tag": "enemy",
      "size": [16, 16],
      "color": [1, 0, 0, 1]
    }""")
    var engine = initEngine()
    discard withEngineScope(engine, proc(): bool =
      let atlas = loadAtlas(atlasPath)
      let frameA = atlasFrame(atlas, atlasFrameId(atlas, "idle_a"))
      check frameA.size == vec2(20, 30)
      let actor = spawnPrefab(prefabPath)
      check prefabTag(actor) == "enemy"
      check prefabInstance(actor).size == vec2(16, 16)

      writeFile(atlasPath, """{
        "frames": [{"name": "idle_b", "size": [80, 90], "color": [0, 1, 0, 1]}],
        "clips": {"idle": ["idle_b"]}
      }""")
      writeFile(prefabPath, """{
        "tag": "boss",
        "size": [32, 48],
        "color": [0, 0, 1, 1]
      }""")

      check reloadImportedAssets() == 2
      let frameB = atlasFrame(atlas, atlasFrameId(atlas, "idle_b"))
      check frameB.size == vec2(80, 90)
      check atlasClip(atlas, "idle").len == 1
      check prefabTag(actor) == "boss"
      check prefabInstance(actor).size == vec2(32, 48)
      check prefabInstance(actor).color == rgba(0, 0, 1, 1)
      setImportedAssetsAutoReload(true)
      check importedAssetsAutoReload()
      true
    )
