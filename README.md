# Project MulitNav App
A vibrotactile wayifinding app that enables blind and low vision (BLV) users to navigate outdoor environments.

## How to run
1. Clone repo
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
18-round handshake, Firebase setup checklist, and optimizer integration contract.
