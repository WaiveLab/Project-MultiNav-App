//
//  ContentView.swift
//  Project MultiNav App
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
    
    //Load json
    @State public var document =
        try! TactileMapDocument.load(from: "sparse_civic_blocks", bundle: .main)
    
    //MARK: - Custom visual appearance
    public var config: TactileMapViewConfiguration {
        var config = TactileMapViewConfiguration.default

        //Overview Styles
        config.typeStyles[.start] = ElementStyle(
            color: .systemGreen,
            sizeMM: 10.0,
            showAnchorDot: true
        )
        config.typeStyles[.onRoute] = ElementStyle(
            color: .systemBlue,
            sizeMM: 4.0,
            showAnchorDot: true
        )
        config.typeStyles[.offRoute] = ElementStyle(
            color: .systemGray,
            sizeMM: 4.0,
            pointShape: .roundedRect(cornerRadius: 3),
            showAnchorDot: true
        )
        config.typeStyles[.onRouteIntersection] = ElementStyle(
            color: .systemBlue,
            sizeMM: 10.0,
            showAnchorDot: true
        )
        config.typeStyles[.offRouteIntersection] = ElementStyle(
            color: .systemGray,
            sizeMM: 10.0,
            showAnchorDot: true
        )
        config.typeStyles[.end] = ElementStyle(
            color : .systemRed,
            sizeMM: 10.0,
            showAnchorDot: true
        )
        
        //Zoomed Styles
        config.typeStyles[.street] = ElementStyle(
            color : .systemGray2,
            sizeMM: 20.0,
            showAnchorDot: true
        )
        config.typeStyles[.offRouteSidewalk] = ElementStyle(
            color : .systemGray,
            sizeMM: 8.0,
            showAnchorDot: true
        )
        config.typeStyles[.onRouteSidewalk] = ElementStyle(
            color : .systemBlue,
            sizeMM: 8.0,
            showAnchorDot: true
        )
        config.typeStyles[.offRouteCrosswalk] = ElementStyle(
            color : .systemRed,
            sizeMM: 6.0,
            showAnchorDot: true
        )
        config.typeStyles[.onRouteCrosswalk] = ElementStyle(
            color : .white,
            sizeMM: 6.0,
            showAnchorDot: true
        )

        return config
    }

    //MARK: - Draw Document
    var body: some View {
        ZStack {
            TactileMapView(
                document: document,
                configuration: config,
                feedbackPolicy: SpatialPolicy(),
                onBackGesture: { dismiss() },
                onDoubleTap: { element in
                        doubleTap(on: element)
                }
            )
            .ignoresSafeArea()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SettingsView()
                        .environmentObject(hapticSettings)
                } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
    }
    
    //Handles doubletap feature
    ///Reports doubletapped element to console and goes to the intersection of interest
    private func doubleTap(on element: any TactileMapElement) {
        print("__________________\nDouble tapped:")
        print("  name: \(element.properties.name)")
        print("  type: \(element.elementType)")
        print("  raw: \(element.elementType.rawValue)\n__________________")

        switch element.elementType {
            case .onRouteIntersection:
                zoomIntoIntersection(named: element.properties.name)
            
            default:
                print("That element is not a recognized intersection")
        }
    }

    //Handles zoom feature
    ///updates document and trys to load the new TactileMapDocument
    private func zoomIntoIntersection(named name: String) {
        switch name {
            case "Intersection Between Civic Avenue and Library Street":
                document = try! TactileMapDocument.load(from: "civic_zoom_civic_and_library", bundle: .main )

            default:
                let _ = print("Failed to load document : \(name)")
        }
    }
}


//MARK: - Custom Element Types
extension TactileElementType {
    ///Overview elements:
    static let onRoute = TactileElementType(rawValue: "onRoute")
    static let offRoute = TactileElementType(rawValue: "offRoute")
    static let onRouteIntersection = TactileElementType(rawValue: "onRouteIntersection")
    static let offRouteIntersection = TactileElementType(rawValue: "offRouteIntersection")
    static let start = TactileElementType(rawValue: "start")
    static let end = TactileElementType(rawValue: "end")
    
    ///Zoomed in elements:
    static let street = TactileElementType(rawValue: "street")
    static let onRouteSidewalk = TactileElementType(rawValue: "onRouteSidewalk")
    static let offRouteSidewalk = TactileElementType(rawValue: "offRouteSidewalk")
    static let onRouteCrosswalk = TactileElementType(rawValue: "onRouteCrosswalk")
    static let offRouteCrosswalk = TactileElementType(rawValue: "offRouteCrosswalk")
}


//MARK: - Feedback Policy
@MainActor
class SpatialPolicy: DefaultFeedbackPolicy {
    
    let hapticSettings = HapticSettings.shared
    
    override func onEnter(element: any TactileMapElement, touchType: TouchType) {
        
        let name = element.properties.name

        //Play patterns accordingly
        switch element.elementType {
        ///Overview patterns
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
        
        ///Zoomed
        case .street:
            let _ = print("__________________\nStreet element: \(name)\n__________________")
            
        case .onRouteSidewalk:
            let _ = print("__________________\nonRouteSidewalk element: \(name)\n__________________")
            if let pattern = hapticSettings.patterns[.onRouteSidewalk] {
                    hapticEngine.start(pattern: pattern)
            }
            audioEngine.speak(name)
            
        case .offRouteSidewalk:
            let _ = print("__________________\noffRouteSidewalk element: \(name)\n__________________")
            if let pattern = hapticSettings.patterns[.offRouteSidewalk] {
                    hapticEngine.start(pattern: pattern)
            }
            audioEngine.speak(name)
            
        case .onRouteCrosswalk:
            let _ = print("__________________\nonRouteCrosswalk element: \(name)\n__________________")
            if let pattern = hapticSettings.patterns[.onRouteCrosswalk] {
                    hapticEngine.start(pattern: pattern)
            }
            audioEngine.speak(name)
        
        case .offRouteCrosswalk:
            let _ = print("__________________\noffRouteCrosswalk element: \(name)\n__________________")
            if let pattern = hapticSettings.patterns[.offRouteCrosswalk] {
                    hapticEngine.start(pattern: pattern)
            }
            audioEngine.speak(name)
    
        ///Unkown element
        default:
            // Unknown element type -- provide basic tap + speech.
            let _ = print("__________________\nE: \(name) is an Unknown element type: \(element.elementType)\n__________________")
            hapticEngine.playSingleTap()
            audioEngine.speak(name)
        }
    }
    
}
