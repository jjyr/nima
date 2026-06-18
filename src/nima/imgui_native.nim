when not defined(nimaUseNativeImgui):
  {.fatal: "nima/imgui_native requires -d:nimaUseNativeImgui".}

import std/os
import pkg/sdl3
import ./color
import ./native_imgui/cimgui

export cimgui

type
  NativeImGuiLayer* = proc() {.closure.}
  NativeImGuiBackend = enum
    nibNone, nibSdlRenderer, nibSdlGpu

var
  context: ImGuiContext
  layers: seq[NativeImGuiLayer]
  backend = nibNone
  iniPath: string

proc nativeImguiCompiled*(): bool = true

proc nativeImgui*(layer: NativeImGuiLayer) =
  layers.add layer

proc clearNativeImguiLayers*() =
  layers.setLen 0

proc nativeImguiSetNavigation*(keyboard = true; gamepad = false) =
  Nima_ImGui_SetNavigation(keyboard, gamepad)

proc nativeImguiSetDocking*(enabled: bool) =
  Nima_ImGui_SetDocking(enabled)

proc nativeImguiClipboardText*(): string =
  let text = igGetClipboardText()
  if text.isNil: "" else: $text

proc nativeImguiSetClipboardText*(text: string) =
  igSetClipboardText(text.cstring)

proc textBuffer(value: string, maxLen: int): string =
  let capacity = max(1, maxLen + 1)
  result = newString(capacity)
  let n = min(value.len, maxLen)
  for i in 0..<n:
    result[i] = value[i]
  result[n] = '\0'

proc bufferCString(buffer: var string): cstring =
  cast[cstring](addr buffer[0])

proc nativeImguiSetNextWindow*(pos: ImVec2; size = imvec2();
                               cond = ImGuiCond_FirstUseEver) =
  igSetNextWindowPos(pos, cond)
  if size.x > 0 or size.y > 0:
    igSetNextWindowSize(size, cond)

proc nativeImguiBegin*(title: string; flags = ImGuiWindowFlags_None): bool =
  igBegin(title.cstring, nil, flags)

proc nativeImguiBegin*(title: string; open: var bool;
                       flags = ImGuiWindowFlags_None): bool =
  igBegin(title.cstring, addr open, flags)

proc nativeImguiEnd*() = igEnd()

proc nativeImguiText*(content: string) =
  igTextUnformatted(content.cstring, nil)

proc nativeImguiSeparator*() = igSeparator()

