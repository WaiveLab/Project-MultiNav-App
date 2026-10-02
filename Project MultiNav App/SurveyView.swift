import SwiftUI

struct SurveyView: View {
    @EnvironmentObject var session: StudySession
    let onSubmit: (_ subjectiveScore: Double, _ rawAnswers: [String: Any]) -> Void

    @State private var cognitiveLoad = ""
    @State private var clarity: Int?
    @State private var likability: Int?
    @State private var comfort: Int?
    @FocusState private var editingLoad: Bool

    private let agreement = ["Strongly disagree", "Disagree", "Neutral", "Agree", "Strongly agree"]
    private var response: SurveyResponse? {
        SurveyResponse(cognitiveLoad: cognitiveLoad, clarity: clarity,
                       likability: likability, comfort: comfort)
    }

    var body: some View {
        Form {
            Section {
                Text("How much mental and perceptual activity was required (e.g., thinking, deciding, calculating, remembering, looking, searching).")
                TextField("Enter a whole number from 1 to 21", text: $cognitiveLoad)
                    .keyboardType(.numberPad)
                    .focused($editingLoad)
                    .accessibilityLabel("Cognitive load, 1 to 21")
                if !cognitiveLoad.isEmpty && !validLoad {
                    Text("Enter a whole number from 1 to 21.").foregroundStyle(.red)
                }
                if editingLoad {
                    Button("Done entering cognitive load") { editingLoad = false }
                }
            } header: {
                Text("1. Cognitive load")
            } footer: {
                Text("1 = very low, 21 = very high. Researcher: record the participant's answer.")
            }

            ratingSection("2. Clarity", question: "How clear or distinct were the vibrations",
                          labels: ["Extremely unclear", "Somewhat unclear", "Neutral", "Clear", "Extremely clear"],
                          selection: $clarity)
            ratingSection("3. Likability", question: "I liked the vibrations",
                          labels: agreement, selection: $likability)
            ratingSection("4. Comfort", question: "I could use the vibrations without discomfort",
                          labels: agreement, selection: $comfort)

            Button(session.isLocalTestMode ? "Continue local test" : "Submit") {
                guard let response else { return }
                editingLoad = false
                onSubmit(response.subjectiveScore, response.rawAnswers)
            }
            .disabled(response == nil)
            .accessibilityHint(response == nil ? "Answer all four questions first" : "Completes this questionnaire")
        }
    }

    private var validLoad: Bool {
        guard let value = Int(cognitiveLoad.trimmingCharacters(in: .whitespacesAndNewlines)) else { return false }
        return (1...21).contains(value)
    }

    private func ratingSection(_ title: String, question: String, labels: [String],
                               selection: Binding<Int?>) -> some View {
        Section {
            Text(question)
            ForEach(1...5, id: \.self) { value in
                Button {
                    editingLoad = false
                    selection.wrappedValue = value
                } label: {
                    HStack {
                        Text("\(value) — \(labels[value - 1])")
                        Spacer()
                        if selection.wrappedValue == value {
                            Image(systemName: "checkmark")
                        }
                    }
                    .frame(minHeight: 36)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection.wrappedValue == value ? [.isSelected] : [])
            }
        } header: { Text(title) }
    }
}
