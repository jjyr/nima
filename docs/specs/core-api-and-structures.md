# Core API and Runtime Structures

This document defines the first public API shape for Nima, a Nim-native 2D game
engine inspired by Roast2D. Roast2D is the reference for capability and flow;
Nima should not copy Rust idioms when Nim has a clearer shape.

## Goals

- Keep the engine 2D-only in v1.
- Preserve the Roast2D feel: small `App`, scene callbacks, facade-first game
  code, immediate drawing, action-based input, simple asset handles.
- Use Nim-native constructs: `ref object`, `method`, `proc`, templates, object
  literals, and modules with explicit exports.
- Hide SDL3 and GPU details behind stable engine interfaces.
- Make desktop cross-platform support a first-class constraint: macOS, Linux,
  and Windows.

## Coordinate System

Nima world coordinates follow Roast2D:

- XY plane.
- X increases left to right.
- Y increases bottom to top.
- Origin is `(0.0, 0.0)`.
- Z is draw ordering, not 3D gameplay.
- Screen and SDL viewport coordinates are backend details and may use top-left
  origin internally.

The SDL3 backend must convert world/UI coordinates into SDL_GPU viewport and
clip space. User game code should never flip Y manually.

## Module Layout

Target public module layout:

```text
src/nima.nim                 # top-level export
src/nima/prelude.nim         # common game-facing exports
src/nima/app.nim             # App config and run
src/nima/engine.nim          # Engine state and frame lifecycle
src/nima/scene.nim           # Scene base type and scene stack
src/nima/facade.nim          # global/current-engine facade procs
src/nima/math.nim            # Vec2, Vec3, Rect helpers
src/nima/color.nim           # Color and color constants
src/nima/transform.nim       # Transform
src/nima/draw.nim            # draw commands and draw API types
src/nima/input.nim           # input state, key codes, actions
src/nima/assets.nim          # handles, asset manager, loaders
src/nima/diagnostics.nim     # perf overlay state
src/nima/imgui.nim           # immediate debug UI lifecycle/layout state
src/nima/audio.nim           # audio API and SDL WAV bridge state
src/nima/physics.nim         # simple AABB physics
src/nima/particles.nim       # CPU particle emitters
src/nima/light2d.nim         # light/occluder overlay data
src/nima/prefab.nim          # simple prefab instances
src/nima/atlas.nim           # atlas/clip facade
src/nima/map.nim             # tile maps and map draw helpers
src/nima/tween.nim           # transient shake/punch transform tweens
src/nima/hotreload.nim       # dynamic library hot reload host API
src/nima/backend/sdlrenderer.nim # SDL3 SDL_Renderer bootstrap backend
src/nima/backend/sdlgpu.nim  # SDL_GPU device/swapchain backend scaffold
```

The prelude exports the high-level API only. Backend modules remain internal
unless an advanced extension story is designed later.

## Public API Sketch

### App

`App` is a value object. Prefer a compact constructor plus named fields over a
Rust-style chained builder.

```nim
type
  AppPlatform* = enum
    apWindow

  ScaleModeKind* = enum
    smNone
    smFit
    smFill
    smStretch
    smPixelPerfect

  ScaleMode* = object
    kind*: ScaleModeKind
    virtualSize*: Vec2

  App* = object
    title*: string
    size*: IVec2
    platform*: AppPlatform
    vsync*: bool
    resizable*: bool
    fullscreen*: bool
    cursorVisible*: bool
    scaleMode*: ScaleMode
    assetRoots*: seq[string]
    initialScene*: Scene

proc app*(
  scene: Scene,
  title = "Hello Nima",
  size = ivec2(800, 600),
  vsync = true,
  resizable = false,
  fullscreen = false,
  cursorVisible = true,
  scaleMode = ScaleMode(kind: smFit, virtualSize: vec2(800, 600)),
  assetRoots: openArray[string] = ["assets"]
): App

proc run*(app: App)
```

`AppPlatform` starts with desktop `apWindow`. Web and terminal modes should not
be exposed until there is a real backend plan.

### Scene

Scenes are `ref object` types with overridable methods. This matches Nim object
orientation and avoids fake trait patterns.

