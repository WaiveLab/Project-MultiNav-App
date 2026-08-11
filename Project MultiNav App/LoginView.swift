import SwiftUI

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

            TextField("Participant ID", text: $participantID)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)
                .accessibilityLabel("Participant ID")
                .onSubmit(logIn)
                .keyboardType(.numberPad)

            Button("Log in", action: logIn)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!session.isSignedIn || trimmedID.isEmpty)
                .accessibilityHint("Starts the study with your participant ID")

            if !session.isSignedIn && session.authError == nil {
                ProgressView("Connecting…")
            }

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
        .task { await session.signIn() }
    }

    private var trimmedID: String {
        participantID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func logIn() {
        guard session.isSignedIn, !trimmedID.isEmpty else { return }
        session.begin(participantID: trimmedID)
    }
}
