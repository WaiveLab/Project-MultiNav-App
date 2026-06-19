//
//  HapticSettings.swift
//  Project MultiNav App
//
//  Created by WAIVE lab on 6/12/26.
//

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
        .start: HapticPattern(intensity: 1.0, sharpness: 0.005, mode: .pulsing(onDuration: 0.08, offDuration: 0.05, count: 10)),
        .onRoute: HapticPattern(intensity: 1.0, sharpness: 0.8, mode: .continuous(duration: 60.0)),
        .offRoute: HapticPattern(intensity: 0.8, sharpness: 0.05, mode: .continuous(duration: 60.0)),
        .onRouteIntersection: HapticPattern(intensity: 1.0, sharpness: 0.15, mode: .pulsing(onDuration: 0.08, offDuration: 0.05, count: 10)),
        .offRouteIntersection: HapticPattern(intensity: 0.8, sharpness: 0.05, mode: .pulsing(onDuration: 0.08, offDuration: 0.05, count: 10)),
        .landmark: HapticPattern(intensity: 1.0, sharpness: 0.15, mode: .continuous(duration: 60.0)),
        .end: HapticPattern(intensity: 1.0, sharpness: 0.9, mode: .continuous(duration: 60.0)),
    ]
}
