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
        //Load json
        let doc = try! TactileMapDocument.load(from: "street_view", bundle: .main)
        
        //Custom visual appearance
        let config = TactileMapViewConfiguration(
            backgroundColor: .clear,
            corridorColor: .systemBlue,
        )
        
        //Define what vibration policy to use
        TactileMapView(
            document: doc,
            configuration: config,
            feedbackPolicy: SpatialPolicy(),
            onBackGesture: { dismiss() }
        )
        
        //Set background
        .background(Image("Background").resizable().scaledToFill())
        .ignoresSafeArea()
        
        //Settings icon
        NavigationStack {
            Text("")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    //link to SettingsView.swift
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
    }
}


//Custom element types are defined here
extension TactileElementType {
    static let onRoute = TactileElementType(rawValue: "onRoute")
    static let offRoute = TactileElementType(rawValue: "offRoute")
    static let onRouteIntersection = TactileElementType(rawValue: "onRouteIntersection")
    static let offRouteIntersection = TactileElementType(rawValue: "offRouteIntersection")
    static let start = TactileElementType(rawValue: "start")
    static let end = TactileElementType(rawValue: "end")
}


//Custom vibration parameters
@MainActor
class SpatialPolicy: DefaultFeedbackPolicy {
    override func onEnter(element: any TactileMapElement, touchType: TouchType) {
        
        //declare custom patterns
        //let start = HapticPattern(intensity: <#T##Float#>, sharpness: <#T##Float#>, mode: <#T##HapticPattern.HapticMode#>)
        let test = HapticPattern(intensity: 1.0, sharpness: 0.005, mode: .continuous(duration: 0.01))
        var landmarkPattern = HapticPattern(intensity: 1.0, sharpness: 1.0, mode: .pulsing(onDuration: 0.05, offDuration: 0.05, count: 5))
        let onRouteStreetPattern = HapticPattern(intensity: 1.0, sharpness: 0.5, mode: .pulsing(onDuration: 0.08, offDuration: 0.05, count: 15))
        let offRouteStreetPattern = HapticPattern(intensity: 0.0, sharpness: 0.0, mode: .continuous(duration: 0.01))
        let onRouteIntersectionPattern = HapticPattern(intensity: 0.5, sharpness: 0.1, mode: .continuous(duration: 100.0))
        let offRouteIntersectionPattern = HapticPattern(intensity: 0.0, sharpness: 0.0, mode: .continuous(duration: 0.01))
        //let end = HapticPattern(intensity: <#T##Float#>, sharpness: <#T##Float#>, mode: <#T##HapticPattern.HapticMode#>))
        
        let name = element.properties.name

        //Play patterns accordingly
        switch element.elementType {
        case .start:
            let _ = print("__________________\nStart element: \(name)\n__________________")
            audioEngine.speak(name)
        
        case .onRoute:
            let _ = print("__________________\nonRoute element: \(name)\n__________________")
            hapticEngine.start(pattern: onRouteStreetPattern)
            audioEngine.speak(name)
        
        case .offRoute:
            let _ = print("__________________\noffRoute element: \(name)\n__________________")
            hapticEngine.start(pattern: offRouteStreetPattern)
            audioEngine.speak(name)

        case .onRouteIntersection:
            let _ = print("__________________\nonRouteIntersection element: \(name)\n__________________")
            hapticEngine.start(pattern: onRouteIntersectionPattern)
            audioEngine.speak(name)
        
        case .offRouteIntersection:
            let _ = print("__________________\noffRouteIntersection element: \(name)\n__________________")
            hapticEngine.start(pattern: offRouteIntersectionPattern)
            audioEngine.speak(name)

        case .landmark:
            let _ = print("__________________\nLandmark element: \(name)\n__________________")
            hapticEngine.start(pattern: landmarkPattern)
            audioEngine.playClickSound()
            audioEngine.speak(name)
        
        case .end:
            let _ = print("__________________\nEnd element: \(name)\n__________________")
            hapticEngine.start(pattern: test)
            audioEngine.speak(name)

        default:
            // Unknown element type -- provide basic tap + speech.
            let _ = print("__________________\nE: \(name) is an Unknown element type: \(element.elementType)\n__________________")
            hapticEngine.playSingleTap()
            audioEngine.speak(name)
        }
    }
}



#Preview {
    MapView()
}
