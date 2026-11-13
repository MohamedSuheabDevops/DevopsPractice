"""Unit tests. Run:  cd apps/careconnect-service && python -m unittest -v"""
import json
import threading
import unittest
import urllib.error
import urllib.request
from http.server import ThreadingHTTPServer

import app


class ServiceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = ThreadingHTTPServer(("127.0.0.1", 0), app.Handler)   # port 0 = any free port
        cls.port = cls.server.server_address[1]
        threading.Thread(target=cls.server.serve_forever, daemon=True).start()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()

    def setUp(self):
        app.DEPS = []          # each test starts with no dependencies

    def get(self, path):
        return urllib.request.urlopen(f"http://127.0.0.1:{self.port}{path}", timeout=3)

    def test_health_ok_without_dependencies(self):
        with self.get("/health") as r:
            body = json.load(r)
            self.assertEqual(r.status, 200)
            self.assertTrue(body["healthy"])

    def test_response_contains_service_and_container(self):
        with self.get("/anything") as r:
            body = json.load(r)
            self.assertIn("service", body)
            self.assertIn("container", body)
            self.assertEqual(body["path"], "/anything")

    def test_health_fails_when_dependency_down(self):
        app.DEPS = ["127.0.0.1:1"]            # nothing listens on port 1
        with self.assertRaises(urllib.error.HTTPError) as ctx:
            self.get("/health")
        self.assertEqual(ctx.exception.code, 503)

    def test_non_health_path_stays_200_when_dependency_down(self):
        app.DEPS = ["127.0.0.1:1"]
        with self.get("/") as r:
            self.assertEqual(r.status, 200)
            self.assertFalse(json.load(r)["healthy"])


if __name__ == "__main__":
    unittest.main()
