import Foundation
import TactileMapFeedback

struct ParameterSet: Equatable {

    var intensity: Double = 0.5      
    var sharpness: Double = 0.5       
    var duration: Double = 0.2        
    var interval: Double = 10.0     
    var pattern: String = "constant"  
    var phase: String = "exploration"
    var phaseStep: Int = 1

    enum Pattern: String { case constant, puls }
}


extension ParameterSet {

    var hapticPattern: HapticPattern {
        let i = Float(intensity)
        let s = Float(sharpness)

        switch Pattern(rawValue: pattern) ?? .constant {
        case .constant:
            return HapticPattern(intensity: i, sharpness: s,
                                 mode: .continuous(duration: duration))
        case .puls:
            let period = 1.0 / max(interval, 0.1)
            let off = max(0.01, period - duration)
            let count = max(1, Int(interval.rounded()))
            return HapticPattern(intensity: i, sharpness: s,
                                 mode: .pulsing(onDuration: duration,
                                                offDuration: off,
                                                count: count))
        }
    }
}


extension ParameterSet {
    init?(document data: [String: Any]) {
        guard let intensity = data["intensity"] as? Double,
              let sharpness = data["sharpness"] as? Double,
              let duration = data["duration"] as? Double,
              let interval = data["interval"] as? Double,
              let pattern = data["pattern"] as? String
        else { return nil }
        self.intensity = intensity
        self.sharpness = sharpness
        self.duration = duration
        self.interval = interval
        self.pattern = pattern
        self.phase = data["phase"] as? String ?? "exploration"
        self.phaseStep = data["phaseStep"] as? Int ?? 1
    }

    var asResultFields: [String: Any] {
        [
            "intensity": intensity,
            "sharpness": sharpness,
            "duration": duration,
            "interval": interval,
            "pattern": pattern,
            "phase": phase,
            "phaseStep": phaseStep,
        ]
    }
}
struct PublishedParameters: Equatable {
    let documentID: String
    let values: ParameterSet
}
