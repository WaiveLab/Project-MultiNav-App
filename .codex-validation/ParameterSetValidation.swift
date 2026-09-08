import Foundation

private func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fatalError(message)
    }
}

private func completeDocument() -> [String: Any] {
    var haptics: [String: Any] = [:]
    for element in HapticPat.allCases {
        haptics[element.rawValue] = ParameterSet.defaultHaptics[element]!.asFirestoreFields
    }

    return [
        "schemaVersion": NSNumber(value: 2),
        "candidateId": "participant-round-01-v1",
        "phase": "exploration",
        "phaseStep": NSNumber(value: 1),
        "haptics": haptics,
    ]
}

private func replacing(
    _ document: [String: Any],
    element: HapticPat,
    field: String,
    with value: Any
) -> [String: Any] {
    var result = document
    var haptics = result["haptics"] as! [String: Any]
    var profile = haptics[element.rawValue] as! [String: Any]
    profile[field] = value
    haptics[element.rawValue] = profile
    result["haptics"] = haptics
    return result
}

@main
private struct ParameterSetValidation {
    static func main() {
        let complete = completeDocument()
        let decoded = ParameterSet(document: complete)
        require(decoded != nil, "A complete schema-v2 candidate should decode")
        require(decoded?.haptics.count == 14, "Every candidate must contain 14 profiles")
        require(decoded?.haptics[.onRoute]?.intensity == 1.0, "Profiles must stay independent")
        require(decoded?.haptics[.offRoute]?.intensity == 0.25, "Profiles must stay independent")

        let encoded = decoded!.asResultFields
        require(encoded["hapticMode"] as? String == "burst", "Results must identify burst mode")
        require((encoded["haptics"] as? [String: Any])?.count == 14, "Results must snapshot all profiles")

        var missingProfile = complete
        var missingHaptics = missingProfile["haptics"] as! [String: Any]
        missingHaptics.removeValue(forKey: HapticPat.turn.rawValue)
        missingProfile["haptics"] = missingHaptics
        require(ParameterSet(document: missingProfile) == nil, "An incomplete candidate must fail")

        let invalidProfiles: [(String, Any)] = [
            ("intensity", NSNumber(value: -0.01)),
            ("intensity", NSNumber(value: 1.01)),
            ("sharpness", NSNumber(value: -0.01)),
            ("sharpness", NSNumber(value: 1.01)),
            ("pulseCount", NSNumber(value: 0)),
            ("pulseCount", NSNumber(value: 121)),
            ("pulseCount", NSNumber(value: Int64.max)),
            ("pulseCount", NSNumber(value: 1.5)),
            ("pulseCount", NSNumber(value: true)),
            ("onDuration", NSNumber(value: 0.009)),
            ("onDuration", NSNumber(value: 2.01)),
            ("offDuration", NSNumber(value: 0.0)),
            ("offDuration", NSNumber(value: 2.01)),
        ]
        for (field, value) in invalidProfiles {
            let invalid = replacing(complete, element: .start, field: field, with: value)
            require(ParameterSet(document: invalid) == nil, "Invalid \(field) should fail")
        }

        let excessiveRate = replacing(
            complete,
            element: .start,
            field: "pulseCount",
            with: NSNumber(value: 120)
        )
        require(ParameterSet(document: excessiveRate) == nil, "More than 120 pulses/second should fail")

        var invalidStep = complete
        invalidStep["phaseStep"] = NSNumber(value: 19)
        require(ParameterSet(document: invalidStep) == nil, "Round 19 must fail")

        var wrongPhase = complete
        wrongPhase["phase"] = "survey"
        require(ParameterSet(document: wrongPhase) == nil, "A non-exploration phase must fail")

        var missingPhase = complete
        missingPhase.removeValue(forKey: "phase")
        require(ParameterSet(document: missingPhase) == nil, "A missing phase must fail")

        print("ParameterSet validation passed")
    }
}
