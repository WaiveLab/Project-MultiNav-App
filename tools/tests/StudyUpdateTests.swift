import Foundation

@main
struct StudyUpdateTests {
    static func main() throws {
        try survey()
        performance()
        try haptics()
        try maps(root: URL(fileURLWithPath: CommandLine.arguments[1]))
        print("Passed questionnaire, performance scoring, haptic preservation, spoken cue and map alignment checks.")
    }

    static func performance() {
        precondition(StudyPerformance.objectiveScore(touchedTarget: false, timeToTarget: 5) == 0)
        precondition(StudyPerformance.objectiveScore(touchedTarget: false, timeToTarget: 40) == 0)
        precondition(StudyPerformance.objectiveScore(touchedTarget: true, timeToTarget: nil) == 0)
        for invalid in [-1.0, Double.nan, Double.infinity] {
            precondition(StudyPerformance.objectiveScore(touchedTarget: true, timeToTarget: invalid) == 0)
        }
        for (time, expected) in [(0.0, 1.0), (5, 1), (47.5, 0.5), (90, 0), (120, 0)] {
            precondition(StudyPerformance.objectiveScore(touchedTarget: true, timeToTarget: time) == expected)
        }
    }

    static func survey() throws {
        for invalid in ["", "0", "22", "1.5", "NaN", "abc", "999999999999999999999999"] {
            precondition(SurveyResponse(cognitiveLoad: invalid, clarity: 3, likability: 3, comfort: 3) == nil)
        }
        precondition(SurveyResponse(cognitiveLoad: "11", clarity: nil, likability: 3, comfort: 3) == nil)
        precondition(SurveyResponse(cognitiveLoad: "11", clarity: 3, likability: nil, comfort: 3) == nil)
        precondition(SurveyResponse(cognitiveLoad: "11", clarity: 3, likability: 3, comfort: nil) == nil)
        for invalid in [0, 6] {
            precondition(SurveyResponse(cognitiveLoad: "11", clarity: invalid, likability: 3, comfort: 3) == nil)
            precondition(SurveyResponse(cognitiveLoad: "11", clarity: 3, likability: invalid, comfort: 3) == nil)
            precondition(SurveyResponse(cognitiveLoad: "11", clarity: 3, likability: 3, comfort: invalid) == nil)
        }
        for (load, rating, expected) in [(1, 5, 1.0), (21, 1, 0.0), (11, 3, 0.5)] {
            let response = SurveyResponse(cognitiveLoad: " \(load) ", clarity: rating, likability: rating, comfort: rating)!
            precondition(response.subjectiveScore == expected)
            precondition(Set(response.rawAnswers.keys) == Set([
                "questionnaireVersion", "q_cognitive_load", "q_clear", "q_likability", "q_comfort"
            ]))
            precondition(response.rawAnswers["questionnaireVersion"] as? Int == 2)
        }
        let mixed = SurveyResponse(cognitiveLoad: "6", clarity: 4, likability: 5, comfort: 3)!
        precondition(mixed.subjectiveScore == 0.75)
        for load in 1...21 {
            for rating in 1...5 {
                let response = SurveyResponse(cognitiveLoad: String(load), clarity: rating, likability: rating, comfort: rating)!
                precondition((0...1).contains(response.subjectiveScore))
            }
        }
    }

    static func haptics() throws {
        let defaults = ParameterSet.defaultHaptics
        let practice = PracticeHaptics.profiles
        let maximum: Set<HapticPat> = [.start, .end, .onRoute, .onRouteIntersection,
            .offRouteIntersection, .onRouteSidewalk, .onRouteCrosswalk, .turn, .intersectionCenter]
        precondition(practice.count == 14)
        for type in HapticPat.allCases {
            let old = defaults[type]!, new = practice[type]!
            precondition(new.isValid)
            precondition(new.intensity == (maximum.contains(type) ? 1 : old.intensity))
            precondition(new.sharpness == old.sharpness && new.pulseCount == old.pulseCount)
            precondition(new.onDuration == old.onDuration && new.offDuration == old.offDuration)
        }
        precondition(defaults == ParameterSet.defaultHaptics && defaults == ParameterSet().haptics)
        // Distinct remote values must survive parsing/playback/result serialization,
        // even after local practice profiles have been requested.
        var profiles: [HapticPat: BurstParameters] = [:]
        for (index, type) in HapticPat.allCases.enumerated() {
            profiles[type] = BurstParameters(intensity: Double(index + 1) / 20, sharpness: 0.43,
                                            pulseCount: index + 1, onDuration: 1, offDuration: 0.12)
        }
        let remote = ParameterSet(haptics: profiles, candidateID: "test-remote", phaseStep: 4)!
        let fields = remote.asResultFields
        let parsed = ParameterSet(document: fields)!
        precondition(parsed == remote)
        // The app must reject candidates that Firestore's exact haptic-map
        // rules reject, rather than silently dropping optimizer fields.
        var extraCue = fields
        var extraCueHaptics = fields["haptics"] as! [String: Any]
        extraCueHaptics["unknownCue"] = profiles[.start]!.asFirestoreFields
        extraCue["haptics"] = extraCueHaptics
        precondition(ParameterSet(document: extraCue) == nil)
        var extraField = profiles[.start]!.asFirestoreFields
        extraField["duration"] = 0.2
        precondition(BurstParameters(document: extraField) == nil)
        var missingCue = fields
        var missingCueHaptics = fields["haptics"] as! [String: Any]
        missingCueHaptics.removeValue(forKey: "intersectionCenter")
        missingCue["haptics"] = missingCueHaptics
        precondition(ParameterSet(document: missingCue) == nil)
        let before = try JSONSerialization.data(withJSONObject: fields, options: .sortedKeys)
        let after = try JSONSerialization.data(withJSONObject: parsed.asResultFields, options: .sortedKeys)
        precondition(before == after)
        for type in HapticPat.allCases {
            let pattern = parsed.hapticPattern(for: type), original = profiles[type]!
            precondition(pattern.intensity == Float(original.intensity) && pattern.sharpness == Float(original.sharpness))
            guard case .burst(let count, let on, let off) = pattern.mode else { preconditionFailure("Lost burst mode") }
            precondition(count == original.pulseCount && on == original.onDuration && off == original.offDuration)
        }
    }

