"""The browser build served by the server: compressed, so phones on the room's Wi-Fi load it quickly."""

import gzip

from fastapi.testclient import TestClient

from app.main import create_app


def web_client(tmp_path, monkeypatch) -> TestClient:
    (tmp_path / "index.html").write_text("<!doctype html><title>Echo</title>", encoding="utf-8")
    # A large, repetitive script, like main.dart.js.
    (tmp_path / "main.dart.js").write_text("function echo(){return 1}\n" * 20000, encoding="utf-8")
    monkeypatch.setenv("WEB_DIR", str(tmp_path))
    return TestClient(create_app(ai_client=None, verifier=None))


def test_the_app_script_is_sent_compressed_to_a_browser_that_accepts_it(tmp_path, monkeypatch):
    client = web_client(tmp_path, monkeypatch)
    response = client.get("/main.dart.js", headers={"Accept-Encoding": "gzip"})
    assert response.status_code == 200
    assert response.headers["content-encoding"] == "gzip"
    raw = response.content  # the test client unpacks it, as a browser does
    assert raw.startswith(b"function echo()")
    assert len(gzip.compress(raw)) < len(raw) / 5  # what travels is a fraction of the script


def test_a_browser_that_does_not_accept_gzip_still_gets_the_plain_file(tmp_path, monkeypatch):
    client = web_client(tmp_path, monkeypatch)
    response = client.get("/main.dart.js", headers={"Accept-Encoding": "identity"})
    assert response.status_code == 200
    assert "content-encoding" not in response.headers
