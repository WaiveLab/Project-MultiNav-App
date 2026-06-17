//
//  ContentView.swift
//  eMultiNav
//
// Built by Evan Logan 6/3/2026
//

import SwiftUI
import UIKit
import TactileMapCore
import TactileMapFeedback
import TactileMapView
internal import Combine

// MARK: - WAIVE Custom Tactile Element Types

/// Custom line types used by the updated Northeastern renderer.
///
/// Keep this limited to the elements used in the current study prototype.
/// Sidewalk, crosswalk, and APS can be added later once the intersection
/// exploration task is finalized.
extension TactileElementType {
    static let routeRoad = TactileElementType(rawValue: "waive_route_road")
    static let nonRouteRoad = TactileElementType(rawValue: "waive_non_route_road")
}

// MARK: - App Entry

struct ContentView: View {
    var body: some View {
        MultiNavBestPrototypeView()
    }
}

// MARK: - Map Roles + Northeastern HapticPattern Settings

/// App-facing roles used to tag Northeastern MapElement metadata.
/// The map, rendering, hit detection, audio, and haptic playback still come from Northeastern.
enum MapRole: String, CaseIterable, Identifiable, Hashable, Sendable {
    case route = "Best Route"
    case road = "Other Road"
    case intersection = "Intersection"
    case origin = "Start"
    case destination = "Destination"
    case userLocation = "You Are Here"
    case poi = "Point of Interest"
    case offRoute = "Off Route"

    var id: Self { self }

    var storageValue: String {
        switch self {
        case .route: return "route"
        case .road: return "road"
        case .intersection: return "intersection"
        case .origin: return "origin"
        case .destination: return "destination"
        case .userLocation: return "userLocation"
        case .poi: return "poi"
        case .offRoute: return "offRoute"
        }
    }

    var icon: String {
        switch self {
        case .route: return "figure.walk.motion"
        case .road: return "road.lanes"
        case .intersection: return "circle.grid.cross"
        case .origin: return "flag.fill"
        case .destination: return "flag.checkered"
        case .userLocation: return "location.fill"
        case .poi: return "star.fill"
        case .offRoute: return "exclamationmark.triangle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .route: return .blue
        case .road: return .secondary
        case .intersection: return .orange
        case .origin: return .green
        case .destination: return .red
        case .userLocation: return .cyan
        case .poi: return .purple
        case .offRoute: return .yellow
        }
    }

    var compactTitle: String {
        switch self {
        case .route: return "Route"
        case .road: return "Road"
        case .intersection: return "Inter."
        case .origin: return "Start"
        case .destination: return "Dest."
        case .userLocation: return "You"
        case .poi: return "POI"
        case .offRoute: return "Off"
        }
    }

    static func fromStorageValue(_ value: String) -> MapRole? {
        allCases.first { $0.storageValue == value }
    }

    static func from(_ element: any TactileMapElement) -> MapRole {
        if let raw = element.properties.custom["waiveRole"], let role = MapRole.fromStorageValue(raw) {
            return role
        }

        switch element.elementType {
        case .routeRoad:
            return .route
        case .nonRouteRoad, .corridor:
            return .road
        case .intersection:
            return .intersection
        case .landmark:
            return .poi
        default:
            return .poi
        }
    }
}

/// UI-only helper for editing Northeastern's HapticPattern.HapticMode.
/// The saved value is still a Northeastern HapticPattern, not a WAIVE preset model.
enum NortheasternPatternShape: String, CaseIterable, Identifiable, Sendable {
    case continuous = "Continuous"
    case pulsing = "Pulsing"
    case transient = "Tap"

    var id: Self { self }
}

/// Temporary editor state. When the user changes a setting, it is immediately
/// converted back into a Northeastern HapticPattern and stored in `customPatterns`.
struct NortheasternPatternDraft: Sendable {
    var shape: NortheasternPatternShape
    var intensity: Double
    var sharpness: Double
    var duration: Double
    var interval: Double
    var count: Int

    init(pattern: HapticPattern) {
        self.intensity = Double(pattern.intensity)
        self.sharpness = Double(pattern.sharpness)

        switch pattern.mode {
        case .continuous(let duration):
            self.shape = .continuous
            // Northeastern corridor defaults can be very long. For the study UI,
            // keep the editable value in a participant-safe range.
            self.duration = min(max(duration, 0.03), 2.0)
            self.interval = 0.20
            self.count = 8

        case .pulsing(let onDuration, let offDuration, let count):
            self.shape = .pulsing
            self.duration = max(0.03, onDuration)
            self.interval = max(0.1, offDuration)
            self.count = count

        case .transient:
            self.shape = .transient
            self.duration = 0.03
            self.interval = 0.20
            self.count = 1
        }
    }

    var pattern: HapticPattern {
        switch shape {
        case .continuous:
            return HapticPattern(
                intensity: Float(intensity),
                sharpness: Float(sharpness),
                mode: .continuous(duration: max(0.03, duration))
            )

        case .pulsing:
            return HapticPattern(
                intensity: Float(intensity),
                sharpness: Float(sharpness),
                mode: .pulsing(
                    onDuration: max(0.03, duration),
                    offDuration: max(0.1, interval),
                    count: max(1, count)
                )
            )

        case .transient:
            return HapticPattern(
                intensity: Float(intensity),
                sharpness: Float(sharpness),
                mode: .transient
            )
        }
    }
}

/// Northeastern-native haptic defaults. These use Northeastern's built-in
/// HapticPattern values wherever possible.
let defaultNortheasternPatterns: [MapRole: HapticPattern] = [
    .route: .corridorContinuous,
    .road: HapticPattern(intensity: 0.35, sharpness: 0.28, mode: .continuous(duration: 100.0)),
    .intersection: .intersectionPulse,
    .origin: .intersectionPulse,
    .destination: .landmarkFastPulse,
    .userLocation: .intersectionPulse,
    .poi: .landmarkFastPulse,
    .offRoute: .singleTap
]

func northeasternDefaultPattern(for role: MapRole) -> HapticPattern {
    defaultNortheasternPatterns[role] ?? .singleTap
}

// MARK: - Destination Model

enum DemoDestination: String, CaseIterable, Identifiable, Sendable {
    case entrance = "Campus Entrance"
    case studentCenter = "Student Center"
    case busStop = "Bus Stop"
    case park = "Campus Park"
    case parkingLot = "Parking Lot"

    var id: Self { self }

    var nodeID: Int {
        switch self {
        case .entrance: return 0
        case .studentCenter: return 11
        case .busStop: return 6
        case .park: return 15
        case .parkingLot: return 12
        }
    }

    var icon: String {
        switch self {
        case .entrance:
            return "building.columns.fill"

        case .studentCenter:
            return "person.3.fill"

        case .busStop:
            return "bus.fill"

        case .park:
            return "tree.fill"

        case .parkingLot:
            return "parkingsign.circle.fill"
        }
    }

    var subtitle: String {
        switch self {
        case .entrance:
            return "Main campus entrance"

        case .studentCenter:
            return "Student gathering area"

        case .busStop:
            return "Transit pickup location"

        case .park:
            return "Outdoor recreation area"

        case .parkingLot:
            return "Vehicle parking area"
        }
    }
}
// MARK: - Route Preset Model

/// Controlled study trials. Each trial uses the same VAM interaction system
/// but a different simplified outdoor-map topology. The layouts are still
/// schematic, but they better represent common real navigation structures:
/// a square/grid, a T-intersection, a dead end, an offset path, a single road,
/// and loop/branch variants.
enum RoutePreset: String, CaseIterable, Identifiable, Sendable {
    case trial01 = "Trial 01: Square Grid"
    case trial02 = "Trial 02: T-Intersection"
    case trial03 = "Trial 03: Dead End"
    case trial04 = "Trial 04: Offset Path"
    case trial05 = "Trial 05: Single Road"
    case trial06 = "Trial 06: Campus Loop"
    case trial07 = "Trial 07: Park Branch"
    case trial08 = "Trial 08: Transit Branch"
    case trial09 = "Trial 09: Parking Branch"
    case trial10 = "Trial 10: South Connector"

    var id: Self { self }

    var trialNumber: Int {
        (Self.allCases.firstIndex(of: self) ?? 0) + 1
    }

    static var totalTrials: Int {
        Self.allCases.count
    }

    var shortName: String {
        switch self {
        case .trial01: return "T1 Square"
        case .trial02: return "T2 T-Int."
        case .trial03: return "T3 Dead End"
        case .trial04: return "T4 Offset"
        case .trial05: return "T5 Single"
        case .trial06: return "T6 Loop"
        case .trial07: return "T7 Park"
        case .trial08: return "T8 Transit"
        case .trial09: return "T9 Parking"
        case .trial10: return "T10 South"
        }
    }

    var subtitle: String {
        switch self {
        case .trial01:
            return "Baseline square-grid route with multiple non-route roads."
        case .trial02:
            return "T-shaped route with one main decision point and side roads."
        case .trial03:
            return "Dead-end style route with nearby non-route branches."
        case .trial04:
            return "Offset route that requires following staggered intersections."
        case .trial05:
            return "Single-road route with minimal branching."
        case .trial06:
            return "Loop-style route with alternate non-route roads nearby."
        case .trial07:
            return "Branching route toward the park with side paths."
        case .trial08:
            return "Transit-focused route with a nearby alternate branch."
        case .trial09:
            return "Parking route with a branch and a dead-end-like spur."
        case .trial10:
            return "South connector route with several nearby road choices."
        }
    }

    var destination: DemoDestination {
        switch self {
        case .trial01, .trial04, .trial06, .trial10:
            return .studentCenter
        case .trial02, .trial08:
            return .busStop
        case .trial05:
            return .studentCenter
        case .trial03, .trial09:
            return .parkingLot
        case .trial07:
            return .park
        }
    }

    /// Routes are intentionally controlled for study use. Most trials keep
    /// similar route complexity while varying the surrounding topology.
    var routeNodeIDs: [Int] {
        switch self {
        case .trial01:
            return [1, 5, 9, 10, 11]
        case .trial02:
            return [1, 5, 9, 10, 6]
        case .trial03:
            return [1, 5, 9, 13, 12]
        case .trial04:
            return [1, 5, 9, 10, 11]
        case .trial05:
            return [1, 2, 3, 7, 11]
        case .trial06:
            return [1, 2, 3, 7, 11]
        case .trial07:
            return [1, 5, 9, 13, 14, 15]
        case .trial08:
            return [1, 5, 9, 10, 6]
        case .trial09:
            return [1, 5, 9, 13, 12]
        case .trial10:
            return [1, 2, 6, 10, 11]
        }
    }
}

