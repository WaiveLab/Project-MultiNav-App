// The comments for this .swift file have been annotated by chatGPT

import Combine
import Foundation
import FirebaseAuth
import TactileMapCore

// Manages authentication, study rounds, maps, parameters, and results.
@MainActor
final class StudySession: ObservableObject {

    // Captures one round's exact observation before the first upload attempt.
    // If Firestore acknowledgement is ambiguous, retrying sends these same
    // answers and measurements rather than presenting a new survey.
    private struct PendingResult {
        let tested: ParameterSet
        let parameterDocumentID: String
        let candidateID: String
        let subjectiveScore: Double
        let objectiveScore: Double
        let attentionCheckPassed: Bool
        let rawAnswers: [String: Any]
        let mapName: String
        let roundNumber: Int
        let timeToTargetSeconds: TimeInterval?
        let touchedTarget: Bool
    }

    // Represents the current stage of the study.
    enum Phase: Equatable {
        case login, waitingForParameters, exploring, survey, submitting, completed
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

    // Published values allow SwiftUI views to react to session changes.
    @Published var phase: Phase = .login
    @Published private(set) var current: ParameterSet?
    @Published private(set) var participantID = ""
    @Published private(set) var roundNumber = 0
    @Published private(set) var currentMapName = ""
    @Published private(set) var targetName = ""
    @Published private(set) var isSignedIn = false
    @Published private(set) var isLocalTestMode = false
    @Published private(set) var parameterStatusMessage: String?
    @Published var authError: String?

    // Tracks maps, Firebase updates, and the current round.
    private var mapDeck: [String] = []
    private var deckIndex = 0
    private var repo: MoboRepo?
    private var listenTask: Task<Void, Never>?
    private var activeParameters: PublishedParameters?
    private var pendingParameters: PublishedParameters?
    private var pendingResult: PendingResult?
    private var observedDocumentIDs: Set<String> = []
    private var observedCandidateIDs: Set<String> = []
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
        // Beginning is a one-shot transition out of the login screen. This
        // prevents rapid repeated activations from leaving two Firestore
        // listeners feeding the same reset session.
        guard phase == .login, isSignedIn, !pid.isEmpty else { return }
        prepareSession(participantID: pid, localTestMode: false)

        let repo = MoboRepo(participantID: pid)
        self.repo = repo
        listenTask = Task { [weak self] in
            for await update in repo.parameterUpdates() {
                switch update {
                case .parameters(let published):
                    self?.parameterStatusMessage = nil
                    self?.receive(published)
                case .issue(let message):
                    self?.parameterStatusMessage = message
                }
            }
        }
    }

    // Starts an app-only run without requiring Firebase authentication and
    // without candidate reads or result writes. This exists for interface and
    // map testing only.
    func beginLocalTest(participantID rawID: String) {
        let pid = rawID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard phase == .login, !pid.isEmpty else { return }
        prepareSession(participantID: pid, localTestMode: true)
        activateNextLocalCandidate()
    }

    // Switches a connected run to local values while it is waiting for MOBO.
    // Previously completed Firebase rounds are left untouched.
    func continueLocally() {
        guard phase == .waitingForParameters,
              roundNumber < Self.overviewMaps.count
        else { return }

        endListening()
        isLocalTestMode = true
        pendingParameters = nil
        parameterStatusMessage = nil
        activateNextLocalCandidate()
    }

    private func prepareSession(participantID: String, localTestMode: Bool) {
        endListening()
        self.participantID = participantID
        isLocalTestMode = localTestMode

        mapDeck = Self.overviewMaps.shuffled()
        deckIndex = 0
        roundNumber = 0
        current = nil
        activeParameters = nil
        pendingParameters = nil
        pendingResult = nil
        observedDocumentIDs.removeAll()
        observedCandidateIDs.removeAll()
        parameterStatusMessage = nil
        phase = .waitingForParameters
    }

    // Stops listening for new parameter updates.
    func endListening() {
        listenTask?.cancel()
        listenTask = nil
        repo?.stop()
        repo = nil
    }

    // Processes new parameters, either starting a round or saving them for later.
    private func receive(_ published: PublishedParameters) {
        guard !isLocalTestMode,
              roundNumber < Self.overviewMaps.count
        else { return }

        // Validate ordering before recording identity. If MOBO accidentally
        // publishes a future step early, a corrected document with the same
        // candidate ID can still be accepted once that step is expected.
        let expectedStep = roundNumber + 1
        guard published.values.phaseStep == expectedStep,
              observedDocumentIDs.insert(published.documentID).inserted
        else { return }

        // `candidateID` is the optimizer's stable identity for a candidate.
        // Fall back to the Firestore document ID so older schema-v2 writers
        // still cannot cause the same document to be tested twice.
        let candidateID = resolvedCandidateID(for: published)
        guard observedCandidateIDs.insert(candidateID).inserted else { return }

        switch phase {
        case .waitingForParameters:
            activate(published)
        case .exploring, .survey, .submitting, .error:
            // The query emits newest-first, so replacing this value keeps the
            // newest candidate for the next round while the current round is
            // still in progress (or its submission is being retried). It is
            // not made active before a successful submission.
            pendingParameters = published
        case .login, .completed:
            break
        }
    }

