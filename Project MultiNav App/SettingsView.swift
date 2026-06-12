//
//  SettingsView.swift
//  Project MultiNav App
//
//  Created by WAIVE lab on 6/12/26.
//

import SwiftUI
import TactileMapCore
import TactileMapFeedback
import TactileMapLogging
import TactileMapView

enum HapticPat: String, CaseIterable, Identifiable {
    case start
    case onRoute
    case offRoute
    case onRouteIntersection
    case offRouteIntersection
    case landmark
    case end
    
    var id: Self { self }
}

struct SettingsView: View {
    let hapticModes = ["continuous", "pulsing"]
    @State public var intensity: Float = 1.0
    @State public var sharpness: Float = 0.005
    @State public var duration: Double = 0.01
    @State public var onDuration: Double = 0.08
    @State public var offDuration: Double = 0.05
    @State public var pulseCount: Int = 10
    @State public var hapticMode: String = "continuous"
    
    @State public var selectedPattern: HapticPat = .start
    
    @EnvironmentObject var hapticSettings: HapticSettings
    
    private func saveCurrentPattern(_ pattern: HapticPat) {
        let mode: HapticPattern.HapticMode

        if hapticMode == "continuous" {
            mode = .continuous(duration: duration)
        } else {
            mode = .pulsing(
                onDuration: onDuration,
                offDuration: offDuration,
                count: pulseCount
            )
        }

        hapticSettings.patterns[pattern] = HapticPattern(
            intensity: intensity,
            sharpness: sharpness,
            mode: mode
        )
    }

    private func loadPattern(_ pattern: HapticPat) {
        guard let settings = hapticSettings.patterns[pattern] else { return }

        intensity = settings.intensity
        sharpness = settings.sharpness

        switch settings.mode {
        case .continuous(let duration):
            hapticMode = "continuous"
            self.duration = duration

        case .pulsing(let onDuration, let offDuration, let count):
            hapticMode = "pulsing"
            self.onDuration = onDuration
            self.offDuration = offDuration
            self.pulseCount = count
            
        default:
            let _ = print("unhandled")
        }
    }


    var body: some View {
        NavigationStack {
            //change current pattern selected
            Form {
                VStack(alignment: .leading) {
                    Text("Intensity: \(intensity, specifier: "%.2f")")
                    Slider(value: $intensity, in: 0...1)
                    Text("Sharpness: \(sharpness, specifier: "%.2f")")
                    Slider(value: $sharpness, in: 0...1)
                }
                Picker("Haptic Mode", selection: $hapticMode){
                    ForEach(hapticModes, id: \.self) { hapticModes in
                        Text(hapticModes)
                    }
                }
                
                switch hapticMode {
                case "continuous":
                    VStack(alignment: .leading) {
                        Text("Duration (sec): \(duration, specifier: "%.2f")")
                        Slider(value: $duration, in: 0...15)
                    }
                case "pulsing":
                    VStack(alignment: .leading) {
                        Text("On Duration: \(onDuration, specifier: "%.2f")")
                        Slider(value: $onDuration, in: 0...1)
                        Text("Off Duration: \(offDuration, specifier: "%.2f")")
                        Slider(value: $offDuration, in: 0...1)
                        Text("Pulse Count")
                        TextField("Enter a number", value: $pulseCount, format: .number).keyboardType(.numberPad)
                    }
                default:
                    Text("Error")
                }
            }
            Text("")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Picker("Pattern", selection: $selectedPattern){
                        ForEach(HapticPat.allCases) { mode in
                                Text(mode.rawValue.capitalized)
                                    .tag(mode)
                        }
                    }
                    .onChange(of: selectedPattern) { oldPattern, newPattern in
                        saveCurrentPattern(oldPattern)
                        loadPattern(newPattern)
                    }
                }
            }
            
            Text("")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            saveCurrentPattern(selectedPattern)
                        }
                    }
                }
        }
        .onAppear {
            loadPattern(selectedPattern)
        }
    }
}
