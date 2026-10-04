#!/usr/bin/env python3
"""Check the optional AI Preferences schema and English UI strings."""
from pathlib import Path
import plistlib
import re

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
assert fields["AIModel"]["aiProvider"] == "cloudflare"
assert fields["AIAccountID"]["aiProvider"] == "cloudflare"
assert fields["AISystemOneModel"]["aiProvider"] == "systemone"
assert sum(item.get("id") == "ve.ai.connection" for item in items) == 1
for item in items:
    for key in ("label", "footerText", "placeholder", "validTitles"):
        values = item.get(key, [])
        if isinstance(values, str):
            values = [values]
        assert all(not re.search(r"[\u3400-\u9fff]", value) for value in values), (key, values)
ui_paths = ["Preferences/Controllers/VeRootListController.m", "Preferences/Controllers/VePromptEditorController.m", "Manager/VEAIPolicy.m"]
ui_paths += [str(path.relative_to(root)) for path in (root / "Tweak/Target").rglob("*.m")]
for path in ui_paths:
    for literal in re.findall(r'@"([^"\n]*)"', (root / path).read_text()):
        assert not re.search(r"[\u3400-\u9fff]", literal), (path, literal)
assert not any(item.get("key") == "AIToken" and item["cell"] == "PSEditTextCell" for item in items)
info = plistlib.loads((root / "Preferences/Resources/Info.plist").read_bytes())
version = next(line.split(": ", 1)[1] for line in (root / "control").read_text().splitlines() if line.startswith("Version: "))
assert info["CFBundleVersion"] == info["CFBundleShortVersionString"] == version
print("AI Preferences schema and package version contracts passed")
