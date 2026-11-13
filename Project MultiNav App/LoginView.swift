// The comments for this .swift file have been annotated by chatGPT

import SwiftUI

// Displays the participant login screen and starts the study session.
struct LoginView: View {
    @EnvironmentObject var session: StudySession
    @State private var participantID = ""

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("MultiNav Study")
                .font(.largeTitle.bold())

            Text(session.phase == .correctingParticipantID
                 ? "Enter the participant ID for this study."
                 : "Enter your participant ID to explore a practice map with the default vibrations.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // Allows the participant to enter their ID.
            TextField("Participant ID", text: $participantID)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)
                .accessibilityLabel("Participant ID")
                .onSubmit(logIn)
                .keyboardType(.asciiCapable)

            Button(session.phase == .correctingParticipantID ? "Continue" : "Start practice", action: logIn)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(trimmedID.isEmpty)

            if let error = session.registrationError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding()
        .onAppear { participantID = session.participantID }
    }

    // Removes accidental whitespace from the participant ID.
    private var trimmedID: String {
        participantID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func logIn() {
        session.begin(participantID: trimmedID)
    }
}
