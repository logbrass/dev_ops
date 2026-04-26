#!/usr/bin/env bash
# teardown.sh — nuke the cluster. Useful between demo runs.
set -euo pipefail
MINIKUBE_PROFILE=${MINIKUBE_PROFILE:-jarvis}
minikube -p "$MINIKUBE_PROFILE" delete
