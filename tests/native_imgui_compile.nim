import nima/imgui_native

doAssert nativeImguiCompiled()
let ctx = igCreateContext(nil)
doAssert not ctx.isNil
nativeImguiSetNavigation(keyboard = true, gamepad = true)
nativeImguiSetDocking(false)
nativeImguiSetClipboardText("nima")
doAssert nativeImguiClipboardText() == "nima"
igDestroyContext(ctx)
