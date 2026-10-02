# PDF change audit

Source: `MultiNav app updates.pdf`. NFB appearance matching and the NFB vibration
comparison are deferred at the user's request.

| Requested change | Status |
| --- | --- |
| Announce Route overview / Intersection view on opening | Added for initial load, zoom and return; announcement waits for the previous view's touch cancellation. |
| One POI per overview | Implemented; retains the first existing POI. |
| Start/end on intersections; three legs and two intermediate intersections | Already implemented. All 17 routes still pass the independent validator against the repository's whiteboard transcription. |
| Append “route” to route cues | Added to overview streets, detail sidewalks/crosswalks and on-route intersection speech. |
| “Start of route” / “End of route” | Updated overview and detail resource labels. |
| Remove completion button from both map views | Replaced with researcher three-finger swipe up, including VoiceOver handling. Swipe right remains back. |
| Larger map without thicker overview lines | Added fitting to feature extents, retained physical stroke widths, removed the button's layout space. Drawing and hit detection share the same transform. |
| Consistent route intensity between segments | Already selected exclusively by element type, with no position/destination scaling. Regression checks cover every overview's route segments. Physical perception still requires device testing. |
| Maximum route/intersection intensity for practice | Local mode now uses fixed intensity 1.0 for route and intersection cues. Remote candidates are unchanged. |
| NFB road/sidewalk widths, colors, crosswalks and strength comparison | Deferred; no NFB-specific style changes applied. |
| Detail start/end street wording and “Turn” | Updated all 34 overlays and their generator. Geometric left/right-turn validation is retained. |
| Remove attention check | Already implemented; preserved. |
| Cognitive load first, 1–21 | Added validated integer entry with full question text. |
| Clarity, likability, comfort in order, 1–5 | Added all requested wording and clarity labels. Submission requires all four valid answers. |

## Scoring and build integration

`SurveyResponse` retains the four raw answers and `questionnaireVersion: 2`.
The composite averages normalized dimensions, reversing cognitive load so a
higher overall score remains better. This formula is an implementation choice;
the PDF specifies scales but no composite formula. See `FIREBASE_MOBO_CONTRACT.md`.

The Xcode project now uses `../Library/TactileMapPackageCode` instead of the
remote package. Keep both folders together when moving this workspace to the
Mac. Renderer, fitting and gesture changes live in that package, so copying
only the app repository is insufficient. Duplicate Xcode package product
references and the obsolete remote package pin were removed.

## Verification

- `node tools/validate_maps.cjs`: all 17 overviews, 12 bases and 34 overlays.
- `python tools/validate_study.py`: compiles actual Foundation-only Swift
  sources; tests rating validation, score endpoints/midpoint, practice profile
  isolation, per-type route intensity, feature fitting and hit detection using
  all 17 overview documents.
- Swift syntax parsing of the app and local package sources.

## Remaining iPhone/Xcode checks

Windows cannot build/run the iOS app or evaluate physical vibration strength.
Build the app in Xcode with the updated local package and check:

1. Open an overview, zoom into each intersection and return; confirm the opening
   announcements, street labels, endpoint labels and “Turn” cue.
2. With VoiceOver both off and on, confirm one-finger exploration does not end
   the round, swipe right returns, and three-finger swipe up opens one survey
   from either map view. Confirm all audio and haptics stop on completion.
3. Check small and large iPhones for clipped markers and match touch locations
   to the expanded grid, including the detail view.
4. In local practice, compare all three route segments and intersection pulses.
   Confirm a connected study still uses its exact supplied candidate values.
5. Enter invalid/missing ratings, then valid endpoint ratings; confirm submission
   gating and inspect a test result for the versioned raw answers.

No cloud deployment or study-data writes were performed for these changes.
