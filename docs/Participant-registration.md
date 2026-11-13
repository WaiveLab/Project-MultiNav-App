# Phone registration after practice

The iPhone app now calls the authenticated `registerParticipant` callable in
`us-central1` before listening for its first schema-v2 candidate. The backend
creates `users/{pid}` once. The existing deployed `registerUserOnCreate` trigger
then asks MOBO for the first candidate, exactly as the PC tester's registration
helper does. MOBO supplies the initial seed profiles; local practice defaults
are never substituted into a connected round.

This change requires both deployment of the new function and a rebuilt iOS app.
The existing cloud service account in this workspace has no function create,
update, list or get permissions (checked with `testIamPermissions`), so it cannot
perform that deployment. It is still sufficient for the PC tester's trusted
registration helper. No live function, rules or indexes were changed while
implementing this feature.

## Starting vibrations for new participants

In the deployed schema-v2 MOBO service, use the 14-entry `haptics` map from
`tools/seed_firebase_candidate.py` when registration requests the first
candidate for a new participant. Preview the complete payload from the app
repository with `python tools/seed_firebase_candidate.py --pid preview --round 1`.
Keep the publisher's own candidate ID, participant ID and server timestamp.
Apply this seed once at round 1 and use the optimizer for rounds 2 through 17.
This requires updating the first-candidate publisher. Installing the iOS app
alone applies these defaults only to local practice and the settings preview.

## Deploy the registration function once

Use a Firebase CLI session/account with permission to deploy Functions in
`project-multinav`. From the app repository:

```powershell
cd registration-functions
npm ci --ignore-scripts
npm test
cd ..
$env:FUNCTIONS_DISCOVERY_TIMEOUT = '120'
firebase deploy --only functions:participant-registration --project project-multinav
```

The dedicated `participant-registration` codebase contains only
`registerParticipant`. The existing registration/result triggers and optimizer
remain in their own deployment. Use the exact functions-only target above; do
not deploy the root configuration without `--only`, and do not deploy rules or
indexes as part of this change. The Admin SDK runs using the function's runtime
identity, which needs Firestore access. No JSON key is bundled with the function
or the phone. Ensure the existing `registerUserOnCreate` trigger still targets
`users/{userId}` in the `(default)` database of this same project.

## Build and verify the phone

Open the Xcode project on a Mac and resolve packages. `FirebaseFunctions` was
added as another product of the existing Firebase package. The Firebase version
requirement and lock file were not upgraded. Build and install on the iPhone.

1. Enter a fresh ID such as `ios-test-001` and tap **Start practice**. Try the
   overview and intersections. Practice also works with the network disabled.
2. Tap **Finish practice**, enable the network, and tap **Start MOBO study**.
   Expect **Connecting to Firebase…**, then a registration message while MOBO
   prepares the first settings.
3. Confirm a single `users/ios-test-001` document exists and MOBO creates a full
   round-one candidate. The first map should open after server-confirmed values
   arrive. Cold-start delays are possible (the PC test observed about 32 seconds).
4. Complete the survey. Confirm one result with the source candidate's IDs and
   all 14 profiles, then a fresh round-two candidate and map.
5. Test a used participant ID: the app should explain that a new run needs a new
   ID. It must not delete, reset or overwrite results or candidates.
6. With the network unavailable, confirm an error or the 90-second waiting
   message, then restore the connection and retry. A late valid candidate may
   still start the expected round without another tap.

## Existing IDs and retry behavior

IDs may contain 1–100 ASCII letters, digits, hyphens and underscores, starting
with a letter or digit. The phone trims surrounding whitespace before connecting.
Repeated taps on **Start MOBO study** cannot start simultaneous registrations. A registration
retry in the same app session retains the same session ID and is idempotent.

An unused pre-registered ID may be claimed if it has no results or completed
study and its newest schema-v2 candidate, if present, is round 1. Its user record
is updated with registration metadata, preserving original fields. Updating an
existing record does not fire a creation trigger again. If a pre-registered ID
has no candidate because its original trigger failed, retries will not restart
MOBO; repair that trigger or use a fresh ID.

A new phone session cannot take over an ID locked by another session, and IDs
with previous results or later-round candidates cannot start another study.
There is no study recovery across app termination in this change; use a fresh
ID for a new run. The endpoint does not provide participant-private data access:
the existing study rules still govern candidate/result access.

The listener starts only after registration succeeds. Errors offer retry or a
different ID. A 90-second wait removes the indefinite spinner and keeps the
listener active for late values. Reconnecting after a completed round restarts
only the listener; it never re-registers or resets the optimizer. Switching to
local mode cancels connection tasks and ignores late registration callbacks.

## Local checks

```powershell
cd registration-functions
npm test
# Optional, with the existing localhost Firestore emulator on port 8197:
node test/emulator.cjs
cd ..
python tools/check_registration_session.py
python tools/check_study_updates.py
```

The session check compiles the actual `StudySession` using test doubles for
Firebase/Combine unavailable on Windows. It covers registration, repeated taps,
timeout, late/wrong-round settings, submission/reconnect, retry, cancellation and
local mode. The emulator check exercises the actual server registration logic
with real transactions, including competing sessions. Neither check replaces
an Xcode build or live function/iPhone verification.

References:
[Firebase callable functions](https://firebase.google.com/docs/functions/callable),
[separate function codebases](https://firebase.google.com/docs/functions/organize-functions).
