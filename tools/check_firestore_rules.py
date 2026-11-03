"""Test rules in an already-running localhost Firestore emulator; never production.

Uses only Python's standard library. Run the emulator on port 8189, then:
python tools/check_firestore_rules.py
All records and unsigned tokens are synthetic and restricted to a demo project.
"""
import base64
import copy
import json
import math
from pathlib import Path
import sys
import time
import urllib.error
import urllib.request
sys.dont_write_bytecode = True
from seed_firebase_candidate import DEFAULT_PROFILES, profile_fields

ROOT = Path(__file__).resolve().parents[1]
PROJECT = 'demo-multinav-debug'
HOST = 'http://127.0.0.1:8189'
BASE = f'{HOST}/v1/projects/{PROJECT}/databases/(default)/documents'
checks = 0

def request(method, url, data=None, token=None):
    headers = {'Content-Type': 'application/json'}
    if token:
        headers['Authorization'] = 'Bearer ' + token
    req = urllib.request.Request(url, data=None if data is None else json.dumps(data).encode(), headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=20) as response:
            return response.status, response.read().decode()
    except urllib.error.HTTPError as error:
        return error.code, error.read().decode()

def b64(data):
    return base64.urlsafe_b64encode(json.dumps(data).encode()).decode().rstrip('=')

TOKEN = b64({'alg': 'none', 'typ': 'JWT'}) + '.' + b64({
    'sub': 'test-user', 'user_id': 'test-user', 'aud': PROJECT,
    'iss': 'https://securetoken.google.com/' + PROJECT,
    'iat': int(time.time()), 'exp': int(time.time()) + 3600,
    'firebase': {'sign_in_provider': 'anonymous', 'identities': {}},
}) + '.'

def value(v):
    if v is None: return {'nullValue': None}
    if isinstance(v, bool): return {'booleanValue': v}
    if isinstance(v, int): return {'integerValue': str(v)}
    if isinstance(v, float):
        return {'doubleValue': v if math.isfinite(v) else ('NaN' if math.isnan(v) else ('Infinity' if v > 0 else '-Infinity'))}
    if isinstance(v, str): return {'stringValue': v}
    return {'mapValue': {'fields': {k: value(x) for k, x in v.items()}}}

def fields(data):
    result = {k: value(v) for k, v in data.items()}
    result['createdAt'] = {'timestampValue': '2026-10-29T19:00:00Z'}
    return result

def check(label, response, expected):
    global checks
    status, body = response
    assert status == expected, f'{label}: expected {expected}, got {status}: {body}'
    if expected == 403:
        assert '1000 expressions' not in body, f'{label}: evaluation budget exceeded'
    checks += 1

rules = (ROOT / 'firestore.rules').read_text()
check('load rules', request('PUT', f'{HOST}/emulator/v1/projects/{PROJECT}:securityRules',
      {'rules': {'files': [{'name': 'firestore.rules', 'content': rules}]}}), 200)
candidate = {'pid': '101', 'candidateId': 'test-seed', 'schemaVersion': 2,
             'phase': 'exploration', 'phaseStep': 1,
             'haptics': {k: profile_fields(v) for k, v in DEFAULT_PROFILES.items()}}
check('seed', request('PATCH', BASE + '/parameterValues/rules-test-seed', {'fields': fields(candidate)}, 'owner'), 200)
result = dict(candidate, authUid='test-user', sessionId='rules-test', resultId='valid',
              parameterDocumentId='rules-test-seed', mapName='map01_orchard', hapticMode='burst',
              roundNumber=1, subjectiveScore=.75, objectiveScore=.5, touchedTarget=True,
              questionnaireVersion=2, q_cognitive_load=6, q_clear=4, q_likability=5, q_comfort=3)

def submit(label, data, expected=403, token=TOKEN):
    check(label, request('PATCH', BASE + '/interventionResults/' + label,
                        {'fields': fields(dict(data, resultId=label))}, token), expected)

