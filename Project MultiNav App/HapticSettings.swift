import SwiftUI
import Combine
import TactileMapCore
import TactileMapFeedback
import TactileMapLogging
import TactileMapView


@MainActor
class HapticSettings: ObservableObject {
    
    static let shared = HapticSettings()
    
    @Published var patterns: [HapticPat: HapticPattern] = [
        .start: HapticPattern(intensity: 0.75, sharpness: 1.0, mode: .pulsing(onDuration: 0.25, offDuration: 0.05, count: 5)),
        .onRoute: HapticPattern(intensity: 1.0, sharpness: 0.8, mode: .burst(pulseCount: 3, onDuration: 0.25, offDuration: 1.00)),
        .offRoute: HapticPattern(intensity: 0.25, sharpness: 0.25, mode: .continuous(duration: 60.0)),
        .onRouteIntersection: HapticPattern(intensity: 0.75, sharpness: 1.0, mode: .pulsing(onDuration: 0.05, offDuration: 0.05, count: 5)),
        .offRouteIntersection: HapticPattern(intensity: 0.25, sharpness: 0.05, mode: .pulsing(onDuration: 0.08, offDuration: 0.05, count: 10)),
        .landmark: HapticPattern(intensity: 1.0, sharpness: 0.15, mode: .continuous(duration: 60.0)),
        .end: HapticPattern(intensity: 0.75, sharpness: 1.0, mode: .pulsing(onDuration: 0.25, offDuration: 0.05, count: 5)),
        
        .street: HapticPattern(intensity: 0.33, sharpness: 0.33, mode: .pulsing(onDuration: 0.25, offDuration: 0.05, count: 25)),
        .onRouteSidewalk: HapticPattern(intensity: 0.75, sharpness: 1.0, mode: .continuous(duration: 60.0)),
        .offRouteSidewalk: HapticPattern(intensity: 0.25, sharpness: 0.25, mode: .continuous(duration: 60.0)),
        .onRouteCrosswalk:HapticPattern(intensity: 0.75, sharpness: 1.0, mode: .continuous(duration: 60.0)),
        .offRouteCrosswalk: HapticPattern(intensity: 0.25, sharpness: 0.25, mode: .continuous(duration: 60.0)),
    ]
}
