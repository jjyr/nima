when defined(nimaUseSdlGpu):
  import std/[algorithm, math as stdmath, strutils, tables]
  import pkg/sdl3
  import ../[assets, color, draw, engine, facade, image, input, math, scene, transform]
  import ./[sdlaudio, sdlimage, sdlttf]

  when defined(nimaUseNativeImgui):
    import ../imgui_native as nativeimgui

  type
    SdlGpuBackendError* = object of CatchableError

    FixedGpuColorTargetInfo {.bycopy.} = object
      texture: SDL_GPUTexture
      mipLevel: uint32
      layerOrDepthPlane: uint32
      clearColor: SDL_FColor
      loadOp: SDL_GPULoadOp
      storeOp: SDL_GPUStoreOp
      resolveTexture: SDL_GPUTexture
      resolveMipLevel: uint32
      resolveLayer: uint32
      cycle: bool
      cycleResolveTexture: bool
      padding1: uint8
      padding2: uint8

    FixedGpuBlitRegion {.bycopy.} = object
      texture: SDL_GPUTexture
      mipLevel: uint32
      layerOrDepthPlane: uint32
      x: uint32
      y: uint32
      w: uint32
      h: uint32

    FixedGpuBlitInfo {.bycopy.} = object
      source: FixedGpuBlitRegion
      destination: FixedGpuBlitRegion
      loadOp: SDL_GPULoadOp
      clearColor: SDL_FColor
      flipMode: SDL_FlipMode
      filter: SDL_GPUFilter
      cycle: bool
      padding1: uint8
      padding2: uint8
      padding3: uint8

    FixedGpuTextureTransferInfo {.bycopy.} = object
      transferBuffer: SDL_GPUTransferBuffer
      offset: uint32
      pixelsPerRow: uint32
      rowsPerLayer: uint32

    FixedGpuTextureRegion {.bycopy.} = object
      texture: SDL_GPUTexture
      mipLevel: uint32
      layer: uint32
      x: uint32
      y: uint32
      z: uint32
      w: uint32
      h: uint32
      d: uint32

    FixedGpuTransferBufferLocation {.bycopy.} = object
      transferBuffer: SDL_GPUTransferBuffer
      offset: uint32

    FixedGpuBufferRegion {.bycopy.} = object
      buffer: SDL_GPUBuffer
      offset: uint32
      size: uint32

    FixedGpuBufferBinding {.bycopy.} = object
      buffer: SDL_GPUBuffer
      offset: uint32

    SdlGpuSampler = pointer

    FixedGpuTextureSamplerBinding {.bycopy.} = object
      texture: SDL_GPUTexture
      sampler: SdlGpuSampler

    FixedGpuGraphicsPipelineCreateInfo {.bycopy.} = object
      vertexShader: SDL_GPUShader
      fragmentShader: SDL_GPUShader
      vertexInputState: SDL_GPUVertexInputState
      primitiveType: SDL_GPUPrimitiveType
      rasterizerState: SDL_GPURasterizerState
      multisampleState: SDL_GPUMultisampleState
      depthStencilState: SDL_GPUDepthStencilState
      targetInfo: SDL_GPUGraphicsPipelineTargetInfo
      props: SDL_PropertiesID

    GpuVertex {.bycopy.} = object
      x, y: float32
      r, g, b, a: float32

    GpuSpriteVertex {.bycopy.} = object
      x, y: float32
      u, v: float32
      r, g, b, a: float32

    UploadedTexture = object
      texture: SDL_GPUTexture
      width: uint32
      height: uint32

    UploadedTextTexture = object
      texture: SDL_GPUTexture
      width: uint32
      height: uint32
      scale: float32

    UploadedGlyphAtlas = object
      texture: SDL_GPUTexture
      width: uint32
      height: uint32
      generation: uint32

    SdlGamepads = Table[SDL_JoystickID, SDL_Gamepad]

    GpuResources = object
      colors: Table[uint32, SDL_GPUTexture]
      textures: Table[uint32, UploadedTexture]
      tintedTextures: Table[uint64, UploadedTexture]
      texts: Table[string, UploadedTextTexture]
      glyphAtlases: Table[string, UploadedGlyphAtlas]
      imageLoader: SdlImageState
      quadPipelineChecked: bool
      quadPipeline: SDL_GPUGraphicsPipeline
      quadVertexShader: SDL_GPUShader
      quadFragmentShader: SDL_GPUShader
      spritePipelineChecked: bool
      spritePipeline: SDL_GPUGraphicsPipeline
      spriteVertexShader: SDL_GPUShader
      spriteFragmentShader: SDL_GPUShader
      spriteSampler: SdlGpuSampler

  const
    quadVertexMsl = """
#include <metal_stdlib>
using namespace metal;

struct VertexIn {
  float2 position [[attribute(0)]];
  float4 color [[attribute(1)]];
};

struct VertexOut {
  float4 position [[position]];
  float4 color;
  float pointSize [[point_size]];
};

vertex VertexOut vmain(VertexIn in [[stage_in]]) {
  VertexOut out;
  out.position = float4(in.position, 0.0, 1.0);
  out.color = in.color;
  out.pointSize = 1.0;
  return out;
}
"""

    quadFragmentMsl = """
#include <metal_stdlib>
using namespace metal;

struct FragmentIn {
  float4 position [[position]];
  float4 color;
};

fragment float4 fmain(FragmentIn in [[stage_in]]) {
  return in.color;
}
"""

    spriteVertexMsl = """
#include <metal_stdlib>
using namespace metal;

struct VertexIn {
  float2 position [[attribute(0)]];
  float2 texcoord [[attribute(1)]];
  float4 color [[attribute(2)]];
};

struct VertexOut {
  float4 position [[position]];
  float2 texcoord;
  float4 color;
  float pointSize [[point_size]];
};

vertex VertexOut vmain(VertexIn in [[stage_in]]) {
  VertexOut out;
  out.position = float4(in.position, 0.0, 1.0);
  out.texcoord = in.texcoord;
  out.color = in.color;
  out.pointSize = 1.0;
  return out;
}
"""

    spriteFragmentMsl = """
#include <metal_stdlib>
using namespace metal;

struct FragmentIn {
  float4 position [[position]];
  float2 texcoord;
  float4 color;
};

fragment float4 fmain(FragmentIn in [[stage_in]],
                      texture2d<float> image [[texture(0)]],
                      sampler imageSampler [[sampler(0)]]) {
  return image.sample(imageSampler, in.texcoord) * in.color;
}
"""

  proc waitAndAcquireGpuSwapchainTexture(
    commandBuffer: SDL_GPUCommandBuffer,
    window: SDL_Window,
    swapchainTexture: var SDL_GPUTexture,
    swapchainTextureWidth: var uint32,
    swapchainTextureHeight: var uint32
  ): bool {.cdecl, dynlib: LibName, importc: "SDL_WaitAndAcquireGPUSwapchainTexture".}

  proc beginGpuRenderPass(
    commandBuffer: SDL_GPUCommandBuffer,
    colorTargetInfos: ptr FixedGpuColorTargetInfo,
    numColorTargets: uint32,
    depthStencilTargetInfo: pointer
  ): SDL_GPURenderPass {.cdecl, dynlib: LibName, importc: "SDL_BeginGPURenderPass".}

  proc blitGpuTexture(
    commandBuffer: SDL_GPUCommandBuffer,
    info: ptr FixedGpuBlitInfo
  ) {.cdecl, dynlib: LibName, importc: "SDL_BlitGPUTexture".}

  proc uploadToGpuTexture(
    copyPass: SDL_GPUCopyPass,
    source: ptr FixedGpuTextureTransferInfo,
    destination: ptr FixedGpuTextureRegion,
    cycle: bool
  ) {.cdecl, dynlib: LibName, importc: "SDL_UploadToGPUTexture".}

  proc uploadToGpuBuffer(
    copyPass: SDL_GPUCopyPass,
    source: ptr FixedGpuTransferBufferLocation,
    destination: ptr FixedGpuBufferRegion,
    cycle: bool
  ) {.cdecl, dynlib: LibName, importc: "SDL_UploadToGPUBuffer".}

  proc createGpuGraphicsPipeline(
    device: SDL_GPUDevice,
    createInfo: ptr FixedGpuGraphicsPipelineCreateInfo
  ): SDL_GPUGraphicsPipeline {.cdecl, dynlib: LibName, importc: "SDL_CreateGPUGraphicsPipeline".}

  proc bindGpuVertexBuffers(
    renderPass: SDL_GPURenderPass,
    firstSlot: uint32,
    bindings: ptr FixedGpuBufferBinding,
    numBindings: uint32
  ) {.cdecl, dynlib: LibName, importc: "SDL_BindGPUVertexBuffers".}

  proc createGpuSampler(
    device: SDL_GPUDevice,
    createInfo: ptr SDL_GPUSamplerCreateInfo
  ): SdlGpuSampler {.cdecl, dynlib: LibName, importc: "SDL_CreateGPUSampler".}

  proc releaseGpuSampler(
    device: SDL_GPUDevice,
    sampler: SdlGpuSampler
  ) {.cdecl, dynlib: LibName, importc: "SDL_ReleaseGPUSampler".}

  proc bindGpuFragmentSamplers(
    renderPass: SDL_GPURenderPass,
    firstSlot: uint32,
    bindings: ptr FixedGpuTextureSamplerBinding,
    numBindings: uint32
  ) {.cdecl, dynlib: LibName, importc: "SDL_BindGPUFragmentSamplers".}

  proc sdlGpuError(message: string): ref SdlGpuBackendError =
    let detail = $SDL_GetError()
    if detail.len > 0:
      newException(SdlGpuBackendError, message & ": " & detail)
    else:
      newException(SdlGpuBackendError, message)

  proc checkSdl(ok: bool, message: string) =
    if not ok:
      raise sdlGpuError(message)

  proc shaderFormats(): SDL_GPUShaderFormat =
    SDL_GPUShaderFormat(SDL_GPU_SHADERFORMAT_SPIRV or
      SDL_GPU_SHADERFORMAT_DXBC or
      SDL_GPU_SHADERFORMAT_DXIL or
      SDL_GPU_SHADERFORMAT_MSL or
      SDL_GPU_SHADERFORMAT_METALLIB)

  proc toKeyCode(scancode: SDL_Scancode): KeyCode =
    case scancode
    of SDL_SCANCODE_A: kcA
    of SDL_SCANCODE_B: kcB
    of SDL_SCANCODE_C: kcC
    of SDL_SCANCODE_D: kcD
    of SDL_SCANCODE_E: kcE
    of SDL_SCANCODE_F: kcF
    of SDL_SCANCODE_G: kcG
    of SDL_SCANCODE_H: kcH
    of SDL_SCANCODE_I: kcI
    of SDL_SCANCODE_J: kcJ
    of SDL_SCANCODE_K: kcK
    of SDL_SCANCODE_L: kcL
    of SDL_SCANCODE_M: kcM
    of SDL_SCANCODE_N: kcN
    of SDL_SCANCODE_O: kcO
    of SDL_SCANCODE_P: kcP
    of SDL_SCANCODE_Q: kcQ
    of SDL_SCANCODE_R: kcR
    of SDL_SCANCODE_S: kcS
    of SDL_SCANCODE_T: kcT
    of SDL_SCANCODE_U: kcU
    of SDL_SCANCODE_V: kcV
    of SDL_SCANCODE_W: kcW
    of SDL_SCANCODE_X: kcX
    of SDL_SCANCODE_Y: kcY
    of SDL_SCANCODE_Z: kcZ
    of SDL_SCANCODE_0: kcDigit0
    of SDL_SCANCODE_1: kcDigit1
    of SDL_SCANCODE_2: kcDigit2
    of SDL_SCANCODE_3: kcDigit3
    of SDL_SCANCODE_4: kcDigit4
    of SDL_SCANCODE_5: kcDigit5
    of SDL_SCANCODE_6: kcDigit6
    of SDL_SCANCODE_7: kcDigit7
    of SDL_SCANCODE_8: kcDigit8
    of SDL_SCANCODE_9: kcDigit9
    of SDL_SCANCODE_ESCAPE: kcEscape
    of SDL_SCANCODE_SPACE: kcSpace
    of SDL_SCANCODE_RETURN: kcEnter
    of SDL_SCANCODE_BACKSPACE: kcBackspace
    of SDL_SCANCODE_TAB: kcTab
    of SDL_SCANCODE_LEFT: kcLeft
    of SDL_SCANCODE_RIGHT: kcRight
    of SDL_SCANCODE_UP: kcUp
    of SDL_SCANCODE_DOWN: kcDown
    of SDL_SCANCODE_LSHIFT: kcLeftShift
    of SDL_SCANCODE_LCTRL: kcLeftCtrl
    of SDL_SCANCODE_LALT: kcLeftAlt
    of SDL_SCANCODE_RSHIFT: kcRightShift
    of SDL_SCANCODE_RCTRL: kcRightCtrl
    of SDL_SCANCODE_RALT: kcRightAlt
    else: kcInvalid

  proc toMouseButton(button: uint8): MouseButton =
    case int(button)
    of SDL_BUTTON_LEFT: mbLeft
    of SDL_BUTTON_MIDDLE: mbMiddle
    of SDL_BUTTON_RIGHT: mbRight
    of SDL_BUTTON_X1: mbBack
    of SDL_BUTTON_X2: mbForward
    else: mbLeft

  proc isKnownMouseButton(button: uint8): bool =
    case int(button)
    of SDL_BUTTON_LEFT, SDL_BUTTON_MIDDLE, SDL_BUTTON_RIGHT, SDL_BUTTON_X1, SDL_BUTTON_X2: true
    else: false

  proc toGamepadButton(button: uint8): GamepadButton =
    case SDL_GamepadButton(button.cint)
    of SDL_GAMEPAD_BUTTON_SOUTH: gpbSouth
    of SDL_GAMEPAD_BUTTON_EAST: gpbEast
    of SDL_GAMEPAD_BUTTON_WEST: gpbWest
    of SDL_GAMEPAD_BUTTON_NORTH: gpbNorth
    of SDL_GAMEPAD_BUTTON_BACK: gpbBack
    of SDL_GAMEPAD_BUTTON_GUIDE: gpbGuide
    of SDL_GAMEPAD_BUTTON_START: gpbStart
    of SDL_GAMEPAD_BUTTON_LEFT_STICK: gpbLeftStick
    of SDL_GAMEPAD_BUTTON_RIGHT_STICK: gpbRightStick
    of SDL_GAMEPAD_BUTTON_LEFT_SHOULDER: gpbLeftShoulder
    of SDL_GAMEPAD_BUTTON_RIGHT_SHOULDER: gpbRightShoulder
    of SDL_GAMEPAD_BUTTON_DPAD_UP: gpbDpadUp
    of SDL_GAMEPAD_BUTTON_DPAD_DOWN: gpbDpadDown
    of SDL_GAMEPAD_BUTTON_DPAD_LEFT: gpbDpadLeft
    of SDL_GAMEPAD_BUTTON_DPAD_RIGHT: gpbDpadRight
    of SDL_GAMEPAD_BUTTON_MISC1: gpbMisc1
    of SDL_GAMEPAD_BUTTON_RIGHT_PADDLE1: gpbRightPaddle1
    of SDL_GAMEPAD_BUTTON_LEFT_PADDLE1: gpbLeftPaddle1
    of SDL_GAMEPAD_BUTTON_RIGHT_PADDLE2: gpbRightPaddle2
    of SDL_GAMEPAD_BUTTON_LEFT_PADDLE2: gpbLeftPaddle2
    of SDL_GAMEPAD_BUTTON_TOUCHPAD: gpbTouchpad
    else: gpbInvalid

  proc toGamepadAxis(axis: uint8): GamepadAxis =
    case SDL_GamepadAxis(axis.cint)
    of SDL_GAMEPAD_AXIS_LEFTX: gpaLeftX
    of SDL_GAMEPAD_AXIS_LEFTY: gpaLeftY
    of SDL_GAMEPAD_AXIS_RIGHTX: gpaRightX
    of SDL_GAMEPAD_AXIS_RIGHTY: gpaRightY
    of SDL_GAMEPAD_AXIS_LEFT_TRIGGER: gpaLeftTrigger
    of SDL_GAMEPAD_AXIS_RIGHT_TRIGGER: gpaRightTrigger
    else: gpaInvalid

  proc normalizeGamepadAxis(value: int16): float32 =
    if value < 0:
      max(-1'f32, value.float32 / 32768'f32)
    else:
      min(1'f32, value.float32 / 32767'f32)

  proc openGamepad(gamepads: var SdlGamepads, input: var InputState,
                   id: SDL_JoystickID) =
    if gamepads.hasKey(id) or not SDL_IsGamepad(id):
      return
    let pad = SDL_OpenGamepad(id)
    if pad.isNil:
      return
    gamepads[id] = pad
    input.setGamepadConnected(id.int32, true)
    let name = SDL_GetGamepadName(pad)
    if name.isNil:
      echo "[Nima] SDL gamepad ", $id, " connected"
    else:
      echo "[Nima] SDL gamepad ", $id, " connected: ", $name

  proc openExistingGamepads(gamepads: var SdlGamepads, input: var InputState) =
    var count: cint
    let ids = SDL_GetGamepads(count)
    if ids.isNil:
      return
    defer: SDL_free(cast[pointer](ids))
    for i in 0..<count.int:
      gamepads.openGamepad(input, ids[i])

  proc closeGamepad(gamepads: var SdlGamepads, input: var InputState,
                    id: SDL_JoystickID) =
    if gamepads.hasKey(id):
      let pad = gamepads[id]
      if not pad.isNil:
        SDL_CloseGamepad(pad)
      gamepads.del id
    input.setGamepadConnected(id.int32, false)

  proc closeGamepads(gamepads: var SdlGamepads, input: var InputState) =
    var ids: seq[SDL_JoystickID]
    for id in gamepads.keys:
      ids.add id
    for id in ids:
      gamepads.closeGamepad(input, id)

  proc renderToWorld(x, y: cfloat, view: Vec2): Vec2 =
    vec2(x.float32 - view.x * 0.5'f32, view.y * 0.5'f32 - y.float32)

  proc updateMetrics(engine: var Engine, window: SDL_Window) =
    var w, h: cint
    if SDL_GetWindowSize(window, w, h):
      engine.screenSize = vec2(w.float32, h.float32)
    let scale = SDL_GetWindowDisplayScale(window).float32
    engine.dpiScale = if scale > 0'f32: scale else: 1'f32

  proc processEvents(engine: var Engine, window: SDL_Window,
                     gamepads: var SdlGamepads) =
    var event: SDL_Event
    while SDL_PollEvent(event):
      when defined(nimaUseNativeImgui):
        nativeimgui.nativeImguiProcessEvent(event)
      case event.`type`
      of SDL_EVENT_QUIT, SDL_EVENT_WINDOW_CLOSE_REQUESTED:
        engine.requestExit()
      of SDL_EVENT_WINDOW_RESIZED, SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED:
        engine.updateMetrics(window)
      of SDL_EVENT_KEY_DOWN, SDL_EVENT_KEY_UP:
        let code = toKeyCode(event.key.scancode)
        if code != kcInvalid:
          engine.input.setKeyDown(code, event.key.down)
      of SDL_EVENT_TEXT_INPUT:
        if not event.text.text.isNil:
          engine.input.addTextInput($event.text.text)
      of SDL_EVENT_MOUSE_MOTION:
        engine.input.setMousePos(renderToWorld(event.motion.x, event.motion.y,
                                               engine.viewSize))
      of SDL_EVENT_MOUSE_BUTTON_DOWN, SDL_EVENT_MOUSE_BUTTON_UP:
        if isKnownMouseButton(event.button.button):
          engine.input.setMousePos(renderToWorld(event.button.x, event.button.y,
                                                 engine.viewSize))
          engine.input.setMouseDown(toMouseButton(event.button.button), event.button.down)
      of SDL_EVENT_MOUSE_WHEEL:
        var dy = event.wheel.y.float32
        if event.wheel.direction == SDL_MOUSEWHEEL_FLIPPED:
          dy = -dy
        engine.input.addScroll(vec2(event.wheel.x.float32, dy))
        engine.input.setMousePos(renderToWorld(event.wheel.mouse_x, event.wheel.mouse_y,
                                               engine.viewSize))
      of SDL_EVENT_GAMEPAD_ADDED:
        gamepads.openGamepad(engine.input, event.gdevice.which)
      of SDL_EVENT_GAMEPAD_REMOVED:
        gamepads.closeGamepad(engine.input, event.gdevice.which)
      of SDL_EVENT_GAMEPAD_BUTTON_DOWN, SDL_EVENT_GAMEPAD_BUTTON_UP:
        engine.input.setGamepadButtonDown(event.gbutton.which.int32,
          toGamepadButton(event.gbutton.button), event.gbutton.down)
      of SDL_EVENT_GAMEPAD_AXIS_MOTION:
        engine.input.setGamepadAxisValue(event.gaxis.which.int32,
          toGamepadAxis(event.gaxis.axis), normalizeGamepadAxis(event.gaxis.value))
      else:
        discard

  proc toSdlColor(color: Color): SDL_FColor =
    SDL_FColor(r: color.r.cfloat, g: color.g.cfloat, b: color.b.cfloat,
               a: color.a.cfloat)

  proc colorKey(color: Color): uint32 =
    let bytes = color.toRgba8
    (bytes[0].uint32 shl 24) or
      (bytes[1].uint32 shl 16) or
      (bytes[2].uint32 shl 8) or
      bytes[3].uint32

  proc tintKey(handle: Handle[Texture], color: Color): uint64 =
    (handle.id.uint64 shl 32) or color.colorKey.uint64

  proc isZeroAngle(angle: float32): bool =
    angle > -0.00001'f32 and angle < 0.00001'f32

  proc coversView(command: DrawCommand, engine: Engine): bool =
    if command.kind != dckRect or command.space != dsWorld:
      return false
    let bounds = command.transform.bounds(command.anchor, command.size)
    bounds.min.x <= -engine.viewSize.x * 0.5'f32 + 0.01'f32 and
      bounds.max.x >= engine.viewSize.x * 0.5'f32 - 0.01'f32 and
      bounds.min.y <= -engine.viewSize.y * 0.5'f32 + 0.01'f32 and
      bounds.max.y >= engine.viewSize.y * 0.5'f32 - 0.01'f32

  proc clearColor(engine: Engine): Color =
    result = Black
    var commands = engine.recorder.commands
    commands.sort(proc(a, b: DrawCommand): int =
      if a.z < b.z: -1
      elif a.z > b.z: 1
      elif a.order < b.order: -1
      elif a.order > b.order: 1
      else: 0
    )
    for command in commands:
      if command.coversView(engine):
        result = command.color
        break

  proc clearTexture(commandBuffer: SDL_GPUCommandBuffer, texture: SDL_GPUTexture,
                    color: Color) =
    var target = FixedGpuColorTargetInfo(
      texture: texture,
      clearColor: color.toSdlColor,
      loadOp: SDL_GPU_LOADOP_CLEAR,
      storeOp: SDL_GPU_STOREOP_STORE,
      cycle: false
    )
    let pass = beginGpuRenderPass(commandBuffer, addr target, 1, nil)
    if pass.isNil:
      raise sdlGpuError("SDL_BeginGPURenderPass failed")
    SDL_EndGPURenderPass(pass)

  proc colorTexture(device: SDL_GPUDevice, commandBuffer: SDL_GPUCommandBuffer,
                    resources: var GpuResources, color: Color): SDL_GPUTexture =
    let key = color.colorKey
    if resources.colors.hasKey(key):
      return resources.colors[key]

    var info = SDL_GPUTextureCreateInfo(
      `type`: SDL_GPU_TEXTURETYPE_2D,
      format: SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM,
      usage: SDL_GPUTextureUsageFlags(SDL_GPU_TEXTUREUSAGE_COLOR_TARGET or
        SDL_GPU_TEXTUREUSAGE_SAMPLER),
      width: 1,
      height: 1,
      layer_count_or_depth: 1,
      num_levels: 1,
      sample_count: SDL_GPU_SAMPLECOUNT_1
    )
    result = SDL_CreateGPUTexture(device, addr info)
    if result.isNil:
      raise sdlGpuError("SDL_CreateGPUTexture failed")
    clearTexture(commandBuffer, result, color)
    resources.colors[key] = result

  proc uploadSurfaceTexture(device: SDL_GPUDevice, commandBuffer: SDL_GPUCommandBuffer,
                            surface: ptr SDL_Surface): UploadedTexture =
    if surface.w <= 0 or surface.h <= 0 or surface.pixels.isNil:
      return

    let width = surface.w.uint32
    let height = surface.h.uint32
    let rowBytes = width * 4
    let byteCount = rowBytes * height

    var textureInfo = SDL_GPUTextureCreateInfo(
      `type`: SDL_GPU_TEXTURETYPE_2D,
      format: SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM,
      usage: SDL_GPUTextureUsageFlags(SDL_GPU_TEXTUREUSAGE_SAMPLER),
      width: width,
      height: height,
      layer_count_or_depth: 1,
      num_levels: 1,
      sample_count: SDL_GPU_SAMPLECOUNT_1
    )
    let texture = SDL_CreateGPUTexture(device, addr textureInfo)
    if texture.isNil:
      return

    var transferInfo = SDL_GPUTransferBufferCreateInfo(
      usage: SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD,
      size: byteCount
    )
    let transfer = SDL_CreateGPUTransferBuffer(device, addr transferInfo)
    if transfer.isNil:
      SDL_ReleaseGPUTexture(device, texture)
      return
    defer: SDL_ReleaseGPUTransferBuffer(device, transfer)

    let mapped = SDL_MapGPUTransferBuffer(device, transfer, false)
    if mapped.isNil:
      SDL_ReleaseGPUTexture(device, texture)
      return
    let dst = cast[ptr UncheckedArray[uint8]](mapped)
    let src = surface.pixels
    for y in 0..<height.int:
      copyMem(addr dst[y * rowBytes.int], addr src[y * surface.pitch.int],
              rowBytes.int)
    SDL_UnmapGPUTransferBuffer(device, transfer)

    let copyPass = SDL_BeginGPUCopyPass(commandBuffer)
    if copyPass.isNil:
      SDL_ReleaseGPUTexture(device, texture)
      return
    var source = FixedGpuTextureTransferInfo(
      transferBuffer: transfer,
      pixelsPerRow: width,
      rowsPerLayer: height
    )
    var destination = FixedGpuTextureRegion(
      texture: texture,
      w: width,
      h: height,
      d: 1
    )
    uploadToGpuTexture(copyPass, addr source, addr destination, false)
    SDL_EndGPUCopyPass(copyPass)

    UploadedTexture(texture: texture, width: width, height: height)

  proc surfaceFromPixels(image: var ImagePixels): ptr SDL_Surface =
    if image.pixels.len == 0:
      return nil
    let source = SDL_CreateSurfaceFrom(image.width.cint, image.height.cint,
                                       SDL_PIXELFORMAT_RGBA32,
                                       unsafeAddr image.pixels[0],
                                       (image.width * 4).cint)
    if source.isNil:
      return nil
    defer: SDL_DestroySurface(source)
    SDL_ConvertSurface(source, SDL_PIXELFORMAT_RGBA32)

  proc loadTextureSurface(resources: var GpuResources,
                          handle: Handle[Texture]): ptr SDL_Surface =
    let asset = textureAsset(handle)
    if asset.isNil or not asset.loaded:
      return nil
    var image: ImagePixels
    try:
      image = loadImageRgba(asset.resolvedPath)
    except ImageLoadError:
      discard
    result = surfaceFromPixels(image)
    if result.isNil:
      result = resources.imageLoader.loadImageSurfaceRgba(asset.resolvedPath)

  proc loadGpuTexture(device: SDL_GPUDevice, commandBuffer: SDL_GPUCommandBuffer,
                      resources: var GpuResources,
                      handle: Handle[Texture]): UploadedTexture =
    let surface = resources.loadTextureSurface(handle)
    if surface.isNil:
      return
    defer: SDL_DestroySurface(surface)

    uploadSurfaceTexture(device, commandBuffer, surface)

  proc tintSurface(surface: ptr SDL_Surface, color: Color) =
    if surface.isNil or surface.pixels.isNil:
      return
    let tint = color.toRgba8
    let rows = cast[ptr UncheckedArray[uint8]](surface.pixels)
    for y in 0..<surface.h.int:
      let row = y * surface.pitch.int
      for x in 0..<surface.w.int:
        let i = row + x * 4
        rows[i] = uint8((rows[i].uint16 * tint[0].uint16) div 255)
        rows[i + 1] = uint8((rows[i + 1].uint16 * tint[1].uint16) div 255)
        rows[i + 2] = uint8((rows[i + 2].uint16 * tint[2].uint16) div 255)
        rows[i + 3] = uint8((rows[i + 3].uint16 * tint[3].uint16) div 255)

  proc loadTintedGpuTexture(device: SDL_GPUDevice, commandBuffer: SDL_GPUCommandBuffer,
                            resources: var GpuResources,
                            handle: Handle[Texture], color: Color): UploadedTexture =
    let surface = resources.loadTextureSurface(handle)
    if surface.isNil:
      return
    defer: SDL_DestroySurface(surface)

    tintSurface(surface, color)
    uploadSurfaceTexture(device, commandBuffer, surface)

  proc textureFor(device: SDL_GPUDevice, commandBuffer: SDL_GPUCommandBuffer,
                  resources: var GpuResources,
                  handle: Handle[Texture]): UploadedTexture =
    if handle.id == 0:
      return
    if resources.textures.hasKey(handle.id):
      return resources.textures[handle.id]
    result = loadGpuTexture(device, commandBuffer, resources, handle)
    if not result.texture.isNil:
      resources.textures[handle.id] = result

  proc textureFor(device: SDL_GPUDevice, commandBuffer: SDL_GPUCommandBuffer,
                  resources: var GpuResources,
                  handle: Handle[Texture], color: Color): UploadedTexture =
    if color.colorKey == White.colorKey:
      return textureFor(device, commandBuffer, resources, handle)
    let key = handle.tintKey(color)
    if resources.tintedTextures.hasKey(key):
      return resources.tintedTextures[key]
    result = loadTintedGpuTexture(device, commandBuffer, resources, handle, color)
    if not result.texture.isNil:
      resources.tintedTextures[key] = result

  proc textTextureKey(text: Text): string =
    let fontId = if text.hasFont: text.font.id else: 0'u32
    text.content & "\0" & $text.size & "\0" & $text.color.colorKey & "\0" & $fontId

  proc renderDebugTextSurface(text: Text): ptr SDL_Surface =
    let lines = text.content.splitLines()
    var maxChars = 1
    for line in lines:
      maxChars = max(maxChars, line.len)
    let lineCount = max(1, lines.len)
    let width = max(1, maxChars * SDL_DEBUG_TEXT_FONT_CHARACTER_SIZE)
    let height = max(1, lineCount * SDL_DEBUG_TEXT_FONT_CHARACTER_SIZE)
    result = SDL_CreateSurface(width.cint, height.cint, SDL_PIXELFORMAT_RGBA32)
    if result.isNil:
      return
    discard SDL_ClearSurface(result, 0, 0, 0, 0)
    let renderer = SDL_CreateSoftwareRenderer(result)
    if renderer.isNil:
      SDL_DestroySurface(result)
      result = nil
      return
    defer: SDL_DestroyRenderer(renderer)
    discard SDL_SetRenderDrawBlendMode(renderer, SDL_BLENDMODE_BLEND)
    discard SDL_SetRenderDrawColorFloat(renderer, text.color.r.cfloat, text.color.g.cfloat,
                                        text.color.b.cfloat, text.color.a.cfloat)
    for i, line in lines:
      discard SDL_RenderDebugText(renderer, 0, (i * SDL_DEBUG_TEXT_FONT_CHARACTER_SIZE).cfloat,
                                  line.cstring)
    discard SDL_RenderPresent(renderer)

  proc textTexture(device: SDL_GPUDevice, commandBuffer: SDL_GPUCommandBuffer,
                   resources: var GpuResources, ttf: var SdlTtfState,
                   text: Text): UploadedTextTexture =
    if text.content.len == 0:
      return
    let key = text.textTextureKey
    if resources.texts.hasKey(key):
      return resources.texts[key]

    var scale = 1'f32
    var surface = ttf.renderTextSurface(text)
    if surface.isNil:
      surface = renderDebugTextSurface(text)
      scale = max(1'f32, text.size / SDL_DEBUG_TEXT_FONT_CHARACTER_SIZE.float32)
    if surface.isNil:
      return

    let uploaded = uploadSurfaceTexture(device, commandBuffer, surface)
    SDL_DestroySurface(surface)
    result = UploadedTextTexture(texture: uploaded.texture, width: uploaded.width,
                                 height: uploaded.height, scale: scale)
    if not result.texture.isNil:
      resources.texts[key] = result

  proc glyphAtlasTexture(device: SDL_GPUDevice, commandBuffer: SDL_GPUCommandBuffer,
                         resources: var GpuResources,
                         atlas: SdlGlyphAtlas): UploadedGlyphAtlas =
    if atlas.isNil or atlas.surface.isNil:
      return
    if resources.glyphAtlases.hasKey(atlas.key):
      let cached = resources.glyphAtlases[atlas.key]
      if cached.generation == atlas.generation and not cached.texture.isNil:
        return cached
      if not cached.texture.isNil:
        SDL_ReleaseGPUTexture(device, cached.texture)

    let uploaded = uploadSurfaceTexture(device, commandBuffer, atlas.surface)
    result = UploadedGlyphAtlas(texture: uploaded.texture,
                                width: uploaded.width,
                                height: uploaded.height,
                                generation: atlas.generation)
    if not result.texture.isNil:
      resources.glyphAtlases[atlas.key] = result

  proc project(pos: Vec2, command: DrawCommand, engine: Engine): Vec2 =
    case command.space
    of dsWorld: (pos - engine.cameraPos) * engine.cameraZoom
    of dsUi: pos

  proc projectSize(size: Vec2, command: DrawCommand, engine: Engine): Vec2 =
    case command.space
    of dsWorld: size * engine.cameraZoom
    of dsUi: size

  proc projectBounds(bounds: Rect, command: DrawCommand, engine: Engine): Rect =
    let c = project(bounds.center, command, engine)
    let s = projectSize(bounds.size, command, engine)
    rect(c - s * 0.5'f32, c + s * 0.5'f32)

  proc rectToRender(bounds: Rect, view: Vec2): Rect =
    rect(vec2(bounds.min.x + view.x * 0.5'f32, view.y * 0.5'f32 - bounds.max.y),
         vec2(bounds.max.x + view.x * 0.5'f32, view.y * 0.5'f32 - bounds.min.y))

  proc pointToRender(pos: Vec2, view: Vec2): Vec2 =
    vec2(pos.x + view.x * 0.5'f32, view.y * 0.5'f32 - pos.y)

  proc clipVertex(renderPos: Vec2, view: Vec2, color: Color): GpuVertex =
    GpuVertex(
      x: renderPos.x / max(1'f32, view.x) * 2'f32 - 1'f32,
      y: 1'f32 - renderPos.y / max(1'f32, view.y) * 2'f32,
      r: color.r,
      g: color.g,
      b: color.b,
      a: color.a
    )

  proc createShader(device: SDL_GPUDevice, source: string, stage: SDL_GPUShaderStage,
                    numSamplers = 0'u32): SDL_GPUShader =
    if source.len == 0:
      return nil
    var info = SDL_GPUShaderCreateInfo(
      code_size: source.len.csize_t,
      code: cast[ptr UncheckedArray[uint8]](unsafeAddr source[0]),
      entrypoint: (if stage == SDL_GPU_SHADERSTAGE_VERTEX: "vmain" else: "fmain"),
      format: SDL_GPUShaderFormat(SDL_GPU_SHADERFORMAT_MSL),
      stage: stage,
      num_samplers: numSamplers
    )
    result = SDL_CreateGPUShader(device, addr info)

  proc alphaBlendState(): SDL_GPUColorTargetBlendState =
    SDL_GPUColorTargetBlendState(
      src_color_blendfactor: SDL_GPU_BLENDFACTOR_SRC_ALPHA,
      dst_color_blendfactor: SDL_GPU_BLENDFACTOR_ONE_MINUS_SRC_ALPHA,
      color_blend_op: SDL_GPU_BLENDOP_ADD,
      src_alpha_blendfactor: SDL_GPU_BLENDFACTOR_ONE,
      dst_alpha_blendfactor: SDL_GPU_BLENDFACTOR_ONE_MINUS_SRC_ALPHA,
      alpha_blend_op: SDL_GPU_BLENDOP_ADD,
      color_write_mask: SDL_GPUColorComponentFlags(
        SDL_GPU_COLORCOMPONENT_R or SDL_GPU_COLORCOMPONENT_G or
        SDL_GPU_COLORCOMPONENT_B or SDL_GPU_COLORCOMPONENT_A),
      enable_blend: true,
      enable_color_write_mask: true
    )

  proc ensureQuadPipeline(device: SDL_GPUDevice, window: SDL_Window,
                          resources: var GpuResources): bool =
    if resources.quadPipelineChecked:
      return not resources.quadPipeline.isNil
    resources.quadPipelineChecked = true

    let formats = SDL_GetGPUShaderFormats(device)
    if (formats and SDL_GPU_SHADERFORMAT_MSL) == 0:
      echo "[Nima] SDL_GPU quad pipeline=blit (MSL unavailable)"
      return false

    resources.quadVertexShader = createShader(device, quadVertexMsl,
                                              SDL_GPU_SHADERSTAGE_VERTEX)
    if resources.quadVertexShader.isNil:
      echo "[Nima] SDL_GPU quad pipeline=blit (vertex shader failed)"
      return false
    resources.quadFragmentShader = createShader(device, quadFragmentMsl,
                                                SDL_GPU_SHADERSTAGE_FRAGMENT)
    if resources.quadFragmentShader.isNil:
      echo "[Nima] SDL_GPU quad pipeline=blit (fragment shader failed)"
      return false

    var bufferDescriptions = [SDL_GPUVertexBufferDescription(
      slot: 0,
      pitch: sizeof(GpuVertex).uint32,
      input_rate: SDL_GPU_VERTEXINPUTRATE_VERTEX,
      instance_step_rate: 0
    )]
    var attributes = [
      SDL_GPUVertexAttribute(
        location: 0,
        buffer_slot: 0,
        format: SDL_GPU_VERTEXELEMENTFORMAT_FLOAT2,
        offset: 0
      ),
      SDL_GPUVertexAttribute(
        location: 1,
        buffer_slot: 0,
        format: SDL_GPU_VERTEXELEMENTFORMAT_FLOAT4,
        offset: (sizeof(float32) * 2).uint32
      )
    ]
    var blend = alphaBlendState()
    var colorTargets = [SDL_GPUColorTargetDescription(
      format: SDL_GetGPUSwapchainTextureFormat(device, window),
      blend_state: blend
    )]
    var vertexInput = SDL_GPUVertexInputState(
      vertex_buffer_descriptions: cast[ptr UncheckedArray[SDL_GPUVertexBufferDescription]](
        addr bufferDescriptions[0]),
      num_vertex_buffers: 1,
      vertex_attributes: cast[ptr UncheckedArray[SDL_GPUVertexAttribute]](
        addr attributes[0]),
      num_vertex_attributes: 2
    )
    var targetInfo = SDL_GPUGraphicsPipelineTargetInfo(
      color_target_descriptions: cast[ptr UncheckedArray[SDL_GPUColorTargetDescription]](
        addr colorTargets[0]),
      num_color_targets: 1
    )
    var createInfo = FixedGpuGraphicsPipelineCreateInfo(
      vertexShader: resources.quadVertexShader,
      fragmentShader: resources.quadFragmentShader,
      vertexInputState: vertexInput,
      primitiveType: SDL_GPU_PRIMITIVETYPE_TRIANGLELIST,
      rasterizerState: SDL_GPURasterizerState(
        fill_mode: SDL_GPU_FILLMODE_FILL,
        cull_mode: SDL_GPU_CULLMODE_NONE,
        front_face: SDL_GPU_FRONTFACE_COUNTER_CLOCKWISE
      ),
      multisampleState: SDL_GPUMultisampleState(sample_count: SDL_GPU_SAMPLECOUNT_1),
      targetInfo: targetInfo
    )
    resources.quadPipeline = createGpuGraphicsPipeline(device, addr createInfo)
    if resources.quadPipeline.isNil:
      echo "[Nima] SDL_GPU quad pipeline=blit (pipeline failed)"
    else:
      echo "[Nima] SDL_GPU quad pipeline=msl"
    not resources.quadPipeline.isNil

  proc ensureSpritePipeline(device: SDL_GPUDevice, window: SDL_Window,
                            resources: var GpuResources): bool =
    if resources.spritePipelineChecked:
      return not resources.spritePipeline.isNil
    resources.spritePipelineChecked = true

    let formats = SDL_GetGPUShaderFormats(device)
    if (formats and SDL_GPU_SHADERFORMAT_MSL) == 0:
      echo "[Nima] SDL_GPU sprite pipeline=blit (MSL unavailable)"
      return false

    resources.spriteVertexShader = createShader(device, spriteVertexMsl,
                                                SDL_GPU_SHADERSTAGE_VERTEX)
    if resources.spriteVertexShader.isNil:
      echo "[Nima] SDL_GPU sprite pipeline=blit (vertex shader failed)"
      return false
    resources.spriteFragmentShader = createShader(device, spriteFragmentMsl,
                                                  SDL_GPU_SHADERSTAGE_FRAGMENT,
                                                  1)
    if resources.spriteFragmentShader.isNil:
      echo "[Nima] SDL_GPU sprite pipeline=blit (fragment shader failed)"
      return false

    var samplerInfo = SDL_GPUSamplerCreateInfo(
      min_filter: SDL_GPU_FILTER_NEAREST,
      mag_filter: SDL_GPU_FILTER_NEAREST,
      mipmap_mode: SDL_GPU_SAMPLERMIPMAPMODE_NEAREST,
      address_mode_u: SDL_GPU_SAMPLERADDRESSMODE_CLAMP_TO_EDGE,
      address_mode_v: SDL_GPU_SAMPLERADDRESSMODE_CLAMP_TO_EDGE,
      address_mode_w: SDL_GPU_SAMPLERADDRESSMODE_CLAMP_TO_EDGE
    )
    resources.spriteSampler = createGpuSampler(device, addr samplerInfo)
    if resources.spriteSampler.isNil:
      echo "[Nima] SDL_GPU sprite pipeline=blit (sampler failed)"
      return false

    var bufferDescriptions = [SDL_GPUVertexBufferDescription(
      slot: 0,
      pitch: sizeof(GpuSpriteVertex).uint32,
      input_rate: SDL_GPU_VERTEXINPUTRATE_VERTEX,
      instance_step_rate: 0
    )]
    var attributes = [
      SDL_GPUVertexAttribute(
        location: 0,
        buffer_slot: 0,
        format: SDL_GPU_VERTEXELEMENTFORMAT_FLOAT2,
        offset: 0
      ),
      SDL_GPUVertexAttribute(
        location: 1,
        buffer_slot: 0,
        format: SDL_GPU_VERTEXELEMENTFORMAT_FLOAT2,
        offset: (sizeof(float32) * 2).uint32
      ),
      SDL_GPUVertexAttribute(
        location: 2,
        buffer_slot: 0,
        format: SDL_GPU_VERTEXELEMENTFORMAT_FLOAT4,
        offset: (sizeof(float32) * 4).uint32
      )
    ]
    var blend = alphaBlendState()
    var colorTargets = [SDL_GPUColorTargetDescription(
      format: SDL_GetGPUSwapchainTextureFormat(device, window),
      blend_state: blend
    )]
    var vertexInput = SDL_GPUVertexInputState(
      vertex_buffer_descriptions: cast[ptr UncheckedArray[SDL_GPUVertexBufferDescription]](
        addr bufferDescriptions[0]),
      num_vertex_buffers: 1,
      vertex_attributes: cast[ptr UncheckedArray[SDL_GPUVertexAttribute]](
        addr attributes[0]),
      num_vertex_attributes: 3
    )
    var targetInfo = SDL_GPUGraphicsPipelineTargetInfo(
      color_target_descriptions: cast[ptr UncheckedArray[SDL_GPUColorTargetDescription]](
        addr colorTargets[0]),
      num_color_targets: 1
    )
    var createInfo = FixedGpuGraphicsPipelineCreateInfo(
      vertexShader: resources.spriteVertexShader,
      fragmentShader: resources.spriteFragmentShader,
      vertexInputState: vertexInput,
      primitiveType: SDL_GPU_PRIMITIVETYPE_TRIANGLELIST,
      rasterizerState: SDL_GPURasterizerState(
        fill_mode: SDL_GPU_FILLMODE_FILL,
        cull_mode: SDL_GPU_CULLMODE_NONE,
        front_face: SDL_GPU_FRONTFACE_COUNTER_CLOCKWISE
      ),
      multisampleState: SDL_GPUMultisampleState(sample_count: SDL_GPU_SAMPLECOUNT_1),
      targetInfo: targetInfo
    )
    resources.spritePipeline = createGpuGraphicsPipeline(device, addr createInfo)
    if resources.spritePipeline.isNil:
      echo "[Nima] SDL_GPU sprite pipeline=blit (pipeline failed)"
    else:
      echo "[Nima] SDL_GPU sprite pipeline=msl"
    not resources.spritePipeline.isNil

  proc uploadVertexBuffer[T](device: SDL_GPUDevice, commandBuffer: SDL_GPUCommandBuffer,
                             vertices: openArray[T]): SDL_GPUBuffer =
    if vertices.len == 0:
      return nil
    let byteCount = (vertices.len * sizeof(T)).uint32
    var bufferInfo = SDL_GPUBufferCreateInfo(
      usage: SDL_GPUBufferUsageFlags(SDL_GPU_BUFFERUSAGE_VERTEX),
      size: byteCount
    )
    result = SDL_CreateGPUBuffer(device, addr bufferInfo)
    if result.isNil:
      return nil

    var transferInfo = SDL_GPUTransferBufferCreateInfo(
      usage: SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD,
      size: byteCount
    )
    let transfer = SDL_CreateGPUTransferBuffer(device, addr transferInfo)
    if transfer.isNil:
      SDL_ReleaseGPUBuffer(device, result)
      result = nil
      return nil
    defer: SDL_ReleaseGPUTransferBuffer(device, transfer)

    let mapped = SDL_MapGPUTransferBuffer(device, transfer, false)
    if mapped.isNil:
      SDL_ReleaseGPUBuffer(device, result)
      result = nil
      return nil
    copyMem(mapped, unsafeAddr vertices[0], byteCount.int)
    SDL_UnmapGPUTransferBuffer(device, transfer)

    let copyPass = SDL_BeginGPUCopyPass(commandBuffer)
    if copyPass.isNil:
      SDL_ReleaseGPUBuffer(device, result)
      result = nil
      return nil
    var source = FixedGpuTransferBufferLocation(transferBuffer: transfer)
    var destination = FixedGpuBufferRegion(buffer: result, size: byteCount)
    uploadToGpuBuffer(copyPass, addr source, addr destination, false)
    SDL_EndGPUCopyPass(copyPass)

  proc quadVertices(command: DrawCommand, engine: Engine): array[6, GpuVertex] =
    let points = command.transform.corners(command.anchor, command.size)
    var v: array[4, GpuVertex]
    for i in 0..<4:
      v[i] = clipVertex(pointToRender(project(points[i], command, engine), engine.viewSize),
                        engine.viewSize, command.color)
    result[0] = v[0]
    result[1] = v[1]
    result[2] = v[2]
    result[3] = v[0]
    result[4] = v[2]
    result[5] = v[3]

  proc spriteVertex(renderPos, uv: Vec2, view: Vec2, color: Color): GpuSpriteVertex =
    GpuSpriteVertex(
      x: renderPos.x / max(1'f32, view.x) * 2'f32 - 1'f32,
      y: 1'f32 - renderPos.y / max(1'f32, view.y) * 2'f32,
      u: uv.x,
      v: uv.y,
      r: color.r,
      g: color.g,
      b: color.b,
      a: color.a
    )

  proc spriteVertices(command: DrawCommand, engine: Engine,
                      uploaded: UploadedTexture): array[6, GpuSpriteVertex] =
    let spriteSize = vec2(command.sprite.size.x.float32, command.sprite.size.y.float32)
    let points = command.transform.corners(command.sprite.anchor, spriteSize)
    let source =
      if command.sprite.hasSrc:
        command.sprite.src
      else:
        rect(Vec2Zero, vec2(uploaded.width.float32, uploaded.height.float32))
    var u0 = clamp(source.min.x / max(1'f32, uploaded.width.float32), 0, 1)
    var u1 = clamp(source.max.x / max(1'f32, uploaded.width.float32), 0, 1)
    var v0 = clamp(source.min.y / max(1'f32, uploaded.height.float32), 0, 1)
    var v1 = clamp(source.max.y / max(1'f32, uploaded.height.float32), 0, 1)
    if command.sprite.flipX:
      swap(u0, u1)
    if command.sprite.flipY:
      swap(v0, v1)

    let uvs = [
      vec2(u0, v1),
      vec2(u1, v1),
      vec2(u1, v0),
      vec2(u0, v0)
    ]
    var v: array[4, GpuSpriteVertex]
    for i in 0..<4:
      let renderPos = pointToRender(project(points[i], command, engine), engine.viewSize)
      v[i] = spriteVertex(renderPos, uvs[i], engine.viewSize, command.sprite.color)
    result[0] = v[0]
    result[1] = v[1]
    result[2] = v[2]
    result[3] = v[0]
    result[4] = v[2]
    result[5] = v[3]

  proc drawShaderRect(commandBuffer: SDL_GPUCommandBuffer, device: SDL_GPUDevice,
                      window: SDL_Window, swapchainTexture: SDL_GPUTexture,
                      engine: Engine, resources: var GpuResources,
                      command: DrawCommand): bool =
    if not ensureQuadPipeline(device, window, resources):
      return false

    let vertices = command.quadVertices(engine)
    let vertexBuffer = uploadVertexBuffer(device, commandBuffer, vertices)
    if vertexBuffer.isNil:
      return false
    defer: SDL_ReleaseGPUBuffer(device, vertexBuffer)

    var target = FixedGpuColorTargetInfo(
      texture: swapchainTexture,
      loadOp: SDL_GPU_LOADOP_LOAD,
      storeOp: SDL_GPU_STOREOP_STORE,
      cycle: false
    )
    let pass = beginGpuRenderPass(commandBuffer, addr target, 1, nil)
    if pass.isNil:
      return false
    SDL_BindGPUGraphicsPipeline(pass, resources.quadPipeline)
    var binding = FixedGpuBufferBinding(buffer: vertexBuffer)
    bindGpuVertexBuffers(pass, 0, addr binding, 1)
    SDL_DrawGPUPrimitives(pass, 6, 1, 0, 0)
    SDL_EndGPURenderPass(pass)
    true

  proc drawShaderRectBatch(commandBuffer: SDL_GPUCommandBuffer, device: SDL_GPUDevice,
                           window: SDL_Window, swapchainTexture: SDL_GPUTexture,
                           engine: Engine, resources: var GpuResources,
                           commands: seq[DrawCommand], start, count: int): bool =
    if count <= 0 or not ensureQuadPipeline(device, window, resources):
      return false

    var vertices = newSeqOfCap[GpuVertex](count * 6)
    for i in start ..< start + count:
      let quad = commands[i].quadVertices(engine)
      for vertex in quad:
        vertices.add vertex

    let vertexBuffer = uploadVertexBuffer(device, commandBuffer, vertices)
    if vertexBuffer.isNil:
      return false
    defer: SDL_ReleaseGPUBuffer(device, vertexBuffer)

    var target = FixedGpuColorTargetInfo(
      texture: swapchainTexture,
      loadOp: SDL_GPU_LOADOP_LOAD,
      storeOp: SDL_GPU_STOREOP_STORE,
      cycle: false
    )
    let pass = beginGpuRenderPass(commandBuffer, addr target, 1, nil)
    if pass.isNil:
      return false
    SDL_BindGPUGraphicsPipeline(pass, resources.quadPipeline)
    var binding = FixedGpuBufferBinding(buffer: vertexBuffer)
    bindGpuVertexBuffers(pass, 0, addr binding, 1)
    SDL_DrawGPUPrimitives(pass, vertices.len.uint32, 1, 0, 0)
    SDL_EndGPURenderPass(pass)
    true

  proc polyPoints(command: DrawCommand, engine: Engine): seq[Vec2] =
    if command.sides < 3:
      return
    let radius = command.radius * (if command.space == dsWorld: engine.cameraZoom else: 1'f32)
    if radius <= 0'f32:
      return
    let center = project(command.center.xy, command, engine)
    for i in 0..<command.sides.int:
      let t = command.rotation + (i.float32 / command.sides.float32) *
        (2'f32 * stdmath.PI.float32)
      let p = vec2(center.x + stdmath.cos(t).float32 * radius,
                   center.y + stdmath.sin(t).float32 * radius)
      result.add pointToRender(p, engine.viewSize)

  proc drawShaderVertices(commandBuffer: SDL_GPUCommandBuffer, device: SDL_GPUDevice,
                          window: SDL_Window, swapchainTexture: SDL_GPUTexture,
                          engine: Engine, resources: var GpuResources,
                          vertices: openArray[GpuVertex]): bool =
    if vertices.len == 0:
      return true
    if not ensureQuadPipeline(device, window, resources):
      return false

    let vertexBuffer = uploadVertexBuffer(device, commandBuffer, vertices)
    if vertexBuffer.isNil:
      return false
    defer: SDL_ReleaseGPUBuffer(device, vertexBuffer)

    var target = FixedGpuColorTargetInfo(
      texture: swapchainTexture,
      loadOp: SDL_GPU_LOADOP_LOAD,
      storeOp: SDL_GPU_STOREOP_STORE,
      cycle: false
    )
    let pass = beginGpuRenderPass(commandBuffer, addr target, 1, nil)
    if pass.isNil:
      return false
    SDL_BindGPUGraphicsPipeline(pass, resources.quadPipeline)
    var binding = FixedGpuBufferBinding(buffer: vertexBuffer)
    bindGpuVertexBuffers(pass, 0, addr binding, 1)
    SDL_DrawGPUPrimitives(pass, vertices.len.uint32, 1, 0, 0)
    SDL_EndGPURenderPass(pass)
    true

  proc addLineSegmentVertices(vertices: var seq[GpuVertex], a, b: Vec2,
                              thickness: float32, view: Vec2, color: Color) =
    let thick = max(1'f32, thickness)
    let half = thick * 0.5'f32
    let delta = b - a
    let len = delta.length
    var points: array[4, Vec2]
    if len <= 0.0001'f32:
      points[0] = vec2(a.x - half, a.y - half)
      points[1] = vec2(a.x + half, a.y - half)
      points[2] = vec2(a.x + half, a.y + half)
      points[3] = vec2(a.x - half, a.y + half)
    else:
      let normal = vec2(-delta.y / len, delta.x / len) * half
      points[0] = a - normal
      points[1] = b - normal
      points[2] = b + normal
      points[3] = a + normal

    vertices.add clipVertex(points[0], view, color)
    vertices.add clipVertex(points[1], view, color)
    vertices.add clipVertex(points[2], view, color)
    vertices.add clipVertex(points[0], view, color)
    vertices.add clipVertex(points[2], view, color)
    vertices.add clipVertex(points[3], view, color)

  proc patternedLineVertices(command: DrawCommand, engine: Engine): seq[GpuVertex] =
    let a = pointToRender(project(command.line.start, command, engine), engine.viewSize)
    let b = pointToRender(project(command.line.stop, command, engine), engine.viewSize)
    let delta = b - a
    let len = delta.length
    if len <= 0.0001'f32:
      return
    let dir = delta / len
    case command.line.pattern.kind
    of lpkSolid:
      result = newSeqOfCap[GpuVertex](6)
      result.addLineSegmentVertices(a, b, command.line.thickness, engine.viewSize,
                                    command.line.color)
    of lpkDashed, lpkDotted:
      let dash =
        case command.line.pattern.kind
        of lpkDashed: max(0.01'f32, command.line.pattern.dashLength)
        of lpkDotted: max(0.01'f32, command.line.pattern.spacing * 0.5'f32)
        else: 1'f32
      let gap =
        case command.line.pattern.kind
        of lpkDashed: max(0.01'f32, command.line.pattern.gapLength)
        of lpkDotted: max(0.01'f32, command.line.pattern.spacing * 0.5'f32)
        else: 1'f32
      let period = dash + gap
      let segmentCount = max(1, stdmath.ceil(len / period).int)
      result = newSeqOfCap[GpuVertex](segmentCount * 6)
      var current = -command.line.patternOffset
      while current < len:
        let startD = max(0'f32, current)
        let endD = min(len, current + dash)
        if startD < endD:
          result.addLineSegmentVertices(a + dir * startD, a + dir * endD,
                                        command.line.thickness, engine.viewSize,
                                        command.line.color)
        current += period

  proc circleSegments(radius: float32): int =
    max(16, min(128, stdmath.ceil(radius * 0.75'f32).int))

  proc circleVertices(command: DrawCommand, engine: Engine): seq[GpuVertex] =
    let radius = command.radius * (if command.space == dsWorld: engine.cameraZoom else: 1'f32)
    if radius <= 0'f32:
      return
    let center = pointToRender(project(command.center.xy, command, engine), engine.viewSize)
    let segments = circleSegments(radius)
    result = newSeqOfCap[GpuVertex](segments * 3)
    let centerVertex = clipVertex(center, engine.viewSize, command.color)
    for i in 0..<segments:
      let a = (i.float32 / segments.float32) * (2'f32 * stdmath.PI.float32)
      let b = ((i + 1).float32 / segments.float32) * (2'f32 * stdmath.PI.float32)
      let pa = vec2(center.x + stdmath.cos(a).float32 * radius,
                    center.y + stdmath.sin(a).float32 * radius)
      let pb = vec2(center.x + stdmath.cos(b).float32 * radius,
                    center.y + stdmath.sin(b).float32 * radius)
      result.add centerVertex
      result.add clipVertex(pa, engine.viewSize, command.color)
      result.add clipVertex(pb, engine.viewSize, command.color)

  proc polyFanVertices(command: DrawCommand, engine: Engine): seq[GpuVertex] =
    let points = polyPoints(command, engine)
    if points.len < 3:
      return
    let center = pointToRender(project(command.center.xy, command, engine), engine.viewSize)
    let centerVertex = clipVertex(center, engine.viewSize, command.color)
    result = newSeqOfCap[GpuVertex](points.len * 3)
    for i in 0..<points.len:
      result.add centerVertex
      result.add clipVertex(points[i], engine.viewSize, command.color)
      result.add clipVertex(points[(i + 1) mod points.len], engine.viewSize, command.color)

  proc polyLineVertices(command: DrawCommand, engine: Engine): seq[GpuVertex] =
    let points = polyPoints(command, engine)
    if points.len < 2:
      return
    result = newSeqOfCap[GpuVertex](points.len * 6)
    for i in 0..<points.len:
      result.addLineSegmentVertices(points[i], points[(i + 1) mod points.len],
                                    command.thickness, engine.viewSize, command.color)

  proc drawShaderPatternedLine(commandBuffer: SDL_GPUCommandBuffer,
                               device: SDL_GPUDevice, window: SDL_Window,
                               swapchainTexture: SDL_GPUTexture, engine: Engine,
                               resources: var GpuResources,
                               command: DrawCommand): bool =
    let vertices = command.patternedLineVertices(engine)
    drawShaderVertices(commandBuffer, device, window, swapchainTexture,
                       engine, resources, vertices)

  proc drawShaderCircle(commandBuffer: SDL_GPUCommandBuffer, device: SDL_GPUDevice,
                        window: SDL_Window, swapchainTexture: SDL_GPUTexture,
                        engine: Engine, resources: var GpuResources,
                        command: DrawCommand): bool =
    let vertices = command.circleVertices(engine)
    drawShaderVertices(commandBuffer, device, window, swapchainTexture,
                       engine, resources, vertices)

  proc drawShaderPoly(commandBuffer: SDL_GPUCommandBuffer, device: SDL_GPUDevice,
                      window: SDL_Window, swapchainTexture: SDL_GPUTexture,
                      engine: Engine, resources: var GpuResources,
                      command: DrawCommand): bool =
    let vertices = command.polyFanVertices(engine)
    drawShaderVertices(commandBuffer, device, window, swapchainTexture,
                       engine, resources, vertices)

  proc drawShaderPolyLines(commandBuffer: SDL_GPUCommandBuffer,
                           device: SDL_GPUDevice, window: SDL_Window,
                           swapchainTexture: SDL_GPUTexture, engine: Engine,
                           resources: var GpuResources,
                           command: DrawCommand): bool =
    let vertices = command.polyLineVertices(engine)
    drawShaderVertices(commandBuffer, device, window, swapchainTexture,
                       engine, resources, vertices)

  proc drawShaderSprite(commandBuffer: SDL_GPUCommandBuffer, device: SDL_GPUDevice,
                        window: SDL_Window, swapchainTexture: SDL_GPUTexture,
                        engine: Engine, resources: var GpuResources,
                        command: DrawCommand): bool =
    if not ensureSpritePipeline(device, window, resources):
      return false
    let uploaded = textureFor(device, commandBuffer, resources, command.sprite.texture)
    if uploaded.texture.isNil:
      var fallback = command
      fallback.kind = dckRect
      fallback.color = command.sprite.color
      fallback.size = vec2(command.sprite.size.x.float32, command.sprite.size.y.float32)
      fallback.anchor = command.sprite.anchor
      return drawShaderRect(commandBuffer, device, window, swapchainTexture,
                            engine, resources, fallback)

    let vertices = command.spriteVertices(engine, uploaded)
    let vertexBuffer = uploadVertexBuffer(device, commandBuffer, vertices)
    if vertexBuffer.isNil:
      return false
    defer: SDL_ReleaseGPUBuffer(device, vertexBuffer)

    var target = FixedGpuColorTargetInfo(
      texture: swapchainTexture,
      loadOp: SDL_GPU_LOADOP_LOAD,
      storeOp: SDL_GPU_STOREOP_STORE,
      cycle: false
    )
    let pass = beginGpuRenderPass(commandBuffer, addr target, 1, nil)
    if pass.isNil:
      return false
    SDL_BindGPUGraphicsPipeline(pass, resources.spritePipeline)
    var vertexBinding = FixedGpuBufferBinding(buffer: vertexBuffer)
    bindGpuVertexBuffers(pass, 0, addr vertexBinding, 1)
    var samplerBinding = FixedGpuTextureSamplerBinding(
      texture: uploaded.texture,
      sampler: resources.spriteSampler
    )
    bindGpuFragmentSamplers(pass, 0, addr samplerBinding, 1)
    SDL_DrawGPUPrimitives(pass, 6, 1, 0, 0)
    SDL_EndGPURenderPass(pass)
    true

  proc drawShaderSpriteBatch(commandBuffer: SDL_GPUCommandBuffer, device: SDL_GPUDevice,
                             window: SDL_Window, swapchainTexture: SDL_GPUTexture,
                             engine: Engine, resources: var GpuResources,
                             commands: seq[DrawCommand], start, count: int): bool =
    if count <= 0 or not ensureSpritePipeline(device, window, resources):
      return false

    let texture = commands[start].sprite.texture
    let uploaded = textureFor(device, commandBuffer, resources, texture)
    if uploaded.texture.isNil:
      return false

    var vertices = newSeqOfCap[GpuSpriteVertex](count * 6)
    for i in start ..< start + count:
      if commands[i].sprite.texture.id != texture.id:
        return false
      let quad = commands[i].spriteVertices(engine, uploaded)
      for vertex in quad:
        vertices.add vertex

    let vertexBuffer = uploadVertexBuffer(device, commandBuffer, vertices)
    if vertexBuffer.isNil:
      return false
    defer: SDL_ReleaseGPUBuffer(device, vertexBuffer)

    var target = FixedGpuColorTargetInfo(
      texture: swapchainTexture,
      loadOp: SDL_GPU_LOADOP_LOAD,
      storeOp: SDL_GPU_STOREOP_STORE,
      cycle: false
    )
    let pass = beginGpuRenderPass(commandBuffer, addr target, 1, nil)
    if pass.isNil:
      return false
    SDL_BindGPUGraphicsPipeline(pass, resources.spritePipeline)
    var vertexBinding = FixedGpuBufferBinding(buffer: vertexBuffer)
    bindGpuVertexBuffers(pass, 0, addr vertexBinding, 1)
    var samplerBinding = FixedGpuTextureSamplerBinding(
      texture: uploaded.texture,
      sampler: resources.spriteSampler
    )
    bindGpuFragmentSamplers(pass, 0, addr samplerBinding, 1)
    SDL_DrawGPUPrimitives(pass, vertices.len.uint32, 1, 0, 0)
    SDL_EndGPURenderPass(pass)
    true

  proc glyphVertices(command: DrawCommand, engine: Engine,
                     run: SdlGlyphRun,
                     atlas: UploadedGlyphAtlas): seq[GpuSpriteVertex] =
    let p = pointToRender(project(command.transform.pos.xy, command, engine),
                          engine.viewSize)
    let origin = vec2(p.x - run.size.x * command.anchor.x,
                      p.y - run.size.y * (1'f32 - command.anchor.y))
    result = newSeqOfCap[GpuSpriteVertex](run.glyphs.len * 6)
    for glyph in run.glyphs:
      let dstMin = origin + glyph.dst.min
      let dstSize = glyph.dst.size
      let x0 = dstMin.x
      let y0 = dstMin.y
      let x1 = dstMin.x + dstSize.x
      let y1 = dstMin.y + dstSize.y
      let u0 = glyph.src.min.x / max(1'f32, atlas.width.float32)
      let u1 = glyph.src.max.x / max(1'f32, atlas.width.float32)
      let v0 = glyph.src.min.y / max(1'f32, atlas.height.float32)
      let v1 = glyph.src.max.y / max(1'f32, atlas.height.float32)
      let color = command.text.color
      let v = [
        spriteVertex(vec2(x0, y1), vec2(u0, v1), engine.viewSize, color),
        spriteVertex(vec2(x1, y1), vec2(u1, v1), engine.viewSize, color),
        spriteVertex(vec2(x1, y0), vec2(u1, v0), engine.viewSize, color),
        spriteVertex(vec2(x0, y0), vec2(u0, v0), engine.viewSize, color)
      ]
      result.add v[0]
      result.add v[1]
      result.add v[2]
      result.add v[0]
      result.add v[2]
      result.add v[3]

  proc drawShaderGlyphRun(commandBuffer: SDL_GPUCommandBuffer,
                          device: SDL_GPUDevice, window: SDL_Window,
                          swapchainTexture: SDL_GPUTexture, engine: Engine,
                          resources: var GpuResources, ttf: var SdlTtfState,
                          command: DrawCommand): bool =
    if not ensureSpritePipeline(device, window, resources):
      return false
    let run = ttf.layoutGlyphRun(command.text)
    if run.atlas.isNil:
      return false
    let atlas = glyphAtlasTexture(device, commandBuffer, resources, run.atlas)
    if atlas.texture.isNil:
      return false
    if run.glyphs.len == 0:
      return true

    let vertices = command.glyphVertices(engine, run, atlas)
    let vertexBuffer = uploadVertexBuffer(device, commandBuffer, vertices)
    if vertexBuffer.isNil:
      return false
    defer: SDL_ReleaseGPUBuffer(device, vertexBuffer)

    var target = FixedGpuColorTargetInfo(
      texture: swapchainTexture,
      loadOp: SDL_GPU_LOADOP_LOAD,
      storeOp: SDL_GPU_STOREOP_STORE,
      cycle: false
    )
    let pass = beginGpuRenderPass(commandBuffer, addr target, 1, nil)
    if pass.isNil:
      return false
    SDL_BindGPUGraphicsPipeline(pass, resources.spritePipeline)
    var vertexBinding = FixedGpuBufferBinding(buffer: vertexBuffer)
    bindGpuVertexBuffers(pass, 0, addr vertexBinding, 1)
    var samplerBinding = FixedGpuTextureSamplerBinding(
      texture: atlas.texture,
      sampler: resources.spriteSampler
    )
    bindGpuFragmentSamplers(pass, 0, addr samplerBinding, 1)
    SDL_DrawGPUPrimitives(pass, vertices.len.uint32, 1, 0, 0)
    SDL_EndGPURenderPass(pass)
    true

  proc blitTargetRect(commandBuffer: SDL_GPUCommandBuffer, device: SDL_GPUDevice,
                      swapchainTexture: SDL_GPUTexture, targetWidth, targetHeight: uint32,
                      engine: Engine, resources: var GpuResources,
                      x, y, w, h: float32, color: Color) =
    if w <= 0'f32 or h <= 0'f32:
      return
    let scaleX = targetWidth.float32 / max(1'f32, engine.viewSize.x)
    let scaleY = targetHeight.float32 / max(1'f32, engine.viewSize.y)
    let minX = max(0'f32, stdmath.floor(x * scaleX))
    let minY = max(0'f32, stdmath.floor(y * scaleY))
    let maxX = min(targetWidth.float32, stdmath.ceil((x + w) * scaleX))
    let maxY = min(targetHeight.float32, stdmath.ceil((y + h) * scaleY))
    if maxX <= minX or maxY <= minY:
      return

    let srcTexture = colorTexture(device, commandBuffer, resources, color)
    var info = FixedGpuBlitInfo(
      source: FixedGpuBlitRegion(texture: srcTexture, w: 1, h: 1),
      destination: FixedGpuBlitRegion(texture: swapchainTexture,
                                      x: minX.uint32,
                                      y: minY.uint32,
                                      w: (maxX - minX).uint32,
                                      h: (maxY - minY).uint32),
      loadOp: SDL_GPU_LOADOP_LOAD,
      filter: SDL_GPU_FILTER_NEAREST,
      cycle: false
    )
    blitGpuTexture(commandBuffer, addr info)

  proc blitFilledPoints(commandBuffer: SDL_GPUCommandBuffer, device: SDL_GPUDevice,
                        swapchainTexture: SDL_GPUTexture, targetWidth, targetHeight: uint32,
                        engine: Engine, resources: var GpuResources,
                        points: openArray[Vec2], color: Color) =
    if points.len < 3:
      return
    var minY = points[0].y
    var maxY = points[0].y
    for p in points:
      minY = min(minY, p.y)
      maxY = max(maxY, p.y)
    let y0 = max(0, stdmath.floor(minY).int)
    let y1 = min(engine.viewSize.y.ceil.int, stdmath.ceil(maxY).int)
    if y1 < y0:
      return
    for yi in y0..y1:
      let scanY = yi.float32 + 0.5'f32
      var xs: seq[float32]
      for i in 0..<points.len:
        let a = points[i]
        let b = points[(i + 1) mod points.len]
        if (a.y <= scanY and b.y > scanY) or (b.y <= scanY and a.y > scanY):
          let t = (scanY - a.y) / (b.y - a.y)
          xs.add a.x + (b.x - a.x) * t
      xs.sort()
      var i = 0
      while i + 1 < xs.len:
        let x0 = xs[i]
        let x1 = xs[i + 1]
        if x1 > x0:
          blitTargetRect(commandBuffer, device, swapchainTexture, targetWidth, targetHeight,
                         engine, resources, x0, yi.float32, x1 - x0, 1'f32, color)
        i += 2

  proc rectRenderPoints(command: DrawCommand, engine: Engine): array[4, Vec2] =
    let points = command.transform.corners(command.anchor, command.size)
    for i in 0..<4:
      result[i] = pointToRender(project(points[i], command, engine), engine.viewSize)

  proc clippedBlitRect(command: DrawCommand, engine: Engine,
                       targetWidth, targetHeight: uint32): tuple[ok: bool, x, y, w, h: uint32] =
    let bounds = command.transform.bounds(command.anchor, command.size)
    let projected = projectBounds(bounds, command, engine).rectToRender(engine.viewSize)
    let scaleX = targetWidth.float32 / max(1'f32, engine.viewSize.x)
    let scaleY = targetHeight.float32 / max(1'f32, engine.viewSize.y)
    let minX = max(0'f32, stdmath.floor(projected.min.x * scaleX))
    let minY = max(0'f32, stdmath.floor(projected.min.y * scaleY))
    let maxX = min(targetWidth.float32, stdmath.ceil(projected.max.x * scaleX))
    let maxY = min(targetHeight.float32, stdmath.ceil(projected.max.y * scaleY))
    if maxX <= minX or maxY <= minY:
      return (false, 0'u32, 0'u32, 0'u32, 0'u32)
    (true, minX.uint32, minY.uint32, (maxX - minX).uint32, (maxY - minY).uint32)

  proc blitRect(commandBuffer: SDL_GPUCommandBuffer, device: SDL_GPUDevice,
                swapchainTexture: SDL_GPUTexture, targetWidth, targetHeight: uint32,
                engine: Engine, resources: var GpuResources, command: DrawCommand) =
    if not command.transform.angle.isZeroAngle:
      let points = rectRenderPoints(command, engine)
      blitFilledPoints(commandBuffer, device, swapchainTexture, targetWidth, targetHeight,
                       engine, resources, points, command.color)
      return

    let dst = clippedBlitRect(command, engine, targetWidth, targetHeight)
    if not dst.ok:
      return
    let srcTexture = colorTexture(device, commandBuffer, resources, command.color)
    var info = FixedGpuBlitInfo(
      source: FixedGpuBlitRegion(texture: srcTexture, w: 1, h: 1),
      destination: FixedGpuBlitRegion(texture: swapchainTexture, x: dst.x, y: dst.y,
                                      w: dst.w, h: dst.h),
      loadOp: SDL_GPU_LOADOP_LOAD,
      filter: SDL_GPU_FILTER_NEAREST,
      cycle: false
    )
    blitGpuTexture(commandBuffer, addr info)

  proc blitLineSegment(commandBuffer: SDL_GPUCommandBuffer, device: SDL_GPUDevice,
                       swapchainTexture: SDL_GPUTexture, targetWidth, targetHeight: uint32,
                       engine: Engine, resources: var GpuResources,
                       a, b: Vec2, thickness: float32, color: Color) =
    let delta = b - a
    let len = delta.length
    let thick = max(1'f32, thickness)
    if len <= 0.0001'f32:
      blitTargetRect(commandBuffer, device, swapchainTexture, targetWidth, targetHeight,
                     engine, resources, a.x - thick * 0.5'f32, a.y - thick * 0.5'f32,
                     thick, thick, color)
      return
    let step = max(1'f32, thick * 0.5'f32)
    let count = max(1, stdmath.ceil(len / step).int)
    for i in 0..count:
      let t = i.float32 / count.float32
      let p = a + delta * t
      blitTargetRect(commandBuffer, device, swapchainTexture, targetWidth, targetHeight,
                     engine, resources, p.x - thick * 0.5'f32, p.y - thick * 0.5'f32,
                     thick, thick, color)

  proc blitPatternedLine(commandBuffer: SDL_GPUCommandBuffer, device: SDL_GPUDevice,
                         swapchainTexture: SDL_GPUTexture, targetWidth, targetHeight: uint32,
                         engine: Engine, resources: var GpuResources,
                         command: DrawCommand) =
    let a = pointToRender(project(command.line.start, command, engine), engine.viewSize)
    let b = pointToRender(project(command.line.stop, command, engine), engine.viewSize)
    let delta = b - a
    let len = delta.length
    if len <= 0.0001'f32:
      return
    let dir = delta / len
    case command.line.pattern.kind
    of lpkSolid:
      blitLineSegment(commandBuffer, device, swapchainTexture, targetWidth, targetHeight,
                      engine, resources, a, b, command.line.thickness, command.line.color)
    of lpkDashed, lpkDotted:
      let dash =
        case command.line.pattern.kind
        of lpkDashed: max(0.01'f32, command.line.pattern.dashLength)
        of lpkDotted: max(0.01'f32, command.line.pattern.spacing * 0.5'f32)
        else: 1'f32
      let gap =
        case command.line.pattern.kind
        of lpkDashed: max(0.01'f32, command.line.pattern.gapLength)
        of lpkDotted: max(0.01'f32, command.line.pattern.spacing * 0.5'f32)
        else: 1'f32
      let period = dash + gap
      var current = -command.line.patternOffset
      while current < len:
        let startD = max(0'f32, current)
        let endD = min(len, current + dash)
        if startD < endD:
          blitLineSegment(commandBuffer, device, swapchainTexture, targetWidth, targetHeight,
                          engine, resources, a + dir * startD, a + dir * endD,
                          command.line.thickness, command.line.color)
        current += period

  proc blitCircle(commandBuffer: SDL_GPUCommandBuffer, device: SDL_GPUDevice,
                  swapchainTexture: SDL_GPUTexture, targetWidth, targetHeight: uint32,
                  engine: Engine, resources: var GpuResources, command: DrawCommand) =
    let radius = command.radius * (if command.space == dsWorld: engine.cameraZoom else: 1'f32)
    if radius <= 0'f32:
      return
    let center = pointToRender(project(command.center.xy, command, engine), engine.viewSize)
    let r = radius.ceil.int
    for y in -r..r:
      let yf = y.float32
      let inner = radius * radius - yf * yf
      if inner < 0'f32:
        continue
      let span = stdmath.sqrt(inner).float32
      blitTargetRect(commandBuffer, device, swapchainTexture, targetWidth, targetHeight,
                     engine, resources, center.x - span, center.y + yf,
                     span * 2'f32, 1'f32, command.color)

  proc blitPoly(commandBuffer: SDL_GPUCommandBuffer, device: SDL_GPUDevice,
                swapchainTexture: SDL_GPUTexture, targetWidth, targetHeight: uint32,
                engine: Engine, resources: var GpuResources, command: DrawCommand) =
    let points = polyPoints(command, engine)
    blitFilledPoints(commandBuffer, device, swapchainTexture, targetWidth, targetHeight,
                     engine, resources, points, command.color)

  proc blitPolyLines(commandBuffer: SDL_GPUCommandBuffer, device: SDL_GPUDevice,
                     swapchainTexture: SDL_GPUTexture, targetWidth, targetHeight: uint32,
                     engine: Engine, resources: var GpuResources, command: DrawCommand) =
    let points = polyPoints(command, engine)
    if points.len < 2:
      return
    for i in 0..<points.len:
      blitLineSegment(commandBuffer, device, swapchainTexture, targetWidth, targetHeight,
                      engine, resources, points[i], points[(i + 1) mod points.len],
                      command.thickness, command.color)

  proc clippedSpriteRect(command: DrawCommand, engine: Engine,
                         targetWidth, targetHeight: uint32): tuple[ok: bool, x, y, w, h: uint32] =
    let spriteSize = vec2(command.sprite.size.x.float32, command.sprite.size.y.float32)
    var base = command.transform
    base.angle = 0
    let bounds = base.bounds(command.sprite.anchor, spriteSize)
    let projected = projectBounds(bounds, command, engine).rectToRender(engine.viewSize)
    let scaleX = targetWidth.float32 / max(1'f32, engine.viewSize.x)
    let scaleY = targetHeight.float32 / max(1'f32, engine.viewSize.y)
    let minX = max(0'f32, stdmath.floor(projected.min.x * scaleX))
    let minY = max(0'f32, stdmath.floor(projected.min.y * scaleY))
    let maxX = min(targetWidth.float32, stdmath.ceil(projected.max.x * scaleX))
    let maxY = min(targetHeight.float32, stdmath.ceil(projected.max.y * scaleY))
    if maxX <= minX or maxY <= minY:
      return (false, 0'u32, 0'u32, 0'u32, 0'u32)
    (true, minX.uint32, minY.uint32, (maxX - minX).uint32, (maxY - minY).uint32)

  proc spriteFlip(sprite: Sprite): SDL_FlipMode =
    if sprite.flipX:
      SDL_FLIP_HORIZONTAL
    elif sprite.flipY:
      SDL_FLIP_VERTICAL
    else:
      SDL_FLIP_NONE

  proc blitSprite(commandBuffer: SDL_GPUCommandBuffer, device: SDL_GPUDevice,
                  swapchainTexture: SDL_GPUTexture, targetWidth, targetHeight: uint32,
                  engine: Engine, resources: var GpuResources, command: DrawCommand) =
    let uploaded = textureFor(device, commandBuffer, resources, command.sprite.texture,
                              command.sprite.color)
    if uploaded.texture.isNil:
      var fallback = command
      fallback.kind = dckRect
      fallback.color = command.sprite.color
      fallback.size = vec2(command.sprite.size.x.float32, command.sprite.size.y.float32)
      fallback.anchor = command.sprite.anchor
      blitRect(commandBuffer, device, swapchainTexture, targetWidth, targetHeight,
               engine, resources, fallback)
      return

    let dst = clippedSpriteRect(command, engine, targetWidth, targetHeight)
    if not dst.ok:
      return

    var source = FixedGpuBlitRegion(texture: uploaded.texture, w: uploaded.width,
                                    h: uploaded.height)
    if command.sprite.hasSrc:
      let minX = max(0'f32, stdmath.floor(command.sprite.src.min.x))
      let minY = max(0'f32, stdmath.floor(command.sprite.src.min.y))
      let maxX = min(uploaded.width.float32, stdmath.ceil(command.sprite.src.max.x))
      let maxY = min(uploaded.height.float32, stdmath.ceil(command.sprite.src.max.y))
      if maxX <= minX or maxY <= minY:
        return
      source.x = minX.uint32
      source.y = minY.uint32
      source.w = (maxX - minX).uint32
      source.h = (maxY - minY).uint32

    var info = FixedGpuBlitInfo(
      source: source,
      destination: FixedGpuBlitRegion(texture: swapchainTexture, x: dst.x, y: dst.y,
                                      w: dst.w, h: dst.h),
      loadOp: SDL_GPU_LOADOP_LOAD,
      flipMode: command.sprite.spriteFlip,
      filter: SDL_GPU_FILTER_NEAREST,
      cycle: false
    )
    blitGpuTexture(commandBuffer, addr info)

  proc blitText(commandBuffer: SDL_GPUCommandBuffer, device: SDL_GPUDevice,
                window: SDL_Window,
                swapchainTexture: SDL_GPUTexture, targetWidth, targetHeight: uint32,
                engine: Engine, resources: var GpuResources, ttf: var SdlTtfState,
                command: DrawCommand) =
    if drawShaderGlyphRun(commandBuffer, device, window, swapchainTexture,
                          engine, resources, ttf, command):
      return
    let uploaded = textTexture(device, commandBuffer, resources, ttf, command.text)
    if uploaded.texture.isNil:
      return
    let p = pointToRender(project(command.transform.pos.xy, command, engine), engine.viewSize)
    let width = uploaded.width.float32 * uploaded.scale
    let height = uploaded.height.float32 * uploaded.scale
    let scaleX = targetWidth.float32 / max(1'f32, engine.viewSize.x)
    let scaleY = targetHeight.float32 / max(1'f32, engine.viewSize.y)
    let x = p.x - width * command.anchor.x
    let y = p.y - height * (1'f32 - command.anchor.y)
    let minX = max(0'f32, stdmath.floor(x * scaleX))
    let minY = max(0'f32, stdmath.floor(y * scaleY))
    let maxX = min(targetWidth.float32, stdmath.ceil((x + width) * scaleX))
    let maxY = min(targetHeight.float32, stdmath.ceil((y + height) * scaleY))
    if maxX <= minX or maxY <= minY:
      return
    var info = FixedGpuBlitInfo(
      source: FixedGpuBlitRegion(texture: uploaded.texture,
                                  w: uploaded.width,
                                  h: uploaded.height),
      destination: FixedGpuBlitRegion(texture: swapchainTexture,
                                      x: minX.uint32,
                                      y: minY.uint32,
                                      w: (maxX - minX).uint32,
                                      h: (maxY - minY).uint32),
      loadOp: SDL_GPU_LOADOP_LOAD,
      filter: SDL_GPU_FILTER_NEAREST,
      cycle: false
    )
    blitGpuTexture(commandBuffer, addr info)

  proc renderFrame(device: SDL_GPUDevice, window: SDL_Window, engine: var Engine,
                   resources: var GpuResources, ttf: var SdlTtfState) =
    let commandBuffer = SDL_AcquireGPUCommandBuffer(device)
    if commandBuffer.isNil:
      raise sdlGpuError("SDL_AcquireGPUCommandBuffer failed")

    var swapchainTexture: SDL_GPUTexture
    var width, height: uint32
    if not waitAndAcquireGpuSwapchainTexture(commandBuffer, window,
                                             swapchainTexture, width, height):
      discard SDL_CancelGPUCommandBuffer(commandBuffer)
      raise sdlGpuError("SDL_WaitAndAcquireGPUSwapchainTexture failed")

    if swapchainTexture.isNil:
      discard SDL_SubmitGPUCommandBuffer(commandBuffer)
      return

    clearTexture(commandBuffer, swapchainTexture, engine.clearColor())

    var commands = engine.recorder.commands
    commands.sort(proc(a, b: DrawCommand): int =
      if a.z < b.z: -1
      elif a.z > b.z: 1
      elif a.order < b.order: -1
      elif a.order > b.order: 1
      else: 0
    )
    var batchCount = 0
    var i = 0
    while i < commands.len:
      let command = commands[i]
      case command.kind
      of dckSprite:
        var run = 1
        while i + run < commands.len and commands[i + run].kind == dckSprite and
            commands[i + run].sprite.texture.id == command.sprite.texture.id:
          inc run
        if run > 1 and drawShaderSpriteBatch(commandBuffer, device, window,
                                             swapchainTexture, engine, resources,
                                             commands, i, run):
          inc batchCount
          i += run
          continue
        if not drawShaderSprite(commandBuffer, device, window, swapchainTexture,
                                engine, resources, command):
          blitSprite(commandBuffer, device, swapchainTexture, width, height,
                     engine, resources, command)
        inc batchCount
      of dckRect:
        var run = 1
        while i + run < commands.len and commands[i + run].kind == dckRect:
          inc run
        if run > 1 and drawShaderRectBatch(commandBuffer, device, window,
                                           swapchainTexture, engine, resources,
                                           commands, i, run):
          inc batchCount
          i += run
          continue
        if not drawShaderRect(commandBuffer, device, window, swapchainTexture,
                              engine, resources, command):
          blitRect(commandBuffer, device, swapchainTexture, width, height,
                   engine, resources, command)
        inc batchCount
      of dckLine:
        if not drawShaderPatternedLine(commandBuffer, device, window,
                                       swapchainTexture, engine, resources, command):
          blitPatternedLine(commandBuffer, device, swapchainTexture, width, height,
                            engine, resources, command)
        inc batchCount
      of dckCircle:
        if not drawShaderCircle(commandBuffer, device, window, swapchainTexture,
                                engine, resources, command):
          blitCircle(commandBuffer, device, swapchainTexture, width, height,
                     engine, resources, command)
        inc batchCount
      of dckPoly:
        if not drawShaderPoly(commandBuffer, device, window, swapchainTexture,
                              engine, resources, command):
          blitPoly(commandBuffer, device, swapchainTexture, width, height,
                   engine, resources, command)
        inc batchCount
      of dckPolyLines:
        if not drawShaderPolyLines(commandBuffer, device, window, swapchainTexture,
                                   engine, resources, command):
          blitPolyLines(commandBuffer, device, swapchainTexture, width, height,
                        engine, resources, command)
        inc batchCount
      of dckText:
        blitText(commandBuffer, device, window, swapchainTexture, width, height,
                 engine, resources, ttf, command)
        inc batchCount
      inc i

    when defined(nimaUseNativeImgui):
      nativeimgui.beginNativeImguiSdlGpuFrame(engine.dpiScale)
      nativeimgui.prepareNativeImguiSdlGpuDrawData(commandBuffer)
      var target = FixedGpuColorTargetInfo(
        texture: swapchainTexture,
        clearColor: SDL_FColor(r: 0, g: 0, b: 0, a: 0),
        loadOp: SDL_GPU_LOADOP_LOAD,
        storeOp: SDL_GPU_STOREOP_STORE
      )
      let pass = beginGpuRenderPass(commandBuffer, addr target, 1, nil)
      if not pass.isNil:
        nativeimgui.renderNativeImguiSdlGpuDrawData(commandBuffer, pass)
        SDL_EndGPURenderPass(pass)
      engine.imgui.wantsPointerInput =
        engine.imgui.wantsPointerInput or nativeimgui.nativeImguiWantsPointerInput()
      engine.imgui.wantsKeyboardInput =
        engine.imgui.wantsKeyboardInput or nativeimgui.nativeImguiWantsKeyboardInput()

    engine.perf.batches = batchCount

    checkSdl(SDL_SubmitGPUCommandBuffer(commandBuffer), "SDL_SubmitGPUCommandBuffer failed")

  proc runSdlGpu*(title: string, size: IVec2, viewSize: Vec2,
                  initialScene: Scene, vsync, resizable, fullscreen,
                  cursorVisible: bool) =
    checkSdl(SDL_Init(SDL_INIT_VIDEO or SDL_INIT_EVENTS or SDL_INIT_GAMEPAD),
             "SDL_Init failed")

    var window: SDL_Window = nil
    var device: SDL_GPUDevice = nil
    var claimed = false
    try:
      var flags = SDL_WINDOW_HIGH_PIXEL_DENSITY
      if resizable:
        flags = flags or SDL_WINDOW_RESIZABLE
      if fullscreen:
        flags = flags or SDL_WINDOW_FULLSCREEN

      window = SDL_CreateWindow(title.cstring, size.x.cint, size.y.cint, flags)
      if window.isNil:
        raise sdlGpuError("SDL_CreateWindow failed")

      device = SDL_CreateGPUDevice(shaderFormats(), false, nil)
      if device.isNil:
        raise sdlGpuError("SDL_CreateGPUDevice failed")

      checkSdl(SDL_ClaimWindowForGPUDevice(device, window),
               "SDL_ClaimWindowForGPUDevice failed")
      claimed = true

      let presentMode =
        if vsync: SDL_GPU_PRESENTMODE_VSYNC else: SDL_GPU_PRESENTMODE_IMMEDIATE
      if SDL_WindowSupportsGPUPresentMode(device, window, presentMode):
        discard SDL_SetGPUSwapchainParameters(device, window,
          SDL_GPU_SWAPCHAINCOMPOSITION_SDR, presentMode)
      else:
        discard SDL_SetGPUSwapchainParameters(device, window,
          SDL_GPU_SWAPCHAINCOMPOSITION_SDR, SDL_GPU_PRESENTMODE_VSYNC)
      let activePresentMode =
        if SDL_WindowSupportsGPUPresentMode(device, window, presentMode):
          presentMode
        else:
          SDL_GPU_PRESENTMODE_VSYNC

      if cursorVisible:
        discard SDL_ShowCursor()
      else:
        discard SDL_HideCursor()
      discard SDL_StartTextInput(window)

      echo "[Nima] SDL_GPU ", $SDL_GetVersion(), " video=", $SDL_GetCurrentVideoDriver(),
           " gpu=", $SDL_GetGPUDeviceDriver(device)

      when defined(nimaUseNativeImgui):
        nativeimgui.initNativeImguiForSdlGpu(window, device,
          SDL_GetGPUSwapchainTextureFormat(device, window), activePresentMode, title)

      var engine = initEngine(initialScene, viewSize)
      engine.updateMetrics(window)
      var gamepads = initTable[SDL_JoystickID, SDL_Gamepad]()
      gamepads.openExistingGamepads(engine.input)
      var resources = GpuResources(colors: initTable[uint32, SDL_GPUTexture](),
                                   textures: initTable[uint32, UploadedTexture](),
                                   tintedTextures: initTable[uint64, UploadedTexture](),
                                   texts: initTable[string, UploadedTextTexture](),
                                   glyphAtlases: initTable[string, UploadedGlyphAtlas](),
                                   imageLoader: initSdlImageState())
      var ttf = initSdlTtfState()
      var sdlAudio = initSdlAudioState()

      var lastTicks = SDL_GetTicks()
      try:
        discard withEngineScope(engine, proc(): bool =
          while not engine.exitRequested:
            engine.processEvents(window, gamepads)
            let now = SDL_GetTicks()
            var dt = (now - lastTicks).float32 / 1000'f32
            lastTicks = now
            if dt <= 0'f32:
              dt = 1'f32 / 60'f32
            elif dt > 0.25'f32:
              dt = 0.25'f32

            engine.stepFrame(dt)
            sdlAudio.syncAudio(engine.audio)
            renderFrame(device, window, engine, resources, ttf)

            if not vsync:
              SDL_Delay(1)
          true
        )
      finally:
        discard SDL_WaitForGPUIdle(device)
        when defined(nimaUseNativeImgui):
          nativeimgui.shutdownNativeImgui()
        gamepads.closeGamepads(engine.input)
        sdlAudio.shutdown()
        ttf.shutdown()
        for _, texture in resources.colors.mpairs:
          if not texture.isNil:
            SDL_ReleaseGPUTexture(device, texture)
        for _, uploaded in resources.textures.mpairs:
          if not uploaded.texture.isNil:
            SDL_ReleaseGPUTexture(device, uploaded.texture)
        for _, uploaded in resources.tintedTextures.mpairs:
          if not uploaded.texture.isNil:
            SDL_ReleaseGPUTexture(device, uploaded.texture)
        for _, uploaded in resources.texts.mpairs:
          if not uploaded.texture.isNil:
            SDL_ReleaseGPUTexture(device, uploaded.texture)
        for _, uploaded in resources.glyphAtlases.mpairs:
          if not uploaded.texture.isNil:
            SDL_ReleaseGPUTexture(device, uploaded.texture)
        if not resources.quadPipeline.isNil:
          SDL_ReleaseGPUGraphicsPipeline(device, resources.quadPipeline)
        if not resources.quadVertexShader.isNil:
          SDL_ReleaseGPUShader(device, resources.quadVertexShader)
        if not resources.quadFragmentShader.isNil:
          SDL_ReleaseGPUShader(device, resources.quadFragmentShader)
        if not resources.spritePipeline.isNil:
          SDL_ReleaseGPUGraphicsPipeline(device, resources.spritePipeline)
        if not resources.spriteVertexShader.isNil:
          SDL_ReleaseGPUShader(device, resources.spriteVertexShader)
        if not resources.spriteFragmentShader.isNil:
          SDL_ReleaseGPUShader(device, resources.spriteFragmentShader)
        if not resources.spriteSampler.isNil:
          releaseGpuSampler(device, resources.spriteSampler)
        resources.imageLoader.shutdown()
    finally:
      if not window.isNil:
        discard SDL_StopTextInput(window)
      if claimed and not device.isNil and not window.isNil:
        SDL_ReleaseWindowFromGPUDevice(device, window)
      if not device.isNil:
        SDL_DestroyGPUDevice(device)
      if not window.isNil:
        SDL_DestroyWindow(window)
      SDL_Quit()

  proc sdlGpuLinked*(): bool = true
else:
  proc sdlGpuLinked*(): bool = false
