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

struct SettingsView: View {
    @State public var intensity: Float = 1.0
    @State public var sharpness: Float = 0.005
    @State public var onDuration: Double = 0.08
    @State public var offDuration: Double = 0.05
    @State public var pulseCount: Int = 10
    
    @State public var selectedPattern: HapticPat = .start
    
    @EnvironmentObject var hapticSettings: HapticSettings
    
    //gets the current pattern settings and saves them accordingly
    private func saveCurrentPattern(_ pattern: HapticPat) {
        let safePulseCount = min(120, max(1, pulseCount))
        let minimumOnDuration = max(0.01, Double(safePulseCount) / 120.0)
        let safeOnDuration = min(2.0, max(minimumOnDuration, onDuration))
        let safeOffDuration = min(2.0, max(0.01, offDuration))

        pulseCount = safePulseCount
        onDuration = safeOnDuration
        offDuration = safeOffDuration

        // All study and preview feedback uses the same mode. The five values
        // remain independent for every selected element type.
        hapticSettings.patterns[pattern] = HapticPattern(
            intensity: intensity,
            sharpness: sharpness,
            mode: .burst(
                pulseCount: safePulseCount,
                onDuration: safeOnDuration,
                offDuration: safeOffDuration
            )
        )
    }

    //loads patterns from HapticSettings
    private func loadPattern(_ pattern: HapticPat) {
        guard let settings = hapticSettings.patterns[pattern] else { return }

        intensity = settings.intensity
        sharpness = settings.sharpness

        switch settings.mode {
        case .continuous(let duration):
            // Convert any legacy preview value into an equivalent burst edit.
            onDuration = min(2.0, max(0.01, duration))
            offDuration = 0.01
            pulseCount = 1

        case .pulsing(let onDuration, let offDuration, let count):
            let safeCount = min(120, max(1, count))
            let minimumOnDuration = max(0.01, Double(safeCount) / 120.0)
            self.onDuration = min(2.0, max(minimumOnDuration, onDuration))
            self.offDuration = min(2.0, max(0.01, offDuration))
            pulseCount = safeCount
            
        case .burst(let pulseCount, let onDuration, let offDuration):
            let safeCount = min(120, max(1, pulseCount))
            let minimumOnDuration = max(0.01, Double(safeCount) / 120.0)
            self.onDuration = min(2.0, max(minimumOnDuration, onDuration))
            self.offDuration = min(2.0, max(0.01, offDuration))
            self.pulseCount = safeCount
            
        default:
            let _ = print("unhandled")
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
                Section("Burst") {
                    VStack(alignment: .leading) {
                        Text("On Duration: \(onDuration, specifier: "%.2f") seconds")
                        Slider(value: $onDuration, in: 0.01...2.0)
                        Text("Off Duration: \(offDuration, specifier: "%.2f") seconds")
                        Slider(value: $offDuration, in: 0.01...2.0)
                        Text("Pulse Count")
                        TextField("Enter a number", value: $pulseCount, format: .number)
                            .keyboardType(.numberPad)
                    }
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
