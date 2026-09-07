//
//  SettingsView.swift
//  Project MultiNav App
//
//  Main file - Document management, Customized elements, Double tap, Feedback Policy
//

import SwiftUI
import FirebaseCore
import TactileMapCore
import TactileMapFeedback
import TactileMapLogging
import TactileMapView



@main
struct MyApp: App {

    @StateObject private var session = StudySession()
    let hapticSettings = HapticSettings.shared

    init() {
        FirebaseApp.configure()   
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .environmentObject(hapticSettings)
        }
    }
}



struct RootView: View {
    @EnvironmentObject var session: StudySession
    @EnvironmentObject var hapticSettings: HapticSettings

    var body: some View {
        switch session.phase {
        case .login:
            LoginView()

        case .waitingForParameters:
            WaitingView()

        case .exploring:
            NavigationStack {
                MapScreen()
            }

        case .survey:
            SurveyView { score, attentionPassed, raw in
                session.submit(subjectiveScore: score,
                               attentionCheckPassed: attentionPassed,
                               rawAnswers: raw)
            }

        case .submitting:
            VStack(spacing: 12) {
                ProgressView()
                Text("Uploading your answers…")
            }

        case .error(let message):
            VStack(spacing: 12) {
                Text(message).multilineTextAlignment(.center)
                Button("Retry") { session.retrySurvey() }
                    .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }
}



struct WaitingView: View {
    @EnvironmentObject var session: StudySession
    @State private var showEscapeHatch = false

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text(session.roundNumber == 0
                 ? "Loading your vibration settings…"
                 : "Preparing the next round…")

            if showEscapeHatch, session.current != nil, session.roundNumber > 0 {
                Button("Still waiting — continue with same settings") {
                    session.continueWithCurrentSettings()
                }
                .font(.footnote)
                .accessibilityHint("Starts the next map without waiting for new vibration settings")
            }
        }
        .padding()
        .task {
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            showEscapeHatch = true
        }
    }
}



// MARK: Custom Element Style
struct MapScreen: View {
    @EnvironmentObject var session: StudySession
    @EnvironmentObject var hapticSettings: HapticSettings

    private enum MapPresentation {
        case overview(TactileMapLayer)
        case intersection(overview: TactileMapLayer, base: TactileMapLayer, route: TactileMapLayer)

        var layers: [TactileMapLayer] {
            switch self {
            case .overview(let layer):
                return [layer]
            case .intersection(_, let base, let route):
                // Drawing is bottom-to-top; touches check the route first.
                return [base, route]
            }
        }

        var isZoomed: Bool {
            if case .intersection = self { return true }
            return false
        }
    }

    @State private var presentation: MapPresentation?
    @State private var loadError: String?
    @State private var intersectionLoadError: String?
    @State private var policy = OptimizedSpatialPolicy()

    private var isZoomed: Bool { presentation?.isZoomed ?? false }

    private var config: TactileMapViewConfiguration {
        var config = TactileMapViewConfiguration.default

        config.typeStyles[.start] = ElementStyle(
            color: .systemGreen,
            sizeMM: 8.0,
        )
        config.typeStyles[.onRoute] = ElementStyle(
            color: .systemBlue,
            sizeMM: 4.0,
        )
        config.typeStyles[.offRoute] = ElementStyle(
            color: .systemGray,
            sizeMM: 4.0,
            pointShape: .roundedRect(cornerRadius: 3),
        )
        config.typeStyles[.onRouteIntersection] = ElementStyle(
            color: .systemYellow,
            sizeMM: 6.0,
            pointShape: .roundedRect(cornerRadius: 3),
        )
        config.typeStyles[.offRouteIntersection] = ElementStyle(
            color: .systemGray,
            sizeMM: 6.0,
            pointShape: .roundedRect(cornerRadius: 3),
        )
        config.typeStyles[.end] = ElementStyle(
            color : .systemRed,
            sizeMM: 8.0,
        )
        config.typeStyles[.landmark] = ElementStyle(
            color: .systemYellow,
            sizeMM: 4.0,
        )

        //Intersection specific elements
        config.typeStyles[.street] = ElementStyle(
            color : .systemGray2,
            sizeMM: 10.0,
        )
        config.typeStyles[.offRouteSidewalk] = ElementStyle(
            color : .systemGray,
            sizeMM: 6.0,
        )
        config.typeStyles[.onRouteSidewalk] = ElementStyle(
            color : .systemBlue,
            sizeMM: 6.0,
        )
        config.typeStyles[.offRouteCrosswalk] = ElementStyle(
            color : .systemRed,
            sizeMM: 4.0,
        )
        config.typeStyles[.onRouteCrosswalk] = ElementStyle(
            color : .white,
            sizeMM: 4.0,
        )
        config.typeStyles[.crosswalk] = ElementStyle(
            color: .white,
            sizeMM: 6.0,
        )
        config.typeStyles[.turn] = ElementStyle(
            color: .systemRed,
            sizeMM: 6.0,
            pointShape: .roundedRect(cornerRadius: 3),
        )
        config.typeStyles[.intersectionCenter] = ElementStyle(
            color: .systemGray2,
            sizeMM: 10.0,
        )

        return config
    }

    
    
