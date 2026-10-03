#!/usr/bin/env python3
"""Synthetic System One and Bark endpoints for the vphone integration fixture."""
import argparse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import threading
import time

parser = argparse.ArgumentParser()
parser.add_argument("--bind", required=True)
parser.add_argument("--port", required=True, type=int)
parser.add_argument("--output", required=True, type=Path)
args = parser.parse_args()
lock = threading.Lock()
app = "codes.wingchan.ve-ai-runtime-test"

class Handler(BaseHTTPRequestHandler):
    def log_message(self, *values):
        pass
    def respond(self, code, body):
        data = json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)
    def do_POST(self):
        body = json.loads(self.rfile.read(int(self.headers.get("Content-Length", "0"))))
        kind = "ai" if "questions" in body else "bark"
        if kind == "ai" and body.get("state", {}).get("notification", {}).get("app") != app:
            self.respond(400, {"error": "fixture_only"})
            return
        if kind == "bark" and not body.get("title", "").startswith("Ve AI"):
            self.respond(200, {"code": 200, "message": "ignored_non_fixture"})
            return
        with lock, args.output.open("a") as file:
            file.write(json.dumps({"kind": kind, "path": self.path, "time": time.time(), "body": body}, ensure_ascii=False) + "\n")
        if kind == "bark":
            self.respond(200, {"code": 200, "message": "synthetic_receiver"})
            return
        text = body["state"]["notification"]["body"]
        if "error" in text:
            self.respond(503, {"error": "synthetic_failure"})
            return
        if "slow" in text:
            time.sleep(0.8)
        # This is a deterministic protocol fixture, not a Clef/Jev inference.
        probability = 0.97 if "promo" in text or "slow" in text else 0.03
        if "corrected-promo" in text and any(x["should_forward"] for x in body["state"]["corrected_examples"]):
            probability = 0.03
        result = {"model": body["model"], "answers": {"skip_bark": {"type": "noul", "noul": probability}}, "usage": {"input_tokens": 0, "output_tokens": 0}}
        self.respond(200, {"success": True, "result": result} if self.path.startswith("/cloudflare/") else result)

args.output.parent.mkdir(parents=True, exist_ok=True)
print(f"Synthetic fixture listening on {args.bind}:{args.port}", flush=True)
ThreadingHTTPServer((args.bind, args.port), Handler).serve_forever()
