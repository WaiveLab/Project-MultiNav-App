# Firestore submission fix — October 29, 2026

The original rules rejected a representative valid seed-based submission in the
official Firestore emulator with `PERMISSION_DENIED`: the maximum 1,000 evaluated
expressions had been reached. Earlier portable Swift checks did not execute the
Firestore rules engine and therefore did not detect this problem.

The replacement `firestore.rules` validates result metadata and compares the full
haptics snapshot to the trusted `parameterValues` document named by
`parameterDocumentId`. Participant, candidate, schema, phase and step must also
match. Clients still cannot write parameter candidates, read/delete results, or
alter existing results; the owning client may retry with only `createdAt` changed.

The final comparison uses `MapDiff.affectedKeys()`, not plain map equality.
The expanded emulator tests showed that plain map equality rejects equivalent
integer/double encodings, while MapDiff permits the app's normalization without
permitting changed numeric values. Use the current file, including this correction.

This deliberately changes the validation boundary: Firestore no longer independently
checks each haptic number's type/range. Numeric validation remains in the app decoder
and the trusted candidate publisher. An administrator must publish valid candidates;
these rules are not an independent defense against an invalid administrator-written
candidate being echoed by a modified client. The original seed is compatible.
Keep candidate documents available and unchanged until their results are saved.
The candidate lookup is an additional rules document read per new submission.

Local verification: `python tools/check_firestore_rules.py`, with the official
Firestore emulator 1.22.0 listening on localhost port 8189, passed 230 assertions.
The test first reproduces the original rules' rejection using the retained fixture,
then verifies the replacement rules against valid creation for rounds 1–17,
server timestamp transforms, unchanged/timestamp-only retries, integer/double
normalization across all profiles, denied answer and owner edits, missing/mismatched
candidates, score/round bounds, modifications and omissions for all 14 cues and all
70 profile fields, extra fields, malformed submitted values, and client access checks.
Every expected rejection must be a rejection without an expression-budget failure.
It also explicitly confirms the trusted-publisher limitation: an invalid Admin-written
candidate can be echoed by a modified client, even though the real app rejects it.
Tests use a synthetic demo project only and do not connect to production.

Deployment: replace the complete Firebase Console Rules tab for `project-multinav`
with `firestore.rules`, then Publish. No app rebuild, package change, index change
or seed replacement is required for this fix. Retry the failed submission in the
still-open session. Confirm a new `interventionResults` document and then confirm
the optimizer publishes round two. Local tests do not confirm that live handoff.