    // MARK: .json Handling
    var body: some View {
        @AppStorage("participantID") var participantID = ""
        
        VStack(spacing: 0) {
            roundHeader

            if let presentation {
                TactileMapView(
                    layers: presentation.layers,
                    configuration: config,
                    feedbackPolicy: policy,
                    onBackGesture: { handleBackGesture() },
                    onDoubleTap: { element in
                        doubleTap(on: element)
                    }
                )
                .id(presentation.layers.map(\.id))
                .ignoresSafeArea(edges: .horizontal)
            } else {
                Spacer()
                Text(loadError ?? "Loading map…")
                    .multilineTextAlignment(.center)
                    .padding()
                Spacer()
            }

            foundButton
        }
        
        //Toolbar with navigation buttons
        .toolbar {
            if participantID == "0"{
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        MapSwitcherView()
                    } label: {
                        Image(systemName: "map")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                            .environmentObject(hapticSettings)
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Haptic settings")
                }
            }
            
            ToolbarItem(placement: .topBarLeading) {
                if isZoomed {
                    Button(action: returnToOverview) {
                        Label("Back to Overview", systemImage: "arrow.left")
                    }
                }
            }
        }
        .onAppear { loadOverview() }
        .onChange(of: session.currentMapName) { _, _ in loadOverview() }
        .onDisappear { policy.stopAll() }
        .alert("Could not open intersection", isPresented: Binding(
            get: { intersectionLoadError != nil },
            set: { if !$0 { intersectionLoadError = nil } }
        )) {
            Button("OK", role: .cancel) { intersectionLoadError = nil }
        } message: {
            Text(intersectionLoadError ?? "")
        }
    }

    private var roundHeader: some View {
        VStack(spacing: 4) {
            Text("Round \(session.roundNumber)")
                .font(.headline)
            if !session.targetName.isEmpty {
                Text("Find: \(session.targetName)")
                    .font(.title3.bold())
            }
            Text(session.currentMapName)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.thinMaterial)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Round \(session.roundNumber). Your task: find \(session.targetName)")
    }

    private var foundButton: some View {
        Button {
            policy.stopAll()
            session.foundTarget()
        } label: {
            Text("I found the target")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .padding()
        .accessibilityHint("Ends this round and opens the survey")
    }

    private func loadOverview() {
        intersectionLoadError = nil
        policy.parameters = session.current ?? ParameterSet()
        policy.onElementEntered = { [weak session] element in
            session?.elementEntered(name: element.properties.name,
                                    typeRaw: element.elementType.rawValue)
        }
        do {
            let doc = try TactileMapDocument.load(from: session.currentMapName, bundle: .main)
            showMap(.overview(TactileMapLayer(
                id: "overview:\(session.currentMapName)",
                document: doc,
                isInteractable: true
            )))
            loadError = nil
            let target = doc.features.first { $0.elementType == .end }?.properties.name ?? ""
            session.overviewLoaded(targetName: target)
        } catch {
            showMap(nil)
            loadError = "Could not load map \(session.currentMapName): \(error.localizedDescription)"
        }
    }

    //MARK: Double Tap
    ///Zooms into the intersection of interest; double-tapping an end element returns to the overview when zoomed in.
    private func doubleTap(on element: any TactileMapElement) {
        switch element.elementType {
        case .onRouteIntersection:
            if !isZoomed { loadIntersection(named: element.properties.name) }

        case .end:
            returnToOverview()

        default:
            print("\(element) is not able to be double tapped.")
        }
    }

    // MARK: Intersection layers
    /// Loads <name>.json and <overview>__<name>_route.json in the same coordinate space.
    /// Keep the overview visible unless both documents load successfully.
    private func loadIntersection(named name: String) {
        guard case .overview(let overview)? = presentation else { return }
        let overviewName = session.currentMapName
        guard overview.id == "overview:\(overviewName)" else {
            loadOverview()
            return
        }
        intersectionLoadError = nil
        var resourceName = name
        do {
            let base = try TactileMapDocument.load(from: resourceName, bundle: .main)
            resourceName = "\(overviewName)__\(name)_route"
            let route = try TactileMapDocument.load(from: resourceName, bundle: .main)

            // Publish the complete pair together. The cached overview is not rendered.
            showMap(.intersection(
                overview: overview,
                base: TactileMapLayer(id: "intersection-base:\(name)", document: base, isInteractable: true),
                route: TactileMapLayer(id: "intersection-route:\(resourceName)", document: route, isInteractable: true)
            ))
        } catch {
            intersectionLoadError = "Could not load \(resourceName).json: \(error.localizedDescription)"
        }
    }

    private func returnToOverview() {
        guard case .intersection(let overview, _, _)? = presentation else { return }
        showMap(.overview(overview))
        intersectionLoadError = nil
    }

    private func showMap(_ newPresentation: MapPresentation?) {
        // Feedback and active touches belong to the map being left.
        policy.stopAll()
        policy.toneGen.stop()
        presentation = newPresentation
    }

    private func handleBackGesture() {
        returnToOverview()
    }
}



