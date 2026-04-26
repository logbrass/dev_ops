# jarvis-web

A tiny FastAPI service that renders one HTML page whose background color and
version label come from environment variables. We ship multiple image tags of
this service to make canary rollouts visible at a glance:

| Tag | `APP_VERSION` | `THEME_COLOR` | `THEME_NAME` | `FAIL_MODE` | Purpose |
| --- | --- | --- | --- | --- | --- |
| `v1.0.0` | v1.0.0 | `#1f6feb` | blue | `false` | initial stable |
| `v2.0.0` | v2.0.0 | `#f97316` | orange | `false` | the canary upgrade |
| `v3.0.0-broken` | v3.0.0 | `#dc2626` | red | `true` | deliberately failing — used to demo auto-rollback |

## Endpoints

- `GET /` — colored version page
- `GET /version` — JSON `{version, theme, color}`
- `GET /healthz` — liveness probe (returns 500 when `FAIL_MODE=true`)
- `GET /readyz` — readiness probe
- `GET /metrics` — Prometheus metrics scraped by Argo Rollouts AnalysisTemplate

## Local run

```bash
pip install -r requirements.txt
APP_VERSION=v1.0.0 THEME_COLOR='#1f6feb' THEME_NAME=blue \
  uvicorn app.main:app --reload --port 8080
```

## Tests

```bash
pip install -r requirements.txt
pytest -q
```

## Build

```bash
docker build -t jarvis-web:v1.0.0 .
docker run --rm -p 8080:8080 \
  -e APP_VERSION=v1.0.0 -e THEME_COLOR='#1f6feb' -e THEME_NAME=blue \
  jarvis-web:v1.0.0
```
