# Project MulitNav App
A vibrotactile wayifinding app that enables blind and low vision (BLV) users to navigate outdoor environments.

## How to run
1. Clone repo and keep the updated `Library/TactileMapPackageCode` folder beside
   `Project-MultiNav-App` (the Xcode project now uses that local Swift package).
2. Connect an iPhone 8 or newer
3. Select iPhone
4. Build and run

To test the maps, intersection layers, haptics, and surveys without a working
Firebase/MOBO connection, enter any participant ID and tap **Test without
Firebase or MOBO**. A visible local-test banner confirms that no study data is
being uploaded.

## Firebase and MOBO

The app tests one complete, per-element burst-haptic candidate per map round.
See [FIREBASE_MOBO_CONTRACT.md](FIREBASE_MOBO_CONTRACT.md) for the schema,
17-round handshake, Firebase setup checklist, and optimizer integration contract.

## Updated study controls

The researcher completes exploration with a **three-finger swipe up** on either
map view. This also handles VoiceOver's corresponding scroll gesture. A
three-finger swipe right or VoiceOver escape returns from an intersection to
the overview. There is no on-screen completion button.

Local testing doubles as practice: route and intersection cues use intensity
1.0 with fixed pulse timing. Remote study candidates retain their supplied
profiles. All segments of one element type use exactly the same profile.

See [UPDATE_CHECKLIST.md](UPDATE_CHECKLIST.md) for the PDF change audit and
remaining device checks. Run the portable checks from this directory:

```powershell
node tools/validate_maps.cjs
python tools/validate_study.py
```

The second check requires Swift on PATH. An iOS build still requires Xcode;
portable tests do not exercise UIKit, VoiceOver, speech or physical haptics.
