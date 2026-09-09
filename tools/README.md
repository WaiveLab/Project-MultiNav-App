# Firebase candidate uploader

`seed_firebase_candidate.py` creates one complete schema-version-2 candidate in
the `parameterValues` collection. It includes all 14 independently controlled
haptic element types, including `intersectionCenter`.

Keep the downloaded Firebase Admin JSON key outside this repository. Preview a
candidate first:

```powershell
py .\tools\seed_firebase_candidate.py `
  --credentials "C:\FirebaseKeys\project-multinav-admin.json" `
  --pid "101" `
  --round 1
```

The preview does not contact or change Firebase. To publish it, install the
Admin SDK and repeat the command with `--write`:

```powershell
py -m pip install firebase-admin

py .\tools\seed_firebase_candidate.py `
  --credentials "C:\FirebaseKeys\project-multinav-admin.json" `
  --pid "101" `
  --round 1 `
  --write
```

Only publish the next round the app expects. The app deliberately rejects a
partial candidate or a candidate for a different participant/round.
