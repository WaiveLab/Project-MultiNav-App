//
//  SettingsView.swift
//  Project MultiNav App
//
//  Created by WAIVE lab on 6/12/26.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("hapticIntensity") private var hapticIntensity = 0.75
    @AppStorage("hapticSharpness") private var hapticSharpness = 0.75
    @AppStorage("hapticMode") private var hapticMode = 0

    var body: some View {
        NavigationStack {
            //change to current element selected
            Text("<Current Element Name>")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    //link to SettingsView.swift
                    NavigationLink {
                        ElementSelectionView()
                    } label: {
                        Image(systemName: "list.bullet")
                        Text("Change Element")
                    }
                }
            }
        }
        
        Form {
            Slider(value: $hapticIntensity, in: 0...1) { Text("Intensity") }
            Slider(value: $hapticSharpness, in: 0...1) { Text("Sharpness") }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
