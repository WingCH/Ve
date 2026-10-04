#!/usr/bin/env python3
"""Synthetic System One and Bark endpoints for the vphone integration fixture."""
import argparse
import base64
import hashlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import threading
import time

parser = argparse.ArgumentParser()
parser.add_argument("--bind", required=True)
parser.add_argument("--port", required=True, type=int)
parser.add_argument("--output", required=True, type=Path)
parser.add_argument("--raw-padding-bytes", type=int, default=0)
args = parser.parse_args()
lock = threading.Lock()
app = "codes.wingchan.ve-ai-runtime-test"

class Handler(BaseHTTPRequestHandler):
    def log_message(self, *values):
        pass
    def respond(self, code, body):
        if args.raw_padding_bytes:
            body = {**body, "trace_padding": "x" * args.raw_padding_bytes}
        data = json.dumps(body, ensure_ascii=False, indent=2).encode()
        with lock, args.output.open("a") as file:
            file.write(json.dumps({"kind": "response", "request_sha256": self.request_sha256, "status_code": code, "body_base64": base64.b64encode(data).decode()}) + "\n")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("X-Raw-Trace", "fixture-response-original")
        self.end_headers()
        self.wfile.write(data)
    def do_POST(self):
        raw = self.rfile.read(int(self.headers.get("Content-Length", "0")))
        self.request_sha256 = hashlib.sha256(raw).hexdigest()
        body = json.loads(raw)
        kind = "ai" if "questions" in body else "bark"
        if kind == "ai" and body.get("state", {}).get("notification", {}).get("app") != app:
            self.respond(400, {"error": "fixture_only"})
            return
        if kind == "bark" and not body.get("title", "").startswith("Ve AI"):
            self.respond(200, {"code": 200, "message": "ignored_non_fixture"})
            return
        with lock, args.output.open("a") as file:
            file.write(json.dumps({"kind": kind, "path": self.path, "time": time.time(), "body": body, "headers": dict(self.headers), "body_base64": base64.b64encode(raw).decode(), "request_sha256": self.request_sha256}, ensure_ascii=False) + "\n")
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
        probability = 0.97 if any(marker in text for marker in ("promo", "slow", "scam")) else 0.03
        if "corrected-promo" in text and any(x["should_forward"] for x in body["state"]["corrected_examples"]):
            probability = 0.03
        result = {"model": body["model"], "answers": {"skip_bark": {"type": "noul", "noul": probability}}, "usage": {"input_tokens": 0, "output_tokens": 0}}
        self.respond(200, {"success": True, "result": result} if self.path.startswith("/cloudflare/") else result)

args.output.parent.mkdir(parents=True, exist_ok=True)
print(f"Synthetic fixture listening on {args.bind}:{args.port}", flush=True)
ThreadingHTTPServer((args.bind, args.port), Handler).serve_forever()