```nim
type
  Scene* = ref object of RootObj

method init*(scene: Scene) {.base.} = discard
method onEnter*(scene: Scene) {.base.} = discard
method onPause*(scene: Scene) {.base.} = discard
method onResume*(scene: Scene) {.base.} = discard
method onExit*(scene: Scene) {.base.} = discard
method update*(scene: Scene) {.base.} = discard
method draw*(scene: Scene) {.base.} = discard
method cleanup*(scene: Scene) {.base.} = discard
```

Scene transitions are queued and applied at frame-safe boundaries.

```nim
proc setScene*(scene: Scene)
proc replaceScene*(scene: Scene)
proc pushScene*(scene: Scene)
proc popScene*()
```

Typed payloads are useful in Roast2D but should start simpler in Nima:

```nim
type ScenePayload* = ref object of RootObj

proc pushScene*(scene: Scene, payload: ScenePayload)
proc popScene*(payload: ScenePayload = nil)
proc takeScenePayload*[T](): T
```

`T` should be a `ScenePayload` subtype. The current implementation uses a
single payload slot per scene-stack entry and consumes it once.

### Facade

Facade procs operate on the current engine installed for the active frame.
Calling them outside an engine frame is a programmer error.

```nim
proc withEngine*[T](body: proc(engine: var Engine): T): T
proc time*(): float32
proc tick*(): float32
proc timeScale*(): float32
proc setTimeScale*(scale: float32)
proc frame*(): uint64
proc viewSize*(): Vec2
proc screenSize*(): Vec2
proc dpiScale*(): float32
proc dpiScaleFactor*(): float32
proc uiWantsPointerInput*(): bool
proc uiWantsKeyboardInput*(): bool
proc exit*()
proc cameraPos*(): Vec2
proc setCameraPos*(pos: Vec2)
proc cameraZoom*(): float32
proc setCameraZoom*(zoom: float32)
proc worldToScreen*(pos: Vec2): Vec2
proc screenToWorld*(pos: Vec2): Vec2
```

Game code should prefer facade procs. `withEngine` is reserved for advanced or
internal access.

### Math and Geometry

Use small value objects instead of depending on a large external math package in
the public API.

```nim
type
  Vec2* = object
    x*, y*: float32

  Vec3* = object
    x*, y*, z*: float32

  IVec2* = object
    x*, y*: int32

  Rect* = object
    min*, max*: Vec2

proc vec2*(x, y: float32): Vec2
proc vec3*(x, y, z: float32): Vec3
proc ivec2*(x, y: int32): IVec2
proc rectCenterRadius*(center: Vec2, radius: float32): Rect
proc center*(r: Rect): Vec2
proc size*(r: Rect): Vec2
proc contains*(r: Rect, p: Vec2): bool
proc overlaps*(a, b: Rect): bool
```

### Transform

Nima keeps Roast2D's split: transform controls position, rotation, and scale;
draw calls carry size. `angle` is stored in radians. Backends convert it to
their native representation at submission time.

```nim
type
  Transform* = object
    pos*: Vec3
    scale*: Vec2
    angle*: float32

proc transform*(pos: Vec3, scale = vec2(1, 1), angle = 0'f32): Transform
proc withPos*(t: Transform, pos: Vec3): Transform
proc withScale*(t: Transform, scale: Vec2): Transform
proc withAngle*(t: Transform, angle: float32): Transform
proc corners*(t: Transform, anchor, size: Vec2): array[4, Vec2]
proc bounds*(t: Transform, anchor, size: Vec2): Rect
```

`corners` returns the transformed quad in bottom-left, bottom-right, top-right,
top-left order before backend coordinate conversion. `bounds` returns the exact
axis-aligned bounds around those transformed corners.

### Color

Colors are linear engine values with helpers for byte input.

```nim
type
  Color* = object
    r*, g*, b*, a*: float32

proc rgb*(r, g, b: float32): Color
proc rgba*(r, g, b, a: float32): Color
proc rgb8*(r, g, b: uint8): Color
proc rgba8*(r, g, b, a: uint8): Color
proc withAlpha*(c: Color, a: float32): Color
```

Export common constants: `White`, `Black`, `Red`, `Green`, `Blue`, `Yellow`,
`Transparent`.

### Assets and Handles

Handles are lightweight ids. Asset loading is asynchronous-ready even if v1
loads synchronously.

