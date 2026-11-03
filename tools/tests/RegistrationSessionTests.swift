import Foundation

@main @MainActor struct RegistrationSessionTests {
    static func until(_ condition: () -> Bool) async throws {
        for _ in 0..<500 {
            if condition() { return }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        preconditionFailure("Asynchronous session condition did not arrive")
    }

    static func main() async throws {
        for pid in ["101", "201", "pc-test-abc_1"] { precondition(StudySession.isValidParticipantID(pid)) }
        for pid in ["", "a/b", "101\n", " a", String(repeating: "a", count: 101)] {
            precondition(!StudySession.isValidParticipantID(pid))
        }
        let session = StudySession(parameterWaitNanoseconds: 50_000_000)
        await session.signIn()
        session.begin(participantID: "101")
        session.begin(participantID: "101") // Repeated taps cannot launch a second registration.
        try await until { MoboRepo.instances.last?.continuation != nil }
        let first = MoboRepo.instances.last!
        precondition(MoboRepo.instances.count == 1 && first.registrations.count == 1)
        precondition(session.roundNumber == 0 && session.current == nil) // No local fallback.
        try await until { session.parameterWaitTimedOut }
        first.emit(step: 8)
        try await until { session.parameterStatusMessage?.contains("round 8") == true }
        precondition(session.roundNumber == 0)
        first.emit(step: 1) // Late response after timeout still starts round one.
        try await until { session.phase == .exploring }
        precondition(!session.parameterWaitTimedOut && session.roundNumber == 1)
        first.emit(step: 1)
        await Task.yield()
        precondition(session.roundNumber == 1)
        session.foundTarget()
        session.submit(subjectiveScore: 0.5, rawAnswers: [:])
        try await until { session.phase == .waitingForParameters }
        precondition(first.submitted == ["step-1"])
        session.retryConnection()
        try await until { MoboRepo.instances.last?.continuation != nil }
        let next = MoboRepo.instances.last!
        precondition(first.stopped && next.registrations.isEmpty) // Later rounds only restart the listener.
        next.emit(step: 2)
        try await until { session.roundNumber == 2 }
        session.endListening()

        MoboRepo.registrationFails = true
        let retry = StudySession()
        await retry.signIn()
        retry.begin(participantID: "201")
        try await until { retry.registrationError != nil }
        let failed = MoboRepo.instances.last!
        precondition(failed.continuation == nil && retry.current == nil)
        MoboRepo.registrationFails = false
        retry.retryConnection()
        try await until { MoboRepo.instances.last?.continuation != nil }
        let retried = MoboRepo.instances.last!
        precondition(retried.registrations == failed.registrations) // Idempotent backend retry uses same session ID.
        retry.endListening()

        MoboRepo.registrationDelay = 50_000_000
        let cancelled = StudySession()
        await cancelled.signIn()
        cancelled.begin(participantID: "301")
        try await until { MoboRepo.instances.last?.registrations.isEmpty == false }
        let abandoned = MoboRepo.instances.last!
        cancelled.returnToLogin()
        cancelled.beginLocalTest(participantID: "local")
        try await Task.sleep(nanoseconds: 70_000_000)
        precondition(cancelled.isLocalTestMode && cancelled.roundNumber == 1)
        precondition(abandoned.continuation == nil && abandoned.stopped)
        precondition(Auth.auth().signs == 1) // Existing anonymous identity is reused.
        print("Passed phone session: registration-before-listening, duplicate taps, timeout/late candidate, wrong round, submission, reconnect, retry, cancellation and local mode.")
    }
}
