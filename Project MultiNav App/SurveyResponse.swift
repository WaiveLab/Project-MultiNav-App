import Foundation

/// Versioned researcher-entered ratings. Each dimension contributes equally;
/// less cognitive load and higher clarity, liking and comfort score better.
struct SurveyResponse {
    let cognitiveLoad: Int
    let clarity: Int
    let likability: Int
    let comfort: Int

    init?(cognitiveLoad: String, clarity: Int?, likability: Int?, comfort: Int?) {
        guard let load = Int(cognitiveLoad.trimmingCharacters(in: .whitespacesAndNewlines)),
              (1...21).contains(load),
              let clarity, (1...5).contains(clarity),
              let likability, (1...5).contains(likability),
              let comfort, (1...5).contains(comfort) else { return nil }
        self.cognitiveLoad = load
        self.clarity = clarity
        self.likability = likability
        self.comfort = comfort
    }

    var subjectiveScore: Double {
        let ease = Double(21 - cognitiveLoad) / 20
        let ratings = Double(clarity + likability + comfort - 3) / 4
        return (ease + ratings) / 4
    }

    var rawAnswers: [String: Any] {
        ["questionnaireVersion": 2, "q_cognitive_load": cognitiveLoad,
         "q_clear": clarity, "q_likability": likability, "q_comfort": comfort]
    }
}
