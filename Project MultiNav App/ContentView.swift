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



@main
struct MyApp: App {
   var body: some Scene {
       WindowGroup {
           NavigationStack {
               MapView()
           }
       }
   }
}



struct MapView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        //load json
        let doc = try! TactileMapDocument.load(from: "street_view", bundle: .main)
        
        TactileMapView(
            document: doc,
            feedbackPolicy: SpatialPolicy(),
            onBackGesture: { dismiss() }
        )
        
        //Set background
        .background(Image("Background").resizable().scaledToFill())
        .ignoresSafeArea()
        .navigationTitle("DCIH to Hampton Inn")
    }
}



extension TactileElementType {
    static let street = TactileElementType(rawValue: "street")
    static let start = TactileElementType(rawValue: "start")
    static let end = TactileElementType(rawValue: "end")
}



@MainActor
class SpatialPolicy: DefaultFeedbackPolicy {
    override func onEnter(element: any TactileMapElement, touchType: TouchType) {
        
        //declare custom patterns
        let landmarkPattern = HapticPattern(intensity: 1.0, sharpness: 1.0, mode: .pulsing(onDuration: 0.05, offDuration: 0.05, count: 5))
        let onRouteStreetPattern = HapticPattern(intensity: 1.0, sharpness: 0.5, mode: .pulsing(onDuration: 0.10, offDuration: 0.01, count: 15))
        let onRouteIntersectionPattern = HapticPattern(intensity: 0.5, sharpness: 0.1, mode: .continuous(duration: 100.0))
        
        let name = element.properties.name

        //Play patterns accordingly
        switch element.elementType {
            case .start:
                let _ = print("__________________\nStart element: \(name)\n__________________")
                audioEngine.speak(name)
            
            case .street:
                let _ = print("__________________\nStreet element: \(name)\n__________________")
                hapticEngine.start(pattern: onRouteStreetPattern)
                audioEngine.speak(name)

            case .intersection:
                let _ = print("__________________\nIntersection element: \(name)\n__________________")
                hapticEngine.start(pattern: .intersectionPulse)
                audioEngine.speak(name)

            case .landmark:
                let _ = print("__________________\nLandmark element: \(name)\n__________________")
                hapticEngine.start(pattern: .landmarkFastPulse)
                audioEngine.playClickSound()
                audioEngine.speak(name)

            default:
                // Unknown element type -- provide basic tap + speech.
                let _ = print("__________________\nE: Unknown element type: \(element.elementType)\n__________________")
                hapticEngine.playSingleTap()
                audioEngine.speak(name)
        }
    }
}



#Preview {
    MapView()
}
