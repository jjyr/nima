# Fau Reference Notes

The reference project is cloned locally at:

```text
/Users/jjy/Workspace/fau
```

Nima should copy the useful packaging/backend patterns, not Fau's full engine
architecture.

## Useful Patterns

- SDL backend imports the Nim package directly:

  ```nim
  import pkg/sdl3
  ```

- Fau selects backend by compile define:

  ```nim
  elif defined(fauUseSdl):
    import fau/backend/sdlcore
    export sdlcore
  ```

  Nima can use a similar internal compile flag later, but v1 should make SDL3
  the only real backend.

- SDL errors are wrapped immediately:

  ```nim
  template checkError(val: bool): untyped =
    if not val:
      raise newException(Exception, "SDL error: " & $getError())
  ```

- Input events are converted from SDL scancodes/buttons into engine key enums.
  Nima should follow this boundary and never expose SDL event structs in scene
  code.

- High-DPI mouse conversion uses both logical window size and pixel framebuffer
  size, then flips Y into engine coordinates. Nima should do the same concept
  but keep the math in backend/platform code.

- Fau logs SDL revision and video driver after init:

  ```nim
  echo "[Fau] Initialized ", getRevision(), " [", getCurrentVideoDriver(), "]"
  ```

  Nima should expose the selected SDL video/GPU driver through diagnostics.

## ImGui Pattern

Fau ships a generated cimgui wrapper under `src/fau/imgui/wrapper.nim` and a
runtime bridge in `src/fau/imgui/impl.nim`. The bridge maps engine key enums to
`ImGuiKey`, uploads the ImGui font atlas as an engine texture, converts
`ImDrawData` into engine mesh vertices, and runs update/render hooks every
frame.

In the local Fau checkout, `src/fau/imgui/cimgui` is empty, so Nima cannot
directly reuse Fau's generated wrapper as a buildable dependency without first
sourcing cimgui/ImGui. Nima currently keeps a pure-Nim immediate debug UI for
bootstrap tooling and also ships an opt-in vendored CImGui/Dear ImGui bridge
behind `-d:nimaUseNativeImgui`.

Nima should copy the boundary, not the exact OpenGL renderer:

- keep cimgui wrapper code isolated from `nima/prelude`;
- map Nima `KeyCode`, mouse, text input, and clipboard into ImGui IO;
- upload the font atlas through the SDL_GPU texture path;
- translate `ImDrawData` into an SDL_GPU UI pass;
- expose game-facing registration through `imgui(proc() = ...)`.

The current Nima native bridge owns context lifecycle, SDL3 event forwarding,
SDL_Renderer/SDL_GPU backend initialization, capture flag forwarding, and a
first batch of Nim-style helper widgets. It uses the official Dear ImGui SDL
renderer backends instead of Fau's OpenGL mesh path.

## Windows Pattern

Fau's project generator uses MinGW for Windows builds:

```nim
(name: "win64", os: "windows", cpu: "amd64",
 args: "--gcc.exe:x86_64-w64-mingw32-gcc --gcc.linkerexe:x86_64-w64-mingw32-g++")
```

Its config also adds:

```nim
when defined(Windows):
  switch("passL", "-static-libstdc++ -static-libgcc")
```

Nima should use this as the first documented Windows path. The release bundle
still needs `SDL3.dll`; the Nim `sdl3` package is only bindings.

## Differences From Nima

- Fau defaults to GLFW on desktop and uses SDL3 mainly for controller support.
  Nima's target backend is SDL3 + SDL_GPU.
- Fau uses OpenGL via SDL. Nima should use SDL_GPU directly.
- Fau's `fau.nimble` currently does not directly declare `requires "sdl3"`.
  Nima should declare `requires "sdl3 >= 1.1.0"` explicitly.
- Fau has web/mobile paths; Nima v1 desktop scope should not copy them.

## References

- `/Users/jjy/Workspace/fau/fau.nimble`
- `/Users/jjy/Workspace/fau/config.nims`
- `/Users/jjy/Workspace/fau/src/core.nim`
- `/Users/jjy/Workspace/fau/src/fau/backend/sdlcore.nim`
- `/Users/jjy/Workspace/fau/src/fau/tools/fauproject.nim`
