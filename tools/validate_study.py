"""Run the Foundation-only study regression tests on macOS or Windows with Swift.

Compiles production sources in a single module, removing only package imports.
Extracts the actual Canvas transform before the UIKit renderer. This does not
replace an iOS build or device tests for gestures, speech and Core Haptics.
"""
import os
from pathlib import Path
import subprocess
import tempfile

APP = Path(__file__).resolve().parents[1]
PACKAGE = APP.parent / "Library" / "TactileMapPackageCode"
SOURCES = PACKAGE / "Sources"

def read(path):
    return path.read_text(encoding="utf-8-sig")

env = {key.upper(): value for key, value in os.environ.items()} if os.name == "nt" else dict(os.environ)
with tempfile.TemporaryDirectory(prefix="multinav-tests-") as temp:
    scratch = Path(temp)
    inputs = [APP / "Project MultiNav App" / "SurveyResponse.swift",
              APP / "Project MultiNav App" / "ParameterSet.swift",
              SOURCES / "TactileMapFeedback" / "HapticPattern.swift"]
    inputs += [SOURCES / "TactileMapCore" / name for name in [
        "TactileMapDocument.swift", "TactileMapElement.swift", "TactileProperties.swift",
        "TactileElementType.swift", "TactileGeometry.swift", "TactileMapLayer.swift"]]
    inputs += [SOURCES / "TactileMapView" / name for name in ["HitDetectionConfig.swift", "CanvasHitDetector.swift"]]
    files = []
    for source in inputs:
        dest = scratch / source.name
        text = read(source)
        for module in ["TactileMapCore", "TactileMapFeedback"]:
            text = text.replace(f"import {module}\n", "")
        dest.write_text(text, encoding="utf-8")
        files.append(str(dest))
    transform = read(SOURCES / "TactileMapView" / "CanvasMapView.swift")
    transform = transform.split("// MARK: - Canvas Coordinate Transform", 1)[1]
    transform = transform.split("// MARK: - Canvas Map View (UIViewRepresentable wrapper)", 1)[0]
    touch_type = read(SOURCES / "TactileMapFeedback" / "FeedbackPolicy.swift")
    touch_type = touch_type.split("public enum TouchType: Sendable {", 1)[1].split("\n}", 1)[0]
    dest = scratch / "CanvasTransform.swift"
    dest.write_text("import Foundation\n" + transform + "\npublic enum TouchType: Sendable {" + touch_type + "\n}\n", encoding="utf-8")
    files.append(str(dest))
    binary = scratch / ("study-tests.exe" if os.name == "nt" else "study-tests")
    subprocess.run(["swiftc", "-module-cache-path", str(scratch / "module-cache"),
                    *files, str(APP / "tools/tests/main.swift"), "-o", str(binary)],
                   cwd=scratch, env=env, check=True)
    subprocess.run([str(binary), str(APP / "Project MultiNav App/Maps")], env=env, check=True)
