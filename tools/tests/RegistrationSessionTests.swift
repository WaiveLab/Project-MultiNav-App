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
        let offline = StudySession()
        offline.begin(participantID: "offline")
        session.begin(participantID: " 101 ")
        session.begin(participantID: "other")
        precondition(session.participantID == "101" && session.phase == .learning)
        session.selectOverviewMap(StudySession.overviewMaps[0])
        precondition(session.currentMapName == offline.currentMapName && session.currentMapName == StudySession.learningMap)
        precondition(!StudySession.overviewMaps.contains(session.currentMapName))
        session.overviewLoaded(targetName: "Practice end")
        session.elementEntered(name: "Practice end", typeRaw: "end")
        session.foundTarget()
        session.submit(subjectiveScore: 1, rawAnswers: [:])
        session.startMoboStudy()
        precondition(session.phase == .learning && session.roundNumber == 0 && session.current == nil)
        precondition(session.targetName.isEmpty && session.objectiveScore == 0)
        session.finishLearning()
        precondition(session.phase == .readyForStudy)
        offline.finishLearning()
        offline.beginLocalTest()
        precondition(offline.isLocalTestMode && offline.roundNumber == 1 && offline.phase == .exploring)
        precondition(FirebaseApp.app() == nil && MoboRepo.instances.isEmpty)

        Auth.instance.signInFails = true
        session.startMoboStudy()
        session.startMoboStudy()
        try await until { session.registrationError != nil }
        precondition(session.phase == .waitingForParameters && MoboRepo.instances.isEmpty)
        Auth.instance.signInFails = false
        session.retryConnection()
        session.retryConnection()
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
        var visited = Set([session.currentMapName])
        first.emit(step: 1)
        await Task.yield()
        precondition(session.roundNumber == 1)
        session.foundTarget()
        session.submit(subjectiveScore: 0.5, rawAnswers: [:])
        try await until { session.phase == .waitingForParameters }
        precondition(first.submitted == ["step-1"])
        session.retryConnection()
        try await until { MoboRepo.instances.last !== first && MoboRepo.instances.last?.continuation != nil }
        let next = MoboRepo.instances.last!
        precondition(first.stopped && next.registrations.isEmpty) // Later rounds only restart the listener.
        for step in 2...StudySession.overviewMaps.count {
            next.emit(step: step)
            try await until { session.phase == .exploring }
            precondition(session.roundNumber == step && visited.insert(session.currentMapName).inserted)
            session.foundTarget()
            precondition(session.phase == .survey)
            let isLast = step == StudySession.overviewMaps.count
            next.submissionFails = isLast
            session.submit(subjectiveScore: 1, rawAnswers: [:])
            if isLast {
                try await until { if case .error = session.phase { return true }; return false }
                next.submissionFails = false
                session.retrySubmission()
            }
            try await until { session.phase == (isLast ? .completed : .waitingForParameters) }
        }
        precondition(visited == Set(StudySession.overviewMaps))
        precondition(first.submitted + next.submitted == (1...17).map { "step-\($0)" })
        precondition(next.stopped)

        MoboRepo.registrationFails = true
        let retry = StudySession()
        retry.begin(participantID: "201")
        retry.finishLearning()
        retry.startMoboStudy()
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
        cancelled.begin(participantID: "301")
        cancelled.finishLearning()
        cancelled.startMoboStudy()
        try await until { MoboRepo.instances.last !== retried && MoboRepo.instances.last?.registrations.isEmpty == false }
        let abandoned = MoboRepo.instances.last!
        cancelled.changeParticipantID()
        cancelled.begin(participantID: "local")
        precondition(cancelled.phase == .readyForStudy && cancelled.participantID == "local")
        cancelled.beginLocalTest()
        try await Task.sleep(nanoseconds: 70_000_000)
        precondition(cancelled.isLocalTestMode && cancelled.roundNumber == 1)
        precondition(abandoned.continuation == nil && abandoned.stopped)
        precondition(Auth.auth().signs == 2) // One failed attempt, then reuse the successful identity.
        print("Passed offline learning, MOBO handoff, all 17 submissions, final screen, retries, cancellation and local testing.")
    }
}
