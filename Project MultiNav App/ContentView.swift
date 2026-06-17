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
    
    let hapticSettings = HapticSettings.shared
    
   var body: some Scene {
       WindowGroup {
           NavigationStack {
               MapView()
                   .environmentObject(hapticSettings)
           }
       }
   }
}



struct MapView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var hapticSettings: HapticSettings
    
    //Custom visual appearance
    public var config: TactileMapViewConfiguration {
            var config = TactileMapViewConfiguration.default

            config.typeStyles[.offRoute] = ElementStyle(
                color: .systemGray,
                sizeMM: 4.0,
                pointShape: .roundedRect(cornerRadius: 3),
                showAnchorDot: true
            )

            return config
    }
    
    var body: some View {
        //Load json
        let doc = try! TactileMapDocument.load(from: "street_view", bundle: .main)
        
        //Define what vibration policy to use
        TactileMapView(
            document: doc,
            configuration: config,
            feedbackPolicy: SpatialPolicy(),
            onBackGesture: { dismiss() }
        )
        
        //Set background
        .background()
        .ignoresSafeArea()
        
        //Settings icon
        NavigationStack {
            Text("")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    //link to SettingsView.swift
                    NavigationLink {
                        SettingsView()
                            .environmentObject(hapticSettings)
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
    
    let hapticSettings = HapticSettings.shared
    
    override func onEnter(element: any TactileMapElement, touchType: TouchType) {
        
        let name = element.properties.name

        //Play patterns accordingly
        switch element.elementType {
        case .start:
            let _ = print("__________________\nStart element: \(name)\n__________________")
            if let pattern = hapticSettings.patterns[.start] {
                    hapticEngine.start(pattern: pattern)
            }
            audioEngine.speak(name)
        
        case .onRoute:
            let _ = print("__________________\nonRoute element: \(name)\n__________________")
            if let pattern = hapticSettings.patterns[.onRoute] {
                    hapticEngine.start(pattern: pattern)
            }
            audioEngine.speak(name)
        
        case .offRoute:
            let _ = print("__________________\noffRoute element: \(name)\n__________________")
            if let pattern = hapticSettings.patterns[.offRoute] {
                    hapticEngine.start(pattern: pattern)
            }
            audioEngine.speak(name)

        case .onRouteIntersection:
            let _ = print("__________________\nonRouteIntersection element: \(name)\n__________________")
            if let pattern = hapticSettings.patterns[.onRouteIntersection] {
                    hapticEngine.start(pattern: pattern)
            }
            audioEngine.speak(name)
        
        case .offRouteIntersection:
            let _ = print("__________________\noffRouteIntersection element: \(name)\n__________________")
            if let pattern = hapticSettings.patterns[.offRouteIntersection] {
                    hapticEngine.start(pattern: pattern)
            }
            audioEngine.speak(name)

        case .landmark:
            let _ = print("__________________\nLandmark element: \(name)\n__________________")
            if let pattern = hapticSettings.patterns[.end] {
                    hapticEngine.start(pattern: pattern)
            }
            audioEngine.speak(name)
        
        case .end:
            let _ = print("__________________\nEnd element: \(name)\n__________________")
            if let pattern = hapticSettings.patterns[.end] {
                    hapticEngine.start(pattern: pattern)
            }
            audioEngine.speak(name)

        default:
            // Unknown element type -- provide basic tap + speech.
            let _ = print("__________________\nE: \(name) is an Unknown element type: \(element.elementType)\n__________________")
            hapticEngine.playSingleTap()
            audioEngine.speak(name)
        }
    }
}