// MARK: - Main State

@MainActor
final class MultiNavPrototypeState: ObservableObject {
    @Published var destination: DemoDestination = .studentCenter
    @Published var routePreset: RoutePreset = .trial01
    @Published var document: TactileMapDocument
    @Published var selectedRole: MapRole = .route
    @Published var selectedElementName: String = "Best route"
    @Published var selectedElementDetail: String = "Drag across the Northeastern tactile map to hear and feel elements."
    @Published var customPatterns: [MapRole: HapticPattern] = defaultNortheasternPatterns
    @Published var showRouteOnly = false
    @Published var selectedIntersectionID: Int? = nil
    @Published private(set) var routeNodeIDs: [Int]

    private var isCurrentlyOffGraph = false
    private var lastOffGraphStatusTime = Date.distantPast

    init() {
        // Randomize the first trial for study use so participants do not all
        // begin with the same route layout. Testers can still choose any trial
        // manually from Settings.
        let startingPreset = RoutePreset.allCases.randomElement() ?? .trial01
        self.routePreset = startingPreset
        self.destination = startingPreset.destination

        let result = MultiNavMapBuilder.makeDocument(
            destination: startingPreset.destination,
            routePreset: startingPreset,
            showRouteOnly: false
        )
        self.document = result.document
        self.routeNodeIDs = result.routeNodeIDs
    }

    var routeSummary: String {
        guard routeNodeIDs.count > 1 else { return "No route available" }
        return routeNodeIDs.map(String.init).joined(separator: " → ")
    }

    var estimatedSteps: Int {
        max(1, (routeNodeIDs.count - 1) * 18)
    }

    var progressText: String {
        "\(routePreset.rawValue) to \(destination.rawValue): \(routeNodeIDs.count - 1) segments • about \(estimatedSteps) steps"
    }

    func setDestination(_ newDestination: DemoDestination) {
        destination = newDestination
        rebuildRoute()
    }

    func setRoutePreset(_ newPreset: RoutePreset) {
        routePreset = newPreset
        destination = newPreset.destination
        rebuildRoute()
    }

    func toggleRouteOnly() {
        showRouteOnly.toggle()
        rebuildRoute()
    }

    func updateTouchedElement(_ element: any TactileMapElement, touchType: TouchType) {
        let role = MapRole.from(element)
        selectedRole = role
        selectedElementName = element.properties.name
        selectedIntersectionID = Self.intersectionID(from: element)

        let routeNote = element.properties.custom["routeStep"] ?? ""
        let touchNote = touchType == .anchor ? "Anchor point" : "Direct touch"
        let category = element.properties.category ?? element.elementType.rawValue

        let actionHint = role == .intersection
            ? "Keep holding to zoom. Double tap for haptic settings."
            : "Double tap for haptic settings."

        if routeNote.isEmpty {
            selectedElementDetail = "\(touchNote) • \(category.capitalized) • \(actionHint)"
        } else {
            selectedElementDetail = "\(touchNote) • \(category.capitalized) • \(routeNote) • \(actionHint)"
        }
    }

    func clearTouchedElement() {
        isCurrentlyOffGraph = false
        selectedIntersectionID = nil
        selectedElementDetail = "Touch lifted. Continue exploring the map."
    }

    /// Called by a lightweight SwiftUI drag gesture on top of the Northeastern map.
    /// Northeastern still owns map rendering/hit detection for real map elements;
    /// this only detects when the finger is not close to any graph element.
    @discardableResult
    func updateOffGraphStatusIfNeeded(location: CGPoint, in viewSize: CGSize) -> Bool {
        let role = MultiNavMapGeometry.role(
            atViewPoint: location,
            in: viewSize,
            routeNodeIDs: routeNodeIDs,
            destination: destination,
            routePreset: routePreset,
            showRouteOnly: showRouteOnly
        )

        if role == .offRoute {
            // Only announce/trigger off-graph once when the user first leaves the graph.
            // The cooldown prevents duplicate "Off graph" speech when SwiftUI and
            // Northeastern hit detection both update during the same drag transition.
            let now = Date()
            if !isCurrentlyOffGraph {
                isCurrentlyOffGraph = true
                selectedRole = .offRoute
                selectedElementName = "Off graph"
                selectedIntersectionID = nil
                selectedElementDetail = "Move back to a road, route segment, intersection, or landmark."

                guard now.timeIntervalSince(lastOffGraphStatusTime) > 1.0 else { return false }
                lastOffGraphStatusTime = now
                return true
            }
        } else {
            isCurrentlyOffGraph = false
        }

        return false
    }

    func resetHaptics() {
        customPatterns = defaultNortheasternPatterns
    }

    func resetHaptic(for role: MapRole, preserving shape: NortheasternPatternShape) {
        // Reset only the selected element type while preserving the pattern type
        // the user is currently editing. Example: if Off Route is being edited as
        // Continuous, Reset returns its values to a safe default but stays Continuous
        // instead of jumping back to Northeastern's default Tap pattern.
        var draft = NortheasternPatternDraft(pattern: northeasternDefaultPattern(for: role))
        draft.shape = shape

        switch shape {
        case .continuous:
            draft.duration = max(0.1, min(draft.duration, 2.0))
            draft.interval = 0.2
            draft.count = 8
        case .pulsing:
            draft.duration = max(0.1, min(draft.duration, 1.0))
            draft.interval = max(0.1, min(draft.interval, 1.0))
            draft.count = max(1, min(draft.count, 120))
        case .transient:
            draft.duration = 0.03
            draft.interval = 0.2
            draft.count = 1
        }

        customPatterns[role] = draft.pattern
    }

    func selectRoleForSettings(_ role: MapRole) {
        selectedRole = role
        selectedElementName = role.rawValue
        selectedIntersectionID = nil
        selectedElementDetail = "Editing haptics for \(role.rawValue)."
    }

    private func rebuildRoute() {
        let result = MultiNavMapBuilder.makeDocument(
            destination: destination,
            routePreset: routePreset,
            showRouteOnly: showRouteOnly
        )

        document = result.document
        routeNodeIDs = result.routeNodeIDs
        isCurrentlyOffGraph = false
        selectedElementName = "\(routePreset.rawValue) to \(destination.rawValue)"
        selectedRole = .route
        selectedIntersectionID = nil
        selectedElementDetail = progressText
    }

    private static func intersectionID(from element: any TactileMapElement) -> Int? {
        guard element.elementType == .intersection else { return nil }
        let rawID = element.id.replacingOccurrences(of: "intersection_", with: "")
        return Int(rawID)
    }
}

// MARK: - Feedback Policy using Northeastern engines

@MainActor
final class MultiNavPrototypeFeedbackPolicy: FeedbackPolicy {
    private let hapticEngine: any HapticEngine
    private let audioEngine: any SpatialAudioEngine
    private let getPatterns: () -> [MapRole: HapticPattern]
    private let onTouch: (any TactileMapElement, TouchType) -> Void
    private let onLift: () -> Void
    private var lastOffGraphSpokenAt = Date.distantPast
    private var lastSpokenElementID: String?
    private var lastSpokenPhrase: String?
    private var lastSpokenAt = Date.distantPast
    private var pendingActionHintWorkItem: DispatchWorkItem?

    init(
        getPatterns: @escaping () -> [MapRole: HapticPattern],
        onTouch: @escaping (any TactileMapElement, TouchType) -> Void,
        onLift: @escaping () -> Void
    ) {
        self.hapticEngine = CoreHapticsEngine()
        self.audioEngine = AVSpatialAudioEngine()
        self.getPatterns = getPatterns
        self.onTouch = onTouch
        self.onLift = onLift
    }

    func onEnter(element: any TactileMapElement, touchType: TouchType) {
        onTouch(element, touchType)
        let role = MapRole.from(element)

        if let pattern = getPatterns()[role] {
            hapticEngine.start(pattern: pattern)
        } else {
            playNortheasternDefault(for: element)
        }

        // Keep speech short during drag exploration. Route roads should not say
        // "Best route" twice. The corridor name is only the road name; this layer
        // adds the semantic role once.
        pendingActionHintWorkItem?.cancel()

        let spokenPhrase: String
        switch role {
        case .route:
            spokenPhrase = "Best route, \(element.properties.name)"
        case .road:
            spokenPhrase = element.properties.name
        case .intersection:
            spokenPhrase = "Intersection. Hold to zoom. Double tap for settings."
        case .destination:
            spokenPhrase = "Destination, \(element.properties.name)"
        case .userLocation:
            spokenPhrase = "You are here"
        case .poi:
            spokenPhrase = element.properties.name
        case .origin:
            spokenPhrase = "Start"
        case .offRoute:
            spokenPhrase = "Off graph"
        }

        let shouldSpeakName = role != .road || touchType == .anchor
        if shouldSpeakName {
            let now = Date()
            if lastSpokenPhrase != spokenPhrase || now.timeIntervalSince(lastSpokenAt) > 1.8 {
                audioEngine.speak(spokenPhrase)
                lastSpokenElementID = element.id
                lastSpokenPhrase = spokenPhrase
                lastSpokenAt = now
            }
        }
    }

    func onContinue(element: any TactileMapElement, touchType: TouchType) {
        onTouch(element, touchType)
    }

    func onExit(element: any TactileMapElement) {
        pendingActionHintWorkItem?.cancel()
        hapticEngine.stopAll()
        onLift()
    }

    func onTap(element: any TactileMapElement, touchType: TouchType) {
        onTouch(element, touchType)
        hapticEngine.playSingleTap()
        audioEngine.speak(element.properties.name)
    }

    func playOffGraphWarning() {
        hapticEngine.start(pattern: getPatterns()[.offRoute] ?? .singleTap)

        let now = Date()
        guard now.timeIntervalSince(lastOffGraphSpokenAt) > 1.0 else { return }
        lastOffGraphSpokenAt = now
        audioEngine.speak("Off graph")
    }

    func stopAll() {
        pendingActionHintWorkItem?.cancel()
        hapticEngine.stopAll()
        audioEngine.stopAll()
        lastSpokenElementID = nil
        lastSpokenPhrase = nil
        onLift()
    }