```nim
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

proc loadTexture*(path: string): Handle[Texture]
proc loadFont*(path: string): Handle[Font]
proc loadAudio*(path: string): Handle[AudioClip]
proc loadPrefab*(path: string): Handle[Prefab]
proc isLoaded*[T](handle: Handle[T]): bool
proc resolveAssetPath*(path: string): string
proc assetRoots*(): seq[string]
proc setAssetRoots*(paths: openArray[string])
proc addAssetRoot*(path: string)
proc clearAssetRoots*()
```

Default asset root is `assets/` at the application root. `app(...,
assetRoots = [...])` installs roots before engine startup, and direct root
mutation APIs exist for tests and tools. The current registry tracks typed
handles, original path, resolved path, and loaded status. Decode and GPU upload
remain backend milestones.

### Sprites and Text

```nim
type
  Sprite* = object
    texture*: Handle[Texture]
    src*: Rect
    hasSrc*: bool
    size*: IVec2
    color*: Color
    anchor*: Vec2
    flipX*: bool
    flipY*: bool

  Text* = object
    content*: string
    size*: float32
    color*: Color
    font*: Handle[Font]
    hasFont*: bool

  LaidOutText* = object
    text*: Text
    size*: Vec2

proc sprite*(texture: Handle[Texture], size: IVec2): Sprite
proc withTile*(sprite: Sprite, tile: uint16, tileSize: Vec2, spacing = 0'f32, padding = 0'f32): Sprite
proc text*(content: string, size: float32, color = White): Text
proc withFont*(text: Text, font: Handle[Font]): Text
proc measureText*(text: Text): Vec2
proc layoutText*(text: Text): LaidOutText
```

### Drawing

Drawing is immediate from scene code. The engine records commands, sorts or
batches them, then submits to the SDL_GPU backend.

```nim
proc draw*(sprite: Sprite, transform: Transform)
proc drawRect*(color: Color, size: Vec2, transform: Transform, anchor = vec2(0.5, 0.5))
proc drawLine*(start, stop: Vec2, thickness: float32, color: Color, z = 0'f32)
proc drawLineEx*(line: Line, z: float32, pattern: LinePattern, offset = 0'f32)
proc drawLines*(lines: openArray[Line], z = 0'f32)
proc drawCircle*(center: Vec3, radius: float32, color: Color)
proc drawText*(text: Text, transform: Transform, anchor = vec2(0.5, 0.5))
proc drawTextLayout*(layout: LaidOutText, transform: Transform, anchor = vec2(0.5, 0.5))
proc drawPoly*(center: Vec3, sides: uint32, radius, rotation: float32, color: Color)
proc drawPolyLines*(center: Vec3, sides: uint32, radius, rotation, thickness: float32, color: Color)
proc withUi*[T](body: proc(): T): T
```

The SDL_Renderer bootstrap path currently renders rectangles, image-backed
sprites with placeholder fallback, lines, filled circles, filled polygons,
polygon outlines, and SDL debug text. Texture decode uses `stb_image`, so common
PNG/JPEG/BMP/TGA-class files can become texture handles without SDL3_image.
When SDL3_image is present at runtime, both SDL backends can use it as a
fallback for texture formats outside `stb_image` support.
Text measurement and layout currently use a backend-neutral heuristic so
examples can exercise the API before a glyph cache exists. Line commands include
batched lines plus solid/dashed/dotted patterns; SDL_Renderer approximates line
thickness with parallel lines. `Text.withFont(...)` uses runtime-loaded
SDL3_ttf glyph atlases in the SDL backends when the native library is present.

### Input

Input is frame-stable. Events update raw state; scene code reads snapshots.

