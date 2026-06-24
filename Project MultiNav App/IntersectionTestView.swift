//
//  IntersectionTestView.swift
//  Project MultiNav App
//
//  Standalone test harness for the Intersection Exploration view.
//  Loads `intersection_demo.json` and renders it through the Northeastern
//  library's TactileMapView in Canvas mode.
//
//  HOW TO USE
//  1. Add these 3 files to the app target:
//        IntersectionElements.swift
//        IntersectionFeedbackPolicy.swift
//        IntersectionTestView.swift
//  2. Drag intersection_demo.json into your Maps/ folder, "Copy items if
//     needed" checked, app target selected. Confirm it appears under
//     Build Phases > Copy Bundle Resources.
//  3. Point your app entry (or a NavigationLink) at IntersectionTestView(),
//     or just use the #Preview below.
//  4. Run on a PHYSICAL iPhone for haptics/audio (Simulator renders the map
//     but no vibration).
//

import SwiftUI
internal import Combine
import TactileMapCore
import TactileMapFeedback
import TactileMapView

struct IntersectionTestView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var loadError: String?

    // One policy instance for the lifetime of the view.
    @StateObject private var policyBox = PolicyBox()

    var body: some View {
        Group {
            if let doc = loadedDocument {
                TactileMapView(
                    document: doc,
                    configuration: IntersectionMapStyle.configuration(),
                    feedbackPolicy: policyBox.policy,
                    onBackGesture: { dismiss() }
                )
                .ignoresSafeArea()
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "map")
                        .font(.largeTitle)
                    Text("Could not load intersection_demo.json")
                        .font(.headline)
                    if let loadError {
                        Text(loadError)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    Text("Check the file is in Build Phases > Copy Bundle Resources.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
        }
    }

    private var loadedDocument: TactileMapDocument? {
        do {
            return try TactileMapDocument.load(from: "intersection_demo")
        } catch {
            DispatchQueue.main.async { self.loadError = error.localizedDescription }
            return nil
        }
    }
}

/// Holds the feedback policy so it survives view re-renders.
@MainActor
final class PolicyBox: ObservableObject {
    let policy = IntersectionFeedbackPolicy()
}

#Preview {
    IntersectionTestView()
}
