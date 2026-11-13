# Project MulitNav App
A vibrotactile wayifinding app that enables blind and low vision (BLV) users to navigate outdoor environments.

## How to run
1. Clone repo
2. Connect an iPhone 8 or newer
3. Select iPhone
4. Build and run

Enter a participant ID and tap **Start practice**. Every participant explores the
same practice route using the built-in vibrations. Practice runs offline with
no measurements or questionnaire. Tap **Finish practice** on the overview or
swipe up with three fingers on either map view.

At **Practice complete**, the researcher taps **Start MOBO study** to connect
to Firebase and request round 1. The **MOBO study complete** screen appears
after the final questionnaire has been saved. To test maps and questionnaires
offline, choose **Test without Firebase or MOBO** at the practice handoff.

## Firebase and MOBO

Starting the MOBO study registers the participant ID and requests the first
candidate automatically. Deploy the registration function before
installing this app update; see [Participant-registration.md](docs/Participant-registration.md)
for deployment, ID reuse behavior and device verification.

The app tests one complete, per-element burst-haptic candidate per map round.
See [FIREBASE_MOBO_CONTRACT.md](FIREBASE_MOBO_CONTRACT.md) for the schema,
17-round handshake, Firebase setup checklist, and optimizer integration contract.
