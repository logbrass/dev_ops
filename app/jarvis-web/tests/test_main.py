"""Smoke tests for jarvis-web. Run via `pytest` in CI before image builds."""
import os

from fastapi.testclient import TestClient

os.environ.setdefault("APP_VERSION", "v-test")
os.environ.setdefault("THEME_COLOR", "#000000")
os.environ.setdefault("THEME_NAME", "test")

from app.main import app  # noqa: E402  (import-after-env is intentional)

client = TestClient(app)


def test_index_renders_version() -> None:
    r = client.get("/")
    assert r.status_code == 200
    assert "v-test" in r.text


def test_healthz() -> None:
    r = client.get("/healthz")
    assert r.status_code == 200
    assert r.json()["status"] == "ok"


def test_readyz() -> None:
    r = client.get("/readyz")
    assert r.status_code == 200


def test_version_endpoint() -> None:
    r = client.get("/version")
    body = r.json()
    assert body["version"] == "v-test"
    assert body["theme"] == "test"


def test_metrics_exposed() -> None:
    r = client.get("/metrics")
    assert r.status_code == 200
    assert b"http_requests_total" in r.content
