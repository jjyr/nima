import std/math as stdmath
import nima/prelude

const
  View = vec2(800, 600)
  PaddleSize = vec2(116, 18)
  BallRadius = 11'f32
  BrickSize = vec2(64, 26)
  PaddleY = -260'f32

type
  Action = enum
    moveLeft, moveRight, quit

  Brick = object
    pos: Vec2
    color: Color
    alive: bool

  Debris = object
    pos: Vec2
    vel: Vec2
    size: Vec2
    angle: float32
    spin: float32
    age: float32
    life: float32
    color: Color

  Breakout = ref object of Scene
    paddleX: float32
    ballPos: Vec2
    ballVel: Vec2
    bricks: seq[Brick]
    debris: seq[Debris]
    failures: int
    score: int
    serveTimer: float32
    cameraShake: Tween

proc clampVec2(value, minValue, maxValue: Vec2): Vec2 =
  vec2(value.x.clamp(minValue.x, maxValue.x),
       value.y.clamp(minValue.y, maxValue.y))

proc circleIntersectsRect(center: Vec2, radius: float32,
                          rectCenter, rectSize: Vec2): bool =
  let bounds = rect(rectCenter - rectSize * 0.5'f32, rectCenter + rectSize * 0.5'f32)
  let closest = center.clampVec2(bounds.min, bounds.max)
  (center - closest).length <= radius

proc resetBall(scene: Breakout) =
  scene.ballPos = vec2(0, -130)
  let x = if scene.failures mod 2 == 0: 135'f32 else: -135'f32
  scene.ballVel = vec2(x, 225)
  scene.serveTimer = 0.45

proc brickColor(row: int): Color =
  case row
  of 0: rgb(0.95, 0.31, 0.24)
  of 1: rgb(0.95, 0.53, 0.22)
  of 2: rgb(0.91, 0.75, 0.25)
  of 3: rgb(0.33, 0.72, 0.46)
  else: rgb(0.28, 0.55, 0.95)

