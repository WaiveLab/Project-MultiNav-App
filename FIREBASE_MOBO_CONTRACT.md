# Firebase/MOBO contract

This document is the data contract between the MultiNav iOS app and the external
MOBO process. The app does not run the optimizer. MOBO publishes a candidate to
Cloud Firestore, the app tests that exact candidate for one map overview, and the
app publishes the result for MOBO to consume.

## Non-negotiable haptic behavior

- Every haptic is a `burst`.
- Every supported element type has its own independent five-value profile.
- Instances of the same element type share that type's profile during a round.
- Profiles for different element types are never implicitly shared.
- A candidate document contains the complete profile set. The app either accepts
  the whole candidate or rejects it; it never mixes values from two candidates.
- The app runs exactly 18 rounds and then stops.

The five values for each element type are:

| Field | Firestore type | Meaning | Accepted by the app |
| --- | --- | --- | --- |
| `intensity` | double | Core Haptics intensity | finite `0...1` |
| `sharpness` | double | Core Haptics sharpness | finite `0...1` |
| `pulseCount` | int64 | transient taps in one burst | `1...120`; at most 120 pulses/second of `onDuration` |
| `onDuration` | double | seconds occupied by one burst | finite `0.01...2.0` |
| `offDuration` | double | seconds of silence before the burst repeats | finite `0.01...2.0` |

`pattern`, `duration`, and `interval` are not optimizer inputs in schema version
2. The app constructs `.burst(pulseCount:onDuration:offDuration:)` directly from
the five fields above. A candidate outside any accepted range is rejected as a
whole. These bounds preserve all current app defaults, cap each generated Core
Haptics pattern at 120 transient events, and ensure its silent spacer has a
positive duration. MOBO must also satisfy
`pulseCount <= onDuration * 120`; for example, 120 pulses requires an
`onDuration` of at least 1 second.

## `parameterValues` documents

MOBO must **add a new document** for each candidate. It must not update or reuse
the previous document. The document has this shape:

```text
parameterValues/{auto-generated-document-id}
  schemaVersion: 2                 (int64)
  pid: "101"                       (string)
  candidateId: "101-round-01-v1"   (string)
  createdAt: <server timestamp>     (timestamp)
  phase: "exploration"             (string)
  phaseStep: 1                     (int64, exactly the round this starts)
  haptics:                         (map)
    start:                         (map containing the five fields)
    onRoute:
    offRoute:
    onRouteIntersection:
    offRouteIntersection:
    landmark:
    end:
    street:
    onRouteSidewalk:
    offRouteSidewalk:
    onRouteCrosswalk:
    offRouteCrosswalk:
    turn:
    intersectionCenter:
```

All 14 keys are required, including `intersectionCenter`. That type is supported
by the app even though the current JSON maps do not yet contain one.

Publish only the next expected round. Do not pre-publish all 18 candidates: the
app intentionally listens to the newest document and will not run a candidate
whose `phaseStep` is not exactly the next round.

Here is a complete round-one example using the app's current per-type defaults:

```json
{
  "schemaVersion": 2,
  "pid": "101",
  "candidateId": "101-round-01-v1",
  "createdAt": "USE_A_FIRESTORE_TIMESTAMP_HERE",
  "phase": "exploration",
  "phaseStep": 1,
  "haptics": {
    "start": { "intensity": 0.75, "sharpness": 1.0, "pulseCount": 10, "onDuration": 0.25, "offDuration": 0.5 },
    "onRoute": { "intensity": 1.0, "sharpness": 0.5, "pulseCount": 120, "onDuration": 1.0, "offDuration": 0.01 },
    "offRoute": { "intensity": 0.25, "sharpness": 0.25, "pulseCount": 120, "onDuration": 1.0, "offDuration": 0.01 },
    "onRouteIntersection": { "intensity": 0.75, "sharpness": 0.25, "pulseCount": 15, "onDuration": 0.25, "offDuration": 0.05 },
    "offRouteIntersection": { "intensity": 0.75, "sharpness": 0.25, "pulseCount": 120, "onDuration": 1.0, "offDuration": 0.01 },
    "landmark": { "intensity": 1.0, "sharpness": 0.15, "pulseCount": 60, "onDuration": 1.0, "offDuration": 0.01 },
    "end": { "intensity": 0.75, "sharpness": 1.0, "pulseCount": 120, "onDuration": 1.0, "offDuration": 0.01 },
    "street": { "intensity": 0.33, "sharpness": 0.33, "pulseCount": 60, "onDuration": 1.0, "offDuration": 0.15 },
    "onRouteSidewalk": { "intensity": 0.75, "sharpness": 1.0, "pulseCount": 60, "onDuration": 1.0, "offDuration": 0.01 },
    "offRouteSidewalk": { "intensity": 0.25, "sharpness": 0.25, "pulseCount": 60, "onDuration": 1.0, "offDuration": 0.01 },
    "onRouteCrosswalk": { "intensity": 0.75, "sharpness": 1.0, "pulseCount": 60, "onDuration": 1.0, "offDuration": 0.01 },
    "offRouteCrosswalk": { "intensity": 0.25, "sharpness": 0.25, "pulseCount": 60, "onDuration": 1.0, "offDuration": 0.01 },
    "turn": { "intensity": 0.25, "sharpness": 0.25, "pulseCount": 60, "onDuration": 1.0, "offDuration": 0.01 },
    "intersectionCenter": { "intensity": 0.25, "sharpness": 0.25, "pulseCount": 60, "onDuration": 1.0, "offDuration": 0.01 }
  }
}
```

In the Firebase console, select `timestamp` for `createdAt` and choose the
current date and time. Do not paste the placeholder string shown in the JSON.
Select `int64` for `schemaVersion`, `phaseStep`, and every `pulseCount`. Select
`double` for intensity, sharpness, on-duration, and off-duration values.

The earlier flat test document containing top-level `intensity`, `duration`,
`interval`, and `pattern` fields is not schema version 2. The app's query now
excludes it because it does not have numeric `schemaVersion: 2`; deleting it is
still recommended to avoid confusion in the Firebase console. Do not try to
repair that flat document by changing only its timestamp—the complete nested
schema shown above is required.

## App-to-MOBO result

After the participant completes a map and survey, the app adds one document to
`interventionResults`. It includes:

```text
pid, authUid, sessionId, resultId, roundNumber, mapName, createdAt
parameterDocumentId, candidateId, schemaVersion, phase, phaseStep
hapticMode: "burst"
haptics                              (the complete tested 14-profile snapshot)
subjectiveScore, objectiveScore
attentionCheckPassed, touchedTarget, timeToTargetSeconds
q_pleasant, q_clear, q_distinct, q_comfort, q_attention
```

`parameterDocumentId` is the Firestore document that the app actually loaded.
MOBO should join a result to a candidate with this field; `candidateId` is the
optimizer's human-readable/run-specific identifier. Keeping both prevents a
result from being attributed to the wrong settings. `resultId` is also the
Firestore document ID (`<sessionId>-round-<roundNumber>`), so retrying a write
cannot create a duplicate document. A retry can still produce another Firestore
listener `modified` event, so MOBO must upsert/deduplicate by `resultId` and
process each logical result only once. The app retains and resends the original
survey/measurement payload on retry, and the rules permit only `createdAt` to
change on that deterministic document.

## Round-by-round handshake

1. MOBO creates the complete candidate for participant `pid`, with
   `phaseStep = 1`, using a new document and a server timestamp.
2. The app's listener selects the newest document for that `pid` and accepts it
   only when its `phaseStep` is the expected round. It waits for a
   server-confirmed Firestore snapshot and will not start a round from a
   potentially stale offline cache entry.
3. The app freezes that complete snapshot for the round and opens one shuffled
   map overview. Every element resolves its profile by element-type key.
