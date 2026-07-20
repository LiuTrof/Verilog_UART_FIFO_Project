#!/usr/bin/env bash

# Start the fixed public demo tunnel after the SSH key has been registered with Serveo.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUBDOMAIN="${1:-chip-dv-uart-demo}"
LOCAL_PORT="${2:-5173}"

if ! curl -fsS "http://127.0.0.1:${LOCAL_PORT}" >/dev/null; then
    echo "Frontend is not reachable at http://127.0.0.1:${LOCAL_PORT}."
    echo "Start it first with: cd ${PROJECT_DIR}/dv_platform/frontend && npm run dev -- --host 127.0.0.1"
    exit 1
fi

echo "Public demo URL: https://${SUBDOMAIN}.serveousercontent.com"
echo "Keep this terminal open while presenting. Press Control+C to stop the tunnel."

while true; do
    ssh \
        -o StrictHostKeyChecking=accept-new \
        -o ExitOnForwardFailure=yes \
        -o ConnectTimeout=15 \
        -o ServerAliveInterval=15 \
        -o ServerAliveCountMax=2 \
        -o TCPKeepAlive=yes \
        -R "${SUBDOMAIN}:80:localhost:${LOCAL_PORT}" \
        serveo.net

    echo "Tunnel connection ended; retrying in 3 seconds. Press Control+C to stop."
    sleep 3
done
