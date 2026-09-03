// The comments for this .swift file have been annotated by chatGPT

import Foundation
import TactileMapFeedback

// Stores the parameters used to control haptic feedback.
struct ParameterSet: Equatable {
    var intensity: Double = 0.5
    var sharpness: Double = 0.5
    var duration: Double = 0.2
    var interval: Double = 10.0
    var pattern: String = "puls"
    var phase: String = "exploration"
    var phaseStep: Int = 1
}

// Converts the parameters into a HapticPattern used by the feedback system.
extension ParameterSet {
    var hapticPattern: HapticPattern {
        let i = Float(intensity)
        let s = Float(sharpness)

        // Calculates the on/off timing and number of pulses.
        //
        // Every element vibrates with the same pulsing shape, so there is no
        // mode to select between. Burst spreads `pulseCount` taps evenly across
        // `onDuration`, so a window of `duration` seconds carrying
        // `interval * duration` taps places one tap every 1/interval seconds:
        // `interval` is the tap rate in Hz and `duration` is how long each
        // burst lasts. The short off-duration keeps the loop running while the
        // finger rests on the element, matching the defaults in HapticSettings.
        let window = max(0.03, duration)
        let count = max(1, Int((max(interval, 0.1) * window).rounded()))
        return HapticPattern(intensity: i, sharpness: s,
                             mode: .burst(pulseCount: count,
                                          onDuration: window,
                                          offDuration: 0.01))
    }
}

// Handles converting parameter data to and from dictionary format.
extension ParameterSet {
    // Creates parameters from data loaded from a document.
    init?(document data: [String: Any]) {
        guard let intensity = Self.double(data["intensity"]),
              let sharpness = Self.double(data["sharpness"]),
              let duration = Self.double(data["duration"]),
              let interval = Self.double(data["interval"])
        else { return nil }

        self.intensity = intensity
        self.sharpness = sharpness
        self.duration = duration
        self.interval = interval
        // Carried through to the results for the optimizer's bookkeeping, but
        // no longer used to choose a vibration shape. Optional, so a document
        // that has dropped the field still parses instead of being discarded.
        self.pattern = data["pattern"] as? String ?? "puls"
        self.phase = data["phase"] as? String ?? "exploration"
        self.phaseStep = Self.int(data["phaseStep"]) ?? 1
    }

    /// Firestore returns numbers as `NSNumber`, so a field written as `1`
    /// instead of `1.0` can arrive as an integer. A plain `as? Double` cast on
    /// that fails, which discards the entire parameter document - and the app
    /// cannot tell that apart from no parameters arriving at all. Accept any
    /// numeric representation instead.
    private static func double(_ value: Any?) -> Double? {
        switch value {
        case let d as Double:   return d
        case let i as Int:      return Double(i)
        case let n as NSNumber: return n.doubleValue
        case let s as String:   return Double(s)
        default:                return nil
        }
    }

    private static func int(_ value: Any?) -> Int? {
        switch value {
        case let i as Int:      return i
        case let d as Double:   return Int(d)
        case let n as NSNumber: return n.intValue
        case let s as String:   return Int(s)
        default:                return nil
        }
    }

    // Converts the parameters back into dictionary form for saving/results.
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

// Associates a set of parameters with the document they belong to.
struct PublishedParameters: Equatable {
    let documentID: String
    let values: ParameterSet
}
