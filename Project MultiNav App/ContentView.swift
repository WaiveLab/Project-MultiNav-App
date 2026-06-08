//
//  ContentView.swift
//  delete me
//
//  Created by WAIVE lab on 6/4/26.
//

import SwiftUI
import TactileMapCore
import TactileMapFeedback
import TactileMapLogging
import TactileMapView

struct ContentView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        //load json
        let doc = try! TactileMapDocument.load(from: "street_view", bundle: .main)
        
        TactileMapView(
            document: doc,
            feedbackPolicy: DefaultFeedbackPolicy(),
            onBackGesture: { dismiss() }
        )
        
        //Set background
        .background(Image("Background").resizable().scaledToFill())
        .ignoresSafeArea()
        .navigationTitle("DCIH to Hampton Inn")
    }
}

@MainActor
final class Policy: FeedbackPolicy {
    
    //Set up and initilize the haptic engine
    private let hapticEngine: HapticEngine
    private let audioEngine: SpatialAudioEngine
    public init(hapticEngine: HapticEngine, audioEngine: SpatialAudioEngine) {
        self.hapticEngine = hapticEngine
        self.audioEngine = audioEngine
    }
    public convenience init() {
        self.init(
            hapticEngine: CoreHapticsEngine(),
            audioEngine: AVSpatialAudioEngine()
        )
    }
    
    //Parameters for entering an element
    func onEnter(element: any TactileMapElement, touchType: TouchType) {
        //Delcare custom haptic patterns
        let landmarkPattern = HapticPattern(intensity: 1.0, sharpness: 1.0, mode: .pulsing(onDuration: 0.05, offDuration: 0.05, count: 5))
        let onRouteStreetPattern = HapticPattern(intensity: 0.1, sharpness: 0.5, mode: .continuous(duration: 100.0))
        let onRouteIntersectionPattern = HapticPattern(intensity: 0.5, sharpness: 0.1, mode: .continuous(duration: 100.0))
        
        //play custom haptic patterns per element type
        let name = element.properties.name
        
        switch element.elementType {
        case .corridor:
            hapticEngine.start(pattern: onRouteStreetPattern)

        case .intersection:
            hapticEngine.start(pattern: .intersectionPulse)
            audioEngine.speak(name)

        case .landmark:
            hapticEngine.start(pattern: .landmarkFastPulse)
            audioEngine.playClickSound()
            audioEngine.speak(name)

        default:
            // Unknown element type -- provide basic tap + speech.
            hapticEngine.playSingleTap()
            audioEngine.speak(name)
        }
    }

    //
    func onContinue(element: any TactileMapElement, touchType: TouchType) {}

    //
    func onExit(element: any TactileMapElement) {
    }

    //
    func onTap(element: any TactileMapElement, touchType: TouchType) {
    }

    //
    func stopAll() {
    }
}

#Preview {
    ContentView()
}
