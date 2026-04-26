"""jarvis-web: tiny FastAPI service used as the canary-rollout target.

The page color and version label are driven by environment variables so we can
ship visually distinct images (v1 = blue, v2 = orange, v3 = broken) without
touching any code. This is what the team will see during a live canary on
Argo Rollouts.
"""
import os
import socket

from fastapi import FastAPI, Response
from fastapi.responses import HTMLResponse
from prometheus_fastapi_instrumentator import Instrumentator

VERSION = os.getenv("APP_VERSION", "v0.0.0")
THEME_COLOR = os.getenv("THEME_COLOR", "#1f6feb")
THEME_NAME = os.getenv("THEME_NAME", "default")

# When set truthy, /healthz and /readyz return 500 and "/" returns 500 on every
# Nth request. We use this to ship a deliberately-broken image (v3) and watch
# Argo Rollouts auto-rollback once Prometheus analysis trips.
FAIL_MODE = os.getenv("FAIL_MODE", "false").lower() in ("1", "true", "yes")
FAIL_RATIO = int(os.getenv("FAIL_RATIO", "1"))

app = FastAPI(title="jarvis-web", version=VERSION)

# Expose Prometheus /metrics for Argo Rollouts AnalysisTemplate to scrape.
Instrumentator().instrument(app).expose(app, endpoint="/metrics")

_request_counter = 0


@app.get("/", response_class=HTMLResponse)
def index() -> Response:
    """Render a single page whose background reflects this pod's version."""
    global _request_counter
    _request_counter += 1
    if FAIL_MODE and _request_counter % FAIL_RATIO == 0:
        return HTMLResponse(content="boom", status_code=500)

    pod = socket.gethostname()
    html = f"""<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <title>Jarvis {VERSION}</title>
    <style>
      html, body {{ margin: 0; height: 100%; font-family: -apple-system, system-ui, sans-serif; }}
      body {{
        background: {THEME_COLOR};
        color: #fff;
        display: flex; flex-direction: column; align-items: center; justify-content: center;
      }}
      h1 {{ font-size: 5rem; margin: 0; letter-spacing: -2px; }}
      h2 {{ font-weight: 400; opacity: 0.85; margin: 0.5rem 0 2rem; }}
      code {{ background: rgba(0,0,0,0.25); padding: 0.4rem 0.8rem; border-radius: 6px; }}
    </style>
  </head>
  <body>
    <h1>Jarvis {VERSION}</h1>
    <h2>theme: {THEME_NAME}</h2>
    <code>pod: {pod}</code>
  </body>
</html>"""
    return HTMLResponse(content=html)


@app.get("/healthz")
def healthz() -> dict:
    """Liveness probe. Returns 500 when FAIL_MODE is on so K8s/Rollouts notice."""
    if FAIL_MODE:
        return Response(status_code=500)
    return {"status": "ok", "version": VERSION}


@app.get("/readyz")
def readyz() -> dict:
    """Readiness probe — kept separate from liveness so we can fail just one."""
    return {"status": "ready", "version": VERSION}


@app.get("/version")
def version() -> dict:
    """Plain-JSON version endpoint used by demo scripts."""
    return {"version": VERSION, "theme": THEME_NAME, "color": THEME_COLOR}
