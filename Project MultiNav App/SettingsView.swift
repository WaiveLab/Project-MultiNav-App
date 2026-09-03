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
    
    case street
    case onRouteSidewalk
    case offRouteSidewalk
    case onRouteCrosswalk
    case offRouteCrosswalk
    case turn
    case intersectionCenter
    
    var id: Self { self }
}


struct SettingsView: View {
    let hapticModes = ["continuous", "pulsing", "burst"]
    @State public var intensity: Float = 1.0
    @State public var sharpness: Float = 0.005
    @State public var duration: Double = 0.01
    @State public var onDuration: Double = 0.08
    @State public var offDuration: Double = 0.05
    @State public var pulseCount: Int = 10
    @State public var hapticMode: String = "continuous"
    
    @State public var selectedPattern: HapticPat = .start
    
    @EnvironmentObject var hapticSettings: HapticSettings
    
    //gets the current pattern settings and saves them accordingly
    private func saveCurrentPattern(_ pattern: HapticPat) {
        let mode: HapticPattern.HapticMode

        //Checks if the selected mode is continuous, otherwise sets mode to burst
        if hapticMode == "continuous" {
            mode = .continuous(duration: duration)
        } else if hapticMode == "pulsing" {
            mode = .pulsing(
                onDuration: onDuration,
                offDuration: offDuration,
                count: pulseCount
            )
        } else {
            mode = .burst(
                pulseCount: pulseCount,
                onDuration: onDuration,
                offDuration: offDuration
            )
        }

        hapticSettings.patterns[pattern] = HapticPattern(
            intensity: intensity,
            sharpness: sharpness,
            mode: mode
        )
    }

    //loads patterns from HapticSettings
    private func loadPattern(_ pattern: HapticPat) {
        guard let settings = hapticSettings.patterns[pattern] else { return }

        intensity = settings.intensity
        sharpness = settings.sharpness

        switch settings.mode {
        // Every branch assigns all four timing fields. Previously each branch
        // set only the ones its own mode used, so switching between elements
        // left the others holding the previous element's values - and saving
        // then wrote that mixture back.
        case .continuous(let duration):
            hapticMode = "continuous"
            self.duration = duration
            self.onDuration = 0.08
            self.offDuration = 0.05
            self.pulseCount = 10

        case .pulsing(let onDuration, let offDuration, let count):
            hapticMode = "pulsing"
            self.duration = 0.01
            self.onDuration = onDuration
            self.offDuration = offDuration
            self.pulseCount = count

        case .burst(let pulseCount, let onDuration, let offDuration):
            hapticMode = "burst"
            self.duration = 0.01
            self.onDuration = onDuration
            self.offDuration = offDuration
            self.pulseCount = pulseCount

        case .transient:
            // A transient is one instantaneous tap; show it as the shortest
            // possible burst so the form has a coherent mode selected rather
            // than silently keeping the previous element's values.
            hapticMode = "burst"
            self.duration = 0.01
            self.onDuration = 0.08
            self.offDuration = 0.05
            self.pulseCount = 1
        }
    }


    //Settings front-end
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
                case "burst":
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
            // Commit edits as they happen. Previously the only writes were the
            // Save button and the pattern picker, so adjusting a slider and
            // navigating back discarded the change. Re-saving immediately after
            // `loadPattern` is harmless now that it assigns every field: the
            // write simply reproduces the pattern that was just loaded.
            .onChange(of: intensity)   { _, _ in saveCurrentPattern(selectedPattern) }
            .onChange(of: sharpness)   { _, _ in saveCurrentPattern(selectedPattern) }
            .onChange(of: duration)    { _, _ in saveCurrentPattern(selectedPattern) }
            .onChange(of: onDuration)  { _, _ in saveCurrentPattern(selectedPattern) }
            .onChange(of: offDuration) { _, _ in saveCurrentPattern(selectedPattern) }
            .onChange(of: pulseCount)  { _, _ in saveCurrentPattern(selectedPattern) }
            .onChange(of: hapticMode)  { _, _ in saveCurrentPattern(selectedPattern) }
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