    static func coordinates(_ geometry: TactileGeometry) -> [TactileCoordinate] {
        switch geometry {
        case .point(let point): return [point]
        case .lineString(let points), .polygon(let points): return points
        }
    }

    static func checkFit(_ original: [TactileMapLayer]) {
        let fitted = StudyMapLayout.fittedLayers(original)
        precondition(fitted.count == original.count)
        var offset: TactileCoordinate?
        for (before, after) in zip(original, fitted) {
            precondition(before.id == after.id && before.isInteractable == after.isInteractable)
            precondition(before.document.metadata == after.document.metadata)
            precondition(before.document.version == after.document.version)
            precondition(after.document.bounds == fitted[0].document.bounds)
            precondition(before.document.features.count == after.document.features.count)
            for (old, new) in zip(before.document.features, after.document.features) {
                precondition(old.id == new.id && old.elementType == new.elementType && old.properties == new.properties)
                for (a, b) in zip(coordinates(old.geometry), coordinates(new.geometry)) {
                    let delta = TactileCoordinate(x: a.x - b.x, y: a.y - b.y)
                    if let offset { precondition(offset == delta) } else { offset = delta }
                    precondition(b.x >= 0 && b.y >= 0 && b.x <= after.document.bounds.width && b.y <= after.document.bounds.height)
                }
            }
        }
        let points = fitted.flatMap { $0.document.features }.flatMap { coordinates($0.geometry) }
        precondition(points.map(\.x).min() == 0 && points.map(\.y).min() == 0)
        precondition(points.map(\.x).max() == fitted[0].document.bounds.width)
        precondition(points.map(\.y).max() == fitted[0].document.bounds.height)

        // Decoration must leave every touchable document and its order unchanged.
        let decorated = StudyMapLayout.withCrosswalkStripes(fitted)
        let interactive = decorated.filter(\.isInteractable)
        let originalInteractive = fitted.filter(\.isInteractable)
        precondition(interactive.count == originalInteractive.count)
        for (before, after) in zip(originalInteractive, interactive) {
            precondition(before.id == after.id)
            precondition(before.document.features == after.document.features)
            precondition(before.document.bounds == after.document.bounds)
        }
        precondition(decorated.allSatisfy { $0.document.bounds == fitted[0].document.bounds })
        let crossings = fitted.flatMap { $0.document.features }.filter {
            ["onRouteCrosswalk", "offRouteCrosswalk"].contains($0.elementType.rawValue)
        }
        if crossings.isEmpty {
            precondition(decorated.count == fitted.count)
        } else {
            precondition(decorated.count == fitted.count + 1 && !decorated.last!.isInteractable)
            let stripes = decorated.last!.document.features.filter { $0.elementType == .crosswalk }
            for crossing in crossings {
                guard case .lineString(let points) = crossing.geometry else { continue }
                precondition(stripes.filter {
                    $0.geometry == crossing.geometry || $0.geometry == .lineString(Array(points.reversed()))
                }.count == 1)
            }
        }
    }

    static func maps(root: URL) throws {
        func load(_ file: URL) throws -> TactileMapDocument {
            try JSONDecoder().decode(TactileMapDocument.self, from: Data(contentsOf: file))
        }
        let files = try FileManager.default.contentsOfDirectory(at: root.appendingPathComponent("overviews"), includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
        precondition(files.count == 17)
        var overlays = 0
        for file in files {
            let overview = try load(file)
            checkFit([TactileMapLayer(id: "overview", document: overview)])
            for feature in overview.features {
                let type = feature.elementType.rawValue, name = feature.properties.name
                let spoken = StudyMapSpeech.label(type: type, name: name)
                if type == "onRoute" || type == "onRouteIntersection" { precondition(spoken == name + ", route") }
                if type == "start" { precondition(spoken == "Start of route") }
                if type == "end" { precondition(spoken == "End of route") }
                guard type == "onRouteIntersection" else { continue }
                let directory = root.appendingPathComponent("intersection_views")
                let base = try load(directory.appendingPathComponent(name + ".json"))
                let routeName = file.deletingPathExtension().lastPathComponent + "__" + name + "_route.json"
                let route = try load(directory.appendingPathComponent(routeName))
                checkFit([TactileMapLayer(id: "base", document: base), TactileMapLayer(id: "route", document: route)])
                for marker in route.features {
                    let type = marker.elementType.rawValue
                    let speech = StudyMapSpeech.label(type: type, name: marker.properties.name)
                    if type == "start" { precondition(speech.hasPrefix("Start of route from ")) }
                    if type == "end" { precondition(speech.hasPrefix("End of route on ")) }
                    if type == "turn" { precondition(speech == "Turn") }
                }
                overlays += 1
            }
        }
        precondition(overlays == 34)
        precondition(StudyMapLayout.fittedLayers([]).isEmpty)
        precondition(StudyMapLayout.withCrosswalkStripes([]).isEmpty)
        precondition(StudyMapSpeech.label(type: "offRoute", name: "Birch Street") == "Birch Street")
        precondition(StudyMapSpeech.label(type: "landmark", name: "Library") == "Library")
        print("Checked all 17 overviews and 34 base/route pairs using the app's actual layout and speech code.")
    }
}
