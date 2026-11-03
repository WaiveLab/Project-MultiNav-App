"""Compile actual StudySession with test doubles for unavailable Firebase/Combine.

This verifies session behavior on Windows; an Xcode build is still required to
validate the Firebase SDK linkage and actual callable transport on iOS.
"""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
app = root / "Project MultiNav App"
swift = shutil.which("swiftc")
if not swift:
    raise SystemExit("Swift compiler is required.")
env = {k.upper(): v for k, v in os.environ.items()} if os.name == "nt" else dict(os.environ)
staging = root / ".codex-validation"
staging.mkdir(exist_ok=True)
sources = [app / (name + ".swift") for name in ["ParameterSet", "PracticeHaptics", "StudyPerformance", "StudySession"]]
sources += [root.parent / "Library/TactileMapPackageCode/Sources/TactileMapFeedback/HapticPattern.swift"]
sources += [root / "tools/tests/RegistrationSessionDoubles.swift", root / "tools/tests/RegistrationSessionTests.swift"]
with tempfile.TemporaryDirectory(prefix="registration-", dir=staging) as tmp:
    directory = Path(tmp)
    copied = []
    for source in sources:
        text = source.read_text(encoding="utf-8-sig")
        for module in ["Combine", "FirebaseAuth", "TactileMapCore", "TactileMapFeedback"]:
            text = text.replace(f"import {module}\n", "")
        destination = directory / source.name
        destination.write_text(text, encoding="utf-8")
        copied.append(destination)
    executable = directory / ("session-tests.exe" if os.name == "nt" else "session-tests")
    subprocess.run([swift, "-module-cache-path", str(directory / "cache"), *map(str, copied), "-o", str(executable)], env=env, check=True)
    subprocess.run([str(executable)], env=env, check=True)