    private func resolvedCandidateID(for published: PublishedParameters) -> String {
        published.values.candidateID ?? published.documentID
    }

    // Makes one complete Firestore document the immutable candidate for a round.
    private func activate(_ published: PublishedParameters) {
        guard phase == .waitingForParameters,
              published.values.phaseStep == roundNumber + 1
        else { return }

        activeParameters = published
        current = published.values
        startRound()
    }

    // Creates a complete local candidate with the same 14 independent burst
    // profiles used by the app defaults and the expected round number.
    private func activateNextLocalCandidate() {
        let step = roundNumber + 1
        let candidateID = "local-\(sessionID)-round-\(step)"
        guard isLocalTestMode,
              let values = ParameterSet(
                haptics: ParameterSet.defaultHaptics,
                candidateID: candidateID,
                phase: "exploration",
                phaseStep: step
              )
        else {
            phase = .error("The local test haptic settings could not be loaded.")
            return
        }

        activate(PublishedParameters(documentID: candidateID, values: values))
    }

    // Selects the next map and begins a new exploration round.
    private func startRound() {
        guard roundNumber < Self.overviewMaps.count,
              deckIndex < mapDeck.count
        else {
            endListening()
            phase = .completed
            return
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
        guard phase == .survey,
              let activeParameters
        else { return }

        // Local testing still displays and exercises the survey, but does not
        // retain or upload participant responses.
        if isLocalTestMode {
            finishRound(completedRound: roundNumber)
            return
        }

        guard pendingResult == nil else { return }

        pendingResult = PendingResult(
            tested: activeParameters.values,
            parameterDocumentID: activeParameters.documentID,
            candidateID: resolvedCandidateID(for: activeParameters),
            subjectiveScore: subjectiveScore,
            objectiveScore: objectiveScore,
            attentionCheckPassed: attentionCheckPassed,
            rawAnswers: rawAnswers,
            mapName: currentMapName,
            roundNumber: roundNumber,
            timeToTargetSeconds: timeToTarget,
            touchedTarget: touchedTarget
        )
        submitPendingResult()
    }

    // Uploads the immutable payload captured by `submit`. A retry reaches this
    // method with the same PendingResult, so it cannot change the survey or
    // measured trial values for the deterministic result document.
    private func submitPendingResult() {
        guard let pendingResult, let repo else { return }
        phase = .submitting
        Task {
            do {
                try await repo.submitResult(
                    tested: pendingResult.tested,
                    parameterDocumentID: pendingResult.parameterDocumentID,
                    candidateID: pendingResult.candidateID,
                    subjectiveScore: pendingResult.subjectiveScore,
                    objectiveScore: pendingResult.objectiveScore,
                    attentionCheckPassed: pendingResult.attentionCheckPassed,
                    rawQuestionnaire: pendingResult.rawAnswers,
                    mapName: pendingResult.mapName,
                    roundNumber: pendingResult.roundNumber,
                    timeToTargetSeconds: pendingResult.timeToTargetSeconds,
                    touchedTarget: pendingResult.touchedTarget,
                    sessionID: sessionID
                )

                finishRound(completedRound: pendingResult.roundNumber)
            } catch {
                phase = .error("Submission failed: \(error.localizedDescription)")
            }
        }
    }

    private func finishRound(completedRound: Int) {
        pendingResult = nil

        // A study session has exactly one pass through the 18-map deck.
        if completedRound >= Self.overviewMaps.count {
            pendingParameters = nil
            current = nil
            activeParameters = nil
            endListening()
            phase = .completed
            return
        }

        current = nil
        activeParameters = nil
        phase = .waitingForParameters

        if isLocalTestMode {
            activateNextLocalCandidate()
        } else if let pending = pendingParameters {
            pendingParameters = nil
            activate(pending)
        }
    }

    // Changes the currently displayed overview map.
    func selectOverviewMap(_ mapName: String) {
        guard Self.overviewMaps.contains(mapName) else {
            return
        }

        currentMapName = mapName
    }

    // Retries the exact same captured result after an upload error.
    func retrySubmission() {
        guard case .error = phase, pendingResult != nil else { return }
        submitPendingResult()
    }

    // Discards an unsent result after an upload failure and continues the
    // remaining maps locally. No further Firebase reads or writes are made.
    func skipFailedUploadAndContinueLocally() {
        guard case .error = phase, let pendingResult else { return }
        endListening()
        isLocalTestMode = true
        pendingParameters = nil
        parameterStatusMessage = nil
        finishRound(completedRound: pendingResult.roundNumber)
    }
}
