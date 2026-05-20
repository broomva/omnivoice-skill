#!/usr/bin/env bash
# Start the OmniVoice FastAPI backend on 127.0.0.1:3900, detached, idempotent.
# Honors $OMNIVOICE_HOME (default ~/OmniVoice-Studio).
set -euo pipefail

HOME_DIR="${OMNIVOICE_HOME:-$HOME/OmniVoice-Studio}"
URL="${OMNIVOICE_API_URL:-http://127.0.0.1:3900}"
LOG="$HOME_DIR/backend.log"

if [ ! -d "$HOME_DIR" ]; then
  echo "OMNIVOICE_HOME not found: $HOME_DIR" >&2
  echo "See references/mcp-setup.md for install steps." >&2
  exit 2
fi

# Already up?
if curl -sf --max-time 2 "$URL/health" >/dev/null 2>&1; then
  echo "already running: $URL"
  curl -sf "$URL/health"; echo
  exit 0
fi

# Port held by something else?
if lsof -nP -iTCP:3900 -sTCP:LISTEN >/dev/null 2>&1; then
  echo "port 3900 held but /health not responding — investigate before starting" >&2
  lsof -nP -iTCP:3900 -sTCP:LISTEN >&2
  exit 3
fi

cd "$HOME_DIR"
nohup uv run uvicorn main:app --app-dir backend --host 127.0.0.1 --port 3900 \
  > "$LOG" 2>&1 &
PID=$!
echo "starting backend (PID $PID, log: $LOG)..."

# Wait up to 60 s for /health
for i in $(seq 1 30); do
  sleep 2
  if curl -sf --max-time 2 "$URL/health" >/dev/null 2>&1; then
    curl -sf "$URL/health"; echo
    echo "ready after $((i*2))s"
    exit 0
  fi
done

echo "backend did not respond on $URL/health within 60s — see $LOG" >&2
exit 4
