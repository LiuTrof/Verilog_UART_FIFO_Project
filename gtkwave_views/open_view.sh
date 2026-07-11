#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

case "${1:-}" in
    1|01|single)
        CASE_NAME="single"
        ;;
    2|02|multi)
        CASE_NAME="multi"
        ;;
    3|03|stream)
        CASE_NAME="stream"
        ;;
    4|04|fifo)
        CASE_NAME="fifo"
        ;;
    5|05|reset)
        CASE_NAME="reset"
        ;;
    *)
        echo "Usage: $0 {1|2|3|4|5}"
        echo "  1: single byte loopback"
        echo "  2: multi-byte loopback"
        echo "  3: stream loopback"
        echo "  4: FIFO boundary"
        echo "  5: reset recovery"
        exit 1
        ;;
esac

exec "$PROJECT_DIR/run.sh" "$CASE_NAME" --wave
