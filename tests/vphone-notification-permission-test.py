#!/usr/bin/env python3
"""Check the scope guards for the notification permission clicker."""
import importlib.util
from pathlib import Path
import unittest

path = Path(__file__).resolve().parents[1] / "scripts/vphone-allow-notifications.py"
spec = importlib.util.spec_from_file_location("notification_allow", path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


def word(text, x, y, line, width=100):
    return {"text": text, "left": x, "top": y, "width": width, "height": 40, "line": (str(line), "1", "1")}


def dialog(title):
    return [word(title, 180, 1100, 1, 900), word("不", 350, 1600, 2, 40),
            word("允許", 405, 1600, 2, 90), word("允許", 820, 1600, 3, 90)]


class ScopeTests(unittest.TestCase):
    def test_expected_notification_dialog(self):
        result = module.permission_button(dialog("Ve Al Runtime Test 想要傳送通知"), "Ve AI Runtime Test")
        self.assertEqual(result["left"], 820)

    def test_other_app_is_not_approved(self):
        self.assertIsNone(module.permission_button(dialog("Another App 想要傳送通知"), "Ve AI Runtime Test"))

    def test_camera_is_not_approved(self):
        self.assertIsNone(module.permission_button(dialog("Ve AI Runtime Test 想要使用相機"), "Ve AI Runtime Test"))

    def test_ambiguous_allow_is_not_clicked(self):
        words = dialog("Ve AI Runtime Test 想要傳送通知") + [word("允許", 820, 1800, 4)]
        self.assertIsNone(module.permission_button(words, "Ve AI Runtime Test"))

    def test_english_notification_dialog(self):
        words = [word('Ve AI Runtime Test would like to send you notifications', 100, 1000, 1, 1000),
                 word("Don't Allow", 300, 1600, 2, 200), word("Allow", 850, 1600, 3, 150)]
        self.assertEqual(module.permission_button(words, "Ve AI Runtime Test")["left"], 850)


if __name__ == "__main__":
    unittest.main()
