"""Run portable Swift checks with existing tools; never install/change packages.

Usage: python tools/check_study_updates.py [--library PATH_TO_TACTILE_PACKAGE]
These checks use the supplied package source copy for portable models, not an
iOS SDK or a substitute for an Xcode build against the resolved dependency.
"""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--library", type=Path, default=root.parent / "Library/TactileMapPackageCode")
args = parser.parse_args()
swift = shutil.which("swiftc")
if not swift:
    raise SystemExit("Swift compiler not available. Run on a machine with Swift installed.")
env = {key.upper(): value for key, value in os.environ.items()} if os.name == "nt" else dict(os.environ)
app = root / "Project MultiNav App"

def run(command):
    subprocess.run([str(item) for item in command], env=env, check=True)

# Syntax only for UIKit/SwiftUI/Firebase files; no iOS SDK is present on Windows.
run([swift, "-frontend", "-parse", *app.glob("*.swift")])
core = args.library / "Sources/TactileMapCore"
sources = [core / (name + ".swift") for name in [
    "TactileMapDocument", "TactileMapElement", "TactileProperties",
    "TactileElementType", "TactileGeometry", "TactileMapLayer",
]]
sources += [args.library / "Sources/TactileMapFeedback/HapticPattern.swift"]
sources += [app / (name + ".swift") for name in [
    "ParameterSet", "PracticeHaptics", "SurveyResponse", "StudyPerformance", "StudyMapLayout", "StudyMapSpeech",
]]
sources += [root / "tools/tests/StudyUpdateTests.swift"]
with tempfile.TemporaryDirectory(prefix="multinav-checks-") as temporary:
    directory = Path(temporary)
    copied = []
    for source in sources:
        destination = directory / source.name
        text = source.read_text(encoding="utf-8-sig")
        # Combine existing pure model sources into one module, only in temp.
        text = text.replace("import TactileMapCore\n", "").replace("import TactileMapFeedback\n", "")
        destination.write_text(text, encoding="utf-8")
        copied.append(destination)
    executable = directory / ("study-checks.exe" if os.name == "nt" else "study-checks")
    run([swift, "-module-cache-path", directory / "module-cache", *copied, "-o", executable])
    run([executable, app / "Maps"])
print("All app Swift sources parsed. Portable study checks passed; iOS build/device verification still required.")
