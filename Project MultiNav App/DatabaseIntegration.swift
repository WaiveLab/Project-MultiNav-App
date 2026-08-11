
import FirebaseFirestore

final class MoboRepo {

    private let pid: String
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    init(participantID: String) {
        self.pid = participantID
    }
    func parameterUpdates() -> AsyncStream<PublishedParameters> {
        AsyncStream { continuation in
            listener?.remove()
            listener = db.collection("parameterValues")
                .whereField("pid", isEqualTo: pid)
                .order(by: "createdAt", descending: true)
                .limit(to: 1)
                .addSnapshotListener { snapshot, error in
                    if let error {
                        print("parameterUpdates error: \(error)")
                        return
                    }
                    guard let doc = snapshot?.documents.first,
                          let params = ParameterSet(document: doc.data())
                    else { return }
                    continuation.yield(PublishedParameters(documentID: doc.documentID,
                                                           values: params))
                }
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in self?.stop() }
            }
        }
    }

    func stop() {
        listener?.remove()
        listener = nil
    }

    func submitResult(
        tested: ParameterSet,
        subjectiveScore: Double,
        objectiveScore: Double,
        attentionCheckPassed: Bool,
        rawQuestionnaire: [String: Any],
        mapName: String,
        roundNumber: Int,
        timeToTargetSeconds: TimeInterval?,
        touchedTarget: Bool,
        sessionID: String
    ) async throws {
        var doc: [String: Any] = [
            "pid": pid,
            "attentionCheckPassed": attentionCheckPassed,
            "subjectiveScore": min(1, max(0, subjectiveScore)),
            "objectiveScore": min(1, max(0, objectiveScore)),
            "mapName": mapName,
            "roundNumber": roundNumber,
            "touchedTarget": touchedTarget,
            "sessionId": sessionID,
            "createdAt": FieldValue.serverTimestamp(),
        ]
        if let t = timeToTargetSeconds {
            doc["timeToTargetSeconds"] = t
        }
        doc.merge(tested.asResultFields) { current, _ in current }
        doc.merge(rawQuestionnaire) { current, _ in current }

        try await db.collection("interventionResults").addDocument(data: doc)
    }
}
