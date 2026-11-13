// The comments for this .swift file have been annotated by chatGPT

import Foundation
import TactileMapFeedback

// Every feature with the same element type shares one optimizer-controlled
// profile. These raw values must match the map JSON `type` values and the
// keys inside Firestore's `haptics` map.
enum HapticPat: String, CaseIterable, Identifiable {
    case start
    case onRoute
    case offRoute
    case onRouteIntersection
    case offRouteIntersection
    case landmark
    case end

    case street
    case onRouteSidewalk
    case offRouteSidewalk
    case onRouteCrosswalk
    case offRouteCrosswalk
    case turn
    case intersectionCenter

    var id: Self { self }
}

// The five values the optimizer controls for one element type. Playback mode
// is deliberately not a parameter: optimized feedback always uses `.burst`.
struct BurstParameters: Equatable {
    static let pulseCountRange = 1...120
    static let durationRange = 0.01...2.0
    static let maximumPulsesPerSecond = 120.0

    let intensity: Double
    let sharpness: Double
    let pulseCount: Int
    let onDuration: Double
    let offDuration: Double

    init(
        intensity: Double,
        sharpness: Double,
        pulseCount: Int,
        onDuration: Double,
        offDuration: Double
    ) {
        self.intensity = intensity
        self.sharpness = sharpness
        self.pulseCount = pulseCount
        self.onDuration = onDuration
        self.offDuration = offDuration
    }

    var isValid: Bool {
        intensity.isFinite && (0.0...1.0).contains(intensity)
            && sharpness.isFinite && (0.0...1.0).contains(sharpness)
            && Self.pulseCountRange.contains(pulseCount)
            && onDuration.isFinite && Self.durationRange.contains(onDuration)
            && Double(pulseCount) <= onDuration * Self.maximumPulsesPerSecond
            && offDuration.isFinite && Self.durationRange.contains(offDuration)
    }

    var hapticPattern: HapticPattern {
        HapticPattern(
            intensity: Float(intensity),
            sharpness: Float(sharpness),
            mode: .burst(
                pulseCount: pulseCount,
                onDuration: onDuration,
                offDuration: offDuration
            )
        )
    }

    init?(document data: [String: Any]) {
        guard Set(data.keys) == Set([
                "intensity", "sharpness", "pulseCount", "onDuration", "offDuration"
              ]),
              let intensity = FirestoreNumber.double(data["intensity"]),
              let sharpness = FirestoreNumber.double(data["sharpness"]),
              let pulseCount = FirestoreNumber.integer(
                data["pulseCount"],
                in: Self.pulseCountRange
              ),
              let onDuration = FirestoreNumber.double(data["onDuration"]),
              let offDuration = FirestoreNumber.double(data["offDuration"])
        else { return nil }

        self.init(
            intensity: intensity,
            sharpness: sharpness,
            pulseCount: pulseCount,
            onDuration: onDuration,
            offDuration: offDuration
        )

        guard isValid else { return nil }
    }

    var asFirestoreFields: [String: Any] {
        [
            "intensity": intensity,
            "sharpness": sharpness,
            "pulseCount": pulseCount,
            "onDuration": onDuration,
            "offDuration": offDuration,
        ]
    }
}

// One atomic optimizer candidate. A valid remote candidate contains an
// independent burst profile for every supported element type.
struct ParameterSet: Equatable {
    static let currentSchemaVersion = 2
    static let phaseStepRange = 1...17

    let schemaVersion: Int
    let candidateID: String?
    let haptics: [HapticPat: BurstParameters]
    let phase: String
    let phaseStep: Int

    // Local defaults are available for previews/development. Firestore
    // documents do not receive these defaults: their haptics map must be
    // complete and valid or the whole document is rejected.
    init() {
        schemaVersion = Self.currentSchemaVersion
        candidateID = nil
        haptics = Self.defaultHaptics
        phase = "exploration"
        phaseStep = 1
    }

