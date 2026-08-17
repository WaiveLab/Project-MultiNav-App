// The comments for this .swift file have been annotated by chatGPT

import FirebaseFirestore

final class MoboRepo {

    /// Participant ID used to filter parameter documents and associate results
    /// with the participant.
    private let pid: String

    /// Shared Firestore database instance.
    private let db = Firestore.firestore()

    /// The currently active Firestore snapshot listener, if any.
    /// `parameterUpdates()` replaces an existing listener when called again.
    private var listener: ListenerRegistration?

    init(participantID: String) {
        self.pid = participantID
    }

    /// Creates an AsyncStream that emits the most recently created
    /// `PublishedParameters` document for this participant.
    ///
    /// The underlying Firestore query is a real-time listener, so the stream
    /// can emit a new value whenever the matching query results change.
    func parameterUpdates() -> AsyncStream<PublishedParameters> {
        AsyncStream { continuation in

            // If another parameter listener is already active, stop it before
            // creating a new one. This means this repository maintains at most
            // one active parameter listener at a time.
            listener?.remove()

            // Listen in real time to this participant's parameter documents.
            //
            // Documents are:
            //   - filtered to the current participant (`pid`)
            //   - sorted newest-first by `createdAt`
            //   - limited to the newest document
            listener = db.collection("parameterValues")
                .whereField("pid", isEqualTo: pid)
                .order(by: "createdAt", descending: true)
                .limit(to: 1)
                .addSnapshotListener { snapshot, error in

                    // Firestore errors are logged, but are NOT propagated
                    // through the AsyncStream. The stream simply receives
                    // no value for this callback.
                    if let error {
                        print("parameterUpdates error: \(error)")
                        return
                    }

                    // Take the newest matching document and attempt to
                    // convert its data into a ParameterSet.
                    //
                    // If there is no matching document or conversion fails,
                    // nothing is yielded to the stream.
                    guard let doc = snapshot?.documents.first,
                          let params = ParameterSet(document: doc.data())
                    else { return }

                    // Emit the parameter values along with the Firestore
                    // document ID that they came from.
                    continuation.yield(
                        PublishedParameters(
                            documentID: doc.documentID,
                            values: params
                        )
                    )
                }

            // When the consumer stops consuming/cancels the AsyncStream,
            // remove the Firestore listener so it does not continue receiving
            // updates.
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in
                    self?.stop()
                }
            }
        }
    }

    /// Stops the currently active Firestore parameter listener.
    func stop() {
        listener?.remove()
        listener = nil
    }

    /// Stores the result of an intervention/trial in Firestore.
    ///
    /// The method:
    /// - records participant/session/round metadata
    /// - clamps subjective and objective scores to the range 0...1
    /// - optionally records time-to-target
    /// - adds the tested parameter values
    /// - adds the raw questionnaire fields
    /// - creates a new document in `interventionResults`
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

        // Build the base result document.
        var doc: [String: Any] = [
            "pid": pid,
            "attentionCheckPassed": attentionCheckPassed,

            // Clamp subjectiveScore to [0, 1].
            // Values below 0 become 0; values above 1 become 1.
            "subjectiveScore": min(1, max(0, subjectiveScore)),

            // Clamp objectiveScore to [0, 1].
            "objectiveScore": min(1, max(0, objectiveScore)),

            "mapName": mapName,
            "roundNumber": roundNumber,
            "touchedTarget": touchedTarget,
            "sessionId": sessionID,

            // Firestore assigns the server's timestamp when the document
            // is written. This avoids relying on the device's local clock.
            "createdAt": FieldValue.serverTimestamp(),
        ]

        // Only include timeToTargetSeconds when a value was supplied.
        if let t = timeToTargetSeconds {
            doc["timeToTargetSeconds"] = t
        }

        // Add the tested parameter values to the result document.
        //
        // If a key from `tested.asResultFields` already exists in `doc`,
        // the existing value in `doc` wins because the merge closure
        // returns `current`.
        doc.merge(tested.asResultFields) { current, _ in current }

        // Add the raw questionnaire fields.
        //
        // Again, if a questionnaire key conflicts with an existing key,
        // the existing value in `doc` is retained rather than overwritten.
        doc.merge(rawQuestionnaire) { current, _ in current }

        // Create a new document in `interventionResults`.
        //
        // `addDocument` lets Firestore generate the document ID.
        // Because this is awaited and the method is `throws`, the caller
        // can detect a Firestore write failure.
        try await db.collection("interventionResults").addDocument(data: doc)
    }
}