proc spawnBrickDebris(scene: Breakout, brick: Brick) =
  for i in 0..<10:
    let angle = (i.float32 / 10'f32) * stdmath.PI.float32 * 2'f32 +
      (frame() mod 17).float32 * 0.07'f32
    let speed = 95'f32 + (i mod 4).float32 * 32'f32
    scene.debris.add Debris(
      pos: brick.pos + vec2(((i mod 5).float32 - 2'f32) * 7'f32,
                            ((i div 5).float32 - 0.5'f32) * 8'f32),
      vel: vec2(stdmath.cos(angle).float32 * speed,
                stdmath.sin(angle).float32 * speed + 45'f32),
      size: vec2(8 + (i mod 3).float32 * 3, 5 + (i mod 2).float32 * 4),
      angle: angle,
      spin: if i mod 2 == 0: 7'f32 else: -8'f32,
      life: 0.55'f32 + (i mod 4).float32 * 0.08'f32,
      color: brick.color
    )

method init(scene: Breakout) =
  setCameraPos(Vec2Zero)
  bindAction(moveLeft, key(kcLeft))
  bindAction(moveLeft, gamepadButton(gpbDpadLeft))
  bindAction(moveLeft, gamepadAxis(gpaLeftX, gadNegative))
  bindAction(moveRight, key(kcRight))
  bindAction(moveRight, gamepadButton(gpbDpadRight))
  bindAction(moveRight, gamepadAxis(gpaLeftX, gadPositive))
  bindAction(quit, key(kcEscape))
  scene.resetBall()
  for row in 0..<5:
    for col in 0..<10:
      scene.bricks.add Brick(pos: vec2(-315 + col.float32 * 70, 222 - row.float32 * 36),
                             color: brickColor(row), alive: true)

method update(scene: Breakout) =
  let tweened = scene.cameraShake.apply(tick(), transform(cameraPos().extend(0)))
  setCameraPos(tweened.pos.xy)

  if actionDown(moveLeft):
    scene.paddleX -= 360'f32 * tick()
  if actionDown(moveRight):
    scene.paddleX += 360'f32 * tick()
  if actionJustPressed(quit):
    exit()

  scene.paddleX = scene.paddleX.clamp(-View.x * 0.5'f32 + PaddleSize.x * 0.5'f32 + 18,
                                      View.x * 0.5'f32 - PaddleSize.x * 0.5'f32 - 18)

  if scene.serveTimer > 0:
    scene.serveTimer -= tick()

  scene.ballPos = scene.ballPos + scene.ballVel * tick()
  if scene.ballPos.x - BallRadius < -View.x * 0.5'f32:
    scene.ballPos.x = -View.x * 0.5'f32 + BallRadius
    scene.ballVel.x = abs(scene.ballVel.x)
  elif scene.ballPos.x + BallRadius > View.x * 0.5'f32:
    scene.ballPos.x = View.x * 0.5'f32 - BallRadius
    scene.ballVel.x = -scene.ballVel.x
  if scene.ballPos.y + BallRadius > View.y * 0.5'f32:
    scene.ballPos.y = View.y * 0.5'f32 - BallRadius
    scene.ballVel.y = -scene.ballVel.y
  if scene.ballPos.y + BallRadius < -View.y * 0.5'f32:
    inc scene.failures
    let reset = scene.cameraShake.reset(transform(cameraPos().extend(0)))
    setCameraPos(reset.pos.xy)
    scene.resetBall()

  if scene.ballVel.y < 0 and circleIntersectsRect(scene.ballPos, BallRadius,
      vec2(scene.paddleX, PaddleY), PaddleSize):
    let hit = ((scene.ballPos.x - scene.paddleX) / (PaddleSize.x * 0.5'f32)).clamp(-1, 1)
    let speed = max(260'f32, scene.ballVel.length + 8'f32)
    scene.ballVel = vec2(hit * 245'f32, 1'f32).normalized * speed
    scene.ballPos.y = PaddleY + PaddleSize.y * 0.5'f32 + BallRadius + 1
    scene.cameraShake.addShake(3, 0.16, 40, seed = (frame().uint32 + 17'u32))

  for brick in scene.bricks.mitems:
    if brick.alive and circleIntersectsRect(scene.ballPos, BallRadius, brick.pos, BrickSize):
      brick.alive = false
      scene.score += 100
      scene.ballVel.y = -scene.ballVel.y
      scene.spawnBrickDebris(brick)
      scene.cameraShake.addShake(8, 0.22, 42, seed = (frame().uint32 + 101'u32))
      break

  var i = 0
  while i < scene.debris.len:
    scene.debris[i].age += tick()
    if scene.debris[i].age >= scene.debris[i].life:
      scene.debris.delete(i)
      continue
    scene.debris[i].vel = scene.debris[i].vel + vec2(0, -420) * tick()
    scene.debris[i].pos = scene.debris[i].pos + scene.debris[i].vel * tick()
    scene.debris[i].angle += scene.debris[i].spin * tick()
    inc i

method draw(scene: Breakout) =
  drawRect(rgb(0.025, 0.032, 0.05), viewSize(), transform(vec3(0, 0, -1)))
  drawRect(rgba(0.10, 0.14, 0.22, 0.9), vec2(View.x - 36, View.y - 34),
           transform(vec3(0, 4, -0.8)))
  drawLine(vec2(-View.x * 0.5'f32 + 18, -View.y * 0.5'f32 + 18),
           vec2(-View.x * 0.5'f32 + 18, View.y * 0.5'f32 - 18), 3,
           rgba(0.24, 0.36, 0.62, 1), -0.4)
  drawLine(vec2(View.x * 0.5'f32 - 18, -View.y * 0.5'f32 + 18),
           vec2(View.x * 0.5'f32 - 18, View.y * 0.5'f32 - 18), 3,
           rgba(0.24, 0.36, 0.62, 1), -0.4)
  drawLine(vec2(-View.x * 0.5'f32 + 18, View.y * 0.5'f32 - 18),
           vec2(View.x * 0.5'f32 - 18, View.y * 0.5'f32 - 18), 3,
           rgba(0.24, 0.36, 0.62, 1), -0.4)

  drawRect(rgba(0.06, 0.07, 0.09, 0.85), PaddleSize + vec2(10, 8),
           transform(vec3(scene.paddleX, PaddleY - 3, -0.1)))
  drawRect(rgb(0.86, 0.90, 0.96), PaddleSize, transform(vec3(scene.paddleX, PaddleY, 0)))
  drawRect(rgb(0.22, 0.58, 0.95), vec2(PaddleSize.x - 16, 5),
           transform(vec3(scene.paddleX, PaddleY + 4, 0.1)))

  drawCircle(scene.ballPos.extend(0.08), BallRadius + 3, rgba(0, 0, 0, 0.28))
  drawCircle(scene.ballPos.extend(0.12), BallRadius, rgb(1.0, 0.82, 0.28))
  drawCircle((scene.ballPos + vec2(-3, 4)).extend(0.13), BallRadius * 0.35'f32,
             rgba(1, 1, 1, 0.55))
  for brick in scene.bricks:
    if brick.alive:
      drawRect(rgba(0, 0, 0, 0.25), BrickSize + vec2(4, 4),
               transform(vec3(brick.pos.x + 2, brick.pos.y - 2, 0.15)))
      drawRect(brick.color, BrickSize, transform(brick.pos.extend(0.2)))
      drawRect(rgba(1, 1, 1, 0.18), vec2(BrickSize.x - 8, 4),
               transform(vec3(brick.pos.x, brick.pos.y + BrickSize.y * 0.28'f32, 0.21)))
  for shard in scene.debris:
    let t = 1'f32 - (shard.age / shard.life).clamp(0, 1)
    drawRect(shard.color.withAlpha(t), shard.size,
             transform(shard.pos.extend(0.22), angle = shard.angle))

  discard withUi(proc(): bool =
    drawText(text("Score " & $scene.score & "   Failures " & $scene.failures, 18, White),
             transform(vec3(-380, 282, 2)), vec2(0, 1))
    drawText(text("Left/Right or gamepad move. ESC quit. Brick hits create debris.", 15,
                  rgba(0.78, 0.82, 0.88, 1)),
             transform(vec3(-380, 258, 2)), vec2(0, 1))
    true
  )

when isMainModule:
  run app(title = "Breakout", size = ivec2(800, 600), scene = Breakout())
