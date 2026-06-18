import std/algorithm
import ./[ecs, math]

type
  PhysicsBodyKind* = enum
    pbStatic, pbDynamic

  PhysicsShapeKind* = enum
    psCuboid, psBall

  PhysicsShape* = object
    case kind*: PhysicsShapeKind
    of psCuboid:
      halfExtents*: Vec2
    of psBall:
      radius*: float32

  PhysicsLayers* = object
    memberships*: uint32
    filters*: uint32

  PhysicsColliderDesc* = object
    shape*: PhysicsShape
    offset*: Vec2
    rotation*: float32
    layers*: PhysicsLayers
    isSensor*: bool

  PhysicsBodyDesc* = object
    kind*: PhysicsBodyKind
    position*: Vec2
    rotation*: float32
    velocity*: Vec2
    gravityScale*: float32

  PhysicsBodyPose* = object
    position*: Vec2
    rotation*: float32

  PhysicsCollisionEventKind* = enum
    pceStarted

  PhysicsCollisionEvent* = object
    kind*: PhysicsCollisionEventKind
    a*, b*: Ent

  PhysicsRaycastHit* = object
    ent*: Ent
    point*: Vec2
    normal*: Vec2
    distance*: float32
    fraction*: float32

  PhysicsBody = object
    ent: Ent
    kind: PhysicsBodyKind
    pose: PhysicsBodyPose
    velocity: Vec2
    gravityScale: float32
    offset: Vec2
    halfExtents: Vec2
    layers: PhysicsLayers
    isSensor: bool

  PhysicsState* = object
    gravity*: Vec2
    bodies: seq[PhysicsBody]
    events*: seq[PhysicsCollisionEvent]

proc cuboid*(halfExtents: Vec2): PhysicsShape =
  PhysicsShape(kind: psCuboid, halfExtents: halfExtents)

proc ball*(radius: float32): PhysicsShape =
  PhysicsShape(kind: psBall, radius: radius)

proc physicsLayers*(memberships, filters: uint32): PhysicsLayers =
  PhysicsLayers(memberships: memberships, filters: filters)

proc physicsLayersAll*(): PhysicsLayers =
  physicsLayers(uint32.high, uint32.high)

proc physicsLayersNone*(): PhysicsLayers =
  physicsLayers(0'u32, 0'u32)

proc physicsCollider*(shape: PhysicsShape): PhysicsColliderDesc =
  PhysicsColliderDesc(shape: shape, layers: physicsLayersAll())

proc withOffset*(collider: PhysicsColliderDesc, offset: Vec2): PhysicsColliderDesc =
  result = collider
  result.offset = offset

proc withLayers*(collider: PhysicsColliderDesc, layers: PhysicsLayers): PhysicsColliderDesc =
  result = collider
  result.layers = layers

proc asSensor*(collider: PhysicsColliderDesc, isSensor = true): PhysicsColliderDesc =
  result = collider
  result.isSensor = isSensor

proc initPhysicsState*(): PhysicsState =
  PhysicsState(gravity: vec2(0, -520))

proc findBody(state: PhysicsState, ent: Ent): int =
  for i, body in state.bodies:
    if body.ent == ent:
      return i
  -1

proc insertBody*(state: var PhysicsState, ent: Ent, body: PhysicsBodyDesc,
                 collider: PhysicsColliderDesc): bool =
  let half =
    case collider.shape.kind
    of psCuboid: collider.shape.halfExtents
    of psBall: vec2(collider.shape.radius)
  let idx = state.findBody(ent)
  let value = PhysicsBody(ent: ent, kind: body.kind,
    pose: PhysicsBodyPose(position: body.position, rotation: body.rotation),
    velocity: body.velocity, gravityScale: if body.gravityScale == 0: 1 else: body.gravityScale,
    offset: collider.offset, halfExtents: half, layers: collider.layers, isSensor: collider.isSensor)
  if idx >= 0:
    state.bodies[idx] = value
  else:
    state.bodies.add value
  true

proc setBodyPose*(state: var PhysicsState, ent: Ent, pose: PhysicsBodyPose,
                  resetVelocity = false): bool =
  let idx = state.findBody(ent)
  if idx < 0: return false
  state.bodies[idx].pose = pose
  if resetVelocity:
    state.bodies[idx].velocity = Vec2Zero
  true

proc syncedBodyPose*(state: PhysicsState, ent: Ent): PhysicsBodyPose =
  let idx = state.findBody(ent)
  if idx < 0: return PhysicsBodyPose(position: vec2(0, 0))
  state.bodies[idx].pose

proc hasBody*(state: PhysicsState, ent: Ent): bool = state.findBody(ent) >= 0