    private func playNortheasternDefault(for element: any TactileMapElement) {
        switch element.elementType {
        case .routeRoad, .nonRouteRoad, .corridor:
            hapticEngine.start(pattern: .corridorContinuous)
        case .intersection:
            hapticEngine.start(pattern: .intersectionPulse)
        case .landmark:
            hapticEngine.start(pattern: .landmarkFastPulse)
            audioEngine.playClickSound()
        default:
            hapticEngine.playSingleTap()
        }
    }
}

// MARK: - Main Prototype View

struct MultiNavBestPrototypeView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var state = MultiNavPrototypeState()
    @State private var feedbackPolicy: MultiNavPrototypeFeedbackPolicy?
    @State private var showSettings = false
    @State private var showIntersectionZoom = false
    @State private var zoomIntersectionID: Int? = nil
    @State private var settingsStartRole: MapRole = .route
    @State private var pendingZoomIntersectionID: Int? = nil
    @State private var pendingZoomWorkItem: DispatchWorkItem? = nil

    var body: some View {
        ZStack {
            background

            VStack(spacing: 8) {
                header

                // Phase 1 study simplification:
                // Destination presets are intentionally hidden for now.
                // Keep `destinationCarousel` available for future demos.
                // destinationCarousel

                mapCard
                compactStatusBar
                bottomBar
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)
            .padding(.bottom, 6)
        }
        .task { createFeedbackPolicyIfNeeded() }
        .sheet(isPresented: $showSettings, onDismiss: {
            feedbackPolicy?.stopAll()
            state.clearTouchedElement()
        }) {
            HapticSettingsView(state: state, initialRole: settingsStartRole)
        }
        .sheet(isPresented: $showIntersectionZoom, onDismiss: {
            // Defensive stop in case any main-map haptic was still active
            // while the zoom sheet was being presented or dismissed.
            feedbackPolicy?.stopAll()
            state.clearTouchedElement()
        }) {
            if let zoomIntersectionID {
                IntersectionZoomView(
                    intersectionID: zoomIntersectionID,
                    routeNodeIDs: state.routeNodeIDs,
                    destination: state.destination,
                    routePreset: state.routePreset,
                    customPatterns: state.customPatterns
                )
            }
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [
                Color(.systemBackground),
                Color.blue.opacity(0.08),
                Color.purple.opacity(0.06)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(.blue.gradient)
                    .frame(width: 42, height: 42)
                Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("WAIVE MultiNav")
                    .font(.title.weight(.black))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text("Outdoor route built with Northeastern tactile-map blocks")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
    }

    private var destinationCarousel: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Choose Destination", systemImage: "mappin.and.ellipse")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(state.progressText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(DemoDestination.allCases) { destination in
                        DestinationChip(
                            destination: destination,
                            isSelected: state.destination == destination
                        ) {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                                state.setDestination(destination)
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private var mapCard: some View {
        VStack(spacing: 6) {
            HStack {
                Label("Outdoor Route Map", systemImage: "map.fill")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                RouteBadge(text: "Trial \(state.routePreset.trialNumber) of \(RoutePreset.totalTrials) • \(state.routeNodeIDs.count - 1) seg")
            }
            .padding(.horizontal, 4)

            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 28)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.12), radius: 18, x: 0, y: 10)

                if let feedbackPolicy {
                    GeometryReader { mapGeometry in
                        TactileMapView(
                            document: state.document,
                            configuration: .multiNavPremium,
                            feedbackPolicy: feedbackPolicy,
                            hitDetection: .multiNavForgiving,
                            coordinateTransform: .default,
                            onBackGesture: { dismiss() }
                        )
                        .id("map-\(state.destination.rawValue)-\(state.routePreset.rawValue)-\(state.showRouteOnly)")
                        .accessibilityLabel("Outdoor tactile route map")
                        .accessibilityHint("Drag to explore, double tap to edit haptics, or hold on an intersection to zoom in.")
                        .simultaneousGesture(
                            TapGesture(count: 2)
                                .onEnded {
                                    settingsStartRole = state.selectedRole
                                    feedbackPolicy.stopAll()
                                    state.selectRoleForSettings(state.selectedRole)
                                    showSettings = true
                                }
                        )
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    if state.updateOffGraphStatusIfNeeded(location: value.location, in: mapGeometry.size) {
                                        feedbackPolicy.playOffGraphWarning()
                                    }

                                    if let intersectionID = MultiNavMapGeometry.routeIntersectionID(
                                        atViewPoint: value.location,
                                        in: mapGeometry.size,
                                        routeNodeIDs: state.routeNodeIDs
                                    ) {
                                        scheduleZoomFromContinuousTouch(intersectionID, feedbackPolicy: feedbackPolicy)
                                    } else {
                                        cancelPendingZoom()
                                    }
                                }
                                .onEnded { _ in
                                    cancelPendingZoom()
                                    feedbackPolicy.stopAll()
                                    state.clearTouchedElement()

                                    // Extra defensive stop for continuous/pulsing patterns.
                                    // Some Core Haptics players can continue briefly if the
                                    // gesture ends before TactileMapView receives onExit.
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                        feedbackPolicy.stopAll()
                                    }
                                }
                        )
                        .simultaneousGesture(
                            LongPressGesture(minimumDuration: 2.5)
                                .onEnded { _ in
                                    if let intersectionID = state.selectedIntersectionID {
                                        // Important: opening the zoom sheet can prevent
                                        // TactileMapView from receiving a normal onExit callback.
                                        // Stop the main-map haptics before presenting zoom so
                                        // intersection/route vibrations do not continue underneath.
                                        cancelPendingZoom()
                                        feedbackPolicy.stopAll()
                                        state.clearTouchedElement()
                                        zoomIntersectionID = intersectionID
                                        showIntersectionZoom = true
                                    }
                                }
                        )

                        RouteClarityOverlay(
                            routeNodeIDs: state.routeNodeIDs,
                            destination: state.destination,
                            routePreset: state.routePreset,
                            showRouteOnly: state.showRouteOnly
                        )
                        .allowsHitTesting(false)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 28))

                } else {
                    ProgressView("Preparing tactile map…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // Route Focus toggle is intentionally hidden for the current study.
                // It may be useful later for development/demo mode, so the
                // `showRouteOnly` state and `toggleRouteOnly()` logic are preserved.
                /*
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        state.toggleRouteOnly()
                    }
                } label: {
                    Label(state.showRouteOnly ? "Show All" : "Route Focus", systemImage: state.showRouteOnly ? "rectangle.grid.2x2" : "scope")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(12)
                */
            }
            .frame(height: 500)
        }
    }

    private var compactStatusBar: some View {
        HStack(spacing: 10) {
            Image(systemName: state.selectedRole.icon)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(state.selectedRole.tint)
                .frame(width: 28, height: 28)
                .background(state.selectedRole.tint.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(state.selectedElementName)
                    .font(.subheadline.weight(.bold))
                    .lineLimit(1)
                Text(state.selectedElementDetail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Current element: \(state.selectedElementName)")
        .accessibilityHint(state.selectedElementDetail)
    }

    private var bottomBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "hand.tap.fill")
                .foregroundStyle(.blue)
            Text("Drag to explore. Keep holding on an intersection to zoom. Double tap to edit haptics")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Map instructions")
        .accessibilityHint("Drag to explore. Keep holding on an intersection to zoom. Double tap to edit haptics.")
    }

    private func scheduleZoomFromContinuousTouch(_ intersectionID: Int, feedbackPolicy: MultiNavPrototypeFeedbackPolicy) {
        guard !showIntersectionZoom else { return }
        guard pendingZoomIntersectionID != intersectionID else { return }

        cancelPendingZoom()
        pendingZoomIntersectionID = intersectionID

        let workItem = DispatchWorkItem {
            guard pendingZoomIntersectionID == intersectionID, !showIntersectionZoom else { return }
            feedbackPolicy.stopAll()
            state.clearTouchedElement()
            zoomIntersectionID = intersectionID
            showIntersectionZoom = true
            cancelPendingZoom()
        }

        pendingZoomWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: workItem)
    }

    private func cancelPendingZoom() {
        pendingZoomWorkItem?.cancel()
        pendingZoomWorkItem = nil
        pendingZoomIntersectionID = nil
    }

    private func createFeedbackPolicyIfNeeded() {
        guard feedbackPolicy == nil else { return }
        feedbackPolicy = MultiNavPrototypeFeedbackPolicy(
            getPatterns: { state.customPatterns },
            onTouch: { element, touchType in
                state.updateTouchedElement(element, touchType: touchType)
            },
            onLift: {
                state.clearTouchedElement()
            }
        )
    }
}

// MARK: - Off-Graph Detection Geometry

enum MultiNavMapGeometry {
    static let mapWidth: CGFloat = 390
    static let mapHeight: CGFloat = 450
    static let canvasPadding: CGFloat = 18

    static let nodes: [Int: CGPoint] = [
        0: CGPoint(x: 55, y: 70),   1: CGPoint(x: 55, y: 160),  2: CGPoint(x: 55, y: 260),  3: CGPoint(x: 55, y: 365),
        4: CGPoint(x: 150, y: 70),  5: CGPoint(x: 150, y: 160), 6: CGPoint(x: 150, y: 260), 7: CGPoint(x: 150, y: 365),
        8: CGPoint(x: 245, y: 70),  9: CGPoint(x: 245, y: 160), 10: CGPoint(x: 245, y: 260), 11: CGPoint(x: 245, y: 365),
        12: CGPoint(x: 335, y: 70), 13: CGPoint(x: 335, y: 160), 14: CGPoint(x: 335, y: 260), 15: CGPoint(x: 335, y: 365)
    ]

    static let edges: [(Int, Int)] = [
        (0, 1), (1, 2), (2, 3),
        (4, 5), (5, 6), (6, 7),
        (8, 9), (9, 10), (10, 11),
        (12, 13), (13, 14), (14, 15),
        (0, 4), (4, 8), (8, 12),
        (1, 5), (5, 9), (9, 13),
        (2, 6), (6, 10), (10, 14),
        (3, 7), (7, 11), (11, 15)
    ]