    init?(
        haptics: [HapticPat: BurstParameters],
        candidateID: String? = nil,
        phase: String = "exploration",
        phaseStep: Int = 1
    ) {
        guard haptics.count == HapticPat.allCases.count,
              HapticPat.allCases.allSatisfy({ haptics[$0]?.isValid == true }),
              Self.phaseStepRange.contains(phaseStep)
        else { return nil }

        if let candidateID {
            guard !candidateID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { return nil }
        }

        schemaVersion = Self.currentSchemaVersion
        self.candidateID = candidateID
        self.haptics = haptics
        self.phase = phase
        self.phaseStep = phaseStep
    }

    func burstParameters(for element: HapticPat) -> BurstParameters {
        // Both constructors guarantee that all HapticPat cases are present.
        haptics[element]!
    }

    func hapticPattern(for element: HapticPat) -> HapticPattern {
        burstParameters(for: element).hapticPattern
    }
}

// Handles converting parameter data to and from Firestore dictionary format.
extension ParameterSet {
    init?(document data: [String: Any]) {
        guard FirestoreNumber.integer(
                data["schemaVersion"],
                in: Self.currentSchemaVersion...Self.currentSchemaVersion
              ) == Self.currentSchemaVersion,
              let rawHaptics = data["haptics"] as? [String: Any],
              Set(rawHaptics.keys) == Set(HapticPat.allCases.map(\.rawValue))
        else { return nil }

        var decodedHaptics: [HapticPat: BurstParameters] = [:]
        decodedHaptics.reserveCapacity(HapticPat.allCases.count)

        for element in HapticPat.allCases {
            guard let rawProfile = rawHaptics[element.rawValue] as? [String: Any],
                  let profile = BurstParameters(document: rawProfile)
            else { return nil }

            decodedHaptics[element] = profile
        }

        guard let candidateID = data["candidateId"] as? String,
              !candidateID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return nil }

        // Schema version 2 currently represents the map-exploration phase
        // only. Reject a missing or different phase instead of silently
        // labelling that candidate as an exploration result later.
        guard let phase = data["phase"] as? String,
              phase == "exploration"
        else { return nil }

        guard let rawPhaseStep = data["phaseStep"],
              let phaseStep = FirestoreNumber.integer(
                rawPhaseStep,
                in: Self.phaseStepRange
              )
        else { return nil }

        guard let decoded = ParameterSet(
            haptics: decodedHaptics,
            candidateID: candidateID,
            phase: phase,
            phaseStep: phaseStep
        ) else { return nil }

        self = decoded
    }

    var asResultFields: [String: Any] {
        var encodedHaptics: [String: Any] = [:]
        encodedHaptics.reserveCapacity(HapticPat.allCases.count)

        for element in HapticPat.allCases {
            encodedHaptics[element.rawValue] = burstParameters(for: element).asFirestoreFields
        }

        var fields: [String: Any] = [
            "schemaVersion": schemaVersion,
            "hapticMode": "burst",
            "haptics": encodedHaptics,
            "phase": phase,
            "phaseStep": phaseStep,
        ]

        if let candidateID {
            fields["candidateId"] = candidateID
        }

        return fields
    }
}

// Firestore exposes integer and floating-point values through NSNumber. These
// helpers accept either representation, reject booleans/non-finite values,
// and require values used as Int to be mathematically integral.
private enum FirestoreNumber {
    static func double(_ rawValue: Any?) -> Double? {
        guard let number = rawValue as? NSNumber else { return nil }

        // Firestore normally bridges booleans to Swift Bool, but NSNumber can
        // also carry Objective-C boolean encodings. Never accept those as 0/1.
        let objectiveCType = String(cString: number.objCType)
        guard objectiveCType != "c", objectiveCType != "B" else { return nil }

        let value = number.doubleValue
        return value.isFinite ? value : nil
    }