```nim
type
  KeyCode* = enum
    kcInvalid, kcA, kcB, kcC, kcD, kcE, kcF, kcG, kcH, kcI, kcJ, kcK, kcL,
    kcM, kcN, kcO, kcP, kcQ, kcR, kcS, kcT, kcU, kcV, kcW, kcX, kcY, kcZ,
    kcEscape, kcSpace, kcEnter, kcBackspace, kcLeft, kcRight, kcUp, kcDown

  MouseButton* = enum
    mbLeft, mbMiddle, mbRight, mbBack, mbForward

  GamepadButton* = enum
    gpbInvalid, gpbSouth, gpbEast, gpbWest, gpbNorth, gpbBack, gpbGuide,
    gpbStart, gpbLeftStick, gpbRightStick, gpbLeftShoulder, gpbRightShoulder,
    gpbDpadUp, gpbDpadDown, gpbDpadLeft, gpbDpadRight, gpbMisc1,
    gpbRightPaddle1, gpbLeftPaddle1, gpbRightPaddle2, gpbLeftPaddle2,
    gpbTouchpad

  GamepadAxis* = enum
    gpaInvalid, gpaLeftX, gpaLeftY, gpaRightX, gpaRightY, gpaLeftTrigger,
    gpaRightTrigger

  GamepadAxisDir* = enum
    gadNegative, gadPositive

  InputSource* = object
    gamepad*: int32
    case kind*: InputSourceKind
    of iskKey:
      keyCode*: KeyCode
    of iskMouse:
      mouseButton*: MouseButton
    of iskGamepadButton:
      gamepadButton*: GamepadButton
    of iskGamepadAxis:
      gamepadAxis*: GamepadAxis
      gamepadAxisDir*: GamepadAxisDir
      gamepadAxisThreshold*: float32

proc bindAction*[A: enum](action: A, source: InputSource)
proc setActionSources*[A: enum](action: A, sources: openArray[InputSource])
proc clearAction*[A: enum](action: A)
proc actionDown*[A: enum](action: A): bool
proc actionUp*[A: enum](action: A): bool
proc actionJustPressed*[A: enum](action: A): bool
proc actionJustReleased*[A: enum](action: A): bool
proc mousePos*(): Vec2
proc mouseScroll*(): Vec2
proc textInput*(): string
proc mouseDown*(button: MouseButton): bool
proc mouseJustPressed*(button: MouseButton): bool
proc mouseJustReleased*(button: MouseButton): bool
proc setGamepadDeadzone*(deadzone: float32)
proc gamepadDeadzone*(): float32
proc connectedGamepads*(): seq[int32]
proc gamepadButtonDown*(button: GamepadButton, gamepad = AnyGamepad): bool
proc gamepadButtonJustPressed*(button: GamepadButton, gamepad = AnyGamepad): bool
proc gamepadButtonJustReleased*(button: GamepadButton, gamepad = AnyGamepad): bool
proc gamepadAxisValue*(axis: GamepadAxis, gamepad = AnyGamepad): float32
```

Action keys should be scoped by enum type, so two scenes can use different
action enums without collision.

`AnyGamepad` means "first matching connected gamepad" for action bindings.
Specific SDL instance ids can be passed for split-screen or diagnostics. Axis
sources use normalized values in `[-1, 1]`, per-source thresholds, and a global
deadzone.

`textInput()` returns the UTF-8 text submitted by the platform text service
during the current frame. SDL backends fill it from `SDL_EVENT_TEXT_INPUT` and
clear it in `InputState.endFrame`. Immediate text widgets use it first and keep
ASCII key fallback for headless tests.

### ECS and Entities

Roast2D has a minimal vector-backed ECS. Nima should start with a small entity
id and component stores only when there is a real feature consumer.

```nim
type Ent* = distinct uint32

proc spawn*(): Ent
proc despawn*(ent: Ent)
```

Physics, prefab, and particle systems can use `Ent` without exposing a full ECS
in v1.

### Audio, Physics, Particles, Light, UI

These modules now exist as first runnable engine slices:

- `audio`: clip instances, pause/resume/stop, master/music/sfx bus volume,
  SDL backend WAV playback through `SDL_AudioStream`, and optional SDL3_mixer
  dynamic playback for non-WAV formats when the native library is present.
- `physics`: simple static/dynamic bodies, cuboid/ball collider shapes
  represented by AABB broadphase, collider offsets, sensor flag, layer filters,
  gravity, point query, AABB overlap, sorted raycast, body removal, and frame
  collision events.
- `particles`: CPU emitters with burst/spawn rate, velocity, lifetime, color and
  size interpolation.
- `light2d`: ambient settings, point lights, rectangle occluders, and a debug
  overlay pass.
