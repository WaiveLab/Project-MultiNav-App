// The comments for this .swift file have been annotated by chatGPT

import SwiftUI

// Displays the post-round questionnaire and calculates a subjective score.
struct SurveyView: View {

    // Sends the survey score, attention-check result, and raw answers to the study session.
    let onSubmit: (_ subjectiveScore: Double,
                   _ attentionPassed: Bool,
                   _ rawAnswers: [String: Any]) -> Void

    // Survey questions using a 1–7 Likert scale.
    private static let items: [(key: String, text: String)] = [
        ("q_pleasant", "The vibration felt pleasant."),
        ("q_clear", "I could clearly feel when I was on the route."),
        ("q_distinct", "The vibration was easy to tell apart from other map feedback."),
        ("q_comfort", "I could use this vibration for a long session without discomfort."),
    ]

    // Randomly selects the correct answer for the attention-check question.
    @State public var attentionExpected = Int.random(in: 1..<7)

    public var attentionText: String {
        "Please select “Agree” (\(attentionExpected)) for this statement."
    }

    // Stores the participant's survey selections.
    @State private var answers: [Int?] = Array(repeating: nil, count: items.count)
    @State private var attentionAnswer: Int?

    // The Submit button is enabled only after every question is answered.
    private var complete: Bool {
        answers.allSatisfy { $0 != nil } && attentionAnswer != nil
    }

    var body: some View {
        Form {
            Section {
                likertRow(text: Self.items[0].text, selection: $answers[0])
                likertRow(text: Self.items[1].text, selection: $answers[1])
                likertRow(text: attentionText, selection: $attentionAnswer)
                likertRow(text: Self.items[2].text, selection: $answers[2])
                likertRow(text: Self.items[3].text, selection: $answers[3])
            } header: {
                Text("How did the route vibration feel?")
            } footer: {
                Text("1 = strongly disagree, 7 = strongly agree.")
            }

            // Calculates the survey score and submits all responses.
            Button("Submit") {
                let values = answers.compactMap { $0 }
                let mean = Double(values.reduce(0, +)) / Double(values.count)
                let score = (mean - 1) / 6   // Converts 1–7 to 0–1.

                var raw: [String: Any] = [:]
                for (i, item) in Self.items.enumerated() {
                    raw[item.key] = answers[i] ?? 0
                }
                raw["q_attention"] = attentionAnswer ?? 0

                onSubmit(score, attentionAnswer == attentionExpected, raw)
            }
            .disabled(!complete)
            .accessibilityHint(complete
                               ? "Sends your answers"
                               : "Answer every statement first")
        }
    }

    // Creates a reusable row of 1–7 Likert-scale buttons.
    private func likertRow(text: String, selection: Binding<Int?>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text)
            HStack {
                ForEach(1...7, id: \.self) { value in
                    Button {
                        selection.wrappedValue = value
                    } label: {
                        Text("\(value)")
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .background(selection.wrappedValue == value
                                        ? Color.accentColor : Color(.systemGray5))
                            .foregroundStyle(selection.wrappedValue == value
                                             ? .white : .primary)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(value) of 7")
                }
            }
            HStack {
                Text("Disagree").font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Text("Agree").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