proc removeBody*(state: var PhysicsState, ent: Ent): bool =
  let idx = state.findBody(ent)
  if idx < 0:
    return false
  state.bodies.delete(idx)
  true

proc aabb(body: PhysicsBody): Rect =
  let center = body.pose.position + body.offset
  rect(center - body.halfExtents, center + body.halfExtents)

proc interacts(a, b: PhysicsLayers): bool =
  (a.memberships and b.filters) != 0'u32 and
    (b.memberships and a.filters) != 0'u32

proc update*(state: var PhysicsState, dt: float32) =
  state.events.setLen 0
  for body in state.bodies.mitems:
    if body.kind == pbDynamic:
      body.velocity = body.velocity + state.gravity * body.gravityScale * dt
      body.pose.position = body.pose.position + body.velocity * dt

  for i in 0..<state.bodies.len:
    if state.bodies[i].kind != pbDynamic:
      continue
    for j in 0..<state.bodies.len:
      if i == j or state.bodies[j].kind != pbStatic:
        continue
      let dynRect = state.bodies[i].aabb()
      let staticRect = state.bodies[j].aabb()
      if dynRect.overlaps(staticRect) and state.bodies[i].layers.interacts(state.bodies[j].layers):
        if not state.bodies[i].isSensor and not state.bodies[j].isSensor:
          state.bodies[i].pose.position.y = staticRect.max.y + state.bodies[i].halfExtents.y
          if state.bodies[i].velocity.y < 0:
            state.bodies[i].velocity.y = 0
        state.events.add PhysicsCollisionEvent(kind: pceStarted,
          a: state.bodies[i].ent, b: state.bodies[j].ent)

proc pointQuery*(state: PhysicsState, point: Vec2,
                 layers = physicsLayersAll()): seq[Ent] =
  for body in state.bodies:
    if body.aabb().contains(point) and body.layers.interacts(layers):
      result.add body.ent

proc overlapAabb*(state: PhysicsState, bounds: Rect,
                  layers = physicsLayersAll()): seq[Ent] =
  for body in state.bodies:
    if body.aabb().overlaps(bounds) and body.layers.interacts(layers):
      result.add body.ent

proc rayAabb(origin, dir: Vec2, bounds: Rect, maxDistance: float32,
             hit: var PhysicsRaycastHit, ent: Ent): bool =
  var tMin = 0'f32
  var tMax = maxDistance
  var normal = Vec2Zero

  template slab(axisOrigin, axisDir, minBound, maxBound: float32,
                negNormal, posNormal: Vec2): bool =
    block:
      if abs(axisDir) < 0.000001'f32:
        axisOrigin >= minBound and axisOrigin <= maxBound
      else:
        let inv = 1'f32 / axisDir
        var t1 = (minBound - axisOrigin) * inv
        var t2 = (maxBound - axisOrigin) * inv
        var n = negNormal
        if t1 > t2:
          swap(t1, t2)
          n = posNormal
        if t1 > tMin:
          tMin = t1
          normal = n
        if t2 < tMax:
          tMax = t2
        tMin <= tMax

  if not slab(origin.x, dir.x, bounds.min.x, bounds.max.x, vec2(-1, 0), vec2(1, 0)):
    return false
  if not slab(origin.y, dir.y, bounds.min.y, bounds.max.y, vec2(0, -1), vec2(0, 1)):
    return false
  if tMin < 0'f32 or tMin > maxDistance:
    return false

  hit = PhysicsRaycastHit(ent: ent, point: origin + dir * tMin,
                          normal: normal, distance: tMin,
                          fraction: if maxDistance <= 0'f32: 0'f32 else: tMin / maxDistance)
  true

proc raycast*(state: PhysicsState, origin, direction: Vec2,
              maxDistance: float32, layers = physicsLayersAll()): seq[PhysicsRaycastHit] =
  if maxDistance <= 0'f32:
    return
  let len = direction.length
  if len <= 0.000001'f32:
    return
  let dir = direction / len
  for body in state.bodies:
    if not body.layers.interacts(layers):
      continue
    var hit: PhysicsRaycastHit
    if rayAabb(origin, dir, body.aabb(), maxDistance, hit, body.ent):
      result.add hit
  result.sort(proc(a, b: PhysicsRaycastHit): int =
    if a.distance < b.distance: -1
    elif a.distance > b.distance: 1
    else: 0)

proc takeCollisionEvents*(state: var PhysicsState): seq[PhysicsCollisionEvent] =
  result = state.events
  state.events.setLen 0

proc clear*(state: var PhysicsState) =
  state.bodies.setLen 0
  state.events.setLen 0
