import nima/prelude

type
  Action = enum
    reset

  PhysicsBasic = ref object of Scene
    floor: Ent
    boxes: seq[Ent]
    hovered: seq[Ent]
    rayHits: seq[PhysicsRaycastHit]
    contacts: int

proc containsEnt(items: seq[Ent], ent: Ent): bool =
  for item in items:
    if item == ent: return true
  false

method init(scene: PhysicsBasic) =
  scene.floor = ent(1)
  bindAction(reset, key(kcR))
  discard physicsInsertBody(scene.floor,
    PhysicsBodyDesc(kind: pbStatic, position: vec2(0, -180), rotation: 0),
    physicsCollider(cuboid(vec2(260, 16))))
  for i in 0..<6:
    let e = ent(uint32(10 + i))
    discard physicsInsertBody(e,
      PhysicsBodyDesc(kind: pbDynamic, position: vec2(-90 + i.float32 * 36, 120 + i.float32 * 30),
                      velocity: vec2(0, 0), gravityScale: 1),
      physicsCollider(cuboid(vec2(12, 12))))
    scene.boxes.add e

method update(scene: PhysicsBasic) =
  if actionJustPressed(reset):
    for i, e in scene.boxes:
      discard physicsSetBodyPose(e, PhysicsBodyPose(position: vec2(-90 + i.float32 * 36, 160 + i.float32 * 20),
                                                    rotation: 0), true)
  scene.hovered = physicsPointQuery(mousePos())
  scene.rayHits = physicsRaycast(vec2(-300, 250), mousePos() - vec2(-300, 250), 900)
  for event in physicsTakeCollisionEvents():
    if event.kind == pceStarted:
      inc scene.contacts

method draw(scene: PhysicsBasic) =
  drawRect(rgb(0.05, 0.06, 0.08), viewSize(), transform(vec3(0, 0, -1)))
  let floorPose = physicsSyncedBodyPose(scene.floor)
  drawRect(rgb(0.55, 0.32, 0.18), vec2(520, 32), transform(floorPose.position.extend(0.1)))
  for e in scene.boxes:
    let pose = physicsSyncedBodyPose(e)
    let color = if scene.hovered.containsEnt(e): Yellow else: rgb(0.2, 0.7, 1)
    drawRect(color, vec2(24, 24), transform(pose.position.extend(0.5)))
  drawLine(vec2(-300, 250), mousePos(), 2, rgba(1, 1, 0, 0.5), 1)
  if scene.rayHits.len > 0:
    drawCircle(scene.rayHits[0].point.extend(1.1), 8, Yellow)
  discard withUi(proc(): bool =
    drawText(text("Physics Basic\nR reset stack\nMouse point query + raycast\nContacts: " &
                  $scene.contacts & " rayHits: " & $scene.rayHits.len, 18, White),
             transform(vec3(-250, 220, 2)), vec2(0, 1))
    true
  )

method cleanup(scene: PhysicsBasic) =
  physicsClear()

when isMainModule:
  run app(title = "Physics Basic", size = ivec2(800, 600), scene = PhysicsBasic())
