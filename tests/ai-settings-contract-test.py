#!/usr/bin/env python3
"""Check the Preferences schema needed by the optional AI controls."""
from pathlib import Path
import plistlib

root = Path(__file__).resolve().parents[1]
items = plistlib.loads((root / "Preferences/Resources/Root.plist").read_bytes())["items"]
fields = {item["key"]: item for item in items if "key" in item}
for item in items:
    if "keyboard" in item:
        assert isinstance(item["keyboard"], str), "Preferences keyboardTypeForString requires a string"
    if "validValues" in item:
        assert len(item["validValues"]) == len(item["validTitles"])
        assert item["default"] in item["validValues"]
assert fields["AIEnabled"]["default"] is False
assert fields["AIMode"]["default"] == "observe"
assert fields["AIProvider"]["default"] == "cloudflare"
assert fields["AIProvider"]["validValues"] == ["cloudflare", "systemone"]
assert fields["AIModel"]["default"] == "clef"
assert fields["AISystemOneModel"]["default"] == "jev-latest"
assert fields["AITimeout"]["default"] == 2
assert fields["AIThreshold"]["default"] == 0.9
assert not any(item.get("key") == "AIToken" and item["cell"] == "PSEditTextCell" for item in items)
info = plistlib.loads((root / "Preferences/Resources/Info.plist").read_bytes())
version = next(line.split(": ", 1)[1] for line in (root / "control").read_text().splitlines() if line.startswith("Version: "))
assert info["CFBundleVersion"] == info["CFBundleShortVersionString"] == version
print("AI Preferences schema and package version contracts passed")
