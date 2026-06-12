//
//  SettingsView.swift
//  Project MultiNav App
//
//  Created by WAIVE lab on 6/12/26.
//

import SwiftUI

struct SettingsView: View {
    let hapticModes = ["continuous", "pulsing"]
    let hapticPatterns = ["start", "landmarkPattern", "end"]
    
    @AppStorage("hapticPattern") private var hapticPattern: String = "landmarkPattern"
    @AppStorage("hapticIntensity") private var hapticIntensity: Double = 0.75
    @AppStorage("hapticSharpness") private var hapticSharpness: Double = 0.75
    @AppStorage("hapticMode") private var hapticMode: String = "continuous"
    @AppStorage("hapticPulsingOnDuration") private var hapticPulsingOnDuration: Double = 0.2
    @AppStorage("hapticPulsingOffDuration") private var hapticPulsingOffDuration: Double = 0.2
    @AppStorage("hapticPulsingCount") private var hapticPulsingCount: Int = 1
    @AppStorage("hapticContinuousDuration") private var hapticContinuousDuration: Double = 0.5

    var body: some View {
        NavigationStack {
            //change to current element selected
            Text("")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Picker("Pattern", selection: $hapticPattern){
                        ForEach(hapticPatterns, id: \.self) { hapticPatterns in
                            Text(hapticPatterns)
                        }
                    }
                }
            }
        }
        
        Form {
            VStack(alignment: .leading) {
                Text("Intensity: \(hapticIntensity, specifier: "%.2f")")
                Slider(value: $hapticIntensity, in: 0...1)
                Text("Sharpness: \(hapticSharpness, specifier: "%.2f")")
                Slider(value: $hapticSharpness, in: 0...1)
            }
            Picker("Haptic Mode", selection: $hapticMode){
                ForEach(hapticModes, id: \.self) { hapticModes in
                    Text(hapticModes)
                }
            }
            
            switch hapticMode {
            case "continuous":
                VStack(alignment: .leading) {
                    Text("Duration: \(hapticContinuousDuration, specifier: "%.2f")")
                    Slider(value: $hapticContinuousDuration, in: 0...1)
                }
            case "pulsing":
                VStack(alignment: .leading) {
                    Text("On Duration: \(hapticPulsingOnDuration, specifier: "%.2f")")
                    Slider(value: $hapticPulsingOnDuration, in: 0...1)
                    Text("Off Duration: \(hapticPulsingOffDuration, specifier: "%.2f")")
                    Slider(value: $hapticPulsingOffDuration, in: 0...1)
                    Text("Pulse Count")
                    TextField("Enter a number", value: $hapticPulsingCount, format: .number).keyboardType(.numberPad)
                }
            default:
                Text("Error")
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