# Repeatable tests: delete only synthetic results in this isolated demo emulator.
check('reset demo', request('DELETE', f'{HOST}/emulator/v1/projects/{PROJECT}/databases/(default)/documents', token='owner'), 200)
check('reseed', request('PATCH', BASE + '/parameterValues/rules-test-seed', {'fields': fields(candidate)}, 'owner'), 200)
# Reproduce the exact regression first, then repeat with the replacement rules.
original = (ROOT / 'tools/tests/fixtures/firestore-before-submission-fix.rules').read_text()
check('load original', request('PUT', f'{HOST}/emulator/v1/projects/{PROJECT}:securityRules',
      {'rules': {'files': [{'name': 'firestore.rules', 'content': original}]}}), 200)
original_status, original_error = request('PATCH', BASE + '/interventionResults/valid',
                                        {'fields': fields(result)}, TOKEN)
assert original_status == 403 and '1000 expressions' in original_error, original_error
checks += 1
print('CONFIRMED: original rules reject valid round-one result at the 1,000-expression limit.')
check('reload replacement', request('PUT', f'{HOST}/emulator/v1/projects/{PROJECT}:securityRules',
      {'rules': {'files': [{'name': 'firestore.rules', 'content': rules}]}}), 200)
submit('valid', result, 200)
server_fields = fields(dict(result, resultId='server-time'))
server_fields.pop('createdAt')
check('server timestamp', request('POST', BASE + ':commit', {'writes': [{
    'update': {'name': f'projects/{PROJECT}/databases/(default)/documents/interventionResults/server-time',
               'fields': server_fields},
    'updateTransforms': [{'fieldPath': 'createdAt', 'setToServerValue': 'REQUEST_TIME'}],
}]}, TOKEN), 200)
submit('valid', result, 200)  # Exact retry.
retry = fields(dict(result, resultId='valid'))
retry['createdAt'] = {'timestampValue': '2026-10-29T19:01:00Z'}
check('timestamp retry', request('PATCH', BASE + '/interventionResults/valid', {'fields': retry}, TOKEN), 200)
submit('valid', dict(result, q_clear=1))
submit('valid', dict(result, authUid='other'))
submit('unauthenticated', result, token=None)
for key, replacement in [('authUid', 'other'), ('pid', '102'), ('candidateId', 'other'),
                         ('parameterDocumentId', 'missing'), ('phaseStep', 2), ('roundNumber', 18),
                         ('subjectiveScore', 2), ('objectiveScore', -1), ('schemaVersion', 1),
                         ('phase', 'other'), ('hapticMode', 'other'), ('touchedTarget', 'yes')]:
    submit('bad-' + key, dict(result, **{key: replacement}))
for cue in candidate['haptics']:
    changed = copy.deepcopy(result)
    changed['haptics'][cue]['intensity'] = .12345
    submit('changed-' + cue, changed)
    del changed['haptics'][cue]
    submit('missing-' + cue, changed)
for key, replacement in [('pulseCount', 1.5), ('intensity', -1), ('onDuration', 0), ('sharpness', True)]:
    changed = copy.deepcopy(result)
    changed['haptics']['start'][key] = replacement
    submit('bad-profile-' + key, changed)
changed = copy.deepcopy(result)
changed['haptics']['start'] = 'not a profile'
submit('scalar-profile', changed)
for cue in candidate['haptics']:
    for field in candidate['haptics'][cue]:
        missing = copy.deepcopy(result)
        del missing['haptics'][cue][field]
        submit('missing-' + cue + '-' + field, missing)
    extra = copy.deepcopy(result)
    extra['haptics'][cue]['extra'] = 1
    submit('extra-' + cue, extra)
check('candidate write denied', request('PATCH', BASE + '/parameterValues/client-write', {'fields': fields(candidate)}, TOKEN), 403)
check('result read denied', request('GET', BASE + '/interventionResults/valid', token=TOKEN), 403)
check('result delete denied', request('DELETE', BASE + '/interventionResults/valid', token=TOKEN), 403)
check('candidate read allowed', request('GET', BASE + '/parameterValues/rules-test-seed', token=TOKEN), 200)

