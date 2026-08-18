///deticated .swift file to store the default haptic settings

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
        //Overview Elements
        .onRoute: HapticPattern(intensity: 1.0, sharpness: 0.5, mode: .burst(pulseCount: 120, onDuration: 1.00, offDuration: 0.01)),
        .offRoute: HapticPattern(intensity: 0.25, sharpness: 0.25, mode: .burst(pulseCount: 120, onDuration: 1.00, offDuration: 0.01)),
        .onRouteIntersection: HapticPattern(intensity: 0.75, sharpness: 0.25, mode: .burst(pulseCount: 120, onDuration: 1.00, offDuration: 0.01)),
        .offRouteIntersection: HapticPattern(intensity: 0.75, sharpness: 0.25, mode: .burst(pulseCount: 120, onDuration: 1.00, offDuration: 0.01)),
        
        //Intersection elements
        .street: HapticPattern(intensity: 0.33, sharpness: 0.33, mode: .burst(pulseCount: 60, onDuration: 1.00, offDuration: 0.15)),
        .onRouteSidewalk: HapticPattern(intensity: 0.75, sharpness: 1.0, mode: .burst(pulseCount: 60, onDuration: 1.00, offDuration: 0.01)),
        .offRouteSidewalk: HapticPattern(intensity: 0.25, sharpness: 0.25, mode: .burst(pulseCount: 60, onDuration: 1.00, offDuration: 0.01)),
        .onRouteCrosswalk:HapticPattern(intensity: 0.75, sharpness: 1.0, mode: .burst(pulseCount: 60, onDuration: 1.00, offDuration: 0.01)),
        .offRouteCrosswalk: HapticPattern(intensity: 0.25, sharpness: 0.25, mode: .burst(pulseCount: 60, onDuration: 1.00, offDuration: 0.01)),
        
        //All applicaiton elements
        .start: HapticPattern(intensity: 0.75, sharpness: 1.0, mode: .burst(pulseCount: 10, onDuration: 0.25, offDuration: 0.50)),
        .landmark: HapticPattern(intensity: 1.0, sharpness: 0.15, mode: .burst(pulseCount: 60, onDuration: 1.00, offDuration: 0.01)),
        .end: HapticPattern(intensity: 0.75, sharpness: 1.0, mode: .burst(pulseCount: 120, onDuration: 1.00, offDuration: 0.01)),
    ]
}
