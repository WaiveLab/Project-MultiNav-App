"use strict";
const { test } = require("node:test");
const assert = require("node:assert/strict");
const { makeRegistration } = require("../registration");

class HttpsError extends Error {
  constructor(code, message) { super(message); this.code = code; }
}

function fixture({ user, results = [], candidates = [] } = {}) {
  const state = { user, creates: 0, updates: 0 };
  const db = {
    collection(name) {
      const query = { name, doc: () => ({ name, id: "101" }),
        where: () => query, limit: () => query, orderBy: () => query };
      return query;
    },
    runTransaction: async (callback) => callback({
      get: async (ref) => ref.name === "users"
        ? { exists: state.user !== undefined, data: () => state.user }
        : { empty: !(ref.name === "interventionResults" ? results : candidates).length,
            docs: (ref.name === "interventionResults" ? results : candidates).map(value => ({ data: () => value })) },
      create: (_, data) => { assert.equal(state.user, undefined); state.user = data; state.creates++; },
      update: (_, data) => { state.user = { ...state.user, ...data }; state.updates++; },
    }),
  };
  return { state, register: makeRegistration({ db, HttpsError, serverTimestamp: () => "SERVER_TIME" }) };
}
const request = (data = {}, uid = "uid-one") => ({ auth: { uid }, data: { pid: "101", sessionId: "session-one", ...data } });

test("new ID creates the user once; identical retries preserve the trigger source", async () => {
  const { state, register } = fixture();
  assert.deepEqual(await register(request()), { status: "registered", pid: "101" });
  assert.equal(state.user.pid, "101");
  assert.equal(state.user.registrationAuthUid, "uid-one");
  assert.equal(state.user.createdAt, "SERVER_TIME");
  await register(request());
  assert.equal(state.creates, 1);
  assert.equal(state.updates, 0);
});

test("anonymous Firebase users are accepted; unauthenticated calls are rejected", async () => {
  const { register, state } = fixture();
  await assert.rejects(register({ data: request().data }), { code: "unauthenticated" });
  assert.equal(state.creates, 0);
});

test("invalid IDs and sessions cannot become document paths", async () => {
  const { register, state } = fixture();
  for (const pid of ["", "../101", "a/b", "101\n", " 101", "a".repeat(101), 101, null]) {
    await assert.rejects(register(request({ pid })), { code: "invalid-argument" });
  }
  for (const sessionId of ["", "bad/session", "session\n", null]) {
    await assert.rejects(register(request({ sessionId })), { code: "invalid-argument" });
  }
  assert.equal(state.creates, 0);
});

test("another identity or session cannot overwrite a registered participant", async () => {
  const { register, state } = fixture();
  await register(request());
  const original = { ...state.user };
  await assert.rejects(register(request({ sessionId: "session-two" })), { code: "already-exists" });
  await assert.rejects(register(request({}, "uid-two")), { code: "already-exists" });
  assert.deepEqual(state.user, original);
});

test("pre-registered unused round-one IDs can be claimed without recreating users", async () => {
  const { register, state } = fixture({ user: { pid: "101", createdAt: "old-time" }, candidates: [{ phaseStep: 1 }] });
  await register(request());
  assert.equal(state.creates, 0);
  assert.equal(state.updates, 1);
  assert.equal(state.user.createdAt, "old-time");
  assert.equal(state.user.registrationSessionId, "session-one");
});

test("prior results, later candidates and completed users are rejected without writes", async () => {
  for (const setup of [{ user: { studyCompleted: true } }, { results: [{ pid: "101" }] }, { candidates: [{ phaseStep: 8 }] }]) {
    const { register, state } = fixture(setup);
    await assert.rejects(register(request()), { code: "failed-precondition" });
    assert.equal(state.creates + state.updates, 0);
  }
});

test("database failure propagates; no false registration acknowledgement", async () => {
  const register = makeRegistration({ db: {
    collection: () => ({ doc: () => ({}) }),
    runTransaction: async () => { throw new Error("Firestore unavailable"); },
  }, HttpsError, serverTimestamp: () => 0 });
  await assert.rejects(register(request()), /Firestore unavailable/);
});