    static func role(
        atViewPoint viewPoint: CGPoint,
        in viewSize: CGSize,
        routeNodeIDs: [Int],
        destination: DemoDestination,
        routePreset: RoutePreset,
        showRouteOnly: Bool
    ) -> MapRole {
        let point = documentPoint(from: viewPoint, in: viewSize)
        let activeEdges = edges(for: routePreset)
        let destinationNode = destination.nodeID

        if let start = nodes[1], distance(point, start) < 26 { return .userLocation }
        if let destinationPoint = nodes[destinationNode], distance(point, destinationPoint) < 30 { return .destination }

        if !showRouteOnly {
            // All navigation scenarios use the same square-grid context, so any
            // visible non-destination landmark can be treated as a POI.
            for place in DemoDestination.allCases where place != destination && place != .entrance {
                if let poiPoint = nodes[place.nodeID], distance(point, poiPoint) < 24 {
                    return .poi
                }
            }
        }

        for id in routeNodeIDs {
            if let nodePoint = nodes[id], distance(point, nodePoint) < 20 {
                return .intersection
            }
        }

        if isNearRoute(point, routeNodeIDs: routeNodeIDs, edges: activeEdges) { return .route }
        if !showRouteOnly && isNearAnyRoad(point, edges: activeEdges) { return .road }
        return .offRoute
    }

    static func edges(for preset: RoutePreset) -> [(Int, Int)] {
        switch preset {
        case .trial01:
            // Baseline: full original square/grid network.
            return edges

        case .trial02:
            // T-intersection style: main road with a turn toward the bus stop
            // and a few nearby non-route branches.
            return [
                (1, 5), (5, 9), (9, 10), (10, 6),
                (5, 6), (6, 7), (4, 5)
            ]

        case .trial03:
            // Dead-end style: the destination spur ends at the parking lot,
            // with one non-route connector nearby.
            return [
                (1, 5), (5, 9), (9, 13), (13, 12),
                (9, 10), (10, 14)
            ]

        case .trial04:
            // Clean offset route.
            return [
                (1, 5), (5, 9), (9, 10), (10, 11),
                (0, 4), (4, 5),
                (8, 9), (9, 13),
                (10, 14), (7, 11)
            ]

        case .trial05:
            // Single-corridor style route with one small side path.
            return [
                (1, 2), (2, 3), (3, 7), (7, 11),
                (2, 6)
            ]

        case .trial06:
            // Loop-like route along the lower part of the map.
            return [
                (1, 2), (2, 3), (3, 7), (7, 11),
                (1, 5), (5, 6), (6, 7), (7, 11)
            ]

        case .trial07:
            // Branching route toward Campus Park with alternate side roads.
            return [
                (1, 5), (5, 9), (9, 13), (13, 14), (14, 15),
                (9, 10), (10, 14), (13, 12)
            ]

        case .trial08:
            // Transit branch: route reaches the bus stop through a longer
            // controlled path, with nearby alternatives.
            return [
                (1, 5), (5, 9), (9, 10), (10, 6),
                (5, 6), (6, 7), (6, 10)
            ]

        case .trial09:
            // Parking branch with a spur and cross connector.
            return [
                (1, 5), (5, 9), (9, 13), (13, 12),
                (8, 12), (9, 10), (10, 14)
            ]

        case .trial10:
            // South connector route with several nearby road choices.
            return [
                (1, 2), (2, 6), (6, 10), (10, 11),
                (1, 5), (5, 6), (6, 7), (7, 11), (10, 14)
            ]
        }
    }

    static func neighbors(of node: Int, preset: RoutePreset = .trial01) -> [Int] {
        edges(for: preset).compactMap { from, to in
            if from == node { return to }
            if to == node { return from }
            return nil
        }
    }

    static func routeIntersectionID(atViewPoint viewPoint: CGPoint, in viewSize: CGSize, routeNodeIDs: [Int]) -> Int? {
        let point = documentPoint(from: viewPoint, in: viewSize)
        return routeNodeIDs.first { id in
            guard let nodePoint = nodes[id] else { return false }
            return distance(point, nodePoint) < 22
        }
    }

    static func roadName(from: Int, to: Int) -> String {
        // Road names are grouped by continuous campus road instead of giving
        // every single segment a different name. This makes audio feedback
        // feel more realistic for navigation.
        switch edgeKey(from, to) {
        // Horizontal roads across the grid
        case "0-4", "4-8", "8-12":
            return "North Campus Road"
        case "1-5", "5-9", "9-13":
            return "Main Road"
        case "2-6", "6-10", "10-14":
            return "Transit Road"
        case "3-7", "7-11", "11-15":
            return "South Campus Road"

        // Vertical roads down the grid
        case "0-1", "1-2", "2-3":
            return "West Walkway"
        case "4-5", "5-6", "6-7":
            return "Library Walk"
        case "8-9", "9-10", "10-11":
            return "Central Walkway"
        case "12-13", "13-14", "14-15":
            return "Lake Michigan Road"

        default:
            return "Campus Road"
        }
    }

    private static func documentPoint(from viewPoint: CGPoint, in viewSize: CGSize) -> CGPoint {
        let availableWidth = viewSize.width - canvasPadding * 2
        let availableHeight = viewSize.height - canvasPadding * 2
        let scale = min(availableWidth / mapWidth, availableHeight / mapHeight)
        let originX = (viewSize.width - mapWidth * scale) / 2
        let originY = (viewSize.height - mapHeight * scale) / 2
        return CGPoint(x: (viewPoint.x - originX) / scale, y: (viewPoint.y - originY) / scale)
    }

    private static func isNearRoute(_ point: CGPoint, routeNodeIDs: [Int], edges: [(Int, Int)]) -> Bool {
        let routeEdges = Set(routePairs(routeNodeIDs).map { edgeKey($0.0, $0.1) })
        return edges.contains { from, to in
            routeEdges.contains(edgeKey(from, to)) && distanceFromLine(point, nodes[from]!, nodes[to]!) < 24
        }
    }

    private static func isNearAnyRoad(_ point: CGPoint, edges: [(Int, Int)]) -> Bool {
        edges.contains { from, to in
            distanceFromLine(point, nodes[from]!, nodes[to]!) < 24
        }
    }

    private static func routePairs(_ route: [Int]) -> [(Int, Int)] {
        guard route.count > 1 else { return [] }
        return (0..<(route.count - 1)).map { (route[$0], route[$0 + 1]) }
    }

    private static func edgeKey(_ a: Int, _ b: Int) -> String {
        "\(min(a, b))-\(max(a, b))"
    }

    private static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    private static func distanceFromLine(_ point: CGPoint, _ start: CGPoint, _ end: CGPoint) -> CGFloat {
        let dx = end.x - start.x
        let dy = end.y - start.y
        if dx == 0 && dy == 0 { return distance(point, start) }
        let t = max(0, min(1, ((point.x - start.x) * dx + (point.y - start.y) * dy) / (dx * dx + dy * dy)))
        let projection = CGPoint(x: start.x + t * dx, y: start.y + t * dy)
        return distance(point, projection)
    }
}

// MARK: - Clean Visual Overlay

/// Lightweight SwiftUI overlay that makes the correct route obvious while Northeastern's
/// TactileMapView continues to own the document rendering, hit detection, haptics, and audio.
struct RouteClarityOverlay: View {
    let routeNodeIDs: [Int]
    let destination: DemoDestination
    let routePreset: RoutePreset
    let showRouteOnly: Bool

    // Uses MultiNavMapGeometry as the single source of truth for visual overlay coordinates.

    var body: some View {
        GeometryReader { geo in
            let transform = makeTransform(size: geo.size)

            ZStack {
                // Blue visual route overlay. The Northeastern update made route
                // lines visually thicker, so this overlay intentionally stays
                // modest to avoid covering intersections and nearby POIs.
                routePath(transform: transform)
                    .stroke(
                        Color.blue,
                        style: StrokeStyle(lineWidth: showRouteOnly ? 9 : 6, lineCap: .round, lineJoin: .round)
                    )
                    .shadow(color: .blue.opacity(0.35), radius: 8, x: 0, y: 0)
                    .opacity(0.88)

                routePath(transform: transform)
                    .stroke(
                        Color.white.opacity(0.95),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round, dash: [8, 8])
                    )

                ForEach(routeNodeIDs, id: \.self) { id in
                    if id != 1 && id != destination.nodeID, let point = MultiNavMapGeometry.nodes[id] {
                        RouteIntersectionDot()
                            .position(transform.apply(point))
                            .zIndex(20)
                    }
                }

                // Start and current-location are intentionally separated so they do not overlap.
                // The true route still begins at node 1; only the visual labels are offset.
                if let currentPoint = MultiNavMapGeometry.nodes[1] {
                    MapImageMarker(
                        systemName: "location.fill",
                        title: "You",
                        tint: .cyan,
                        size: 42
                    )
                    .position(transform.apply(CGPoint(x: currentPoint.x - 34, y: currentPoint.y + 8)))

                    // Start marker hidden for prototype usability.
                    // The Start concept is preserved in MultiNavMapBuilder as commented code,
                    // but visually we only show "You" to avoid overlap at the route origin.
                    /*
                    MapImageMarker(
                        systemName: "flag.fill",
                        title: "Start",
                        tint: .green,
                        size: 38
                    )
                    .position(transform.apply(CGPoint(x: currentPoint.x - 34, y: currentPoint.y - 38)))
                    */
                }

                if let destinationPoint = MultiNavMapGeometry.nodes[destination.nodeID] {
                    MapImageMarker(
                        systemName: destination.icon,
                        title: destination.rawValue,
                        tint: .red,
                        size: 48
                    )
                    .position(transform.apply(destinationPoint))
                }

                if !showRouteOnly {
                    // Only show POIs that are connected to the active trial network.
                    // This avoids floating landmarks when a trial intentionally uses
                    // a T-intersection, dead-end, or single-road topology.
                    let activeNodes = Set(MultiNavMapGeometry.edges(for: routePreset).flatMap { [$0.0, $0.1] })
                    let visiblePOIs = DemoDestination.allCases.filter { place in
                        place != destination && place != .entrance && activeNodes.contains(place.nodeID)
                    }

                    ForEach(visiblePOIs, id: \.self) { place in
                        if let point = MultiNavMapGeometry.nodes[place.nodeID] {
                            MapImageMarker(
                                systemName: place.icon,
                                title: "",
                                tint: .purple,
                                size: 36
                            )
                            .opacity(0.88)
                            .position(transform.apply(point))
                        }
                    }
                }
            }
        }
    }

    private func routePath(transform: OverlayTransform, trimDistance: CGFloat = 14) -> Path {
        var path = Path()
        let points = routeNodeIDs.compactMap { MultiNavMapGeometry.nodes[$0] }
        guard points.count >= 2 else { return path }

        // Trim route overlays away from the first and last intersections.
        // The dotted centerline gets a larger trim so it does not visually sit
        // on top of the beginning intersection or "You Are Here" marker.
        let trimmedPoints = trimmedRoutePoints(points, trimDistance: trimDistance)

        guard let first = trimmedPoints.first else { return path }
        path.move(to: transform.apply(first))

        for point in trimmedPoints.dropFirst() {
            path.addLine(to: transform.apply(point))
        }

        return path
    }

    private func trimmedRoutePoints(_ points: [CGPoint], trimDistance: CGFloat) -> [CGPoint] {
        guard points.count >= 2 else { return points }

        var output = points

        if let first = points.first, let second = points.dropFirst().first {
            output[0] = point(from: first, toward: second, distance: trimDistance)
        }

        if let last = points.last, points.count >= 2 {
            let previous = points[points.count - 2]
            output[output.count - 1] = point(from: last, toward: previous, distance: trimDistance)
        }

        return output
    }

    private func point(from start: CGPoint, toward end: CGPoint, distance: CGFloat) -> CGPoint {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = max(CGFloat(1), sqrt(dx * dx + dy * dy))
        return CGPoint(
            x: start.x + (dx / length) * distance,
            y: start.y + (dy / length) * distance
        )
    }

    private func makeTransform(size: CGSize) -> OverlayTransform {
        let availW = size.width - MultiNavMapGeometry.canvasPadding * 2
        let availH = size.height - MultiNavMapGeometry.canvasPadding * 2
        let scale = min(availW / MultiNavMapGeometry.mapWidth, availH / MultiNavMapGeometry.mapHeight)
        let ox = (size.width - MultiNavMapGeometry.mapWidth * scale) / 2
        let oy = (size.height - MultiNavMapGeometry.mapHeight * scale) / 2
        return OverlayTransform(scale: scale, ox: ox, oy: oy)
    }
}

