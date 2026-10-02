import Foundation

func close(_ actual: Double, _ expected: Double) {
    precondition(abs(actual - expected) < 0.000001, "\(actual) != \(expected)")
}

for badLoad in ["", "0", "22", "1.5", "abc", "999999999999999999999999"] {
    precondition(SurveyResponse(cognitiveLoad: badLoad, clarity: 3, likability: 3, comfort: 3) == nil)
}
for invalid: Int? in [nil, 0, 6] {
    precondition(SurveyResponse(cognitiveLoad: "11", clarity: invalid, likability: 3, comfort: 3) == nil)
    precondition(SurveyResponse(cognitiveLoad: "11", clarity: 3, likability: invalid, comfort: 3) == nil)
    precondition(SurveyResponse(cognitiveLoad: "11", clarity: 3, likability: 3, comfort: invalid) == nil)
}
let best = SurveyResponse(cognitiveLoad: " 1 ", clarity: 5, likability: 5, comfort: 5)!
let worst = SurveyResponse(cognitiveLoad: "21", clarity: 1, likability: 1, comfort: 1)!
let middle = SurveyResponse(cognitiveLoad: "11", clarity: 3, likability: 3, comfort: 3)!
close(best.subjectiveScore, 1)
close(worst.subjectiveScore, 0)
close(middle.subjectiveScore, 0.5)
close(SurveyResponse(cognitiveLoad: "1", clarity: 1, likability: 1, comfort: 1)!.subjectiveScore, 0.25)
precondition(best.rawAnswers["q_cognitive_load"] as? Int == 1)
precondition(best.rawAnswers["questionnaireVersion"] as? Int == 2)
precondition(best.rawAnswers["q_attention"] == nil)

let defaultsBefore = ParameterSet.defaultHaptics
let practice = ParameterSet(haptics: ParameterSet.practiceHaptics)!
for type: HapticPat in [.onRoute, .start, .end, .onRouteIntersection, .offRouteIntersection,
                       .onRouteSidewalk, .onRouteCrosswalk, .turn, .intersectionCenter] {
    close(practice.burstParameters(for: type).intensity, 1)
    precondition(practice.burstParameters(for: type).isValid)
    precondition(practice.burstParameters(for: type).pulseCount == defaultsBefore[type]!.pulseCount)
}
precondition(defaultsBefore == ParameterSet.defaultHaptics, "Practice must not mutate study defaults")
var remoteProfiles = defaultsBefore
remoteProfiles[.onRoute] = BurstParameters(intensity: 0.4, sharpness: 0.5, pulseCount: 10,
                                         onDuration: 0.25, offDuration: 0.5)
let remote = ParameterSet(haptics: remoteProfiles)!
close(remote.burstParameters(for: .onRoute).intensity, 0.4)

// Decode real study resources, check every route segment and fit/hit-test math.
let maps = URL(fileURLWithPath: CommandLine.arguments[1])
let files = try FileManager.default.contentsOfDirectory(at: maps.appendingPathComponent("overviews"),
                                                       includingPropertiesForKeys: nil)
for file in files where file.pathExtension == "json" {
    let doc = try JSONDecoder().decode(TactileMapDocument.self, from: Data(contentsOf: file))
    let layers = [TactileMapLayer(document: doc)]
    let size = CGSize(width: 375, height: 650)
    let original = canvasTransform(for: layers, size: size, padding: 8)
    let fitted = canvasTransform(for: layers, size: size, padding: 36, fitsFeatures: true)
    precondition(fitted.scale > original.scale)
    let detector = CanvasHitDetector(config: .default)
    for feature in doc.features {
        let coordinates: [TactileCoordinate]
        switch feature.geometry {
        case .point(let point): coordinates = [point]
        case .lineString(let points), .polygon(let points): coordinates = points
        }
        for coordinate in coordinates {
            let point = fitted.apply(coordinate)
            precondition(point.x >= 35.99 && point.x <= size.width - 35.99)
            precondition(point.y >= 35.99 && point.y <= size.height - 35.99)
        }
        if feature.elementType.rawValue == "onRoute" {
            close(Double(remote.hapticPattern(for: .onRoute).intensity), 0.4)
            let mid = TactileCoordinate(x: (coordinates[0].x + coordinates[1].x) / 2,
                                        y: (coordinates[0].y + coordinates[1].y) / 2)
            let hit = detector.findElement(at: fitted.apply(mid), elements: doc.features,
                transform: fitted, velocity: 0, anchorCenter: { _, _ in nil })
            precondition(hit?.element.id == feature.id, "Expanded map hit test must match the drawn route")
        }
    }
}
let empty = canvasTransform(for: [], size: .zero, padding: 36, fitsFeatures: true)
precondition(empty.scale.isFinite && empty.scale > 0)
print("Passed survey validation/scoring, practice isolation, route intensity, map fitting and hit detection for all 17 maps.")
