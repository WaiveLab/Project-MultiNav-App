// Appended to the extracted policy file to exercise its private touch adapter.
@main
@MainActor
struct AudioPolicyTests {
    static func element(_ type: HapticPat) -> MapElement {
        MapElement(id: type.rawValue, elementType: TactileElementType(rawValue: type.rawValue),
                   geometry: .point(TactileCoordinate(x: 0, y: 0)),
                   properties: TactileProperties(name: type.rawValue + " example"))
    }

    static func main() {
        let audio = RecordingAudio()
        let haptics = RecordingHaptics()
        let policy = OptimizedSpatialPolicy(hapticEngine: haptics, audioEngine: audio)
        let touch = ExplorationTouchFeedback(policy: policy)
        var entries = 0
        policy.onElementEntered = { _ in entries += 1 }

        for type in HapticPat.allCases {
            let cue = element(type)
            let oldEvents = audio.events.count
            touch.onEnter(element: cue, touchType: .direct)
            precondition(audio.events.count == oldEvents + 2)
            precondition(audio.events[oldEvents] == "stop", "New entry must interrupt before speaking")
            precondition(audio.current != nil, "Every study cue, including street, should speak")
            precondition(haptics.isPlaying)
            let events = audio.events
            let tones = policy.toneGen.starts

            // A continuing touch may restart haptics, never speech or tone sequences.
            haptics.stopAll()
            for _ in 0..<10 { touch.onContinue(element: cue, touchType: .direct) }
            precondition(haptics.isPlaying)
            precondition(audio.events == events && policy.toneGen.starts == tones)

            // Sliding into blank space and the package's subsequent finger-lift
            // stopAll callback must both leave the current audio running.
            touch.onExit(element: cue)
            precondition(!haptics.isPlaying && audio.current != nil)
            touch.stopAll()
            precondition(audio.events == events && audio.current != nil)

            // Natural speech completion does not start another utterance.
            audio.current = nil
            for _ in 0..<10 { touch.onContinue(element: cue, touchType: .direct) }
            precondition(audio.events == events && audio.current == nil)
        }
        precondition(entries == HapticPat.allCases.count)
        precondition(policy.toneGen.counts.allSatisfy { $0 > 0 }, "Crosswalk patterns must be finite")

        let crossing = element(.onRouteCrosswalk)
        touch.onEnter(element: crossing, touchType: .direct)
        touch.onExit(element: crossing)
        touch.stopAll()
        precondition(policy.toneGen.currentFrequency == 300)
        let street = element(.street)
        touch.onEnter(element: street, touchType: .direct)
        precondition(policy.toneGen.currentFrequency == nil)
        precondition(audio.current == "street example")

        // Explicit tap replaces the preceding cue without an extra haptic start.
        touch.onEnter(element: crossing, touchType: .direct)
        let starts = haptics.starts
        touch.onTap(element: street, touchType: .direct)
        precondition(policy.toneGen.currentFrequency == nil && audio.current == "street example")
        precondition(haptics.starts == starts)

        // Screen/map exits retain the real stop-everything behavior.
        touch.onEnter(element: crossing, touchType: .direct)
        policy.stopAll()
        precondition(audio.current == nil && policy.toneGen.currentFrequency == nil && !haptics.isPlaying)
        print("Passed audio policy: all 14 cues, exit/lift persistence, no automatic replay, interruption, haptics and map-exit cleanup.")
    }
}
