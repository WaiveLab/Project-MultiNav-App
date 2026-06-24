# Intersection Exploration — Test Harness

A minimal, self-contained test to render `intersection_demo.json` through the
Northeastern TactileMapKit library (Canvas mode) and verify haptics + audio
labels on the new Screen 2 elements.

## Files

| File | What it does |
|---|---|
| `intersection_demo.json` | Sample intersection map (route, cross street, sidewalks, crosswalks, median, APS, POI, you-are-here, destination). Audio labels live in `properties.custom.audio_label`. One sidewalk carries a `study_gap` flag. |
| `IntersectionElements.swift` | Registers the new `TactileElementType`s and their `ElementStyle` visuals (mm-based, mockup-matched). |
| `IntersectionFeedbackPolicy.swift` | `DefaultFeedbackPolicy` subclass: speaks each element's `audio_label`, plays a per-type haptic pattern. |
| `IntersectionTestView.swift` | SwiftUI view that loads the JSON and renders it via `TactileMapView`, with double-tap-on-destination → dismiss. |

## Setup in Xcode

1. Add the three `.swift` files to the **Project MultiNav App** target.
2. Drag `intersection_demo.json` into your `Maps/` folder.
   - Check **"Copy items if needed"**, select the **app target**.
   - Confirm it shows under **Build Phases > Copy Bundle Resources**.
3. Show the view — either point your app entry at `IntersectionTestView()`,
   add a `NavigationLink` to it, or run the Xcode `#Preview`.
4. **Run on a physical iPhone** for haptics and spatial audio. The Simulator
   renders the map but produces no vibration.

## What to check

- Layout matches the mockup: vertical cyan route, dark-blue cross street
  (~3x sidewalk width), gray parallel sidewalks, white crosswalks, red median,
  yellow you-are-here / destination, APS + POI points.
- Dragging a finger over each element speaks its label and vibrates.
- Double-tapping the top "End of route" marker dismisses the view.

## Known-provisional bits (waiting on Paul)

The element list and styling are stand-ins until Paul confirms:
crosswalk keep/drop, street one-vs-two elements, median placement, APS
placement/count. The haptic patterns in `IntersectionFeedbackPolicy` are
placeholders — the real values come from the shared element/parameter model
that `SettingsView` edits and the MOBO overwrites between trials.

## Library APIs used (verified against TactileMapKit source)

- `TactileMapDocument.load(from:)`
- `TactileMapView(document:configuration:feedbackPolicy:onBackGesture:onDoubleTap:)`
- `TactileMapViewConfiguration` + `typeStyles[...]` + `.renderingMode = .canvas`
- `ElementStyle(color:sizeMM:pointShape:showAnchorDot:)`
- `DefaultFeedbackPolicy` overrides; `hapticEngine.start(pattern:)`,
  `audioEngine.speak(_:)`
