# App update and Firebase handoff

The app implements the agreed PDF changes. Firebase, Cloud Functions, MOBO,
package references, lockfiles and package source have not been changed or deployed.
The NFB visual/physical comparison remains deferred as requested.

## Questionnaire fields to support

Results still go to `interventionResults` using the existing result document ID,
authentication, upload, retry and candidate association flow. These fields are
top-level fields in that same result document, not a separate collection.

| Field | New value/validation | Meaning |
| --- | --- | --- |
| `questionnaireVersion` | Integer, exactly `2` | Identifies this questionnaire and scoring formula |
| `q_cognitive_load` | Required integer, 1–21 | Lower mental/perceptual demand is better |
| `q_clear` | Required integer, 1–5 | Extremely unclear, Somewhat unclear, Neutral, Clear, Extremely clear |
| `q_likability` | Required integer, 1–5 | Strongly disagree through Strongly agree |
| `q_comfort` | Required integer, 1–5 | Strongly disagree through Strongly agree |
| `subjectiveScore` | Number, 0–1 | Equal-weight mean of the four normalized responses below |

The questions appear in that order, with no preselected answers. Cognitive load
requires a whole number. Submit stays disabled until all four answers are valid.
The attention check remains absent: no `q_attention` or `attentionCheckPassed`.
New results no longer send `q_pleasant` or `q_distinct`.

The app calculates:

```text
subjectiveScore = (
    (21 - q_cognitive_load) / 20
  + (q_clear - 1) / 4
  + (q_likability - 1) / 4
  + (q_comfort - 1) / 4
) / 4
```

Use floating-point division. A score of 1 is best, 0 is worst. All dimensions
carry equal weight. The objective measures destination contact, not route
description. A round without destination contact scores zero; a successful
contact uses `clamp((90 - timeToTargetSeconds) / 85, 0, 1)`.

Example of just the questionnaire portion of an uploaded result:

```json
{
  "questionnaireVersion": 2,
  "q_cognitive_load": 6,
  "q_clear": 4,
  "q_likability": 5,
  "q_comfort": 3,
  "subjectiveScore": 0.75
}
```

This fragment is not a complete result or a parameter candidate. The app still
adds all existing IDs, participant/session/round information, timestamp,
performance measurements and the exact tested haptic snapshot.

## Firebase work

1. Ensure the live result validation accepts the new fields and ranges. The
   repository's current `firestore.rules` permits extra questionnaire fields and
   validates `subjectiveScore` in 0–1, so these app changes alone do not require
   loosening those rules. The deployed rules have not been inspected.
2. If adding strict questionnaire validation, validate every field in the table
   and require all five raw/version fields. Keep ownership, candidate matching,
   immutable haptic values, and retry protections intact. Apply the version-2
   requirements to new-version results; decide explicitly how older clients are
   handled if they remain in use.
3. Update any Cloud Function, export, dashboard or analysis that reads the old
   raw questions or assumes every question uses 1–7. Preserve the four raw
   responses and `questionnaireVersion` when forwarding data. Code consuming
   only the app's `subjectiveScore` still receives a 0–1 number, but its meaning
   has changed. Do not apply the old `(mean - 1) / 6` formula to these responses.
4. Keep historical results as recorded. Treat missing `questionnaireVersion` as
   legacy/unversioned data and keep it separate from version 2 unless the study
   team explicitly chooses a method for combining it. Do not fabricate missing
   cognitive-load or likability responses from the old questions.
5. Test one complete connected round and confirm the questionnaire fragment,
   score, IDs and tested haptics arrive together. Confirm an upload retry still
   targets the same result and the next candidate advances to the next round.

`schemaVersion: 2` continues to describe the existing haptic parameter schema.
It is independent of `questionnaireVersion: 2`. Do not rename/change the 14 keys
inside `haptics` or their five numeric values (`intensity`, `sharpness`,
`pulseCount`, `onDuration`, `offDuration`). `hapticMode: "burst"`, `candidateId`,
`parameterDocumentId`, `phase`, `phaseStep` and the `parameterValues` input
contract are unchanged. Share this scoring/version change with the MOBO owner;
no MOBO implementation is included here.

## App behavior

- Successful entry announces “Route overview” or “Intersection view”; returning
  from an intersection announces the overview again.
- Each overview now retains its first POI only. The existing 17 route shapes,
  three legs, two intermediate intersections, and intersection endpoints remain.
- On-route cues end with “route”; endpoint speech says “Start of route” and
  “End of route”. Detail endpoints include “from [street]” / “on [street]”.
  Turn speech is “Turn”. Internal resource names and turn geometry remain intact.
- The visible completion button is removed. The experimenter performs a
  **three-finger swipe up on the map** to finish exploration and open the survey.
  Existing back gestures remain. A VoiceOver **Finish exploration** custom
  action is also available on the map/round header.
- The map fits its occupied area with room for marker edges; removing the
  completion button frees vertical space. Stroke and marker sizes are unchanged.
- All app default and local test/practice cues use maximum intensity 1,
  preserving sharpness and timings. This
  applies to existing local test mode, which uploads no responses. It does not
  add a separate practice phase to the connected study. Remote candidates are
  played and recorded exactly as received.
- All segments of the same type continue using the same candidate profile;
  there is no distance-to-destination intensity adjustment. Physical differences
  between segments still need assessment on the study device.

## Verification and remaining device checks

Run the map validator from the app repository:

```text
node tools/validate_maps.cjs
```

With Python, Swift and the existing sibling package source available:

```text
python tools/check_study_updates.py
```

The portable check uses actual app model code for survey validation/scoring,
local-practice isolation, remote haptic round-trip preservation, speech labels,
and shared map transforms across all 17 overviews and 34 intersection pairs.
It parses all app Swift sources but does not type-check SwiftUI/UIKit/Firebase
against an iOS SDK. It does not install or update any dependency.

Before a study run, build in Xcode with the existing resolved packages and check:

- Overview/intersection announcements, opening both intersections and returning.
- One-finger exploration, double-tap entry, existing back gestures, and completion
  from both views. With VoiceOver on, verify upward completion and the custom
  action; confirm ordinary exploration never completes a round accidentally.
- Map marker visibility and touch alignment on the study device, including edges.
- New question order, keyboard dismissal, validation, and submission.
- Sustained/restarted vibrations on all three route segments and maximum local
  practice intensity. Confirm leaving the map stops haptics and crosswalk tones.
- A complete connected upload/next-candidate cycle after the Firebase work.

Windows checks do not establish an iOS build or physical-device readiness.
