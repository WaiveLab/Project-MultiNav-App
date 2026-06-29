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
        ///Overview
        .start: HapticPattern(intensity: 0.75, sharpness: 1.0, mode: .pulsing(onDuration: 0.25, offDuration: 0.05, count: 5)),
        .onRoute: HapticPattern(intensity: 0.75, sharpness: 1.0, mode: .continuous(duration: 60.0)),
        .offRoute: HapticPattern(intensity: 0.25, sharpness: 0.05, mode: .continuous(duration: 60.0)),
        .onRouteIntersection: HapticPattern(intensity: 0.75, sharpness: 1.0, mode: .pulsing(onDuration: 0.05, offDuration: 0.05, count: 5)),
        .offRouteIntersection: HapticPattern(intensity: 0.25, sharpness: 0.05, mode: .pulsing(onDuration: 0.08, offDuration: 0.05, count: 10)),
        .landmark: HapticPattern(intensity: 1.0, sharpness: 0.15, mode: .continuous(duration: 60.0)),
        .end: HapticPattern(intensity: 0.75, sharpness: 1.0, mode: .pulsing(onDuration: 0.25, offDuration: 0.05, count: 5)),
        
        ///Zoomed
        .street:HapticPattern(intensity: 0.75, sharpness: 1.0, mode: .pulsing(onDuration: 0.25, offDuration: 0.05, count: 5)),
    ]
}
