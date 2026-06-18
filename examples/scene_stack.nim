import nima/prelude

type
  Action = enum
    pause

  PausePayload = ref object of ScenePayload
    coins: int

  PauseResult = ref object of ScenePayload
    bonus: int

  Gameplay = ref object of Scene
    coins: int
    waitingPayload: bool

  PauseMenu = ref object of Scene
    sourceCoins: int

method init(scene: Gameplay) =
  scene.coins = 10
  bindAction(pause, key(kcEscape))

method onResume(scene: Gameplay) =
  scene.waitingPayload = true

method update(scene: Gameplay) =
  if scene.waitingPayload:
    let payload = takeScenePayload[PauseResult]()
    if payload != nil:
      scene.coins += payload.bonus
    scene.waitingPayload = false
  if actionJustPressed(pause):
    pushScene(PauseMenu(), PausePayload(coins: scene.coins))

method draw(scene: Gameplay) =
  drawRect(rgb(0.05, 0.06, 0.08), viewSize(), transform(vec3(0, 0, -1)))
  drawText(text("Scene Stack", 32, White), transform(vec3(0, 100, 0)))
  drawText(text("Coins: " & $scene.coins, 24, Yellow), transform(vec3(0, 40, 0)))

method onEnter(scene: PauseMenu) =
  let payload = takeScenePayload[PausePayload]()
  if payload != nil:
    scene.sourceCoins = payload.coins

method update(scene: PauseMenu) =
  popScene(PauseResult(bonus: 5))

method draw(scene: PauseMenu) =
  drawRect(rgba(0, 0, 0, 0.75), viewSize(), transform(vec3(0, 0, 5)))
  drawText(text("Pause", 32, White), transform(vec3(0, 80, 6)))

when isMainModule:
  run app(title = "Scene Stack", size = ivec2(800, 600), scene = Gameplay())
