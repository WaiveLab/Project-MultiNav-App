// The comments for this .swift file have been annotated by chatGPT

import SwiftUI

// Displays the participant login screen and starts the study session.
struct LoginView: View {
    @EnvironmentObject var session: StudySession
    @AppStorage("participantID") private var participantID = ""

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("MultiNav Study")
                .font(.largeTitle.bold())

            Text("Enter your participant ID to begin.")
                .foregroundStyle(.secondary)

            // Allows the participant to enter their ID.
            TextField("Participant ID", text: $participantID)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)
                .accessibilityLabel("Participant ID")
                .onSubmit(logIn)
                .keyboardType(.numberPad)

            // Starts the study once authentication and ID are valid.
            Button("Log in", action: logIn)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!session.isSignedIn || trimmedID.isEmpty)
                .accessibilityHint("Starts the study with your participant ID")

            // Shows a loading indicator while connecting.
            if !session.isSignedIn && session.authError == nil {
                ProgressView("Connecting…")
            }

            // Displays authentication errors and allows another attempt.
            if let authError = session.authError {
                Text(authError)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)

                Button("Try again") {
                    Task { await session.signIn() }
                }
            }

            Spacer()
        }
        .padding()
        // Attempts to authenticate when the view first appears.
        .task { await session.signIn() }
    }

    // Removes accidental whitespace from the participant ID.
    private var trimmedID: String {
        participantID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Begins the study if authentication and the participant ID are valid.
    private func logIn() {
        guard session.isSignedIn, !trimmedID.isEmpty else { return }
        session.begin(participantID: trimmedID)
    }
}