// MARK: Custom Element Types
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
    static let turn = TactileElementType(rawValue: "turn")
    static let intersectionCenter = TactileElementType(rawValue: "intersectionCenter")
}



// MARK: Feedback Policy

/// The round's feedback policy. The ON-ROUTE elements (the path the
/// participant follows most of the time) vibrate with the optimizer's
/// parameter set from Firebase; every other element keeps the shared
/// defaults from `HapticSettings`, so intersections, landmarks, start and
/// end stay distinguishable.
@MainActor
class OptimizedSpatialPolicy: DefaultFeedbackPolicy {
    
    // MARK: Speech config
    let config = SpeechConfiguration(rate: 0.65, volume: 1.0, language: "en-US", pitchMultiplier: 1.0)

    let hapticSettings = HapticSettings.shared
    let toneGen = ToneGenerator()

    /// The parameter set under test. Swapped in at the start of every round.
    var parameters = ParameterSet()

    /// Hook for the session (behavioral measurement — detects when the
    /// finger reaches the round's destination).
    var onElementEntered: ((any TactileMapElement) -> Void)?

    override func onEnter(element: any TactileMapElement, touchType: TouchType) {
        onElementEntered?(element)

        let name = element.properties.name

        switch element.elementType {
        // ── The optimized feedback: on-route path elements ──
        case .onRoute, .onRouteSidewalk:
            hapticEngine.start(pattern: parameters.hapticPattern)
            audioEngine.speak(name, configuration: config)

        // ── Everything else keeps the shared defaults ──
        case .start:
            if let pattern = hapticSettings.patterns[.start] {
                hapticEngine.start(pattern: pattern)
            }
            audioEngine.speak(name, configuration: config)

        case .offRoute:
            if let pattern = hapticSettings.patterns[.offRoute] {
                hapticEngine.start(pattern: pattern)
            }
            audioEngine.speak(name, configuration: config)

        case .onRouteIntersection:
            if let pattern = hapticSettings.patterns[.onRouteIntersection] {
                hapticEngine.start(pattern: pattern)
            }
            audioEngine.speak(name, configuration: config)

        case .offRouteIntersection:
            if let pattern = hapticSettings.patterns[.offRouteIntersection] {
                hapticEngine.start(pattern: pattern)
            }
            audioEngine.speak("This intersection is not on your route.", configuration: config)

        case .landmark:
            if let pattern = hapticSettings.patterns[.landmark] {
                hapticEngine.start(pattern: pattern)
            }
            audioEngine.speak(name, configuration: config)

        case .end:
            if let pattern = hapticSettings.patterns[.end] {
                hapticEngine.start(pattern: pattern)
            }
            audioEngine.speak(name, configuration: config)
//            if isZoomed {
//                audioEngine.speak("Double tap to exit", configuration: config)
//            }

        // ── Zoomed-in view ──
        case .street:
            if let pattern = hapticSettings.patterns[.street] {
                hapticEngine.start(pattern: pattern)
            }

        case .offRouteSidewalk:
            if let pattern = hapticSettings.patterns[.offRouteSidewalk] {
                hapticEngine.start(pattern: pattern)
            }
            audioEngine.speak(name, configuration: config)

        case .onRouteCrosswalk:
            if let pattern = hapticSettings.patterns[.onRouteCrosswalk] {
                hapticEngine.start(pattern: pattern)
            }
            toneGen.playRepeatingTone(frequency: 300, duration: 0.05, interval: 0.50, count: 15)
            audioEngine.speak(name, configuration: config)

        case .offRouteCrosswalk:
            if let pattern = hapticSettings.patterns[.offRouteCrosswalk] {
                hapticEngine.start(pattern: pattern)
            }
            toneGen.playRepeatingTone(frequency: 200, duration: 0.05, interval: 0.17, count: 100)
            audioEngine.speak(name, configuration: config)
            
        case .turn:
            if let pattern = hapticSettings.patterns[.turn] {
                hapticEngine.start(pattern: pattern)
            }
            audioEngine.speak(name, configuration: config)
            
        case .intersectionCenter:
            if let pattern = hapticSettings.patterns[.intersectionCenter] {
                hapticEngine.start(pattern: pattern)
            }
            audioEngine.speak("center", configuration: config)

        ///Unknown element
        default:
            hapticEngine.playSingleTap()
            audioEngine.speak(name, configuration: config)
        }
    }
    
    // Stops the haptic engine and tone generator when the finger exits an element
    override func onExit(element: any TactileMapElement) {
        audioEngine.stopAll()
        hapticEngine.stopAll()
        toneGen.stop()
    }

    /// The optimizer can pick very short durations (0.03–2.0 s). Restart the
    /// pattern while the finger stays on an on-route element so contact
    /// keeps vibrating, matching the reference integration's behavior.
    override func onContinue(element: any TactileMapElement, touchType: TouchType) {
        switch element.elementType {
        case .onRoute, .onRouteSidewalk:
            if !hapticEngine.isPlaying {
                hapticEngine.start(pattern: parameters.hapticPattern)
            }
        default:
            break
        }
    }
}
