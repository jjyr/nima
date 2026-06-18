# Dynamic Hot Reload

Nima includes a desktop dynamic-library hot reload path inspired by Roast2D's
hotreload example.

The current design avoids importing the engine facade from the reloadable
library. A Nim dynamic library gets a small C ABI `HotReloadApi` from the host
and draws through host callbacks. This prevents the dylib/dll/so from owning a
separate copy of the engine-global facade state.

## Files

```text
src/nima/hotreload.nim        # host scene and C ABI callback surface
examples/hotreload.nim        # host app
examples/hotreload_game.nim   # reloadable dynamic library
tests/hotreload_smoke.nim     # headless verification
```

## Workflow

Build the reloadable library:

```sh
nimble hotreloadLib
```

Run the host:

```sh
nim c -d:nimaUseSdl -r examples/hotreload.nim
```

Edit `examples/hotreload_game.nim`, rerun `nimble hotreloadLib`, and the host
reloads when the output library modification time changes.

## Verification

```sh
nimble hotreloadSmoke
```

The smoke task builds the dynamic library, loads it through `HotReloadScene`,
runs a few headless frames, and verifies the exported load/update/draw path
does not crash.

## Current Limits

- State is owned by the reloadable library and resets on reload.
- The callback API currently covers rect/text drawing plus time/tick/frame/log.
- Full facade access from the dynamic library is intentionally avoided until
  there is a stable host ABI for engine services.
