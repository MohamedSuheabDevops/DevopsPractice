"""Tiny stand-in microservice for CareConnect practice.
Same image runs as patient-service, appointment-service, doctor-service.
Behaviour is controlled by env vars:
  SERVICE_NAME  - name shown in responses
  DEPENDENCIES  - comma list of host:port to TCP-check, e.g. "postgres:5432,redis:6379"
/health returns 503 until every dependency is reachable.
"""
import json, os, socket
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

NAME = os.getenv("SERVICE_NAME", "service")
DEPS = [d for d in os.getenv("DEPENDENCIES", "").split(",") if d]

def reachable(dep):
    host, port = dep.rsplit(":", 1)
    try:
        with socket.create_connection((host, int(port)), timeout=1):
            return True
    except OSError:
        return False

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        deps = {d: reachable(d) for d in DEPS}
        healthy = all(deps.values())
        code = 503 if (self.path == "/health" and not healthy) else 200
        body = json.dumps({
            "service": NAME,
            "container": socket.gethostname(),   # changes per replica -> see load balancing
            "path": self.path,
            "dependencies": deps,
            "healthy": healthy,
        }, indent=2).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass

if __name__ == "__main__":
    ThreadingHTTPServer(("0.0.0.0", 8000), Handler).serve_forever()