4. The participant explores the overview/intersection layers and completes the
   survey.
5. The app writes `interventionResults` with scores, answers, the source IDs,
   and the exact profile snapshot it tested.
6. MOBO reads that result, calculates independent values for every element type,
   and adds the next complete candidate with `phaseStep = previous + 1`.
7. Repeat through `phaseStep = 18`. After result 18 is saved, the app displays
   completion and stops listening.

MOBO may decide that two types receive equal values, but it must still write both
type maps. Equality is an optimizer decision, never an app-side linkage.

## Local app-only testing

The login and Firebase waiting screens include a clearly labelled option to
continue without Firebase or MOBO. Local test mode uses the app's complete set
of 14 built-in per-element burst profiles, advances through the same shuffled
18-map deck, and still displays every survey. It performs no candidate reads and
no result writes; survey answers from a local run are intentionally discarded.

If a connected result upload fails, the error screen also allows the tester to
skip that unsent result and continue all remaining rounds locally. This escape
hatch is for interface, JSON-layer, and haptic testing only—not participant data
collection.

## Publishing from Python (recommended for MOBO)

The MOBO machine should use a Firebase Admin SDK service account or Application
Default Credentials. Never add a service-account JSON key to this repository or
the iOS app.

```python
import firebase_admin
from firebase_admin import firestore

firebase_admin.initialize_app()
db = firestore.client()

candidate = {
    "schemaVersion": 2,
    "pid": "101",
    "candidateId": "101-round-01-v1",
    "createdAt": firestore.SERVER_TIMESTAMP,
    "phase": "exploration",
    "phaseStep": 1,
    "haptics": complete_haptics_map,  # all 14 keys, each with all five values
}

db.collection("parameterValues").document().set(candidate)
```

Use an Admin SDK only on a trusted computer/server. Admin SDK requests bypass
Firestore Security Rules and are controlled by Google Cloud IAM.

## Firebase project setup checklist

1. Register the Apple app with the exact bundle ID `waivelab.cocadoe`.
2. Put that project's `GoogleService-Info.plist` in the app target. The checked-in
   target file currently points to Firebase project `project-multinav`.
3. Enable Anonymous sign-in under Authentication > Sign-in method.
4. Create the default Cloud Firestore database.
5. Publish `firestore.rules` from this repository.
6. Create/deploy the composite index in `firestore.indexes.json`.
7. Add one complete schema-v2 `parameterValues` document for a test `pid`.
8. Run on a physical iPhone, enter the same `pid`, and confirm round 1 starts.
9. Complete its survey and confirm one `interventionResults` document appears
   with matching `parameterDocumentId`, `candidateId`, and all 14 profiles.
10. Publish a new candidate with `phaseStep = 2`; confirm the app starts round 2
    without reusing the round-one values.

Use a new `pid` for each real study session. If a participant must restart under
the same `pid`, MOBO must publish a fresh round-one candidate after the restart;
otherwise the newest document may still belong to the earlier session.

If the Firebase CLI is installed, run the following from the repository root
after signing in. `.firebaserc` pins these files to `project-multinav`, which
helps avoid deploying the rules to the old Firebase project.

```shell
firebase login
firebase use project-multinav
firebase deploy --only firestore:rules,firestore:indexes
```

Without the CLI, copy `firestore.rules` into Firestore > Rules and publish it,
then create the index in Firestore > Indexes with collection ID
`parameterValues`, field `pid` ascending, field `schemaVersion` ascending, and
field `createdAt` descending.

### Security boundary

The iOS app uses anonymous Firebase Authentication. The included rules let any
signed-in study client query optimizer candidates and append only valid results;
clients cannot write candidates or read submitted results. Anonymous identities
are not inherently tied to the participant ID typed into the app, so do not put
personally identifying information in `pid`. If the deployment later requires
participant-private candidates, add a server-issued identity/claim rather than
trusting the typed participant ID.
