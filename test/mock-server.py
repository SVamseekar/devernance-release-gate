"""Stand-in for the Assurance OS CI release-gate endpoint, used by the self-test workflow and test/run.sh."""
import json
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import parse_qs, urlparse

DECISIONS = {"pass": "PASS", "review": "REVIEW", "blocked": "BLOCKED"}


class Handler(BaseHTTPRequestHandler):
    def _send(self, status, body, content_type="application/json"):
        payload = body.encode() if isinstance(body, str) else body
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def do_GET(self):
        url = urlparse(self.path)
        if url.path != "/api/v1/ci/release-gate":
            self._send(404, '{"error":"not found"}')
            return
        if self.headers.get("X-Api-Key") != "test-key":
            self._send(401, '{"error":"unauthorized"}')
            return
        system = parse_qs(url.query).get("systemId", [""])[0]
        if system == "garbage":
            self._send(200, "<html>proxy error page</html>", "text/html")
            return
        if system == "odd":
            self._send(200, json.dumps({"decision": "MAYBE", "blockers": []}))
            return
        if system == "limit":
            self._send(402, json.dumps({"error": "plan_limit", "code": "gate_runs",
                                        "message": "Monthly gate runs used up on the FREE plan."}))
            return
        decision = DECISIONS.get(system)
        if decision is None:
            self._send(404, '{"error":"AI system not found"}')
            return
        blockers = ["CONTROL:HUMAN_OVERSIGHT", "Missing evidence: DPIA"] if decision == "BLOCKED" else []
        exit_code = {"PASS": 0, "BLOCKED": 1, "REVIEW": 2}[decision]
        self._send(200, json.dumps({"systemId": system, "systemName": "Claims triage", "decision": decision,
                                    "blockers": blockers, "exitCode": exit_code,
                                    "content": f"Release gate {decision}"}))

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8787
    HTTPServer(("127.0.0.1", port), Handler).serve_forever()