struct OverlayTransform {
    let scale: CGFloat
    let ox: CGFloat
    let oy: CGFloat

    func apply(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x * scale + ox, y: point.y * scale + oy)
    }
}

struct RouteIntersectionDot: View {
    var body: some View {
        Circle()
            .fill(Color.orange)
            .frame(width: 28, height: 28)
            .overlay(
                Circle().stroke(.white, lineWidth: 3)
            )
            .shadow(color: .orange.opacity(0.28), radius: 6)
            .zIndex(20)
    }
}

struct MapImageMarker: View {
    let systemName: String
    let title: String
    let tint: Color
    let size: CGFloat

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(tint.gradient)
                    .frame(width: size, height: size)
                    .shadow(color: tint.opacity(0.35), radius: 8, x: 0, y: 4)

                Circle()
                    .stroke(.white, lineWidth: 3)
                    .frame(width: size, height: size)

                Image(systemName: systemName)
                    .font(.system(size: size * 0.42, weight: .bold))
                    .foregroundStyle(.white)
            }

            if !title.isEmpty {
                Text(title)
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(.clear)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.clear)
                    .opacity(0.01)
                    .accessibilityHidden(true)
            }
        }
    }
}

// MARK: - Zoomed Intersection View

struct IntersectionZoomView: View {
    @Environment(\.dismiss) private var dismiss
    let intersectionID: Int
    let routeNodeIDs: [Int]
    let destination: DemoDestination
    let routePreset: RoutePreset
    let customPatterns: [MapRole: HapticPattern]

    @State private var zoomHapticEngine: (any HapticEngine)?
    @State private var zoomAudioEngine: (any SpatialAudioEngine)?
    @State private var lastZoomSpokenName: String?
    @State private var lastZoomSpokenAt = Date.distantPast

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Intersection \(intersectionID)")
                        .font(.largeTitle.weight(.black))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Intersection \(intersectionID)")
                .accessibilityHint("Zoomed route decision point. Drag inside the map to explore nearby route directions and landmarks.")

                ZStack {
                    RoundedRectangle(cornerRadius: 28)
                        .fill(.white)
                        .shadow(color: .black.opacity(0.12), radius: 18, x: 0, y: 10)

                    LocalIntersectionMap(
                        intersectionID: intersectionID,
                        routeNodeIDs: routeNodeIDs,
                        destination: destination,
                        routePreset: routePreset,
                        onStartFeedback: { role, name in
                            startZoomFeedback(role: role, name: name)
                        },
                        onStopFeedback: {
                            stopZoomFeedback()
                        }
                    )
                    .padding(18)
                }
                .padding(.horizontal)
                .frame(maxHeight: .infinity)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Intersection Zoom")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        stopZoomFeedback()
                        dismiss()
                    }
                    .bold()
                }
            }
            .task {
                if zoomHapticEngine == nil {
                    zoomHapticEngine = CoreHapticsEngine()
                }
                if zoomAudioEngine == nil {
                    zoomAudioEngine = AVSpatialAudioEngine()
                }
            }
            .onDisappear {
                stopZoomFeedback()
            }
        }
    }

    private func startZoomFeedback(role: MapRole, name: String) {
        let pattern = customPatterns[role] ?? northeasternDefaultPattern(for: role)

        // Stop only the current haptic immediately before starting the next one.
        // Do not call stopZoomFeedback() here because its delayed defensive stops
        // would stop the new zoom haptic/audio almost immediately after it starts.
        zoomHapticEngine?.stopAll()
        zoomHapticEngine?.start(pattern: pattern)

        let now = Date()
        if lastZoomSpokenName != name || now.timeIntervalSince(lastZoomSpokenAt) > 1.15 {
            zoomAudioEngine?.stopAll()
            zoomAudioEngine?.speak(name)
            lastZoomSpokenName = name
            lastZoomSpokenAt = now
        }
    }

    private func stopZoomFeedback() {
        lastZoomSpokenName = nil
        zoomHapticEngine?.stopAll()
        zoomAudioEngine?.stopAll()

        // Defensive delayed stops for continuous and pulsing patterns.
        // This prevents a haptic from lingering after the finger lifts,
        // especially when the drag is cancelled/interrupted by SwiftUI.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            zoomHapticEngine?.stopAll()
            zoomAudioEngine?.stopAll()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            zoomHapticEngine?.stopAll()
            zoomAudioEngine?.stopAll()
        }
    }
}

struct LocalIntersectionMap: View {
    let intersectionID: Int
    let routeNodeIDs: [Int]
    let destination: DemoDestination
    let routePreset: RoutePreset
    let onStartFeedback: (MapRole, String) -> Void
    let onStopFeedback: () -> Void

    @State private var activeZoomRole: MapRole?
    @State private var activeZoomName: String?

    private let routeRadius: CGFloat = 152
    private let roadRadius: CGFloat = 136
    private let landmarkRadius: CGFloat = 122
    private let centerLandmarkRadius: CGFloat = 82
    private let centerHitRadius: CGFloat = 48

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let routeNeighbors = routeNeighborIDs
            let otherNeighbors = nonRouteNeighborIDs
            let nearbyLandmarks = nearbyZoomLandmarks

            // Zoom radii are tuned to make local roads longer while keeping
            // all neighbor markers inside the iPhone-safe zoom card.

            ZStack {
                // Single translucent intersection circle behind the roads.
                // Roads are drawn on top so the user can still see route direction through it.
                Circle()
                    .fill(Color.orange.opacity(0.28))
                    .frame(width: 104, height: 104)
                    .overlay(Circle().stroke(Color.orange.opacity(0.55), lineWidth: 4))
                    .position(center)
                    .zIndex(0)

                ForEach(otherNeighbors, id: \.self) { neighbor in
                    let endpoint = localPoint(for: neighbor, center: center, radius: roadRadius)
                    localRoad(from: center, to: endpoint)
                        .stroke(Color.gray.opacity(0.35), style: StrokeStyle(lineWidth: 12, lineCap: .round))

                    localRoad(from: center, to: endpoint)
                        .stroke(Color.white.opacity(0.001), style: StrokeStyle(lineWidth: 46, lineCap: .round))
                }

                ForEach(routeNeighbors, id: \.self) { neighbor in
                    let endpoint = localPoint(for: neighbor, center: center, radius: routeRadius)
                    localRoad(from: center, to: endpoint)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 15, lineCap: .round))
                        .shadow(color: .blue.opacity(0.25), radius: 8)

