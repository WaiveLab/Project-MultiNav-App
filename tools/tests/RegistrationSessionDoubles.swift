import Foundation

protocol ObservableObject {}
@propertyWrapper struct Published<Value> { var wrappedValue: Value }

@MainActor final class Auth {
    static let instance = Auth()
    static func auth() -> Auth { instance }
    var currentUser: Int? = nil
    var signs = 0
    func signInAnonymously() async throws -> Int {
        signs += 1
        currentUser = 1
        return 1
    }
}

enum ParameterUpdate {
    case parameters(PublishedParameters)
    case issue(String)
}

enum TestFailure: Error { case registration }

@MainActor final class MoboRepo {
    static var instances: [MoboRepo] = []
    static var registrationFails = false
    static var registrationDelay: UInt64 = 0
    var registrations: [String] = []
    var stopped = false
    var submitted: [String] = []
    var continuation: AsyncStream<ParameterUpdate>.Continuation?
    init(participantID: String) { Self.instances.append(self) }
    func registerParticipant(sessionID: String) async throws {
        registrations.append(sessionID)
        if Self.registrationDelay > 0 { try? await Task.sleep(nanoseconds: Self.registrationDelay) }
        if Self.registrationFails { throw TestFailure.registration }
    }
    func parameterUpdates() -> AsyncStream<ParameterUpdate> {
        AsyncStream { continuation = $0 }
    }
    func stop() { stopped = true; continuation?.finish() }
    func emit(step: Int) {
        let parameters = ParameterSet(haptics: ParameterSet.defaultHaptics, candidateID: "candidate-\(step)", phaseStep: step)!
        continuation?.yield(.parameters(PublishedParameters(documentID: "step-\(step)", values: parameters)))
    }
    func submitResult(tested: ParameterSet, parameterDocumentID: String, candidateID: String,
                      subjectiveScore: Double, objectiveScore: Double, rawQuestionnaire: [String: Any],
                      mapName: String, roundNumber: Int, timeToTargetSeconds: TimeInterval?,
                      touchedTarget: Bool, sessionID: String) async throws {
        submitted.append(parameterDocumentID)
    }
}