proc nativeImguiSameLine*(spacing = -1'f32) =
  igSameLine(0, spacing.cfloat)

proc nativeImguiSpacing*() = igSpacing()

proc nativeImguiButton*(label: string; size = imvec2()): bool =
  igButton(label.cstring, size)

proc nativeImguiCheckbox*(label: string; value: var bool): bool =
  igCheckbox(label.cstring, addr value)

proc nativeImguiRadioButton*(label: string; active: bool): bool =
  igRadioButton_Bool(label.cstring, active)

proc nativeImguiRadioValue*(label: string; value: var int; option: int): bool =
  var v = value.cint
  result = igRadioButton_IntPtr(label.cstring, addr v, option.cint)
  if result:
    value = v.int

proc nativeImguiSliderFloat*(label: string; value: var float32;
                             minValue, maxValue: float32;
                             format = "%.3f"): bool =
  var v = value.cfloat
  result = igSliderFloat(label.cstring, addr v, minValue.cfloat, maxValue.cfloat,
                         format.cstring)
  if result:
    value = v.float32

proc nativeImguiSliderInt*(label: string; value: var int;
                           minValue, maxValue: int; format = "%d"): bool =
  var v = value.cint
  result = igSliderInt(label.cstring, addr v, minValue.cint, maxValue.cint,
                       format.cstring)
  if result:
    value = v.int

proc nativeImguiDragInt*(label: string; value: var int; speed = 1'f32;
                         minValue = 0; maxValue = 0; format = "%d"): bool =
  var v = value.cint
  result = igDragInt(label.cstring, addr v, speed.cfloat, minValue.cint,
                     maxValue.cint, format.cstring)
  if result:
    value = v.int

proc nativeImguiInputText*(label: string; value: var string; maxLen = 256;
                           flags = ImGuiInputTextFlags_None): bool =
  var buffer = textBuffer(value, maxLen)
  result = igInputText(label.cstring, buffer.bufferCString, buffer.len.csize_t,
                       flags)
  if result:
    value = $buffer.bufferCString

proc nativeImguiInputTextWithHint*(label, hint: string; value: var string;
                                   maxLen = 256;
                                   flags = ImGuiInputTextFlags_None): bool =
  var buffer = textBuffer(value, maxLen)
  result = igInputTextWithHint(label.cstring, hint.cstring, buffer.bufferCString,
                               buffer.len.csize_t, flags)
  if result:
    value = $buffer.bufferCString

proc nativeImguiInputTextMultiline*(label: string; value: var string;
                                    size = imvec2(0, 0); maxLen = 1024;
                                    flags = ImGuiInputTextFlags_None): bool =
  var buffer = textBuffer(value, maxLen)
  result = igInputTextMultiline(label.cstring, buffer.bufferCString,
                                buffer.len.csize_t, size, flags)
  if result:
    value = $buffer.bufferCString

proc nativeImguiColorEdit4*(label: string; value: var Color;
                            flags = ImGuiColorEditFlags_AlphaBar): bool =
  var col = [value.r.cfloat, value.g.cfloat, value.b.cfloat, value.a.cfloat]
  result = igColorEdit4(label.cstring, addr col[0], flags)
  if result:
    value = rgba(col[0].float32, col[1].float32, col[2].float32, col[3].float32)

proc nativeImguiProgressBar*(fraction: float32; overlay = "";
                             size = imvec2(-1, 0)) =
  let text = if overlay.len == 0: nil else: overlay.cstring
  igProgressBar(fraction.cfloat, size, text)

proc nativeImguiCombo*(label: string; current: var int;
                       items: openArray[string]): bool =
  if items.len == 0:
    return false
  if current < 0 or current >= items.len:
    current = 0
  if igBeginCombo(label.cstring, items[current].cstring):
    for i, item in items:
      let selected = i == current
      if igSelectable_Bool(item.cstring, selected):
        current = i
        result = true
      if selected:
        igSetItemDefaultFocus()
    igEndCombo()

proc nativeImguiCollapsingHeader*(label: string;
                                  defaultOpen = false): bool =
  let flags =
    if defaultOpen: ImGuiTreeNodeFlags_DefaultOpen else: ImGuiTreeNodeFlags_None
  igCollapsingHeader_TreeNodeFlags(label.cstring, flags)

proc nativeImguiTreeNode*(label: string;
                          flags = ImGuiTreeNodeFlags_OpenOnArrow): bool =
  igTreeNodeEx_Str(label.cstring, flags)

proc nativeImguiTreePop*() = igTreePop()

proc nativeImguiBeginMainMenuBar*(): bool = igBeginMainMenuBar()
proc nativeImguiEndMainMenuBar*() = igEndMainMenuBar()
proc nativeImguiBeginMenu*(label: string; enabled = true): bool =
  igBeginMenu(label.cstring, enabled)
proc nativeImguiEndMenu*() = igEndMenu()
proc nativeImguiMenuItem*(label: string; shortcut = "";
                          selected = false; enabled = true): bool =
  let sc = if shortcut.len == 0: nil else: shortcut.cstring
  igMenuItem_Bool(label.cstring, sc, selected, enabled)

proc nativeImguiBeginTabBar*(id: string;
                             flags = ImGuiTabBarFlags_None): bool =
  igBeginTabBar(id.cstring, flags)
proc nativeImguiEndTabBar*() = igEndTabBar()
proc nativeImguiBeginTabItem*(label: string;
                              flags = ImGuiTabItemFlags_None): bool =
  igBeginTabItem(label.cstring, nil, flags)
proc nativeImguiEndTabItem*() = igEndTabItem()

proc nativeImguiBeginTable*(id: string; columns: int;
                            flags = ImGuiTableFlags_Borders or ImGuiTableFlags_RowBg;
                            outerSize = imvec2(); innerWidth = 0'f32): bool =
  igBeginTable(id.cstring, columns.cint, flags, outerSize, innerWidth.cfloat)

proc nativeImguiEndTable*() = igEndTable()

proc nativeImguiTableSetupColumn*(label: string;
                                  flags = ImGuiTableColumnFlags_None;
                                  widthOrWeight = 0'f32; userId = 0'u32) =
  igTableSetupColumn(label.cstring, flags, widthOrWeight.cfloat, ImGuiID(userId))

proc nativeImguiTableHeadersRow*() = igTableHeadersRow()

proc nativeImguiTableNextRow*(flags = ImGuiTableRowFlags_None;
                              minHeight = 0'f32) =
  igTableNextRow(flags, minHeight.cfloat)

proc nativeImguiTableNextColumn*(): bool = igTableNextColumn()

proc nativeImguiTableSetColumn*(column: int): bool =
  igTableSetColumnIndex(column.cint)

proc nativeImguiOpenPopup*(id: string; flags = ImGuiPopupFlags_None) =
  igOpenPopup_Str(id.cstring, flags)

proc nativeImguiBeginPopup*(id: string;
                            flags = ImGuiWindowFlags_None): bool =
  igBeginPopup(id.cstring, flags)

proc nativeImguiBeginPopupContextItem*(id = "";
                                       flags = ImGuiPopupFlags_MouseButtonRight): bool =
  let cid = if id.len == 0: nil else: id.cstring
  igBeginPopupContextItem(cid, flags)

proc nativeImguiEndPopup*() = igEndPopup()

proc nativeImguiBeginTooltip*(): bool = igBeginTooltip()
proc nativeImguiEndTooltip*() = igEndTooltip()

proc nativeImguiBeginDisabled*(disabled = true) = igBeginDisabled(disabled)
proc nativeImguiEndDisabled*() = igEndDisabled()

proc nativeImguiIndent*(width = 0'f32) = igIndent(width.cfloat)
proc nativeImguiUnindent*(width = 0'f32) = igUnindent(width.cfloat)

proc runLayers() =
  for layer in layers:
    if layer != nil:
      layer()

proc ensureContext(appName: string) =
  if not context.isNil:
    return
  context = igCreateContext(nil)
  if context.isNil:
    raise newException(CatchableError, "igCreateContext failed")
  if appName.len == 0:
    Nima_ImGui_SetIniFilename(nil)
  else:
    let base = getConfigDir() / "nima" / appName
    createDir(base)
    iniPath = base / "imgui.ini"
    Nima_ImGui_SetIniFilename(iniPath.cstring)

proc initNativeImguiForSdlRenderer*(window: SDL_Window; renderer: SDL_Renderer;
                                    appName = "nima") =
  ensureContext(appName)
  if backend != nibNone:
    return
  if not ImGui_ImplSDL3_InitForSDLRenderer(window, renderer):
    raise newException(CatchableError, "ImGui_ImplSDL3_InitForSDLRenderer failed")
  if not ImGui_ImplSDLRenderer3_Init(renderer):
    ImGui_ImplSDL3_Shutdown()
    raise newException(CatchableError, "ImGui_ImplSDLRenderer3_Init failed")
  backend = nibSdlRenderer

proc initNativeImguiForSdlGpu*(window: SDL_Window; device: SDL_GPUDevice;
                               format: SDL_GPUTextureFormat;
                               presentMode: SDL_GPUPresentMode;
                               appName = "nima") =
  ensureContext(appName)
  if backend != nibNone:
    return
  if not ImGui_ImplSDL3_InitForSDLGPU(window):
    raise newException(CatchableError, "ImGui_ImplSDL3_InitForSDLGPU failed")
  var info = ImGui_ImplSDLGPU3_InitInfo(
    Device: device,
    ColorTargetFormat: format,
    MSAASamples: SDL_GPU_SAMPLECOUNT_1,
    SwapchainComposition: SDL_GPU_SWAPCHAINCOMPOSITION_SDR,
    PresentMode: presentMode
  )
  if not ImGui_ImplSDLGPU3_Init(addr info):
    ImGui_ImplSDL3_Shutdown()
    raise newException(CatchableError, "ImGui_ImplSDLGPU3_Init failed")
  backend = nibSdlGpu

proc nativeImguiProcessEvent*(event: var SDL_Event) =
  if backend != nibNone:
    discard ImGui_ImplSDL3_ProcessEvent(addr event)

proc nativeImguiWantsPointerInput*(): bool =
  backend != nibNone and Nima_ImGui_WantCaptureMouse()

proc nativeImguiWantsKeyboardInput*(): bool =
  backend != nibNone and Nima_ImGui_WantCaptureKeyboard()

proc renderNativeImguiSdlRenderer*(renderer: SDL_Renderer; dpiScale = 1'f32) =
  if backend != nibSdlRenderer:
    return
  Nima_ImGui_SetDisplayScale(dpiScale.cfloat, dpiScale.cfloat)
  ImGui_ImplSDLRenderer3_NewFrame()
  ImGui_ImplSDL3_NewFrame()
  igNewFrame()
  runLayers()
  igRender()
  ImGui_ImplSDLRenderer3_RenderDrawData(igGetDrawData(), renderer)

proc beginNativeImguiSdlGpuFrame*(dpiScale = 1'f32) =
  if backend != nibSdlGpu:
    return
  Nima_ImGui_SetDisplayScale(dpiScale.cfloat, dpiScale.cfloat)
  ImGui_ImplSDLGPU3_NewFrame()
  ImGui_ImplSDL3_NewFrame()
  igNewFrame()
  runLayers()
  igRender()

proc prepareNativeImguiSdlGpuDrawData*(commandBuffer: SDL_GPUCommandBuffer) =
  if backend == nibSdlGpu:
    ImGui_ImplSDLGPU3_PrepareDrawData(igGetDrawData(), commandBuffer)

proc renderNativeImguiSdlGpuDrawData*(commandBuffer: SDL_GPUCommandBuffer;
                                      renderPass: SDL_GPURenderPass) =
  if backend == nibSdlGpu:
    ImGui_ImplSDLGPU3_RenderDrawData(igGetDrawData(), commandBuffer, renderPass, nil)

proc shutdownNativeImgui*() =
  case backend
  of nibSdlRenderer:
    ImGui_ImplSDLRenderer3_Shutdown()
    ImGui_ImplSDL3_Shutdown()
  of nibSdlGpu:
    ImGui_ImplSDLGPU3_Shutdown()
    ImGui_ImplSDL3_Shutdown()
  of nibNone:
    discard
  backend = nibNone
  layers.setLen 0
  if not context.isNil:
    igDestroyContext(context)
    context = nil
