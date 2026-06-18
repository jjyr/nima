type
  ScenePayload* = ref object of RootObj
  Scene* = ref object of RootObj

method init*(scene: Scene) {.base.} = discard
method onEnter*(scene: Scene) {.base.} = discard
method onPause*(scene: Scene) {.base.} = discard
method onResume*(scene: Scene) {.base.} = discard
method onExit*(scene: Scene) {.base.} = discard
method update*(scene: Scene) {.base.} = discard
method draw*(scene: Scene) {.base.} = discard
method cleanup*(scene: Scene) {.base.} = discard