                    localRoad(from: center, to: endpoint)
                        .stroke(Color.white.opacity(0.9), style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [8, 7]))

                    localRoad(from: center, to: endpoint)
                        .stroke(Color.white.opacity(0.001), style: StrokeStyle(lineWidth: 50, lineCap: .round))
                }

                ForEach(otherNeighbors, id: \.self) { neighbor in
                    neighborMarker(id: neighbor, routeNeighbor: false)
                        .position(localPoint(for: neighbor, center: center, radius: roadRadius))
                }

                ForEach(routeNeighbors, id: \.self) { neighbor in
                    neighborMarker(id: neighbor, routeNeighbor: true)
                        .position(localPoint(for: neighbor, center: center, radius: routeRadius))
                }

                ForEach(nearbyLandmarks) { landmark in
                    zoomMarker(landmark)
                        .position(zoomLandmarkPoint(for: landmark, center: center))
                }


                if activeZoomRole == .offRoute {
                    Label("Off graph", systemImage: MapRole.offRoute.icon)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(MapRole.offRoute.tint.opacity(0.18), in: Capsule())
                        .position(x: center.x, y: max(24, center.y - (roadRadius + 3)))
                        .accessibilityLabel("Off graph")
                        .accessibilityHint("Move back to the zoomed route, nearby path, intersection, or landmark.")
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let hit = zoomHit(at: value.location, center: center)
                        guard activeZoomRole != hit.role || activeZoomName != hit.name else { return }
                        activeZoomRole = hit.role
                        activeZoomName = hit.name
                        onStartFeedback(hit.role, hit.name)
                    }
                    .onEnded { _ in
                        activeZoomRole = nil
                        activeZoomName = nil
                        onStopFeedback()
                    }
            )
        }
        .onDisappear {
            activeZoomRole = nil
            activeZoomName = nil
            onStopFeedback()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Zoomed intersection \(intersectionID)")
        .accessibilityHint("Drag to explore local route directions, nearby intersections, points of interest, destination, and current location.")
    }

    private var routeNeighborIDs: [Int] {
        guard let index = routeNodeIDs.firstIndex(of: intersectionID) else { return [] }
        var ids: [Int] = []
        if index > 0 { ids.append(routeNodeIDs[index - 1]) }
        if index < routeNodeIDs.count - 1 { ids.append(routeNodeIDs[index + 1]) }
        return ids
    }

    private var nonRouteNeighborIDs: [Int] {
        MultiNavMapGeometry.neighbors(of: intersectionID, preset: routePreset)
            .filter { !routeNeighborIDs.contains($0) }
    }

    private var nearbyZoomLandmarks: [ZoomLandmark] {
        let visibleNodes = Set([intersectionID] + MultiNavMapGeometry.neighbors(of: intersectionID, preset: routePreset))
        var landmarks: [ZoomLandmark] = []

        // Do not place landmarks directly on the current zoomed intersection.
        // If a POI/destination/user marker shares the same node as the active
        // intersection, it can steal audio/haptic focus from the intersection.
        // The landmark remains available on the route overview; zoom keeps the
        // intersection itself as the priority at this exact location.
        if visibleNodes.contains(1), 1 != intersectionID {
            landmarks.append(ZoomLandmark(id: "you", nodeID: 1, role: .userLocation, systemName: "location.fill", tint: .cyan, label: "You"))
        }

        if visibleNodes.contains(destination.nodeID), destination.nodeID != intersectionID {
            landmarks.append(ZoomLandmark(id: "destination", nodeID: destination.nodeID, role: .destination, systemName: destination.icon, tint: .red, label: destination.rawValue))
        }

        for place in DemoDestination.allCases where place != destination && place != .entrance {
            // Keep zoom landmarks tied to the active route instead of showing unrelated floating POIs.
            if visibleNodes.contains(place.nodeID),
               routeNodeIDs.contains(place.nodeID),
               place.nodeID != intersectionID {
                landmarks.append(ZoomLandmark(id: place.rawValue, nodeID: place.nodeID, role: .poi, systemName: place.icon, tint: .purple, label: place.rawValue))
            }
        }

        return landmarks
    }

    private func localRoad(from start: CGPoint, to end: CGPoint) -> Path {
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        return path
    }

    private func neighborMarker(id: Int, routeNeighbor: Bool) -> some View {
        ZStack {
            Circle()
                .fill(routeNeighbor ? Color.blue : Color.gray.opacity(0.25))
                .frame(width: routeNeighbor ? 54 : 46, height: routeNeighbor ? 54 : 46)
                .overlay(Circle().stroke(.white, lineWidth: 3))

            Text("\(id)")
                .font(.headline.weight(.black))
                .foregroundStyle(routeNeighbor ? .white : .secondary)
        }
        .accessibilityLabel(routeNeighbor ? "Route direction to Intersection \(id)" : "Nearby Intersection \(id)")
        .accessibilityHint(routeNeighbor ? "Continue along the current route." : "Nearby intersection, not part of the current route.")
    }

    private func zoomMarker(_ landmark: ZoomLandmark) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(landmark.tint.gradient)
                    .frame(width: 44, height: 44)
                    .overlay(Circle().stroke(.white, lineWidth: 3))
                    .shadow(color: landmark.tint.opacity(0.3), radius: 6)

                Image(systemName: landmark.systemName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
            }

            Text(landmark.label)
                .font(.system(size: 8, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(.ultraThinMaterial, in: Capsule())
        }
        .accessibilityLabel(landmark.accessibilityLabel)
        .accessibilityHint(landmark.accessibilityHint)
    }

    private func localPoint(for nodeID: Int, center: CGPoint, radius: CGFloat) -> CGPoint {
        guard let centerPoint = MultiNavMapGeometry.nodes[intersectionID],
              let nodePoint = MultiNavMapGeometry.nodes[nodeID] else {
            return center
        }

        let dx = nodePoint.x - centerPoint.x
        let dy = nodePoint.y - centerPoint.y
        let length = max(CGFloat(1), sqrt(dx * dx + dy * dy))
        return CGPoint(
            x: center.x + (dx / length) * radius,
            y: center.y + (dy / length) * radius
        )
    }

    private func zoomLandmarkPoint(for landmark: ZoomLandmark, center: CGPoint) -> CGPoint {
        let radius = landmark.nodeID == intersectionID ? centerLandmarkRadius : landmarkRadius
        let basePoint = localPoint(for: landmark.nodeID, center: center, radius: radius)

        // Any landmark that shares an intersection node must be drawn and hit-tested
        // away from the exact intersection point. This includes POIs, destinations,
        // and You Are Here. Otherwise the landmark can steal the intersection audio.
        let offsetDistance: CGFloat = 62

        if landmark.nodeID == intersectionID {
            switch landmark.role {
            case .userLocation:
                return CGPoint(x: center.x - offsetDistance, y: center.y - offsetDistance)
            case .destination:
                return CGPoint(x: center.x + offsetDistance, y: center.y - offsetDistance)
            case .poi:
                return CGPoint(x: center.x + offsetDistance, y: center.y + offsetDistance)
            default:
                return CGPoint(x: center.x + offsetDistance, y: center.y)
            }
        }

        guard let centerNode = MultiNavMapGeometry.nodes[intersectionID],
              let landmarkNode = MultiNavMapGeometry.nodes[landmark.nodeID] else {
            return CGPoint(x: basePoint.x + offsetDistance, y: basePoint.y)
        }

        let dx = landmarkNode.x - centerNode.x
        let dy = landmarkNode.y - centerNode.y
        let length = max(CGFloat(1), sqrt(dx * dx + dy * dy))

        // Offset away from the road direction so the marker stays near the node
        // but no longer sits directly on the route-neighbor/intersection marker.
        let normalX = -dy / length
        let normalY = dx / length

        let roleMultiplier: CGFloat
        switch landmark.role {
        case .destination:
            roleMultiplier = 1.15
        case .userLocation:
            roleMultiplier = -1.15
        case .poi:
            roleMultiplier = 1.0
        default:
            roleMultiplier = 1.0
        }

        return CGPoint(
            x: basePoint.x + normalX * offsetDistance * roleMultiplier,
            y: basePoint.y + normalY * offsetDistance * roleMultiplier
        )
    }

    private func zoomHit(at point: CGPoint, center: CGPoint) -> (role: MapRole, name: String) {
        // Intersection hit targets always win over landmarks. This prevents POIs,
        // Destination, or You Are Here from speaking when the finger is actually
        // on top of an intersection point.
        if distance(point, center) <= centerHitRadius {
            return (.intersection, "Intersection \(intersectionID)")
        }

        for neighbor in routeNeighborIDs {
            let endpoint = localPoint(for: neighbor, center: center, radius: routeRadius)
            if distance(point, endpoint) <= 36 {
                return (.intersection, "Intersection \(neighbor)")
            }
        }

        for neighbor in nonRouteNeighborIDs {
            let endpoint = localPoint(for: neighbor, center: center, radius: roadRadius)
            if distance(point, endpoint) <= 32 {
                return (.intersection, "Intersection \(neighbor)")
            }
        }

        // Landmarks are checked only after all intersection nodes. Since their
        // visual positions are offset with zoomLandmarkPoint, users can still
        // intentionally explore POIs/destination without them stealing node audio.
        for landmark in nearbyZoomLandmarks {
            let landmarkPoint = zoomLandmarkPoint(for: landmark, center: center)
            if distance(point, landmarkPoint) <= 30 {
                return (landmark.role, landmark.accessibilityLabel)
            }
        }

        for neighbor in routeNeighborIDs {
            let endpoint = localPoint(for: neighbor, center: center, radius: routeRadius)
            if distanceFromLine(point, center, endpoint) <= 30 {
                return (.route, "Best route toward Intersection \(neighbor)")
            }
        }

        for neighbor in nonRouteNeighborIDs {
            let endpoint = localPoint(for: neighbor, center: center, radius: roadRadius)
            if distanceFromLine(point, center, endpoint) <= 24 {
                return (.road, "Nearby path toward Intersection \(neighbor)")
            }
        }

        return (.offRoute, "Off graph")
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    private func distanceFromLine(_ point: CGPoint, _ start: CGPoint, _ end: CGPoint) -> CGFloat {
        let dx = end.x - start.x
        let dy = end.y - start.y
        if dx == 0 && dy == 0 { return distance(point, start) }
        let t = max(0, min(1, ((point.x - start.x) * dx + (point.y - start.y) * dy) / (dx * dx + dy * dy)))
        let projection = CGPoint(x: start.x + t * dx, y: start.y + t * dy)
        return distance(point, projection)
    }
}

struct ZoomLandmark: Identifiable {
    let id: String
    let nodeID: Int
    let role: MapRole
    let systemName: String
    let tint: Color
    let label: String

    var accessibilityLabel: String {
        switch role {
        case .userLocation:
            return "You are here"
        case .destination:
            return "Destination, \(label)"
        case .poi:
            return "Point of interest, \(label)"
        default:
            return label
        }
    }

    var accessibilityHint: String {
        switch role {
        case .userLocation:
            return "Current location near this intersection."
        case .destination:
            return "Route destination near this intersection."
        case .poi:
            return "Nearby landmark."
        default:
            return "Nearby map element."
        }
    }
}

// MARK: - UI Components

struct DestinationChip: View {
    let destination: DemoDestination
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.white.opacity(0.24) : Color.blue.opacity(0.12))
                        .frame(width: 30, height: 30)
                    Image(systemName: destination.icon)
                        .foregroundStyle(isSelected ? .white : .blue)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(destination.rawValue)
                        .font(.subheadline.weight(.bold))
                    Text(destination.subtitle)
                        .font(.caption2)
                        .opacity(0.82)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue.gradient : Color(.secondarySystemBackground).gradient, in: RoundedRectangle(cornerRadius: 14))
            .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(destination.rawValue)
        .accessibilityHint(destination.subtitle)
    }
}

struct RouteBadge: View {
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "bolt.route.fill")
            Text(text)
        }
        .font(.caption.weight(.bold))
        .foregroundStyle(.blue)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.blue.opacity(0.12), in: Capsule())
    }
}

// MARK: - Settings

struct HapticSettingsView: View {
    @ObservedObject var state: MultiNavPrototypeState
    let initialRole: MapRole
    @Environment(\.dismiss) private var dismiss
    @State private var previewEngine: (any HapticEngine)?
    @State private var selectedRole: MapRole
    @State private var suppressPreview = false

