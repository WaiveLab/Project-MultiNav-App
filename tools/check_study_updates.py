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

    # Exercise the actual app policy and its private touch adapter with recording
    # engines. Extract only the non-SwiftUI tail; production sources stay intact.
    policy_text = (app / "ContentView.swift").read_text(encoding="utf-8-sig")
    policy_text = policy_text.split("// MARK: Custom Element Types", 1)[1]
    # In the app this shadows an imported module's street; in this single test
    # module use the package's identical definition instead of redeclaring it.
    policy_text = policy_text.replace('    static let street = TactileElementType(rawValue: "street")', '')
    policy_file = directory / "AudioPolicyChecks.swift"
    policy_file.write_text(policy_text + "\n" + (root / "tools/tests/AudioPolicyTests.swift").read_text(), encoding="utf-8")
    feedback_file = directory / "FeedbackPolicy.swift"
    feedback_text = (args.library / "Sources/TactileMapFeedback/FeedbackPolicy.swift").read_text(encoding="utf-8-sig")
    feedback_file.write_text(feedback_text.replace("import TactileMapCore\n", "").replace("import AVFoundation\n", ""), encoding="utf-8")
    audio_sources = [path for path in copied if path.name != "StudyUpdateTests.swift"]
    audio_sources += [feedback_file, policy_file, root / "tools/tests/AudioPolicyTestDoubles.swift"]
    audio_executable = directory / ("audio-checks.exe" if os.name == "nt" else "audio-checks")
    run([swift, "-module-cache-path", directory / "module-cache", *audio_sources, "-o", audio_executable])
    run([audio_executable])
print("All app Swift sources parsed. Portable study checks passed; iOS build/device verification still required.")
