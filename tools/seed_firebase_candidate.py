"""Publish one complete schema-v2 haptic candidate to Cloud Firestore.

This is a development/setup tool. It intentionally publishes all 14 independent
element profiles together because the iOS app rejects partial candidates.

The Firebase Admin key must stay outside this repository. Pass its path with
--credentials, or set GOOGLE_APPLICATION_CREDENTIALS before running this script.
The script previews without writing unless --write is supplied.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


PROJECT_ID = "project-multinav"
COLLECTION = "parameterValues"
SCHEMA_VERSION = 2

# Tuple order: intensity, sharpness, pulseCount, onDuration, offDuration.
DEFAULT_PROFILES: dict[str, tuple[float, float, int, float, float]] = {
    "start": (0.75, 1.00, 10, 0.25, 0.50),
    "onRoute": (1.00, 0.50, 120, 1.00, 0.01),
    "offRoute": (0.25, 0.25, 120, 1.00, 0.01),
    "onRouteIntersection": (0.75, 0.25, 15, 0.25, 0.05),
    "offRouteIntersection": (0.75, 0.25, 120, 1.00, 0.01),
    "landmark": (1.00, 0.15, 60, 1.00, 0.01),
    "end": (0.75, 1.00, 120, 1.00, 0.01),
    "street": (0.33, 0.33, 60, 1.00, 0.15),
    "onRouteSidewalk": (0.75, 1.00, 60, 1.00, 0.01),
    "offRouteSidewalk": (0.25, 0.25, 60, 1.00, 0.01),
    "onRouteCrosswalk": (0.75, 1.00, 60, 1.00, 0.01),
    "offRouteCrosswalk": (0.25, 0.25, 60, 1.00, 0.01),
    "turn": (0.25, 0.25, 60, 1.00, 0.01),
    "intersectionCenter": (0.25, 0.25, 60, 1.00, 0.01),
}


def profile_fields(values: tuple[float, float, int, float, float]) -> dict[str, Any]:
    intensity, sharpness, pulse_count, on_duration, off_duration = values
    return {
        "intensity": intensity,
        "sharpness": sharpness,
        "pulseCount": pulse_count,
        "onDuration": on_duration,
        "offDuration": off_duration,
    }


def validate_profile(element: str, profile: dict[str, Any]) -> None:
    intensity = profile["intensity"]
    sharpness = profile["sharpness"]
    pulse_count = profile["pulseCount"]
    on_duration = profile["onDuration"]
    off_duration = profile["offDuration"]

    if not 0.0 <= intensity <= 1.0:
        raise ValueError(f"{element}.intensity must be between 0 and 1")
    if not 0.0 <= sharpness <= 1.0:
        raise ValueError(f"{element}.sharpness must be between 0 and 1")
    if isinstance(pulse_count, bool) or not isinstance(pulse_count, int):
        raise ValueError(f"{element}.pulseCount must be an integer")
    if not 1 <= pulse_count <= 120:
        raise ValueError(f"{element}.pulseCount must be between 1 and 120")
    if not 0.01 <= on_duration <= 2.0:
        raise ValueError(f"{element}.onDuration must be between 0.01 and 2.0")
    if pulse_count > on_duration * 120:
        raise ValueError(
            f"{element}.pulseCount cannot exceed onDuration multiplied by 120"
        )
    if not 0.01 <= off_duration <= 2.0:
        raise ValueError(f"{element}.offDuration must be between 0.01 and 2.0")


def build_candidate(pid: str, round_number: int, candidate_id: str) -> dict[str, Any]:
    haptics = {
        element: profile_fields(values)
        for element, values in DEFAULT_PROFILES.items()
    }
    for element, profile in haptics.items():
        validate_profile(element, profile)

    return {
        "schemaVersion": SCHEMA_VERSION,
        "pid": pid,
        "candidateId": candidate_id,
        # Replaced with Firestore's server timestamp immediately before writing.
        "createdAt": "<Firestore server timestamp>",
        "phase": "exploration",
        "phaseStep": round_number,
        "haptics": haptics,
    }


def credential_path(explicit_path: Path | None) -> Path:
    raw_path = str(explicit_path) if explicit_path else os.environ.get(
        "GOOGLE_APPLICATION_CREDENTIALS", ""
    )
    if not raw_path:
        raise ValueError(
            "Pass --credentials with the downloaded JSON key path, or set "
            "GOOGLE_APPLICATION_CREDENTIALS."
        )

    path = Path(raw_path).expanduser().resolve()
    if not path.is_file():
        raise ValueError(f"Credential file does not exist: {path}")

    try:
        credential_project = json.loads(path.read_text(encoding="utf-8")).get("project_id")
    except (OSError, json.JSONDecodeError) as error:
        raise ValueError(f"Could not read the credential JSON: {error}") from error

    if credential_project != PROJECT_ID:
        raise ValueError(
            f"That key belongs to {credential_project!r}, not {PROJECT_ID!r}. "
            "No Firestore write was attempted."
        )
    return path


def publish(candidate: dict[str, Any], credentials_path: Path) -> str:
    try:
        import firebase_admin
        from firebase_admin import credentials, firestore
    except ImportError as error:
        raise RuntimeError(
            "firebase-admin is not installed. Run: py -m pip install firebase-admin"
        ) from error

    credential = credentials.Certificate(str(credentials_path))
    firebase_admin.initialize_app(credential, {"projectId": PROJECT_ID})
    db = firestore.client()

    document = dict(candidate)
    document["createdAt"] = firestore.SERVER_TIMESTAMP
    reference = db.collection(COLLECTION).document()
    reference.set(document)
    return reference.id


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Preview or publish one complete MultiNav haptic candidate."
    )
    parser.add_argument("--pid", required=True, help="Participant ID used in the iOS app")
    parser.add_argument(
        "--round",
        required=True,
        type=int,
        dest="round_number",
        help="Expected study round, from 1 through 18",
    )
    parser.add_argument(
        "--candidate-id",
        help="Optional unique optimizer candidate ID; a timestamped ID is generated otherwise",
    )
    parser.add_argument(
        "--credentials",
        type=Path,
        help="Path to the Firebase Admin JSON key stored outside this repository",
    )
    parser.add_argument(
        "--write",
        action="store_true",
        help="Actually create the Firestore document; without this flag only a preview is shown",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    pid = args.pid.strip()
    if not pid:
        print("ERROR: --pid cannot be blank", file=sys.stderr)
        return 2
    if not 1 <= args.round_number <= 18:
        print("ERROR: --round must be between 1 and 18", file=sys.stderr)
        return 2

    candidate_id = args.candidate_id
    if candidate_id is None:
        timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
        candidate_id = f"{pid}-round-{args.round_number:02d}-seed-{timestamp}"
    candidate_id = candidate_id.strip()
    if not candidate_id:
        print("ERROR: --candidate-id cannot be blank", file=sys.stderr)
        return 2

    try:
        candidate = build_candidate(pid, args.round_number, candidate_id)
    except ValueError as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 2

    if not args.write:
        print(json.dumps(candidate, indent=2, sort_keys=True))
        print("\nPREVIEW ONLY: nothing was written to Firebase. Add --write when ready.")
        return 0

    print(
        f"Publishing {candidate_id!r} for participant {pid!r}, "
        f"round {args.round_number}, with {len(candidate['haptics'])} haptic profiles..."
    )

    try:
        path = credential_path(args.credentials)
        document_id = publish(candidate, path)
    except (RuntimeError, ValueError) as error:
        print(f"\nERROR: {error}", file=sys.stderr)
        return 1
    except Exception as error:  # Firebase/network errors should remain actionable.
        print(f"\nFIREBASE ERROR: {error}", file=sys.stderr)
        return 1

    print(f"\nCreated {COLLECTION}/{document_id} in Firebase project {PROJECT_ID}.")
    print("The candidate contains all 14 independent haptic profiles.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
