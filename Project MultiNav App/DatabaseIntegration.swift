// The comments for this .swift file have been annotated by chatGPT

import FirebaseAuth
import FirebaseFirestore
import Foundation

private enum MoboRepoError: LocalizedError {
    case missingAuthenticatedUser

    var errorDescription: String? {
        "The Firebase user is no longer signed in."
    }
}

enum ParameterUpdate {
    case parameters(PublishedParameters)
    case issue(String)
}

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

    /// Creates an AsyncStream that emits either the newest valid parameter
    /// document for this participant or a message explaining why it could not
    /// be loaded.
    ///
    /// The underlying Firestore query is a real-time listener, so the stream
    /// can emit a new value whenever the matching query results change.
    func parameterUpdates() -> AsyncStream<ParameterUpdate> {
        AsyncStream { continuation in

            // If another parameter listener is already active, stop it before
            // creating a new one. This means this repository maintains at most
            // one active parameter listener at a time.
            listener?.remove()

            // Listen in real time to this participant's parameter documents.
            //
            // Documents are:
            //   - filtered to the current participant (`pid`)
            //   - filtered to the supported schema version
            //   - sorted newest-first by `createdAt`
            //   - limited to the newest document
            listener = db.collection("parameterValues")
                .whereField("pid", isEqualTo: pid)
                .whereField(
                    "schemaVersion",
                    isEqualTo: ParameterSet.currentSchemaVersion
                )
                .order(by: "createdAt", descending: true)
                .limit(to: 1)
                .addSnapshotListener(includeMetadataChanges: true) { snapshot, error in

                    if let error {
                        print("parameterUpdates error: \(error)")
                        continuation.yield(
                            .issue("Could not load Firebase parameters: \(error.localizedDescription)")
                        )
                        return
                    }

                    guard let snapshot else { return }

                    // Firestore can immediately emit an older locally cached
                    // candidate before it has checked the server. Starting a
                    // research round from that value would associate the map
                    // and survey with the wrong optimizer candidate, so wait
                    // for a server-confirmed snapshot instead.
                    if snapshot.metadata.isFromCache {
                        continuation.yield(
                            .issue("Checking Firebase for the latest haptic candidate…")
                        )
                        return
                    }

                    // Take the newest matching document and attempt to
                    // convert its complete nested haptic map into one
                    // ParameterSet. ParameterSet's initializer is strict:
                    // an incomplete per-element candidate is rejected as a
                    // whole rather than being combined with local defaults.
                    //
                    // If there is no matching server document, keep the app on
                    // its waiting screen and explain what MOBO must publish.
                    guard let doc = snapshot.documents.first else {
                        continuation.yield(
                            .issue("No haptic candidate is available for this participant yet.")
                        )
                        return
                    }
                    let data = doc.data()

                    guard data["createdAt"] is Timestamp else {
                        continuation.yield(
                            .issue("Candidate \(doc.documentID) has an invalid createdAt value. It must be a Firestore timestamp.")
                        )
                        return
                    }

                    guard let params = ParameterSet(document: data) else {
                        continuation.yield(
                            .issue("Candidate \(doc.documentID) does not match the complete schema-version-2 haptic format.")
                        )
                        return
                    }

                    // Emit the parameter values along with the Firestore
                    // document ID that they came from.
                    continuation.yield(
                        .parameters(PublishedParameters(
                            documentID: doc.documentID,
                            values: params
                        ))
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
    /// - writes one deterministic document per session and round
    func submitResult(
        tested: ParameterSet,
        parameterDocumentID: String,
        candidateID: String,
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
        guard let authUID = Auth.auth().currentUser?.uid else {
            throw MoboRepoError.missingAuthenticatedUser
        }

        // A stable document path makes a retry of an ambiguous network write
        // overwrite the same logical observation instead of giving MOBO two
        // result documents for one participant round.
        let resultDocumentID = "\(sessionID)-round-\(roundNumber)"

        // Build the base result document.
        var doc: [String: Any] = [
            "pid": pid,
            "authUid": authUID,
            "resultId": resultDocumentID,
            // These two IDs close the optimizer loop: the result identifies
            // the exact Firestore document and logical MOBO candidate that
            // produced the haptics tested during this round.
            "parameterDocumentId": parameterDocumentID,
            "candidateId": candidateID,
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

        // Add the complete tested parameter snapshot to the result document.
        // This includes every independently optimized element profile, not
        // merely a reference to a mutable parameter document.
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

        // `setData` at the deterministic path is idempotent for this round.
        // Because it is awaited and the method is `throws`, the caller can
        // detect a Firestore write failure.
        try await db.collection("interventionResults")
            .document(resultDocumentID)
            .setData(doc)
    }
}
