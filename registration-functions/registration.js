"use strict";

// Dependency injection keeps the real transaction logic testable without cloud access.
function makeRegistration({ db, serverTimestamp, HttpsError }) {
  return async function register(request) {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Sign in before connecting.");
    const { pid, sessionId } = request.data || {};
    if (typeof pid !== "string" || pid.trim() !== pid || !/^[A-Za-z0-9][A-Za-z0-9_-]{0,99}$/.test(pid)) {
      throw new HttpsError("invalid-argument", "Use a participant ID of 1–100 letters, digits, hyphens or underscores.");
    }
    if (typeof sessionId !== "string" || sessionId.trim() !== sessionId || !/^[A-Za-z0-9-]{1,100}$/.test(sessionId)) {
      throw new HttpsError("invalid-argument", "A valid study session ID is required.");
    }
    const user = db.collection("users").doc(pid);
    return db.runTransaction(async (transaction) => {
      const existing = await transaction.get(user);
      const data = existing.data() || {};
      if (data.registrationSessionId) {
        if (data.registrationSessionId === sessionId && data.registrationAuthUid === uid) {
          return { status: "registered", pid }; // Retrying the same request never creates another user.
        }
        throw new HttpsError("already-exists", "This participant ID is already registered to another session. Use a new participant ID for a new study run.");
      }
      // Pre-registered, unused IDs are supported. Never restart a participant's history.
      const results = await transaction.get(db.collection("interventionResults").where("pid", "==", pid).limit(1));
      const candidates = await transaction.get(db.collection("parameterValues")
        .where("pid", "==", pid).where("schemaVersion", "==", 2)
        .orderBy("createdAt", "desc").limit(1));
      if (data.studyCompleted === true || !results.empty ||
          (!candidates.empty && candidates.docs[0].data().phaseStep !== 1)) {
        throw new HttpsError("failed-precondition", "This participant ID has already started a study. Use a new participant ID for a new run.");
      }
      const registration = {
        registrationAuthUid: uid, registrationSessionId: sessionId,
        registrationSource: "ios-app", registeredAt: serverTimestamp(),
      };
      if (existing.exists) {
        transaction.update(user, registration);
      } else {
        transaction.create(user, { pid, createdAt: serverTimestamp(), ...registration });
      }
      // Creating users/{pid} invokes the existing registerUserOnCreate function.
      // Updating a pre-registered user leaves its candidate/ongoing trigger intact.
      return { status: "registered", pid };
    });
  };
}

module.exports = { makeRegistration };
