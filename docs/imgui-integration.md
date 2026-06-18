# ImGui Integration

Nima should support Dear ImGui as an optional debug/tooling overlay. The public
scene API should stay small:

```nim
method init(scene: ToolsScene) =
  imgui(proc() =
    if imguiBegin("Tools"):
      imguiText("Debug values")
      discard imguiButton("Reload")
      imguiEnd()
  )
```

## Current Implementation

The repository currently provides a pure-Nim immediate debug UI layer. It is
not Dear ImGui yet, but it gives game code the same frame scheduling model and
lets the SDL3 backend render useful tooling without a native cimgui dependency.

Implemented APIs:

```nim
type ImGuiLayer* = proc() {.closure.}

proc imgui*(layer: ImGuiLayer)
proc setImguiFont*(font: Handle[Font])
proc imguiBegin*(title: string, pos = vec2(16, 16), width = 280'f32, height = 220'f32): bool
proc imguiBeginPanel*(pos = vec2(16, 16), width = 280'f32, height = 220'f32,
                      background = rgba(0.08, 0.09, 0.11, 0.94)): bool
proc imguiEnd*()
proc imguiText*(content: string)
proc imguiButton*(label: string, width = 0'f32): bool
proc imguiSameLine*(spacing = 6'f32)
proc imguiSpacing*(height = 6'f32)
proc imguiCheckbox*(label: string, value: var bool): bool
proc imguiRadioButton*(label: string, active: bool): bool
proc imguiRadioValue*(label: string, value: var int, option: int): bool
proc imguiCombo*(label: string, current: var int, items: openArray[string]): bool
proc imguiSliderFloat*(label: string, value: var float32, minValue, maxValue: float32): bool
proc imguiDragInt*(label: string, value: var int, step = 1): bool
proc imguiInputText*(label: string, value: var string, maxLen = 256): bool
proc imguiInputTextMultiline*(label: string, value: var string, rows = 4, maxLen = 1024): bool
proc imguiCollapsingHeader*(label: string, open: var bool): bool
proc imguiIndent*(width = 18'f32)
proc imguiUnindent*(width = 18'f32)
proc imguiColorEdit4*(label: string, value: var Color): bool
proc imguiSeparator*()
proc imguiProgressBar*(fraction: float32, label = "")
proc uiWantsPointerInput*(): bool
proc uiWantsKeyboardInput*(): bool
```

Runtime behavior:

- `imgui(layer)` registers a closure on `Engine.imgui`.
- Layers run after scene draw recording and before diagnostics overlay drawing.
- Widgets write normal Nima draw commands, so they work in headless tests and
  the SDL_Renderer bootstrap backend and SDL_GPU scaffold backend.
- Widget text uses the normal Nima `drawText` path. Use `setImguiFont(...)` to
  route immediate UI labels through a loaded Nima font handle. If SDL3_ttf is
  available at runtime, SDL backends can render real UTF-8/CJK glyphs;
  otherwise they fall back to SDL debug text.
- `imguiBeginPanel`, fixed-width buttons, and `imguiSameLine` cover the
  top-menu/side-panel/central-panel shape used by the Roast2D egui showcase
  without pulling native Dear ImGui into the public prelude yet.
- Mouse hit testing uses Nima world coordinates after SDL coordinate conversion.
- Window and hovered widgets set `uiWantsPointerInput()`.
- Focused text widgets set `uiWantsKeyboardInput()` and support ASCII keyboard
  fallback input plus SDL UTF-8 text-input events.
- Unit tests cover layer execution, button clicks, checkbox toggles, slider
  dragging, radio/combo changes, collapsing headers, text input focus/editing,
  panel layout, same-line fixed-width widgets, pointer capture, keyboard
  capture, and draw command emission.

Current examples:

- `examples/imgui_overlay.nim`
- `examples/imgui_showcase.nim`
- `examples/imgui_cjk.nim`

## Native Dear ImGui Bridge

Nima also ships an opt-in native bridge behind `-d:nimaUseNativeImgui`.

The bridge vendors CImGui/Dear ImGui under
`src/nima/native_imgui/private/cimgui`, compiles the SDL3 platform backend, and
uses the matching renderer backend:

- `-d:nimaUseSdl -d:nimaUseNativeImgui`: SDL3 platform backend plus
  `imgui_impl_sdlrenderer3`.
- `-d:nimaUseSdlGpu -d:nimaUseNativeImgui`: SDL3 platform backend plus
  `imgui_impl_sdlgpu3`.

Application code imports `nima/imgui_native` and registers closures with
`nativeImgui(...)`. The module exports the low-level `ig*` CImGui symbols for
advanced editor code, plus Nim-style convenience helpers for the common editor
widgets.

Example:

```nim
import nima/prelude
import nima/imgui_native

method init(scene: MyScene) =
  nativeImgui(proc() =
    nativeImguiSetNextWindow(imvec2(20, 40), imvec2(320, 240))
    if nativeImguiBegin("Tools"):
      nativeImguiText("Native Dear ImGui")
      discard nativeImguiButton("Run", imvec2(120, 0))
      discard nativeImguiInputText("Name", scene.name)
      discard nativeImguiColorEdit4("Tint", scene.tint)
      nativeImguiEnd()
  )

method cleanup(scene: MyScene) =
  clearNativeImguiLayers()
```

Build:

```sh
nim c -d:nimaUseSdl -d:nimaUseNativeImgui examples/native_imgui_demo.nim
nim c -d:nimaUseSdlGpu -d:nimaUseNativeImgui examples/native_imgui_demo.nim
```

