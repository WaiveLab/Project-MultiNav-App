import Combine
import Foundation
import FirebaseAuth
import TactileMapCore

@MainActor
final class StudySession: ObservableObject {

    enum Phase: Equatable {
        case login
        case waitingForParameters
        case exploring
        case survey
        case submitting
        case error(String)
    }

    static let overviewMaps: [String] = [
        "map01_orchard", "map02_harbor", "map03_songbird", "map04_gemstone",
        "map05_aurora", "map06_melody", "map07_palette", "map08_atlas",
        "map09_meridian", "map10_solstice", "map11_woodland", "map12_desert",
        "map13_alpine", "map14_storybook", "map15_spice", "map16_meadow",
        "map17_trades", "map18_carnival",
    ]

    private let tBest: TimeInterval = 5
    private let tWorst: TimeInterval = 90
    private let firstRoundFallbackSeconds: UInt64 = 5


    @Published var phase: Phase = .login
    @Published private(set) var current: ParameterSet?
    @Published private(set) var participantID = ""
    @Published private(set) var roundNumber = 0
    @Published private(set) var currentMapName = ""
    @Published private(set) var targetName = ""
    @Published private(set) var isSignedIn = false
    @Published var authError: String?


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

    func endListening() {
        listenTask?.cancel()
        fallbackTask?.cancel()
        repo?.stop()
    }
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

    
    func overviewLoaded(targetName: String) {
        self.targetName = targetName
    }

    
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

    func foundTarget() {
        
        if timeToTarget == nil, let start = explorationStart {
            timeToTarget = Date().timeIntervalSince(start)
        }
        phase = .survey
    }

    var objectiveScore: Double {
        guard let t = timeToTarget else { return 0 }
        return min(1, max(0, (tWorst - t) / (tWorst - tBest)))
    }


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

    func continueWithCurrentSettings() {
        guard phase == .waitingForParameters, let params = current else { return }
        startRound(with: params)
    }

    /// From the error screen: go back to the survey and try again.
    func retrySurvey() {
        phase = .survey
    }
}
