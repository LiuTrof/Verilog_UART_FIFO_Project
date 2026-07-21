#!/usr/bin/env bash

# Start an account-less Cloudflare Quick Tunnel for a temporary public demo.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCAL_PORT="${1:-5173}"
API_CHECK_URL="http://127.0.0.1:${LOCAL_PORT}/api/v1/projects"
TUNNEL_LOG="$(mktemp -t chip-dv-cloudflared.XXXXXX)"
TUNNEL_PID=""

cleanup() {
    if [[ -n "${TUNNEL_PID}" ]] && kill -0 "${TUNNEL_PID}" 2>/dev/null; then
        kill "${TUNNEL_PID}" 2>/dev/null || true
        wait "${TUNNEL_PID}" 2>/dev/null || true
    fi
    rm -f "${TUNNEL_LOG}"
}

trap cleanup EXIT
trap 'exit 0' INT TERM

if ! curl -fsS "http://127.0.0.1:${LOCAL_PORT}" >/dev/null; then
    echo "Frontend is not reachable at http://127.0.0.1:${LOCAL_PORT}."
    echo "Start it first with: cd ${PROJECT_DIR}/dv_platform/frontend && npm run dev -- --host 127.0.0.1"
    exit 1
fi

if ! curl -fsS "${API_CHECK_URL}" >/dev/null; then
    echo "The frontend is running, but its /api proxy cannot reach the backend."
    echo "Start the backend first: ${PROJECT_DIR}/.venv/bin/uvicorn dv_platform.backend.app.main:app --reload --host 127.0.0.1 --port 8000"
    exit 1
fi

if ! command -v cloudflared >/dev/null; then
    echo "cloudflared is required. Install it with: brew install cloudflared"
    exit 1
fi

echo "Creating a Cloudflare Quick Tunnel for http://127.0.0.1:${LOCAL_PORT} ..."
echo "Keep this terminal open while presenting. Each restart creates a new URL."
echo "The frontend and backend connection has been checked."

while true; do
    : > "${TUNNEL_LOG}"
    cloudflared tunnel --protocol http2 --url "http://127.0.0.1:${LOCAL_PORT}" \
        > >(tee "${TUNNEL_LOG}") 2>&1 &
    TUNNEL_PID=$!

    shared_url=""
    while kill -0 "${TUNNEL_PID}" 2>/dev/null; do
        # Use macOS built-ins so this script does not require ripgrep (rg).
        discovered_url="$(grep -Eo 'https://[[:alnum:]-]+\.trycloudflare\.com' "${TUNNEL_LOG}" | tail -n 1 || true)"
        if [[ -n "${discovered_url}" && "${discovered_url}" != "${shared_url}" ]]; then
            shared_url="${discovered_url}"
            printf '\nPublic URL (share this exact URL): %s\n\n' "${shared_url}"
        fi
        sleep 0.2
    done

    wait "${TUNNEL_PID}" || true
    TUNNEL_PID=""
    echo "Tunnel process ended; creating a new temporary URL in 3 seconds."
    sleep 3
done
