#!/usr/bin/env python3
"""Local Brew Services Dashboard server."""

import json
import subprocess
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path


def get_brew_services():
    result = subprocess.run(
        ["brew", "services", "list"],
        capture_output=True,
        text=True,
    )
    lines = result.stdout.strip().splitlines()
    if not lines:
        return []

    services = []
    for line in lines[1:]:  # skip header
        parts = line.split()
        if not parts:
            continue
        name = parts[0]
        status = parts[1] if len(parts) > 1 else "none"
        user = parts[2] if len(parts) > 2 else ""
        file = parts[3] if len(parts) > 3 else ""
        services.append({"name": name, "status": status, "user": user, "file": file})
    return services


def run_brew_action(service, action):
    """Run brew services start/stop/restart on a service."""
    allowed_actions = {"start", "stop", "restart"}
    if action not in allowed_actions:
        return False, f"Invalid action: {action}"
    result = subprocess.run(
        ["brew", "services", action, service],
        capture_output=True,
        text=True,
    )
    ok = result.returncode == 0
    output = (result.stdout + result.stderr).strip()
    return ok, output


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        pass  # suppress default logging

    def send_json(self, data, status=200):
        body = json.dumps(data).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

    def serve_file(self, path, content_type):
        content = Path(path).read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(content)))
        self.end_headers()
        self.wfile.write(content)

    def do_GET(self):
        if self.path == "/" or self.path == "/index.html":
            self.serve_file(Path(__file__).parent / "index.html", "text/html; charset=utf-8")
        elif self.path == "/api/services":
            self.send_json(get_brew_services())
        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        if self.path.startswith("/api/services/"):
            parts = self.path.split("/")
            # /api/services/<name>/<action>
            if len(parts) == 5:
                _, _, _, service, action = parts
                ok, output = run_brew_action(service, action)
                self.send_json({"ok": ok, "output": output})
                return
        self.send_response(404)
        self.end_headers()

    def do_OPTIONS(self):
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.end_headers()


if __name__ == "__main__":
    port = 9999
    server = HTTPServer(("127.0.0.1", port), Handler)
    print(f"Brew Dashboard running at http://localhost:{port}")
    print("Press Ctrl+C to stop.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopped.")