- `diagnostics`: perf overlay state and draw-command backed text panel.
- `prefab`: simple spawned colored rect instances backed by optional JSON or
  RON-like templates for tag, size, and color. Runtime reload refreshes loaded
  templates and updates existing prefab instances spawned from those templates.
  `PrefabPatchOp` supports Nim-style add/replace/remove patches for tag, sprite
  size, and sprite color, including Roast2D-shaped `/components/...` paths.
- `atlas`: optional JSON descriptors for frames and named clips, plus generated
  fallback demo frames when no descriptor exists. Runtime reload reparses loaded
  descriptor files in place.
- `map`: Roast2D-shaped tile map data with bounds, tile lookup, world-to-tile,
  and draw helpers that emit sprite commands from a tileset sprite.
- `tween`: deterministic shake and rotation-punch helpers for applying
  transient offsets to `Transform`, used by examples such as `breakout`.
- `imgui`: built-in immediate debug UI rendered through normal Nima draw
  commands, including `setImguiFont`, pointer/keyboard capture flags, buttons,
  checkbox, radio, combo, sliders, drag int, ASCII text inputs, collapsing
  headers, indentation, color editing, separators, progress bars, panels,
  same-line layout, and fixed-width button rows.
- `ui`: explicit-geometry panels, buttons, labels, insets, rows, columns, and
  content alignment for Roast2D-style immediate UI examples.
- `hotreload`: desktop dynamic-library host scene using a small C ABI callback
  surface for reloadable Nim gameplay libraries. The host copies the library to
  a temporary file before loading so rebuilt dylibs/dlls/so files can be swapped
  by modification time.

Imported asset reload APIs:

```nim
proc reloadImportedAssets*(): int
proc setImportedAssetsAutoReload*(enabled: bool)
proc importedAssetsAutoReload*(): bool
```

Dynamic code hot reload APIs:

```nim
proc hotReloadLibraryName*(base = "hotreload_game"): string
proc hotReloadScene*(libraryPath: string): HotReloadScene
```

These are intentionally conservative. Public audio capability queries, richer
mixer controls, full Aseprite import compatibility, richer physics,
state-preserving hot reload, richer text shaping, and broader native Dear
ImGui/cimgui editor wrappers are follow-up backend/asset milestones. SDL
backends already support optional SDL3_ttf glyph-atlas text for
`Text.withFont(...)`.

Current SDL_GPU status: Metal uses embedded MSL graphics pipelines for solid
quads, textured sprite quads, generated thick-line meshes, filled circles,
filled regular polygons, and polygon outlines. Sprite drawing supports
`Transform.angle`, source rects, tint, and flip. Consecutive sorted solid rects
batch into one GPU draw. Consecutive sorted sprites with the same texture handle
also batch into one GPU draw. Native Dear ImGui draw data is integrated for
SDL_Renderer and SDL_GPU behind `-d:nimaUseNativeImgui`. Non-Metal shader
blobs, broader primitive batching, and richer text shaping are still backend
milestones.

## Example

```nim
import nima/prelude

type
  Action = enum
    moveLeft, moveRight, quit

  Game = ref object of Scene
    playerX: float32

method init(g: Game) =
  bindAction(moveLeft, key(kcLeft))
  bindAction(moveRight, key(kcRight))
  bindAction(quit, key(kcEscape))

method update(g: Game) =
  if actionDown(moveLeft):
    g.playerX -= 240'f32 * tick()
  if actionDown(moveRight):
    g.playerX += 240'f32 * tick()
  if actionJustPressed(quit):
    exit()

method draw(g: Game) =
  drawRect(rgb(0.06, 0.07, 0.09), viewSize(), transform(vec3(0, 0, -1)))
  drawRect(Yellow, vec2(96, 24), transform(vec3(g.playerX, -220, 0)))

when isMainModule:
  run app(
    Game(),
    title = "Nima Breakout",
    size = ivec2(800, 600)
  )
```

## References

- Roast2D local reference: `~/Workspace/roast2d`
- SDL3 GPU API: https://wiki.libsdl.org/SDL3/CategoryGPU
- Nim `sdl3` package: https://github.com/transmutrix/nim-sdl3
- Fau SDL backend reference: `/Users/jjy/Workspace/fau/src/fau/backend/sdlcore.nim`
- Nim2D as SDL3 and SDL_GPU proof point: https://github.com/nim2d/nim2d
