#!/usr/bin/env bash

# Start an account-less Cloudflare Quick Tunnel for a temporary public demo.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCAL_PORT="${1:-5173}"

if ! curl -fsS "http://127.0.0.1:${LOCAL_PORT}" >/dev/null; then
    echo "Frontend is not reachable at http://127.0.0.1:${LOCAL_PORT}."
    echo "Start it first with: cd ${PROJECT_DIR}/dv_platform/frontend && npm run dev -- --host 127.0.0.1"
    exit 1
fi

if ! command -v cloudflared >/dev/null; then
    echo "cloudflared is required. Install it with: brew install cloudflared"
    exit 1
fi

echo "Cloudflare will print a temporary https://*.trycloudflare.com URL below."
echo "Keep this terminal open while presenting. Press Control+C to stop the tunnel."

while true; do
    cloudflared tunnel --protocol http2 --url "http://127.0.0.1:${LOCAL_PORT}"
    echo "Tunnel connection ended; retrying in 3 seconds. Press Control+C to stop."
    sleep 3
done