    init(state: MultiNavPrototypeState, initialRole: MapRole = .route) {
        self.state = state
        self.initialRole = initialRole
        _selectedRole = State(initialValue: initialRole)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    routePresetPicker
                    rolePicker
                    editorCard
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Haptic Settings")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Reset") { resetHapticsSafely() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        stopPreviewSafely()
                        dismiss()
                    }
                    .bold()
                }
            }
            .task {
                if previewEngine == nil {
                    previewEngine = CoreHapticsEngine()
                }
            }
            .onAppear {
                selectedRole = initialRole
            }
            .onDisappear {
                stopPreviewSafely()
            }
        }
    }

    private var routePresetPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Study Trial")
                .font(.subheadline.weight(.semibold))

            Picker("Study Trial", selection: Binding<RoutePreset>(
                get: { state.routePreset },
                set: { newPreset in
                    stopPreviewSafely()
                    state.setRoutePreset(newPreset)
                }
            )) {
                ForEach(RoutePreset.allCases) { preset in
                    Text(preset.shortName).tag(preset)
                }
            }
            .pickerStyle(.menu)

            Text(state.routePreset.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Study trial, \(state.routePreset.rawValue)")
        .accessibilityHint(state.routePreset.subtitle)
    }

    private var rolePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Element Type")
                .font(.subheadline.weight(.semibold))

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 8)], spacing: 8) {
                ForEach(MapRole.allCases) { role in
                    Button {
                        stopPreviewSafely()
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            selectedRole = role
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: role.icon)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(role.tint)

                            Text(role.compactTitle)
                                .font(.caption2.weight(.bold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 7)
                        .background(
                            selectedRole == role
                            ? role.tint.opacity(0.18)
                            : Color(.secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: 13)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 13)
                                .stroke(selectedRole == role ? role.tint.opacity(0.85) : .clear, lineWidth: 1.3)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(role.rawValue)
                    .accessibilityHint("Select this map element type to customize its haptic pattern.")
                }
            }
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 20))
    }

    private var editorCard: some View {
        let draft = Binding<NortheasternPatternDraft>(
            get: {
                NortheasternPatternDraft(
                    pattern: state.customPatterns[selectedRole] ?? northeasternDefaultPattern(for: selectedRole)
                )
            },
            set: { newDraft in
                state.customPatterns[selectedRole] = newDraft.pattern
            }
        )

        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label(selectedRole.rawValue, systemImage: selectedRole.icon)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(selectedRole.tint)
                Spacer()
            }

            Picker("Pattern Type", selection: draft.shape) {
                ForEach(NortheasternPatternShape.allCases) { shape in
                    Text(shape.rawValue).tag(shape)
                }
            }
            .pickerStyle(.segmented)

            // Intensity (0.0 - 1.0)
            //
            // JND ≈ 13% of the current intensity value.
            // Source:
            // "Vibrotactile amplitude discrimination capacity parallels
            // magnitude changes in somatosensory cortex and follows Weber's Law"
            //
            // Example:
            // Intensity = 0.60 -> JND ≈ 0.078
            //
            // Research values are intentionally hidden from participants
            // to reduce cognitive load during the study.
            StudyHapticSlider(
                title: "Intensity",
                value: draft.intensity,
                range: 0...1,
                step: 0.1,
                icon: "speaker.wave.3.fill",
                onPreview: { previewPatternIfAllowed(draft.wrappedValue.pattern) },
                onStopPreview: { stopPreviewSafely() }
            )

            // Sharpness (0.0 - 1.0)
            //
            // No well-established psychophysical JND was identified
            // in the literature.
            //
            // Future work:
            // Pilot testing should determine perceptually meaningful
            // sharpness increments for blind and visually impaired users.
            //
            // Slider remains continuous until pilot data is collected.
            StudyHapticSlider(
                title: "Sharpness",
                value: draft.sharpness,
                range: 0...1,
                step: 0.1,
                icon: "sparkle",
                onPreview: { previewPatternIfAllowed(draft.wrappedValue.pattern) },
                onStopPreview: { stopPreviewSafely() }
            )

            switch draft.wrappedValue.shape {
            case .continuous:
                // Duration (seconds)
                //
                // Minimum perceptible pulse duration:
                // > 0.03 sec (30 ms)
                //
                // Source:
                // Vibrotactile stimulus duration threshold literature
                //
                // Estimated Duration JND:
                // Increase: +0.240 sec
                // Decrease: -0.110 sec
                //
                // Source:
                // "Estimating the Just Noticeable Difference of Tactile
                // Feedback in Oculus Quest 2 Controllers"
                //
                // Research guidance is retained in comments but intentionally
                // hidden from participant-facing UI.
                StudyHapticSlider(
                    title: "Duration (seconds)",
                    value: draft.duration,
                    range: 0.1...2.0,
                    step: 0.1,
                    icon: "timer",
                    onPreview: { previewPatternIfAllowed(draft.wrappedValue.pattern) },
                    onStopPreview: { stopPreviewSafely() }
                )

            case .pulsing:
                // Pulse Duration (seconds)
                //
                // Minimum perceptible pulse duration:
                // > 0.03 sec (30 ms)
                //
                // Estimated Duration JND:
                // Increase: +0.240 sec
                // Decrease: -0.110 sec
                //
                // Source:
                // "Estimating the Just Noticeable Difference of Tactile
                // Feedback in Oculus Quest 2 Controllers"
                //
                // UI uses 0.1 sec steps to keep the setting participant-friendly
                // instead of exposing unnecessary millisecond-level precision.
                StudyHapticSlider(
                    title: "Pulse Duration (seconds)",
                    value: draft.duration,
                    range: 0.1...1.0,
                    step: 0.1,
                    icon: "timer",
                    onPreview: { previewPatternIfAllowed(draft.wrappedValue.pattern) },
                    onStopPreview: { stopPreviewSafely() }
                )

                // Interval (time between pulses)
                //
                // Current study UI uses a participant-friendly range:
                // 0.1 - 1.0 seconds
                //
                // JND ≈ 20% of the current interval value.
                //
                // Source:
                // "Vibrotactile perception: examining the coding of vibrations
                // and the just noticeable difference under various conditions"
                //
                // Example:
                // Interval = 0.5 sec -> JND ≈ 0.1 sec
                //
                // JND calculations are documented here for researchers but
                // intentionally hidden from participants.
                StudyHapticSlider(
                    title: "Interval Between Pulses (seconds)",
                    value: draft.interval,
                    range: 0.1...1.0,
                    step: 0.1,
                    icon: "waveform.path",
                    onPreview: { previewPatternIfAllowed(draft.wrappedValue.pattern) },
                    onStopPreview: { stopPreviewSafely() }
                )

                Stepper("Pulse Count: \(draft.wrappedValue.count)", value: draft.count, in: 1...120)
                    .font(.subheadline.weight(.semibold))

            case .transient:
                Text("Tap patterns use intensity and sharpness only.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 24))
    }

    private func previewPatternIfAllowed(_ pattern: HapticPattern) {
        guard !suppressPreview else { return }

        // CoreHapticsEngine ignores a new continuous pattern while a continuous
        // player is already active. For settings preview, always restart the
        // current pattern so Intensity, Sharpness, and Duration changes are felt
        // immediately while the slider moves.
        previewEngine?.stopAll()
        previewEngine?.start(pattern: pattern)
    }

    private func stopPreviewSafely() {
        previewEngine?.stopAll()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            previewEngine?.stopAll()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            previewEngine?.stopAll()
        }
    }

    private func resetHapticsSafely() {
        // Resetting changes the bound slider values. Without this guard, each
        // slider's onChange can immediately restart a preview haptic after Reset.
        // Reset only the selected role and preserve the visible pattern type.
        let currentPattern = state.customPatterns[selectedRole] ?? northeasternDefaultPattern(for: selectedRole)
        let currentShape = NortheasternPatternDraft(pattern: currentPattern).shape

        suppressPreview = true
        previewEngine?.stopAll()
        state.resetHaptic(for: selectedRole, preserving: currentShape)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            previewEngine?.stopAll()
            suppressPreview = false
        }
    }
}

struct StudyHapticSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let icon: String
    let onPreview: () -> Void
    let onStopPreview: () -> Void
    @State private var isEditing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(value, format: .number.precision(.fractionLength(1)))
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(.secondary)
            }

            Slider(
                value: $value,
                in: range,
                step: step,
                onEditingChanged: { editing in
                    isEditing = editing
                    if editing {
                        onPreview()
                    } else {
                        onStopPreview()
                    }
                }
            )
            .onChange(of: value) { _ in
                guard isEditing else { return }
                onPreview()
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(Text(value, format: .number.precision(.fractionLength(1))))
        .accessibilityHint("Adjust to preview this haptic setting. Haptics stop when your finger leaves the slider.")
    }
}

// MARK: - Northeastern Configuration Extensions

extension TactileMapViewConfiguration {
    static var multiNavPremium: TactileMapViewConfiguration {
        TactileMapViewConfiguration(
            renderingMode: .canvas,
            backgroundColor: UIColor.systemBackground,
            corridorColor: UIColor.systemGray3.withAlphaComponent(0.85),
            corridorLineWidthMM: 3.6,
            intersectionColor: UIColor.systemOrange,
            intersectionDiameterMM: 5.5,
            // Keep Northeastern landmark elements available for hit detection,
            // haptics, and audio, but make the rendered landmark box visually tiny.
            // This removes the visible black/gray boxes around POIs and "You Are Here"
            // while preserving the underlying MapElement landmarks.
            landmarkColor: UIColor.clear,
            landmarkWidthMM: 0.1,
            landmarkHeightMM: 0.1,
            anchorPointColor: UIColor.clear,
            anchorPointDiameterMM: 4.0,
            edgePadding: UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24),
            isVoiceOverBackGestureEnabled: true,
            longPressMinDuration: 0.05,
            junctionDiscEnabled: true,
            showTouchIndicator: true,
            canvasPadding: 18,
            typeStyles: [
                .routeRoad: ElementStyle(
                    color: UIColor.systemBlue.withAlphaComponent(0.92),
                    sizeMM: 3.2
                ),
                .nonRouteRoad: ElementStyle(
                    color: UIColor.systemGray3.withAlphaComponent(0.85),
                    sizeMM: 3.6
                )
            ]
        )
    }
}

extension HitDetectionConfig {
    static var multiNavForgiving: HitDetectionConfig {
        HitDetectionConfig(
            anchorHitRadiusPts: 22, pointHitRadiusPts: 26,
            corridorBaseRadiusPts: 34,
            velocityBonusMax: 28, velocityDivisor: 32
        )
    }
}

// MARK: - Northeastern Document Builder + Best Route

enum MultiNavMapBuilder {
    struct BuildResult {
        let document: TactileMapDocument
        let routeNodeIDs: [Int]
    }

    private static let originID = 1

