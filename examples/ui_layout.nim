import nima/prelude

type UiLayout = ref object of Scene
  status: string
  accent: Color

method init(scene: UiLayout) =
  scene.status = "Ready"
  scene.accent = Blue

method draw(scene: UiLayout) =
  let mouse = mousePos()
  let clicked = mouseJustPressed(mbLeft)
  let root = uiRectFromCenterSize(Vec2Zero, vec2(520, 300))
  let card = root.inset(insets(18))
  let headerSplit = card.splitTop(48, 14)
  let actionRects = headerSplit.top.columns([140'f32, 140, 140], 12)
  let bodySplit = headerSplit.rest.splitBottom(58, 14)
  let columns = bodySplit.rest.columnsEqual(2, 16)
  let leftRows = columns[0].inset(insets(12, 10)).rowsEqual(3, 8)
  let rightRows = columns[1].inset(insets(12, 10)).rowsEqual(3, 8)

  drawRect(rgb(0.04, 0.05, 0.07), viewSize(), transform(vec3(0, 0, -1)))
  panel(root, cardPanelStyle()).draw(0.1)
  label(rect(vec2(card.min.x, card.max.y - 22), vec2(card.max.x, card.max.y)),
        "Explicit Geometry UI",
        defaultLabelStyle().withAlign(caTopLeft).withSize(20)).draw(0.31)

  if button(actionRects[0], "Save", filledButtonStyle(scene.accent)).draw(mouse, 0.3) and clicked:
    scene.status = "Saved layout"
    scene.accent = Green
  if button(actionRects[1], "Clear", filledButtonStyle(rgb(0.35, 0.38, 0.42))).draw(mouse, 0.3) and clicked:
    scene.status = "Cleared selection"
    scene.accent = rgb(0.35, 0.38, 0.42)
  if button(actionRects[2], "Close", filledButtonStyle(Red)).draw(mouse, 0.3) and clicked:
    scene.status = "Close requested"
    scene.accent = Red

  panel(columns[0], PanelStyle(fill: rgba(0.08, 0.10, 0.14, 0.82),
                               border: rgba(0.24, 0.28, 0.36, 1),
                               borderThickness: 1)).draw(0.18)
  panel(columns[1], PanelStyle(fill: rgba(0.08, 0.10, 0.14, 0.82),
                               border: rgba(0.24, 0.28, 0.36, 1),
                               borderThickness: 1)).draw(0.18)
  label(leftRows[0], "Rows", defaultLabelStyle().withAlign(caLeft).withSize(16)
                                      .withColor(Yellow)).draw(0.32)
  label(leftRows[1], "Panels, buttons, and labels share world-space geometry.",
        defaultLabelStyle().withAlign(caLeft).withSize(14)
                           .withColor(rgb(0.84, 0.87, 0.93))).draw(0.32)
  label(leftRows[2], "Left aligned text stays paired with its cell.",
        defaultLabelStyle().withAlign(caBottomLeft).withSize(13)
                           .withColor(rgb(0.72, 0.76, 0.84))).draw(0.32)
  label(rightRows[0], "Columns", defaultLabelStyle().withAlign(caRight).withSize(16)
                                         .withColor(Yellow)).draw(0.32)
  label(rightRows[1], "Right column content is anchored independently.",
        defaultLabelStyle().withAlign(caRight).withSize(14)
                           .withColor(rgb(0.84, 0.87, 0.93))).draw(0.32)
  label(rightRows[2], "BottomRight anchor",
        defaultLabelStyle().withAlign(caBottomRight).withSize(13)
                           .withColor(rgb(0.72, 0.76, 0.84))).draw(0.32)

  panel(bodySplit.bottom, PanelStyle(fill: rgba(0.14, 0.18, 0.25, 0.9),
                                     border: scene.accent,
                                     borderThickness: 1)).draw(0.2)
  label(bodySplit.bottom.inset(insets(16, 10)), "Status: " & scene.status,
        defaultLabelStyle().withAlign(caLeft).withSize(16)).draw(0.33)

when isMainModule:
  run app(title = "UI Layout", size = ivec2(800, 600), scene = UiLayout(), resizable = true)
