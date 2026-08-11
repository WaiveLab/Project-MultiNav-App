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


struct MapScreen: View {
    @EnvironmentObject var session: StudySession
    @EnvironmentObject var hapticSettings: HapticSettings

    @State private var document: TactileMapDocument?
    @State private var isZoomed = false
    @State private var loadError: String?
    @State private var policy = OptimizedSpatialPolicy()

    private var config: TactileMapViewConfiguration {
        var config = TactileMapViewConfiguration.default

        config.typeStyles[.start] = ElementStyle(
            color: .systemGreen,
            sizeMM: 10.0,
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
            color: .systemBlue,
            sizeMM: 10.0,
        )
        config.typeStyles[.offRouteIntersection] = ElementStyle(
            color: .systemGray,
            sizeMM: 10.0,
        )
        config.typeStyles[.end] = ElementStyle(
            color : .systemRed,
            sizeMM: 10.0,
        )
        config.typeStyles[.landmark] = ElementStyle(
            color: .systemYellow,
            sizeMM: 4.0,
        )

        config.typeStyles[.street] = ElementStyle(
            color : .systemGray2,
            sizeMM: 20.0,
        )
        config.typeStyles[.offRouteSidewalk] = ElementStyle(
            color : .systemGray,
            sizeMM: 8.0,
        )
        config.typeStyles[.onRouteSidewalk] = ElementStyle(
            color : .systemBlue,
            sizeMM: 8.0,
        )
        config.typeStyles[.offRouteCrosswalk] = ElementStyle(
            color : .systemRed,
            sizeMM: 8.0,
        )
        config.typeStyles[.onRouteCrosswalk] = ElementStyle(
            color : .white,
            sizeMM: 8.0,
        )

        return config
    }

    var body: some View {
        VStack(spacing: 0) {
            roundHeader

            if let document {
                TactileMapView(
                    document: document,
                    configuration: config,
                    feedbackPolicy: policy,
                    onBackGesture: { handleBackGesture() },
                    onDoubleTap: { element in
                        doubleTap(on: element)
                    }
                )
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
        .toolbar {
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
        .onAppear { loadOverview() }
        .onChange(of: session.currentMapName) { _, _ in loadOverview() }
        .onDisappear { policy.stopAll() }
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
        policy.parameters = session.current ?? ParameterSet()
        policy.onElementEntered = { [weak session] element in
            session?.elementEntered(name: element.properties.name,
                                    typeRaw: element.elementType.rawValue)
        }
        do {
            let doc = try TactileMapDocument.load(from: session.currentMapName, bundle: .main)
            document = doc
            isZoomed = false
            loadError = nil
            let target = doc.features.first { $0.elementType == .end }?.properties.name ?? ""
            session.overviewLoaded(targetName: target)
        } catch {
            document = nil
            loadError = "Could not load map \(session.currentMapName): \(error.localizedDescription)"
        }
    }

    //MARK: - Double Tap
    ///Zooms into the intersection of interest; double-tap elsewhere returns
    ///to the overview when zoomed in.
    private func doubleTap(on element: any TactileMapElement) {
        switch element.elementType {
        case .onRouteIntersection:
            zoomIntoIntersection(named: element.properties.name)

        case .end:
            zoomIntoIntersection(named: element.properties.name)

        default:
            if isZoomed { loadOverview() }
        }
    }

    ///Updates document and tries to load the new TactileMapDocument
    private func zoomIntoIntersection(named name: String) {
        do {
            document = try TactileMapDocument.load(from: "\(name)", bundle: .main)
            isZoomed = true
        } catch {
            print("\(name) does not have a json file to load")
        }
    }

    private func handleBackGesture() {
        if isZoomed { loadOverview() }
    }
}


// MARK: - Custom Element Types

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


// MARK: - Feedback Policy

/// The round's feedback policy. The ON-ROUTE elements (the path the
/// participant follows most of the time) vibrate with the optimizer's
/// parameter set from Firebase; every other element keeps the shared
/// defaults from `HapticSettings`, so intersections, landmarks, start and
/// end stay distinguishable.
@MainActor
class OptimizedSpatialPolicy: DefaultFeedbackPolicy {

    let hapticSettings = HapticSettings.shared

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
            audioEngine.speak(name)

        // ── Everything else keeps the shared defaults ──
        case .start:
            if let pattern = hapticSettings.patterns[.start] {
                hapticEngine.start(pattern: pattern)
            }
            audioEngine.speak(name)

        case .offRoute:
            if let pattern = hapticSettings.patterns[.offRoute] {
                hapticEngine.start(pattern: pattern)
            }
            audioEngine.speak(name)

        case .onRouteIntersection:
            if let pattern = hapticSettings.patterns[.onRouteIntersection] {
                hapticEngine.start(pattern: pattern)
            }
            audioEngine.speak(name)

        case .offRouteIntersection:
            if let pattern = hapticSettings.patterns[.offRouteIntersection] {
                hapticEngine.start(pattern: pattern)
            }
            audioEngine.speak(name)

        case .landmark:
            if let pattern = hapticSettings.patterns[.landmark] {
                hapticEngine.start(pattern: pattern)
            }
            audioEngine.speak(name)

        case .end:
            if let pattern = hapticSettings.patterns[.end] {
                hapticEngine.start(pattern: pattern)
            }
            audioEngine.speak(name)

        // ── Zoomed-in view ──
        case .street:
            if let pattern = hapticSettings.patterns[.street] {
                hapticEngine.start(pattern: pattern)
            }

        case .offRouteSidewalk:
            if let pattern = hapticSettings.patterns[.offRouteSidewalk] {
                hapticEngine.start(pattern: pattern)
            }
            audioEngine.speak(name)

        case .onRouteCrosswalk:
            if let pattern = hapticSettings.patterns[.onRouteCrosswalk] {
                hapticEngine.start(pattern: pattern)
            }
            audioEngine.speak(name)

        case .offRouteCrosswalk:
            if let pattern = hapticSettings.patterns[.offRouteCrosswalk] {
                hapticEngine.start(pattern: pattern)
            }
            audioEngine.speak(name)

        ///Unknown element
        default:
            hapticEngine.playSingleTap()
            audioEngine.speak(name)
        }
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
