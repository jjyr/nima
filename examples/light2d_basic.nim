import nima/prelude

type
  Action = enum
    toggleLights, raiseAmbient, lowerAmbient

  LightDemo = ref object of Scene
    keyLight: Light2DId
    hasLight: bool
    occluders: seq[LightOccluder2DRect]

method init(scene: LightDemo) =
  bindAction(toggleLights, key(kcL))
  bindAction(raiseAmbient, key(kcUp))
  bindAction(lowerAmbient, key(kcDown))
  light2dSetSettings(Light2DSettings(
    enabled: true,
    overlayZ: 760,
    ambient: rgba(0.02, 0.02, 0.03, 0.55),
    shadowColor: rgba(0, 0, 0, 0.92),
    shadowLength: 1600
  ))
  scene.occluders = @[
    LightOccluder2DRect(center: vec2(-220, -60), size: vec2(130, 80), rotation: 0.15),
    LightOccluder2DRect(center: vec2(-20, -20), size: vec2(70, 180), rotation: -0.22),
    LightOccluder2DRect(center: vec2(210, -90), size: vec2(160, 60), rotation: 0.08)
  ]
  for occ in scene.occluders:
    discard light2dAddOccluderRect(occ)
  scene.keyLight = light2dAddLight(Light2D(position: vec2(0, 120), radius: 320,
                                           color: rgba(1, 0.96, 0.85, 1),
                                           intensity: 1.25, softness: 0.78))
  scene.hasLight = true

method update(scene: LightDemo) =
  if actionJustPressed(toggleLights):
    light2dSetEnabled(not light2dEnabled())
  if actionDown(raiseAmbient) or actionDown(lowerAmbient):
    var settings = light2dSettings()
    let delta = (if actionDown(raiseAmbient): 0.4'f32 else: -0.4'f32) * tick()
    settings.ambient = settings.ambient.withAlpha(settings.ambient.a + delta)
    light2dSetSettings(settings)
  if scene.hasLight:
    discard light2dSetLight(scene.keyLight, Light2D(position: mousePos(), radius: 320,
      color: rgba(1, 0.97, 0.85, 1), intensity: 1.25, softness: 0.8))

method draw(scene: LightDemo) =
  let view = viewSize()
  drawRect(rgb(0.07, 0.09, 0.12), view, transform(vec3(0, 0, -1)))
  drawRect(rgb(0.18, 0.21, 0.25), vec2(view.x, 170),
           transform(vec3(0, -view.y * 0.5'f32 + 85, 0.1)))
  for occ in scene.occluders:
    drawRect(rgb(0.34, 0.38, 0.46), occ.size, transform(occ.center.extend(0.4), angle = occ.rotation))
  drawText(text("Light2D\nMouse moves light\nL toggle  Up/Down ambient\nlights=" &
                $light2dLightCount() & " occluders=" & $light2dOccluderCount(), 18, White),
           transform(vec3(-view.x * 0.5'f32 + 16, view.y * 0.5'f32 - 16, 2)), vec2(0, 1))

method cleanup(scene: LightDemo) =
  light2dClear()

when isMainModule:
  run app(title = "Light2D Basic", size = ivec2(960, 540),
          scene = LightDemo(), scaleMode = ScaleMode(kind: smFit, virtualSize: vec2(960, 540)))
