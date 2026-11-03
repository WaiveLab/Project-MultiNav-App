"use strict";
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const logger = require("firebase-functions/logger");
const { makeRegistration } = require("./registration");

initializeApp();
const register = makeRegistration({
  db: getFirestore(), serverTimestamp: () => FieldValue.serverTimestamp(), HttpsError,
});

exports.registerParticipant = onCall({
  region: "us-central1", timeoutSeconds: 30, maxInstances: 5,
}, async (request) => {
  try {
    return await register(request);
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    logger.error("Participant registration failed", error);
    throw new HttpsError("internal", "Registration could not be completed. Try Connect again or contact the researcher.");
  }
});