    static func integer(
        _ rawValue: Any?,
        in validRange: ClosedRange<Int>
    ) -> Int? {
        guard let value = double(rawValue),
              value.rounded(.towardZero) == value,
              value >= Double(validRange.lowerBound),
              value <= Double(validRange.upperBound)
        else { return nil }

        return Int(value)
    }
}

extension ParameterSet {
    // Offline snapshot of parameterValues/001_step_1. The learning map uses
    // these same fourteen profiles for every participant.
    static let learning = ParameterSet(haptics: [
        .start: .init(intensity: 0.75, sharpness: 1, pulseCount: 10, onDuration: 0.25, offDuration: 0.5),
        .onRoute: .init(intensity: 1, sharpness: 0.5, pulseCount: 120, onDuration: 1, offDuration: 0.01),
        .offRoute: .init(intensity: 0.25, sharpness: 0.25, pulseCount: 120, onDuration: 1, offDuration: 0.01),
        .onRouteIntersection: .init(intensity: 0.75, sharpness: 0.25, pulseCount: 15, onDuration: 0.25, offDuration: 0.05),
        .offRouteIntersection: .init(intensity: 0.75, sharpness: 0.25, pulseCount: 120, onDuration: 1, offDuration: 0.01),
        .landmark: .init(intensity: 1, sharpness: 0.15, pulseCount: 60, onDuration: 1, offDuration: 0.01),
        .end: .init(intensity: 0.75, sharpness: 1, pulseCount: 120, onDuration: 1, offDuration: 0.01),
        .street: .init(intensity: 0.33, sharpness: 0.33, pulseCount: 60, onDuration: 1, offDuration: 0.15),
        .onRouteSidewalk: .init(intensity: 0.75, sharpness: 1, pulseCount: 60, onDuration: 1, offDuration: 0.01),
        .offRouteSidewalk: .init(intensity: 0.25, sharpness: 0.25, pulseCount: 60, onDuration: 1, offDuration: 0.01),
        .onRouteCrosswalk: .init(intensity: 0.75, sharpness: 1, pulseCount: 60, onDuration: 1, offDuration: 0.01),
        .offRouteCrosswalk: .init(intensity: 0.25, sharpness: 0.25, pulseCount: 60, onDuration: 1, offDuration: 0.01),
        .turn: .init(intensity: 0.25, sharpness: 0.25, pulseCount: 60, onDuration: 1, offDuration: 0.01),
        .intersectionCenter: .init(intensity: 0.25, sharpness: 0.25, pulseCount: 60, onDuration: 1, offDuration: 0.01),
    ])!

    // Palani, Fink & Giudice, Experiment 5 (p. 1405). The line stimulus was
    // continuous at 250 Hz and full power. Burst playback emits transients,
    // so use its densest train and shortest rest. Sharpness is an app choice.
    private static let line = BurstParameters(
        intensity: 1, sharpness: 0.5, pulseCount: 120, onDuration: 1, offDuration: 0.01
    )
    // One transient every 20 ms approximates the onset timing of the study's
    // 10 ms wide-band pulse. Core Haptics determines the transient waveform.
    private static let marker = BurstParameters(
        intensity: 1, sharpness: 0.5, pulseCount: 1, onDuration: 0.01, offDuration: 0.01
    )

    static let defaultHaptics: [HapticPat: BurstParameters] = [
        .onRoute: line, .offRoute: line, .street: line,
        .onRouteSidewalk: line, .offRouteSidewalk: line,
        .onRouteCrosswalk: line, .offRouteCrosswalk: line,
        .start: marker, .end: marker, .turn: marker, .landmark: marker,
        .onRouteIntersection: marker, .offRouteIntersection: marker, .intersectionCenter: marker,
    ]
}

// Associates a set of parameters with the document they belong to.
struct PublishedParameters: Equatable {
    let documentID: String
    let values: ParameterSet
}