# Every supported round, including the final round; extra MOBO fields are ignored.
for round_number in range(1, 18):
    name = f'step-{round_number}'
    next_candidate = dict(candidate, candidateId=name, phaseStep=round_number,
                          roundNumber=round_number, isFinalRound=round_number == 17,
                          hapticMode='burst', mobo={'stage': 'test'})
    check('seed ' + name, request('PATCH', BASE + '/parameterValues/' + name,
          {'fields': fields(next_candidate)}, 'owner'), 200)
    next_result = dict(result, candidateId=name, phaseStep=round_number,
                       roundNumber=round_number, parameterDocumentId=name)
    submit(name, next_result, 200)

# The iOS decoder normalizes integral doubles to Int and other numbers to Double.
numeric_candidate = copy.deepcopy(candidate)
numeric_candidate['phaseStep'] = 1.0
numeric_candidate['schemaVersion'] = 2.0
for profile in numeric_candidate['haptics'].values():
    profile['pulseCount'] = float(profile['pulseCount'])
    for key in ['intensity', 'sharpness', 'onDuration', 'offDuration']:
        if profile[key].is_integer(): profile[key] = int(profile[key])
check('numeric seed', request('PATCH', BASE + '/parameterValues/numeric-seed',
      {'fields': fields(numeric_candidate)}, 'owner'), 200)
submit('numeric-normalization', dict(result, parameterDocumentId='numeric-seed'), 200)
submit('unreached-target', dict(result, objectiveScore=0, touchedTarget=False), 200)
submit('optional-time', dict(result, timeToTargetSeconds=8.125), 200)
for score in [0.0, 1.0]:
    submit('score-boundary-' + str(score), dict(result, subjectiveScore=score, objectiveScore=score), 200)
for key in ['subjectiveScore', 'objectiveScore']:
    for index, bad in enumerate([float('nan'), float('inf'), -float('inf'), True, '0.5', None]):
        submit(f'invalid-{key}-{index}', dict(result, **{key: bad}))
for key in result:
    if key in ['resultId', 'questionnaireVersion', 'q_cognitive_load', 'q_clear', 'q_likability', 'q_comfort']:
        continue
    missing = copy.deepcopy(result)
    del missing[key]
    submit('missing-field-' + key, missing)
check('wrong result ID', request('PATCH', BASE + '/interventionResults/wrong-id',
      {'fields': fields(result)}, TOKEN), 403)
for key, changed_value in [('sessionId', 'other'), ('candidateId', 'other'),
                           ('roundNumber', 2), ('mapName', 'other'), ('subjectiveScore', 0)]:
    submit('valid', dict(result, **{key: changed_value}))
for invalid_fields in [dict(retry, added=value('unexpected')),
                       {k: v for k, v in retry.items() if k != 'q_clear'},
                       dict(retry, createdAt=value('not a timestamp'))]:
    check('immutable update', request('PATCH', BASE + '/interventionResults/valid',
          {'fields': invalid_fields}, TOKEN), 403)

# Document the trust boundary: the rules trust Admin-authored candidate values.
# The actual app decoder rejects this malformed candidate, but the rules do not
# independently repeat that range validation for a modified client.
trusted_bad = copy.deepcopy(candidate)
trusted_bad['haptics']['start']['intensity'] = -1
check('trusted invalid seed', request('PATCH', BASE + '/parameterValues/trusted-invalid',
      {'fields': fields(trusted_bad)}, 'owner'), 200)
submit('trusted-invalid-echo', dict(result, parameterDocumentId='trusted-invalid',
                                 haptics=trusted_bad['haptics']), 200)

# Updating candidate values during a trial invalidates the old first submission.
check('change seed', request('PATCH', BASE + '/parameterValues/rules-test-seed',
      {'fields': fields(dict(candidate, candidateId='replaced'))}, 'owner'), 200)
submit('changed-candidate', result)

# The first submission requires the published candidate still to exist unchanged.
# An already accepted result can still be retried after candidate cleanup.
check('remove seed', request('DELETE', BASE + '/parameterValues/rules-test-seed', token='owner'), 200)
submit('removed-candidate', result)
submit('valid', result, 200)

print(f'PASS: {checks} emulator assertions; 17 rounds, numeric normalization, server timestamps, '
      'retries, immutable results, ownership, candidate matching, score bounds and access restrictions.')
