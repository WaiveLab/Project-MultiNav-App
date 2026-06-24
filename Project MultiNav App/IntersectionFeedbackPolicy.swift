//
//  IntersectionFeedbackPolicy.swift
//  Project MultiNav App
//
//  Feedback policy for the Intersection Exploration view. Speaks the
//  per-element `audio_label` (from properties.custom) and plays a haptic
//  pattern looked up by element type.
//
//  For this TEST harness the patterns are simple stand-ins. In the real
//  study they come from the shared element/parameter model that SettingsView
//  edits and the MOBO overwrites between trials.
//

import TactileMapCore
import TactileMapFeedback

@MainActor
final class IntersectionFeedbackPolicy: DefaultFeedbackPolicy {

    /// Per-type haptic patterns. Swap this dictionary out for the shared
    /// MOBO-driven model once it exists. Values here are placeholders only.
    var patternsByType: [TactileElementType: HapticPattern] = [
        .route:        .corridorContinuous,
        .street:       .corridorContinuous,
        .sidewalk:     HapticPattern(intensity: 0.6, sharpness: 0.3, mode: .continuous(duration: 100.0)),
        .crosswalk:    HapticPattern(intensity: 1.0, sharpness: 0.7, mode: .pulsing(onDuration: 0.10, offDuration: 0.06, count: 40)),
        .median:       .intersectionPulse,
        .aps:          HapticPattern(intensity: 1.0, sharpness: 1.0, mode: .pulsing(onDuration: 0.05, offDuration: 0.20, count: 20)),
        .landmark:     .landmarkFastPulse,
        .youAreHere:   HapticPattern(intensity: 1.0, sharpness: 0.5, mode: .pulsing(onDuration: 0.20, offDuration: 0.15, count: 10)),
        .destination:  HapticPattern(intensity: 1.0, sharpness: 0.5, mode: .pulsing(onDuration: 0.08, offDuration: 0.05, count: 10))
    ]

    /// Reads the spoken label for an element. Prefers the explicit
    /// `audio_label` in custom properties, falling back to the name.
    private func audioLabel(for element: any TactileMapElement) -> String {
        element.properties.custom["audio_label"] ?? element.properties.name
    }

    override func onEnter(element: any TactileMapElement, touchType: TouchType) {
        let label = audioLabel(for: element)

        if let pattern = patternsByType[element.elementType] {
            hapticEngine.start(pattern: pattern)
            audioEngine.speak(label)
        } else {
            // Unknown type — fall back to the library default behavior.
            super.onEnter(element: element, touchType: touchType)
        }
    }

    override func onExit(element: any TactileMapElement) {
        hapticEngine.stopAll()
    }

    override func onTap(element: any TactileMapElement, touchType: TouchType) {
        hapticEngine.playSingleTap()
        audioEngine.speak(audioLabel(for: element))
    }
}