    private static let nodes: [Int: TactileCoordinate] = [
        0: .init(x: 55, y: 70),   1: .init(x: 55, y: 160),  2: .init(x: 55, y: 260),  3: .init(x: 55, y: 365),
        4: .init(x: 150, y: 70),  5: .init(x: 150, y: 160), 6: .init(x: 150, y: 260), 7: .init(x: 150, y: 365),
        8: .init(x: 245, y: 70),  9: .init(x: 245, y: 160), 10: .init(x: 245, y: 260), 11: .init(x: 245, y: 365),
        12: .init(x: 335, y: 70), 13: .init(x: 335, y: 160), 14: .init(x: 335, y: 260), 15: .init(x: 335, y: 365)
    ]

    private static let edges: [(Int, Int)] = [
        (0, 1), (1, 2), (2, 3),
        (4, 5), (5, 6), (6, 7),
        (8, 9), (9, 10), (10, 11),
        (12, 13), (13, 14), (14, 15),
        (0, 4), (4, 8), (8, 12),
        (1, 5), (5, 9), (9, 13),
        (2, 6), (6, 10), (10, 14),
        (3, 7), (7, 11), (11, 15)
    ]

    static func makeDocument(destination: DemoDestination, routePreset: RoutePreset, showRouteOnly: Bool) -> BuildResult {
        let presetRoute = routePreset.routeNodeIDs
        let route = presetRoute.last == destination.nodeID ? presetRoute : shortestPath(from: originID, to: destination.nodeID, edges: MultiNavMapGeometry.edges(for: routePreset))
        let activeEdges = MultiNavMapGeometry.edges(for: routePreset)
        let routeEdges = Set(routePairs(route).map { edgeKey($0.0, $0.1) })
        let visibleNodes = Set(activeEdges.flatMap { [$0.0, $0.1] } + route)
        var features: [MapElement] = []

        for (from, to) in activeEdges {
            let key = edgeKey(from, to)
            let isRoute = routeEdges.contains(key)
            if showRouteOnly && !isRoute { continue }

            features.append(
                MapElement(
                    id: "corridor_\(from)_\(to)",
                    elementType: isRoute ? .routeRoad : .nonRouteRoad,
                    geometry: .lineString([nodes[from]!, nodes[to]!]),
                    properties: TactileProperties(
                        name: MultiNavMapGeometry.roadName(from: from, to: to),
                        category: isRoute ? "best outdoor route path" : "corridor",
                        custom: [
                            "waiveRole": isRoute ? MapRole.route.storageValue : MapRole.road.storageValue,
                            "routeStep": isRoute ? routeStepDescription(from: from, to: to, route: route) : "",
                            "fromNode": "\(from)",
                            "toNode": "\(to)"
                        ]
                    )
                )
            )
        }

        // Clean prototype view: only show intersections that are actually on the selected route.
        // This reduces clutter while still using Northeastern MapElement + TactileMapView hit detection.
        for id in route {
            let connected = connectedCorridorIDs(for: id, visibleRouteOnly: true, routeEdges: routeEdges, activeEdges: activeEdges)

            features.append(
                MapElement(
                    id: "intersection_\(id)",
                    elementType: .intersection,
                    geometry: .point(nodes[id]!),
                    properties: TactileProperties(
                        name: "Intersection \(id)",
                        category: "intersection",
                        connectedCorridors: connected,
                        custom: ["waiveRole": MapRole.intersection.storageValue]
                    )
                )
            )
        }

        features.append(
            marker(
                id: "user_location",
                name: "You are here",
                node: originID,
                role: .userLocation,
                side: "right"
            )
        )

        // Disabled for prototype usability.
        // Start and User Location occupy the same logical location and
        // caused visual + haptic overlap on the first route segment.
        //
        // features.append(
        //     marker(
        //         id: "origin",
        //         name: "Start",
        //         node: originID,
        //         role: .origin,
        //         side: "left"
        //     )
        // )

        features.append(
            marker(
                id: "destination",
                name: destination.rawValue,
                node: destination.nodeID,
                role: .destination,
                side: "right"
            )
        )

        if destination != .busStop && !showRouteOnly && visibleNodes.contains(DemoDestination.busStop.nodeID) {
            features.append(
                marker(
                    id: "bus_stop",
                    name: "Bus Stop",
                    node: DemoDestination.busStop.nodeID,
                    role: .poi,
                    side: "left"
                )
            )
        }

        if destination != .studentCenter && !showRouteOnly && visibleNodes.contains(DemoDestination.studentCenter.nodeID) {
            features.append(
                marker(
                    id: "student_center",
                    name: "Student Center",
                    node: DemoDestination.studentCenter.nodeID,
                    role: .poi,
                    side: "left"
                )
            )
        }

        if destination != .parkingLot && !showRouteOnly && visibleNodes.contains(DemoDestination.parkingLot.nodeID) {
            features.append(
                marker(
                    id: "parking_lot",
                    name: "Parking Lot",
                    node: DemoDestination.parkingLot.nodeID,
                    role: .poi,
                    side: "right"
                )
            )
        }

        if destination != .park && !showRouteOnly && visibleNodes.contains(DemoDestination.park.nodeID) {
            features.append(
                marker(
                    id: "campus_park",
                    name: "Campus Park",
                    node: DemoDestination.park.nodeID,
                    role: .poi,
                    side: "right"
                )
            )
        }

        let document = TactileMapDocument(
            version: "1.0",
            bounds: TactileMapBounds(width: 390, height: 450),
            features: features,
            metadata: TactileMapMetadata(
                name: "WAIVE MultiNav Outdoor Route Prototype - \(routePreset.rawValue)",
                buildingName: "Outdoor Campus Route",
                floor: 1,
                scale: "Outdoor prototype coordinate space",
                coordinateUnit: .arbitrary,
                author: "WAIVE Lab using Northeastern ProjectMultiNav"
            )
        )

        return BuildResult(document: document, routeNodeIDs: route)
    }

    private static func marker(id: String, name: String, node: Int, role: MapRole, side: String) -> MapElement {
        // Keep the visual overlay at the true node, but offset start/user landmarks
        // in the Northeastern document so they do not steal the first route corridor's haptic hit.
        let base = nodes[node]!
        let coordinate: TactileCoordinate

        switch role {
        case .userLocation:
            // Put current position to the lower-left of the real start node.
            coordinate = TactileCoordinate(x: max(0, base.x - 34), y: base.y + 10)
        case .origin:
            // Put the start marker above the current-position marker.
            coordinate = TactileCoordinate(x: max(0, base.x - 34), y: max(0, base.y - 34))
        default:
            coordinate = base
        }

        return MapElement(
            id: id,
            elementType: .landmark,
            geometry: .point(coordinate),
            properties: TactileProperties(
                name: name,
                category: "landmark",
                side: side,
                custom: [
                    "waiveRole": role.storageValue,
                    "nodeID": "\(node)"
                ]
            )
        )
    }

    private static func shortestPath(from start: Int, to end: Int, edges: [(Int, Int)] = MultiNavMapGeometry.edges(for: .trial01)) -> [Int] {
        var distances = Dictionary(uniqueKeysWithValues: nodes.keys.map { ($0, Double.infinity) })
        var previous: [Int: Int] = [:]
        var unvisited = Set(nodes.keys)
        distances[start] = 0

        while !unvisited.isEmpty {
            guard let current = unvisited.min(by: { distances[$0, default: .infinity] < distances[$1, default: .infinity] }) else { break }
            if current == end { break }
            unvisited.remove(current)

            for neighbor in neighbors(of: current, edges: edges) where unvisited.contains(neighbor) {
                let alt = distances[current, default: .infinity] + distance(nodes[current]!, nodes[neighbor]!)
                if alt < distances[neighbor, default: .infinity] {
                    distances[neighbor] = alt
                    previous[neighbor] = current
                }
            }
        }

        var route = [end]
        var current = end
        while current != start {
            guard let prev = previous[current] else { return [start] }
            route.insert(prev, at: 0)
            current = prev
        }
        return route
    }

    private static func neighbors(of node: Int, edges: [(Int, Int)]) -> [Int] {
        edges.compactMap { from, to in
            if from == node { return to }
            if to == node { return from }
            return nil
        }
    }

    private static func routePairs(_ route: [Int]) -> [(Int, Int)] {
        guard route.count > 1 else { return [] }
        return (0..<(route.count - 1)).map { (route[$0], route[$0 + 1]) }
    }

    private static func routeStepDescription(from: Int, to: Int, route: [Int]) -> String {
        let pairs = routePairs(route)
        guard let index = pairs.firstIndex(where: { edgeKey($0.0, $0.1) == edgeKey(from, to) }) else {
            return "Route segment"
        }
        return "Step \(index + 1) of \(pairs.count)"
    }

    private static func connectedCorridorIDs(for node: Int, visibleRouteOnly: Bool, routeEdges: Set<String>, activeEdges: [(Int, Int)]) -> [String] {
        activeEdges.compactMap { from, to in
            guard from == node || to == node else { return nil }
            if visibleRouteOnly && !routeEdges.contains(edgeKey(from, to)) { return nil }
            return "corridor_\(from)_\(to)"
        }
    }

    private static func edgeKey(_ a: Int, _ b: Int) -> String {
        "\(min(a, b))-\(max(a, b))"
    }

    private static func distance(_ a: TactileCoordinate, _ b: TactileCoordinate) -> Double {
        hypot(a.x - b.x, a.y - b.y)
    }
}

// MARK: - Northeastern HapticPattern Draft Binding Helpers

extension Binding where Value == NortheasternPatternDraft {
    var shape: Binding<NortheasternPatternShape> {
        Binding<NortheasternPatternShape>(
            get: { wrappedValue.shape },
            set: { wrappedValue.shape = $0 }
        )
    }

    var intensity: Binding<Double> {
        Binding<Double>(
            get: { wrappedValue.intensity },
            set: { wrappedValue.intensity = $0 }
        )
    }

    var sharpness: Binding<Double> {
        Binding<Double>(
            get: { wrappedValue.sharpness },
            set: { wrappedValue.sharpness = $0 }
        )
    }

    var duration: Binding<Double> {
        Binding<Double>(
            get: { wrappedValue.duration },
            set: { wrappedValue.duration = $0 }
        )
    }

    var interval: Binding<Double> {
        Binding<Double>(
            get: { wrappedValue.interval },
            set: { wrappedValue.interval = $0 }
        )
    }

    var count: Binding<Int> {
        Binding<Int>(
            get: { wrappedValue.count },
            set: { wrappedValue.count = $0 }
        )
    }
}

// MARK: - Preview

#Preview {
    MultiNavBestPrototypeView()
}
