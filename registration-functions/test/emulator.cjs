"use strict";
// Hard-coded local demo environment: this check cannot target live Firebase.
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8197";
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { HttpsError } = require("firebase-functions/v2/https");
const { makeRegistration } = require("../registration");
const assert = require("node:assert/strict");

async function main() {
  const db = getFirestore(initializeApp({ projectId: "demo-multinav-pc-tester" }));
  const register = makeRegistration({ db, HttpsError, serverTimestamp: () => FieldValue.serverTimestamp() });
  const pid = `ios-registration-test-${Date.now()}`;
  const request = { auth: { uid: "phone-one" }, data: { pid, sessionId: "session-one" } };
  const attempts = await Promise.allSettled([
    register(request), register({ auth: { uid: "phone-two" }, data: { pid, sessionId: "session-two" } }),
  ]);
  assert.equal(attempts.filter(a => a.status === "fulfilled").length, 1);
  const user = await db.collection("users").doc(pid).get();
  assert.equal(user.data().pid, pid);
  assert(user.data().createdAt.toMillis() > 0);
  const winningRequest = user.data().registrationAuthUid === "phone-one" ? request
    : { auth: { uid: "phone-two" }, data: { pid, sessionId: "session-two" } };
  const before = user.updateTime.toMillis();
  await register(winningRequest);
  assert.equal((await user.ref.get()).updateTime.toMillis(), before);
  // Existing PC/pre-registered records can be claimed if unused.
  const pre = `${pid}-preregistered`;
  await db.collection("users").doc(pre).create({ pid: pre });
  await register({ ...request, data: { ...request.data, pid: pre } });
  const used = `${pid}-used`;
  await db.collection("interventionResults").doc(used).create({ pid: used });
  await assert.rejects(register({ ...request, data: { ...request.data, pid: used } }), { code: "failed-precondition" });
  assert.equal((await db.collection("users").doc(used).get()).exists, false);
  console.log("PASS: actual Firestore transactions create one user, reject concurrent sessions, retry without writes, claim unused IDs and reject prior results. LOCAL EMULATOR ONLY.");
  await db.terminate();
}
main().catch(error => { console.error(error); process.exitCode = 1; });
