import std/[os, strutils]
import pkg/sdl3

proc currentSourceDir(): string {.compileTime.} =
  result = currentSourcePath().replace("\\", "/")
  result = result[0 ..< result.rfind("/")]

const
  cimguiRoot = currentSourceDir() / "private" / "cimgui"
  imguiRoot = cimguiRoot / "imgui"
  sdlCFlags = staticExec("pkg-config --cflags sdl3").strip()
  sdlLibs = staticExec("pkg-config --libs sdl3").strip()

{.passC: sdlCFlags.}
{.passC: "-I" & cimguiRoot.}
{.passC: "-I" & imguiRoot.}
{.passC: "-I" & imguiRoot / "backends".}
{.passC: """-DIMGUI_IMPL_API="extern \"C\""""".}
{.passL: sdlLibs.}

when defined(macosx):
  {.passL: "-lc++".}
elif defined(windows):
  {.passL: "-lstdc++".}
else:
  {.passL: "-lstdc++".}

{.compile: cimguiRoot / "cimgui.cpp".}
{.compile: imguiRoot / "imgui.cpp".}
{.compile: imguiRoot / "imgui_draw.cpp".}
{.compile: imguiRoot / "imgui_tables.cpp".}
{.compile: imguiRoot / "imgui_widgets.cpp".}
{.compile: imguiRoot / "imgui_demo.cpp".}
{.compile: imguiRoot / "backends" / "imgui_impl_sdl3.cpp".}
{.compile: imguiRoot / "backends" / "imgui_impl_sdlrenderer3.cpp".}
{.compile: imguiRoot / "backends" / "imgui_impl_sdlgpu3.cpp".}
{.compile: currentSourceDir() / "private" / "nima_imgui_bridge.cpp".}

type
  ImGuiContext* = pointer
  ImFontAtlas* = pointer
  ImDrawData* = pointer
  ImTextureData* = pointer
  ImGuiWindowFlags* = cuint
  ImGuiCond* = cuint
  ImGuiSliderFlags* = cuint
  ImGuiInputTextFlags* = cuint
  ImGuiColorEditFlags* = cuint
  ImGuiComboFlags* = cuint
  ImGuiSelectableFlags* = cuint
  ImGuiTreeNodeFlags* = cuint
  ImGuiTabBarFlags* = cuint
  ImGuiTabItemFlags* = cuint
  ImGuiTableFlags* = cuint
  ImGuiTableColumnFlags* = cuint
  ImGuiTableRowFlags* = cuint
  ImGuiPopupFlags* = cuint
  ImGuiID* = cuint

  ImVec2* {.bycopy.} = object
    x*, y*: cfloat

  ImVec4* {.bycopy.} = object
    x*, y*, z*, w*: cfloat

  ImGui_ImplSDLGPU3_InitInfo* {.bycopy.} = object
    Device*: SDL_GPUDevice
    ColorTargetFormat*: SDL_GPUTextureFormat
    MSAASamples*: SDL_GPUSampleCount
    SwapchainComposition*: SDL_GPUSwapchainComposition
    PresentMode*: SDL_GPUPresentMode

const
  ImGuiWindowFlags_None* = ImGuiWindowFlags(0)
  ImGuiWindowFlags_NoTitleBar* = ImGuiWindowFlags(1 shl 0)
  ImGuiWindowFlags_NoResize* = ImGuiWindowFlags(1 shl 1)
  ImGuiWindowFlags_NoMove* = ImGuiWindowFlags(1 shl 2)
  ImGuiWindowFlags_NoScrollbar* = ImGuiWindowFlags(1 shl 3)
  ImGuiWindowFlags_NoCollapse* = ImGuiWindowFlags(1 shl 5)
  ImGuiWindowFlags_AlwaysAutoResize* = ImGuiWindowFlags(1 shl 6)
  ImGuiWindowFlags_MenuBar* = ImGuiWindowFlags(1 shl 10)
  ImGuiCond_None* = ImGuiCond(0)
  ImGuiCond_Always* = ImGuiCond(1)
  ImGuiCond_Once* = ImGuiCond(2)
  ImGuiCond_FirstUseEver* = ImGuiCond(4)
  ImGuiCond_Appearing* = ImGuiCond(8)
  ImGuiSliderFlags_None* = ImGuiSliderFlags(0)
  ImGuiInputTextFlags_None* = ImGuiInputTextFlags(0)
  ImGuiInputTextFlags_EnterReturnsTrue* = ImGuiInputTextFlags(1 shl 6)
  ImGuiInputTextFlags_AllowTabInput* = ImGuiInputTextFlags(1 shl 5)
  ImGuiColorEditFlags_None* = ImGuiColorEditFlags(0)
  ImGuiColorEditFlags_NoAlpha* = ImGuiColorEditFlags(1 shl 1)
  ImGuiColorEditFlags_AlphaBar* = ImGuiColorEditFlags(1 shl 16)
  ImGuiComboFlags_None* = ImGuiComboFlags(0)
  ImGuiSelectableFlags_None* = ImGuiSelectableFlags(0)
  ImGuiTreeNodeFlags_None* = ImGuiTreeNodeFlags(0)
  ImGuiTreeNodeFlags_Selected* = ImGuiTreeNodeFlags(1 shl 0)
  ImGuiTreeNodeFlags_DefaultOpen* = ImGuiTreeNodeFlags(1 shl 5)
  ImGuiTreeNodeFlags_OpenOnArrow* = ImGuiTreeNodeFlags(1 shl 7)
  ImGuiTreeNodeFlags_Leaf* = ImGuiTreeNodeFlags(1 shl 8)
  ImGuiTreeNodeFlags_SpanAvailWidth* = ImGuiTreeNodeFlags(1 shl 11)
  ImGuiTabBarFlags_None* = ImGuiTabBarFlags(0)
  ImGuiTabItemFlags_None* = ImGuiTabItemFlags(0)
  ImGuiTableFlags_None* = ImGuiTableFlags(0)
  ImGuiTableFlags_Resizable* = ImGuiTableFlags(1 shl 0)
  ImGuiTableFlags_Reorderable* = ImGuiTableFlags(1 shl 1)
  ImGuiTableFlags_Hideable* = ImGuiTableFlags(1 shl 2)
  ImGuiTableFlags_Sortable* = ImGuiTableFlags(1 shl 3)
  ImGuiTableFlags_RowBg* = ImGuiTableFlags(1 shl 6)
  ImGuiTableFlags_BordersInnerH* = ImGuiTableFlags(1 shl 7)
  ImGuiTableFlags_BordersOuterH* = ImGuiTableFlags(1 shl 8)
  ImGuiTableFlags_BordersInnerV* = ImGuiTableFlags(1 shl 9)
  ImGuiTableFlags_BordersOuterV* = ImGuiTableFlags(1 shl 10)
  ImGuiTableFlags_BordersH* = ImGuiTableFlags_BordersInnerH or ImGuiTableFlags_BordersOuterH
  ImGuiTableFlags_BordersV* = ImGuiTableFlags_BordersInnerV or ImGuiTableFlags_BordersOuterV
  ImGuiTableFlags_Borders* = ImGuiTableFlags_BordersH or ImGuiTableFlags_BordersV
  ImGuiTableFlags_ScrollX* = ImGuiTableFlags(1 shl 24)
  ImGuiTableFlags_ScrollY* = ImGuiTableFlags(1 shl 25)
  ImGuiTableColumnFlags_None* = ImGuiTableColumnFlags(0)
  ImGuiTableColumnFlags_WidthStretch* = ImGuiTableColumnFlags(1 shl 3)
  ImGuiTableColumnFlags_WidthFixed* = ImGuiTableColumnFlags(1 shl 4)
  ImGuiTableColumnFlags_NoResize* = ImGuiTableColumnFlags(1 shl 5)
  ImGuiTableColumnFlags_NoReorder* = ImGuiTableColumnFlags(1 shl 6)
  ImGuiTableColumnFlags_NoHide* = ImGuiTableColumnFlags(1 shl 7)
  ImGuiTableRowFlags_None* = ImGuiTableRowFlags(0)
  ImGuiTableRowFlags_Headers* = ImGuiTableRowFlags(1 shl 0)
  ImGuiPopupFlags_None* = ImGuiPopupFlags(0)
  ImGuiPopupFlags_MouseButtonLeft* = ImGuiPopupFlags(1 shl 2)
  ImGuiPopupFlags_MouseButtonRight* = ImGuiPopupFlags(2 shl 2)
  ImGuiPopupFlags_MouseButtonMiddle* = ImGuiPopupFlags(3 shl 2)

proc imvec2*(x = 0'f32, y = 0'f32): ImVec2 =
  ImVec2(x: x.cfloat, y: y.cfloat)

proc imvec4*(x = 0'f32, y = 0'f32, z = 0'f32, w = 0'f32): ImVec4 =
  ImVec4(x: x.cfloat, y: y.cfloat, z: z.cfloat, w: w.cfloat)

{.push cdecl.}
proc igCreateContext*(shared_font_atlas: ImFontAtlas = nil): ImGuiContext {.importc.}
proc igDestroyContext*(ctx: ImGuiContext = nil) {.importc.}
proc igNewFrame*() {.importc.}
proc igRender*() {.importc.}
proc igGetDrawData*(): ImDrawData {.importc.}
proc igShowDemoWindow*(p_open: ptr bool = nil) {.importc.}
proc igBegin*(name: cstring; p_open: ptr bool = nil;
              flags: ImGuiWindowFlags = ImGuiWindowFlags_None): bool {.importc.}
proc igEnd*() {.importc.}
proc igTextUnformatted*(text: cstring; text_end: cstring = nil) {.importc.}
proc igText*(fmt: cstring) {.varargs, importc.}
proc igSeparator*() {.importc.}
proc igSameLine*(offset_from_start_x: cfloat = 0;
                 spacing: cfloat = -1) {.importc.}
proc igSpacing*() {.importc.}
proc igButton*(label: cstring; size: ImVec2 = imvec2()): bool {.importc.}
proc igCheckbox*(label: cstring; v: ptr bool): bool {.importc.}
proc igRadioButton_Bool*(label: cstring; active: bool): bool {.importc.}
proc igRadioButton_IntPtr*(label: cstring; v: ptr cint; v_button: cint): bool {.importc.}
proc igProgressBar*(fraction: cfloat; size_arg: ImVec2 = imvec2(-1, 0);
                    overlay: cstring = nil) {.importc.}
proc igBeginCombo*(label: cstring; preview_value: cstring;
                   flags: ImGuiComboFlags = ImGuiComboFlags_None): bool {.importc.}
proc igEndCombo*() {.importc.}
proc igSelectable_Bool*(label: cstring; selected: bool;
                        flags: ImGuiSelectableFlags = ImGuiSelectableFlags_None;
                        size: ImVec2 = imvec2()): bool {.importc.}
proc igSliderFloat*(label: cstring; v: ptr cfloat; v_min, v_max: cfloat;
                    format: cstring = "%.3f";
                    flags: ImGuiSliderFlags = ImGuiSliderFlags_None): bool {.importc.}
proc igSliderInt*(label: cstring; v: ptr cint; v_min, v_max: cint;
                  format: cstring = "%d";
                  flags: ImGuiSliderFlags = ImGuiSliderFlags_None): bool {.importc.}
proc igDragInt*(label: cstring; v: ptr cint; v_speed: cfloat = 1;
                v_min: cint = 0; v_max: cint = 0; format: cstring = "%d";
                flags: ImGuiSliderFlags = ImGuiSliderFlags_None): bool {.importc.}
proc igInputText*(label: cstring; buf: cstring; buf_size: csize_t;
                  flags: ImGuiInputTextFlags = ImGuiInputTextFlags_None;
                  callback: pointer = nil; user_data: pointer = nil): bool {.importc.}
proc igInputTextMultiline*(label: cstring; buf: cstring; buf_size: csize_t;
                           size: ImVec2 = imvec2();
                           flags: ImGuiInputTextFlags = ImGuiInputTextFlags_None;
                           callback: pointer = nil; user_data: pointer = nil): bool {.importc.}
proc igInputTextWithHint*(label: cstring; hint: cstring; buf: cstring;
                          buf_size: csize_t;
                          flags: ImGuiInputTextFlags = ImGuiInputTextFlags_None;
                          callback: pointer = nil; user_data: pointer = nil): bool {.importc.}
proc igColorEdit4*(label: cstring; col: ptr cfloat;
                   flags: ImGuiColorEditFlags = ImGuiColorEditFlags_None): bool {.importc.}
proc igCollapsingHeader_TreeNodeFlags*(label: cstring;
                                       flags: ImGuiTreeNodeFlags = ImGuiTreeNodeFlags_None): bool {.importc.}
proc igTreeNodeEx_Str*(label: cstring;
                       flags: ImGuiTreeNodeFlags = ImGuiTreeNodeFlags_None): bool {.importc.}
proc igTreePop*() {.importc.}
proc igBeginMainMenuBar*(): bool {.importc.}
proc igEndMainMenuBar*() {.importc.}
proc igBeginMenu*(label: cstring; enabled: bool = true): bool {.importc.}
proc igEndMenu*() {.importc.}
proc igMenuItem_Bool*(label: cstring; shortcut: cstring = nil;
                      selected: bool = false; enabled: bool = true): bool {.importc.}
proc igMenuItem_BoolPtr*(label: cstring; shortcut: cstring = nil;
                         selected: ptr bool = nil; enabled: bool = true): bool {.importc.}
proc igBeginTabBar*(str_id: cstring;
                    flags: ImGuiTabBarFlags = ImGuiTabBarFlags_None): bool {.importc.}
proc igEndTabBar*() {.importc.}
proc igBeginTabItem*(label: cstring; p_open: ptr bool = nil;
                     flags: ImGuiTabItemFlags = ImGuiTabItemFlags_None): bool {.importc.}
proc igEndTabItem*() {.importc.}
proc igBeginTable*(str_id: cstring; columns: cint;
                   flags: ImGuiTableFlags = ImGuiTableFlags_None;
                   outer_size: ImVec2 = imvec2();
                   inner_width: cfloat = 0): bool {.importc.}
proc igEndTable*() {.importc.}
proc igTableSetupColumn*(label: cstring;
                         flags: ImGuiTableColumnFlags = ImGuiTableColumnFlags_None;
                         init_width_or_weight: cfloat = 0;
                         user_id: ImGuiID = 0) {.importc.}
proc igTableHeadersRow*() {.importc.}
proc igTableNextRow*(row_flags: ImGuiTableRowFlags = ImGuiTableRowFlags_None;
                     min_row_height: cfloat = 0) {.importc.}
proc igTableNextColumn*(): bool {.importc.}
proc igTableSetColumnIndex*(column_n: cint): bool {.importc.}
proc igOpenPopup_Str*(str_id: cstring;
                      popup_flags: ImGuiPopupFlags = ImGuiPopupFlags_None) {.importc.}
proc igBeginPopup*(str_id: cstring;
                   flags: ImGuiWindowFlags = ImGuiWindowFlags_None): bool {.importc.}
proc igBeginPopupContextItem*(str_id: cstring = nil;
                              popup_flags: ImGuiPopupFlags = ImGuiPopupFlags_MouseButtonRight): bool {.importc.}
proc igEndPopup*() {.importc.}
proc igBeginTooltip*(): bool {.importc.}
proc igEndTooltip*() {.importc.}
proc igBeginDisabled*(disabled: bool = true) {.importc.}
proc igEndDisabled*() {.importc.}
proc igIndent*(indent_w: cfloat = 0) {.importc.}
proc igUnindent*(indent_w: cfloat = 0) {.importc.}
proc igGetClipboardText*(): cstring {.importc.}
proc igSetClipboardText*(text: cstring) {.importc.}
proc igSetItemDefaultFocus*() {.importc.}
proc igSetNextWindowPos*(pos: ImVec2; cond: ImGuiCond = ImGuiCond_None;
                         pivot: ImVec2 = imvec2()) {.importc.}
proc igSetNextWindowSize*(size: ImVec2;
                          cond: ImGuiCond = ImGuiCond_None) {.importc.}

proc ImGui_ImplSDL3_InitForSDLRenderer*(window: SDL_Window;
                                        renderer: SDL_Renderer): bool {.importc.}
proc ImGui_ImplSDL3_InitForSDLGPU*(window: SDL_Window): bool {.importc.}
proc ImGui_ImplSDL3_ProcessEvent*(event: ptr SDL_Event): bool {.importc.}
proc ImGui_ImplSDL3_NewFrame*() {.importc.}
proc ImGui_ImplSDL3_Shutdown*() {.importc.}

proc ImGui_ImplSDLRenderer3_Init*(renderer: SDL_Renderer): bool {.importc.}
proc ImGui_ImplSDLRenderer3_Shutdown*() {.importc.}
proc ImGui_ImplSDLRenderer3_NewFrame*() {.importc.}
proc ImGui_ImplSDLRenderer3_RenderDrawData*(draw_data: ImDrawData;
                                            renderer: SDL_Renderer) {.importc.}

proc ImGui_ImplSDLGPU3_Init*(info: ptr ImGui_ImplSDLGPU3_InitInfo): bool {.importc.}
proc ImGui_ImplSDLGPU3_Shutdown*() {.importc.}
proc ImGui_ImplSDLGPU3_NewFrame*() {.importc.}
proc ImGui_ImplSDLGPU3_PrepareDrawData*(draw_data: ImDrawData;
                                        command_buffer: SDL_GPUCommandBuffer) {.importc.}
proc ImGui_ImplSDLGPU3_RenderDrawData*(draw_data: ImDrawData;
                                       command_buffer: SDL_GPUCommandBuffer;
                                       render_pass: SDL_GPURenderPass;
                                       pipeline: SDL_GPUGraphicsPipeline = nil) {.importc.}

proc Nima_ImGui_WantCaptureMouse*(): bool {.importc.}
proc Nima_ImGui_WantCaptureKeyboard*(): bool {.importc.}
proc Nima_ImGui_SetIniFilename*(path: cstring) {.importc.}
proc Nima_ImGui_SetDisplayScale*(x, y: cfloat) {.importc.}
proc Nima_ImGui_SetNavigation*(keyboard, gamepad: bool) {.importc.}
proc Nima_ImGui_SetDocking*(enabled: bool) {.importc.}
{.pop.}
