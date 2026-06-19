import ./[assets, engine, facade, math, scene]

when defined(emscripten) and defined(nimaUseSdlGpu):
  {.fatal: "Nima web builds currently use -d:nimaUseSdl/SDL_Renderer; SDL_GPU web support is not implemented yet.".}

when defined(emscripten) and defined(nimaUseNativeImgui):
  {.fatal: "Native Dear ImGui is not supported in Nima web builds; use the built-in immediate UI instead.".}

when defined(nimaUseSdl):
  import ./backend/sdlrenderer as sdlbackend

when defined(nimaUseSdlGpu):
  import ./backend/sdlgpu as sdlgpubackend

type
  AppPlatform* = enum
    apWindow

  ScaleModeKind* = enum
    smNone, smFit, smFill, smStretch, smPixelPerfect

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

proc app*(scene: Scene, title = "Hello Nima", size = ivec2(800, 600),
          vsync = true, resizable = false, fullscreen = false,
          cursorVisible = true,
          scaleMode = ScaleMode(kind: smFit, virtualSize: vec2(800, 600)),
          assetRoots: openArray[string] = ["assets"]): App =
  App(title: title, size: size, platform: apWindow, vsync: vsync,
      resizable: resizable, fullscreen: fullscreen, cursorVisible: cursorVisible,
      scaleMode: scaleMode, assetRoots: @assetRoots, initialScene: scene)

proc runHeadless*(app: App, frames = 1) =
  setAssetRoots(app.assetRoots)
  var engine = initEngine(app.initialScene, app.scaleMode.virtualSize)
  discard withEngineScope(engine, proc(): bool =
    for _ in 0..<frames:
      if engine.exitRequested:
        break
      engine.stepFrame()
    true
  )

proc viewSizeFor(app: App): Vec2 =
  case app.scaleMode.kind
  of smNone:
    vec2(app.size.x.float32, app.size.y.float32)
  else:
    app.scaleMode.virtualSize

proc run*(app: App) =
  setAssetRoots(app.assetRoots)
  when defined(nimaUseSdlGpu):
    sdlgpubackend.runSdlGpu(app.title, app.size, app.viewSizeFor,
                            app.initialScene, app.vsync, app.resizable,
                            app.fullscreen, app.cursorVisible)
  elif defined(nimaUseSdl):
    let presentation =
      case app.scaleMode.kind
      of smNone: sdlbackend.spDisabled
      of smFit: sdlbackend.spLetterbox
      of smFill: sdlbackend.spOverscan
      of smStretch: sdlbackend.spStretch
      of smPixelPerfect: sdlbackend.spIntegerScale
    sdlbackend.runSdl(app.title, app.size, app.viewSizeFor, presentation,
                      app.initialScene, app.vsync, app.resizable,
                      app.fullscreen, app.cursorVisible)
  else:
    app.runHeadless(1)
