// The comments for this .swift file have been annotated by chatGPT

import Combine
import Foundation
import FirebaseAuth
import TactileMapCore

// Manages authentication, study rounds, maps, parameters, and results.
@MainActor
final class StudySession: ObservableObject {

    // Represents the current stage of the study.
    enum Phase: Equatable {
        case login, waitingForParameters, exploring, survey, submitting
        case error(String)
    }

    // Maps available for study rounds.
    static let overviewMaps: [String] = [
        "map01_orchard", "map02_harbor", "map03_songbird", "map04_gemstone",
        "map05_aurora", "map06_melody", "map07_palette", "map08_atlas",
        "map09_meridian", "map10_solstice", "map11_woodland", "map12_desert",
        "map13_alpine", "map14_storybook", "map15_spice", "map16_meadow",
        "map17_trades", "map18_carnival",
    ]

    // Used to convert time-to-target into an objective score.
    private let tBest: TimeInterval = 5
    private let tWorst: TimeInterval = 90
    private let firstRoundFallbackSeconds: UInt64 = 5

    // Published values allow SwiftUI views to react to session changes.
    @Published var phase: Phase = .login
    @Published private(set) var current: ParameterSet?
    @Published private(set) var participantID = ""
    @Published private(set) var roundNumber = 0
    @Published private(set) var currentMapName = ""
    @Published private(set) var targetName = ""
    @Published private(set) var isSignedIn = false
    @Published var authError: String?

    // Tracks maps, Firebase updates, and the current round.
    private var mapDeck: [String] = []
    private var deckIndex = 0
    private var repo: MoboRepo?
    private var listenTask: Task<Void, Never>?
    private var fallbackTask: Task<Void, Never>?
    private var lastDocumentID: String?
    private var pendingParameters: PublishedParameters?
    private var explorationStart: Date?
    private var timeToTarget: TimeInterval?
    private var touchedTarget = false
    private let sessionID = UUID().uuidString

    // Signs the participant into Firebase anonymously.
    func signIn() async {
        guard !isSignedIn else { return }
        do {
            _ = try await Auth.auth().signInAnonymously()
            isSignedIn = true
            authError = nil
        } catch {
            authError = "Sign-in failed: \(error.localizedDescription)"
        }
    }

    // Initializes a study session and starts listening for parameters.
    func begin(participantID rawID: String) {
        let pid = rawID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pid.isEmpty else { return }
        participantID = pid

        mapDeck = Self.overviewMaps.shuffled()
        deckIndex = 0
        roundNumber = 0
        current = nil
        lastDocumentID = nil
        pendingParameters = nil
        phase = .waitingForParameters

        let repo = MoboRepo(participantID: pid)
        self.repo = repo
        listenTask = Task { [weak self] in
            for await published in repo.parameterUpdates() {
                self?.receive(published)
            }
        }
        scheduleFirstRoundFallback()
    }

    // Stops listening for new parameter updates.
    func endListening() {
        listenTask?.cancel()
        fallbackTask?.cancel()
        repo?.stop()
    }

    // Provides default parameters if none arrive within 5 seconds.
    private func scheduleFirstRoundFallback() {
        fallbackTask?.cancel()
        fallbackTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: self.firstRoundFallbackSeconds * 1_000_000_000)
            guard !Task.isCancelled,
                  self.phase == .waitingForParameters,
                  self.current == nil
            else { return }
            self.receive(PublishedParameters(documentID: "shared-initial-defaults",
                                             values: ParameterSet()))
        }
    }

    // Processes new parameters, either starting a round or saving them for later.
    private func receive(_ published: PublishedParameters) {
        guard published.documentID != lastDocumentID else { return }

        if phase == .waitingForParameters {
            fallbackTask?.cancel()
            lastDocumentID = published.documentID
            current = published.values
            startRound(with: published.values)
        } else {
            pendingParameters = published
        }
    }

    // Selects the next map and begins a new exploration round.
    private func startRound(with params: ParameterSet) {
        if deckIndex >= mapDeck.count {
            let last = mapDeck.last
            repeat { mapDeck.shuffle() } while mapDeck.count > 1 && mapDeck.first == last
            deckIndex = 0
        }
        currentMapName = mapDeck[deckIndex]
        deckIndex += 1
        roundNumber += 1
        timeToTarget = nil
        touchedTarget = false
        targetName = ""
        explorationStart = Date()
        phase = .exploring
    }

    // Sets the target the participant must find.
    func overviewLoaded(targetName: String) {
        self.targetName = targetName
    }

    // Records the time when the participant reaches the correct target.
    func elementEntered(name: String, typeRaw: String) {
        guard phase == .exploring,
              timeToTarget == nil,
              typeRaw == "end",
              name == targetName,
              let start = explorationStart
        else { return }
        timeToTarget = Date().timeIntervalSince(start)
        touchedTarget = true
    }

    // Ends exploration and moves to the survey.
    func foundTarget() {
        if timeToTarget == nil, let start = explorationStart {
            timeToTarget = Date().timeIntervalSince(start)
        }
        phase = .survey
    }

    // Converts completion time into a normalized 0–1 objective score.
    var objectiveScore: Double {
        guard let t = timeToTarget else { return 0 }
        return min(1, max(0, (tWorst - t) / (tWorst - tBest)))
    }

    // Submits the round's results and prepares for the next round.
    func submit(subjectiveScore: Double,
                attentionCheckPassed: Bool,
                rawAnswers: [String: Any]) {
        guard let params = current, let repo else { return }
        phase = .submitting
        Task {
            do {
                try await repo.submitResult(
                    tested: params,
                    subjectiveScore: subjectiveScore,
                    objectiveScore: objectiveScore,
                    attentionCheckPassed: attentionCheckPassed,
                    rawQuestionnaire: rawAnswers,
                    mapName: currentMapName,
                    roundNumber: roundNumber,
                    timeToTargetSeconds: timeToTarget,
                    touchedTarget: touchedTarget,
                    sessionID: sessionID
                )
                phase = .waitingForParameters
                if let pending = pendingParameters {
                    pendingParameters = nil
                    receive(pending)
                }
            } catch {
                phase = .error("Submission failed: \(error.localizedDescription)")
            }
        }
    }

    // Starts a round using the current haptic parameters.
    func continueWithCurrentSettings() {
        guard phase == .waitingForParameters, let params = current else { return }
        startRound(with: params)
    }
    
    // Changes the currently displayed overview map.
    func selectOverviewMap(_ mapName: String) {
        guard Self.overviewMaps.contains(mapName) else {
            return
        }

        currentMapName = mapName
    }

    // Returns to the survey after a submission error.
    func retrySurvey() {
        phase = .survey
    }
}
