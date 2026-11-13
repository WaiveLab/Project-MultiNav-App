// The comments for this .swift file have been annotated by chatGPT

import Combine
import Foundation
import FirebaseCore
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
        let rawAnswers: [String: Any]
        let mapName: String
        let roundNumber: Int
        let timeToTargetSeconds: TimeInterval?
        let touchedTarget: Bool
    }

    // Represents the current stage of the study.
    enum Phase: Equatable {
        case login, learning, readyForStudy, correctingParticipantID
        case waitingForParameters, exploring, survey, submitting, completed
        case error(String)
    }

    static let learningMap = "learning"

    // Only these maps consume MOBO candidates.
    static let overviewMaps: [String] = [
        "map01_orchard", "map02_harbor", "map03_songbird", "map04_gemstone",
        "map06_melody", "map07_palette", "map08_atlas",
        "map09_meridian", "map10_solstice", "map11_woodland", "map12_desert",
        "map13_alpine", "map14_storybook", "map15_spice", "map16_meadow",
        "map17_trades", "map18_carnival",
    ]

    // Published values allow SwiftUI views to react to session changes.
    @Published private(set) var phase: Phase = .login
    @Published private(set) var current: ParameterSet?
    @Published private(set) var participantID = ""
    @Published private(set) var roundNumber = 0
    @Published private(set) var currentMapName = ""
    @Published private(set) var targetName = ""
    @Published private(set) var isLocalTestMode = false
    @Published private(set) var parameterStatusMessage: String?
    @Published private(set) var isRegistering = false
    @Published private(set) var registrationError: String?
    @Published private(set) var parameterWaitTimedOut = false

    // Tracks maps, Firebase updates, and the current round.
    private var mapDeck: [String] = []
    private var deckIndex = 0
    private var repo: MoboRepo?
    private var listenTask: Task<Void, Never>?
    private var registrationTask: Task<Void, Never>?
    private var parameterTimeoutTask: Task<Void, Never>?
    private var activeParameters: PublishedParameters?
    private var pendingParameters: PublishedParameters?
    private var pendingResult: PendingResult?
    private var observedDocumentIDs: Set<String> = []
    private var observedCandidateIDs: Set<String> = []
    private var explorationStart: Date?
    private var timeToTarget: TimeInterval?
    private var touchedTarget = false
    private let sessionID = UUID().uuidString
    private let parameterWaitNanoseconds: UInt64

    init(parameterWaitNanoseconds: UInt64 = 90_000_000_000) {
        self.parameterWaitNanoseconds = parameterWaitNanoseconds
    }

    func begin(participantID rawID: String) {
        let pid = rawID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard phase == .login || phase == .correctingParticipantID else { return }
        guard Self.isValidParticipantID(pid) else {
            registrationError = "Use 1–100 letters, digits, hyphens or underscores; start with a letter or digit."
            return
        }
        participantID = pid
        registrationError = nil
        if phase == .correctingParticipantID {
            phase = .readyForStudy
        } else {
            currentMapName = Self.learningMap
            phase = .learning
        }
    }

    func finishLearning() {
        guard phase == .learning else { return }
        phase = .readyForStudy
    }

    func startMoboStudy() {
        guard phase == .readyForStudy else { return }
        prepareStudyRounds()
        connectParticipant()
    }

    static func isValidParticipantID(_ pid: String) -> Bool {
        pid.range(of: "^[A-Za-z0-9][A-Za-z0-9_-]{0,99}$", options: .regularExpression) != nil
            && !pid.contains("\n") && !pid.contains("\r")
    }

    private func connectParticipant() {
        registrationError = nil
        parameterWaitTimedOut = false
        isRegistering = true
        parameterStatusMessage = nil
        registrationTask = Task { [weak self] in
            guard let self, !Task.isCancelled else { return }
            do {
                if FirebaseApp.app() == nil { FirebaseApp.configure() }
                if Auth.auth().currentUser == nil {
                    _ = try await Auth.auth().signInAnonymously()
                }
                guard !Task.isCancelled else { return }
                let repo = MoboRepo(participantID: participantID)
                self.repo = repo
                if roundNumber == 0 {
                    try await repo.registerParticipant(sessionID: sessionID)
                    guard !Task.isCancelled else { return }
                    parameterStatusMessage = "Participant registered. Waiting for MOBO's first vibration settings…"
                }
                isRegistering = false
                listenForParameters(using: repo)
            } catch {
                guard !Task.isCancelled else { return }
                isRegistering = false
                registrationError = error.localizedDescription
                parameterStatusMessage = nil
            }
        }
    }

    private func listenForParameters(using repo: MoboRepo) {
        beginParameterWait()
        listenTask = Task { [weak self] in
            for await update in repo.parameterUpdates() {
                guard !Task.isCancelled, let self, self.repo === repo else { return }
                switch update {
                case .parameters(let published):
                    self.receive(published)
                case .issue(let message):
                    self.parameterStatusMessage = message
                }
            }
        }
    }

    private func beginParameterWait() {
        parameterTimeoutTask?.cancel()
        parameterWaitTimedOut = false
        let wait = parameterWaitNanoseconds
        parameterTimeoutTask = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: wait) }
            catch { return }
            guard !Task.isCancelled, let self, phase == .waitingForParameters else { return }
            parameterWaitTimedOut = true
        }
    }

    func retryConnection() {
        guard phase == .waitingForParameters, !isLocalTestMode, !isRegistering else { return }
        endListening()
        connectParticipant()
    }

    func changeParticipantID() {
        guard phase == .waitingForParameters, roundNumber == 0 else { return }
        endListening()
        registrationError = nil
        parameterStatusMessage = nil
        phase = .correctingParticipantID
    }

    // Starts an app-only run without requiring Firebase authentication and
    // without candidate reads or result writes. This exists for interface and
    // map testing only.
    func beginLocalTest() {
        guard phase == .readyForStudy else { return }
        prepareStudyRounds()
        continueLocally()
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

    private func prepareStudyRounds() {
        mapDeck = Self.overviewMaps.shuffled()
        deckIndex = 0
        currentMapName = ""
        parameterStatusMessage = nil
        registrationError = nil
        phase = .waitingForParameters
    }

    // Stops listening for new parameter updates.
    func endListening() {
        registrationTask?.cancel()
        registrationTask = nil
        parameterTimeoutTask?.cancel()
        parameterTimeoutTask = nil
        isRegistering = false
        parameterWaitTimedOut = false
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
        guard published.values.phaseStep == expectedStep else {
            if phase == .waitingForParameters {
                parameterStatusMessage = "Waiting for round \(expectedStep); Firebase's newest candidate is round \(published.values.phaseStep)."
            }
            return
        }
        guard observedDocumentIDs.insert(published.documentID).inserted else { return }

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
        case .login, .learning, .readyForStudy, .correctingParticipantID, .completed:
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
        parameterTimeoutTask?.cancel()
        parameterTimeoutTask = nil
        parameterWaitTimedOut = false
        parameterStatusMessage = nil
        startRound()
    }

    // Use the same starting profiles for each local practice round.
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
        guard phase == .exploring else { return }
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
        guard phase == .exploring else { return }
        if timeToTarget == nil, let start = explorationStart {
            timeToTarget = Date().timeIntervalSince(start)
        }
        phase = .survey
    }

    // An unfinished target-finding task earns no speed credit. Finishing the
    // exploration screen alone is not evidence that the target was reached.
    var objectiveScore: Double {
        StudyPerformance.objectiveScore(touchedTarget: touchedTarget,
                                        timeToTarget: timeToTarget)
    }

    // Submits the round's results and prepares for the next round.
    func submit(subjectiveScore: Double,
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

        // A study session has exactly one pass through the 17-map deck.
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
        } else {
            parameterStatusMessage = "Answers saved. Waiting for round \(roundNumber + 1) vibration settings…"
            beginParameterWait()
        }
    }

    // Changes the currently displayed overview map.
    func selectOverviewMap(_ mapName: String) {
        guard phase == .exploring, Self.overviewMaps.contains(mapName) else {
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