The native bridge is not exported from `nima/prelude`. This keeps the normal
engine API small and keeps C++ compilation out of non-editor builds.

Current helper surface:

```nim
proc nativeImgui*(layer: NativeImGuiLayer)
proc clearNativeImguiLayers*()
proc nativeImguiSetNextWindow*(pos: ImVec2, size = imvec2(), cond = ImGuiCond_FirstUseEver)
proc nativeImguiBegin*(title: string, flags = ImGuiWindowFlags_None): bool
proc nativeImguiBegin*(title: string, open: var bool, flags = ImGuiWindowFlags_None): bool
proc nativeImguiEnd*()
proc nativeImguiText*(content: string)
proc nativeImguiButton*(label: string, size = imvec2()): bool
proc nativeImguiCheckbox*(label: string, value: var bool): bool
proc nativeImguiRadioValue*(label: string, value: var int, option: int): bool
proc nativeImguiCombo*(label: string, current: var int, items: openArray[string]): bool
proc nativeImguiSliderFloat*(label: string, value: var float32, minValue, maxValue: float32): bool
proc nativeImguiSliderInt*(label: string, value: var int, minValue, maxValue: int): bool
proc nativeImguiDragInt*(label: string, value: var int, speed = 1'f32): bool
proc nativeImguiInputText*(label: string, value: var string, maxLen = 256): bool
proc nativeImguiInputTextWithHint*(label, hint: string, value: var string, maxLen = 256): bool
proc nativeImguiInputTextMultiline*(label: string, value: var string, size = imvec2(0, 0), maxLen = 1024): bool
proc nativeImguiColorEdit4*(label: string, value: var Color): bool
proc nativeImguiProgressBar*(fraction: float32, overlay = "", size = imvec2(-1, 0))
proc nativeImguiCollapsingHeader*(label: string, defaultOpen = false): bool
proc nativeImguiTreeNode*(label: string, flags = ImGuiTreeNodeFlags_OpenOnArrow): bool
proc nativeImguiTreePop*()
proc nativeImguiBeginMainMenuBar*(): bool
proc nativeImguiBeginMenu*(label: string, enabled = true): bool
proc nativeImguiMenuItem*(label: string, shortcut = "", selected = false, enabled = true): bool
proc nativeImguiBeginTabBar*(id: string): bool
proc nativeImguiBeginTabItem*(label: string): bool
proc nativeImguiBeginTable*(id: string, columns: int): bool
proc nativeImguiTableSetupColumn*(label: string)
proc nativeImguiTableHeadersRow*()
proc nativeImguiTableNextRow*()
proc nativeImguiTableNextColumn*(): bool
proc nativeImguiOpenPopup*(id: string)
proc nativeImguiBeginPopup*(id: string): bool
proc nativeImguiEndPopup*()
proc nativeImguiBeginTooltip*(): bool
proc nativeImguiEndTooltip*()
proc nativeImguiBeginDisabled*(disabled = true)
proc nativeImguiEndDisabled*()
proc nativeImguiIndent*(width = 0'f32)
proc nativeImguiUnindent*(width = 0'f32)
proc nativeImguiSetNavigation*(keyboard = true, gamepad = false)
proc nativeImguiSetDocking*(enabled: bool)
proc nativeImguiClipboardText*(): string
proc nativeImguiSetClipboardText*(text: string)
```

## Fau Reference

Fau's model is the right reference:

- generated cimgui bindings live under `/Users/jjy/Workspace/fau/src/fau/imgui/wrapper.nim`;
- convenience helpers live in `/Users/jjy/Workspace/fau/src/fau/imgui/impl.nim`;
- `src/fau/g2/imgui.nim` re-exports wrapper, implementation, and styles;
- the runtime bridge maps engine input into ImGui IO;
- font atlas data becomes an engine texture;
- ImGui draw lists become engine mesh batches.

Nima should keep the same boundary but render through SDL_GPU, not Fau's OpenGL
mesh path.

## Native Dear ImGui Follow-Up Work

The first native bridge is in place. Remaining production work:

1. Extend typed Nim convenience wrappers to drag-and-drop and docking when
   editor code needs them.
2. Validate clipboard and keyboard/gamepad navigation behavior on each desktop
   backend.
3. Add runtime validation on Linux/Vulkan and Windows/D3D12.
4. Decide whether CImGui remains vendored source or becomes a managed
   submodule/package.

The pure immediate layer remains useful for small debug overlays and headless
tests. Raw Dear ImGui symbols stay out of `nima/prelude`; native code is
available only from the opt-in tooling module.

## Text And CJK

SDL3_ttf is loaded dynamically, not linked through Nimble. This keeps SDL3_ttf
optional for small games and lets release bundles choose whether to ship
`libSDL3_ttf`/`SDL3_ttf.dll`.

Example:

```nim
let uiFont = loadFont("fonts/NotoSansCJK-Regular.ttc")
drawText(text("你好，世界", 24, White).withFont(uiFont), transform(vec3(0, 0, 0)))
```

`examples/imgui_cjk.nim` probes common macOS, Linux, Windows, and project-local
CJK font paths, then calls `setImguiFont(...)` when a font is found. Real CJK
rendering still requires the optional SDL3_ttf runtime library; on macOS that
usually means installing the Homebrew `sdl3_ttf` formula or bundling
`libSDL3_ttf.0.dylib`. SDL backends call `SDL_StartTextInput` and route
`SDL_EVENT_TEXT_INPUT` into `InputState.textInput`, so focused
`imguiInputText` and `imguiInputTextMultiline` widgets can receive CJK input
from IME/text services.
