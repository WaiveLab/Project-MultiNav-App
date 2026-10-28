import Foundation

/// The behavioral objective measures destination contact, not route recall.
enum StudyPerformance {
    static func objectiveScore(touchedTarget: Bool, timeToTarget: TimeInterval?) -> Double {
        guard touchedTarget, let timeToTarget,
              timeToTarget.isFinite, timeToTarget >= 0
        else { return 0 }

        let best: TimeInterval = 5
        let worst: TimeInterval = 90
        return min(1, max(0, (worst - timeToTarget) / (worst - best)))
    }
}
