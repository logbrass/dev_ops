#!/usr/bin/env python3
import json
import subprocess
from http.server import BaseHTTPRequestHandler, HTTPServer

ROLLOUT = "jarvis-web-jarvis-web"
NAMESPACE = "jarvis"

def get_rollout():
    result = subprocess.run(
        ["kubectl", "get", "rollout", ROLLOUT, "-n", NAMESPACE, "-o", "json"],
        capture_output=True, text=True
    )
    return json.loads(result.stdout)

def build_page(data):
    s = data["status"]
    phase = s.get("phase", "Unknown")
    canary_w = s.get("canary", {}).get("weights", {}).get("canary", {}).get("weight", 0)
    stable_w = s.get("canary", {}).get("weights", {}).get("stable", {}).get("weight", 100)
    analysis = s.get("canary", {}).get("currentStepAnalysisRunStatus", {})
    analysis_status = analysis.get("status", "")
    analysis_msg = analysis.get("message", "")
    aborted = s.get("abort", False)

    phase_color = {
        "Healthy": "#22c55e",
        "Degraded": "#ef4444",
        "Paused": "#f59e0b",
        "Progressing": "#3b82f6",
    }.get(phase, "#6b7280")

    return f"""<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta http-equiv="refresh" content="3">
  <title>Jarvis Rollout</title>
  <style>
    body {{ font-family: monospace; background: #0f172a; color: #e2e8f0; padding: 40px; margin: 0; }}
    h1 {{ font-size: 1.4rem; margin-bottom: 30px; color: #94a3b8; }}
    .phase {{ font-size: 2rem; font-weight: bold; color: {phase_color}; margin-bottom: 30px; }}
    .label {{ font-size: 0.8rem; color: #64748b; margin-bottom: 6px; }}
    .bar-row {{ display: flex; height: 48px; border-radius: 6px; overflow: hidden; margin-bottom: 24px; }}
    .stable {{ background: #3b82f6; display: flex; align-items: center; justify-content: center; font-weight: bold; font-size: 1rem; }}
    .canary {{ background: #f59e0b; display: flex; align-items: center; justify-content: center; font-weight: bold; font-size: 1rem; color: #0f172a; }}
    .split {{ display: flex; gap: 40px; margin-bottom: 24px; }}
    .box {{ background: #1e293b; border-radius: 8px; padding: 20px 28px; }}
    .num {{ font-size: 2.5rem; font-weight: bold; }}
    .analysis {{ background: #1e293b; border-radius: 8px; padding: 16px 20px; font-size: 0.85rem; color: #94a3b8; }}
    .aborted {{ color: #ef4444; font-weight: bold; margin-bottom: 12px; }}
  </style>
</head>
<body>
  <h1>jarvis-web rollout &mdash; refreshes every 3s</h1>
  <div class="phase">{phase}</div>
  {'<div class="aborted">ABORTED (rollback)</div>' if aborted else ''}
  <div class="label">Traffic split</div>
  <div class="bar-row">
    <div class="stable" style="width:{stable_w}%">{stable_w}% stable</div>
    <div class="canary" style="width:{canary_w}%">{f"{canary_w}% canary" if canary_w > 5 else ""}</div>
  </div>
  <div class="split">
    <div class="box">
      <div class="label">Stable</div>
      <div class="num" style="color:#3b82f6">{stable_w}%</div>
    </div>
    <div class="box">
      <div class="label">Canary</div>
      <div class="num" style="color:#f59e0b">{canary_w}%</div>
    </div>
  </div>
  {'<div class="analysis"><b>Analysis:</b> ' + analysis_status + ' &mdash; ' + analysis_msg + '</div>' if analysis_status else ''}
</body>
</html>"""

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        try:
            data = get_rollout()
            html = build_page(data)
            self.send_response(200)
            self.send_header("Content-Type", "text/html")
            self.end_headers()
            self.wfile.write(html.encode())
        except Exception as e:
            self.send_response(500)
            self.end_headers()
            self.wfile.write(f"<pre>Error: {e}</pre>".encode())

    def log_message(self, *args):
        pass  # silence request logs

if __name__ == "__main__":
    port = 3000
    print(f"Dashboard running at http://localhost:{port}")
    HTTPServer(("", port), Handler).serve_forever()
