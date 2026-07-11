#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VIEW_DIR="$PROJECT_DIR/gtkwave_views"
VCD_FILE="$PROJECT_DIR/sim/uart_fifo_sim/tb_top_loop_test.vcd"

case "${1:-}" in
    1|01|single)
        VIEW_FILE="$VIEW_DIR/01_single_byte_loopback.gtkw"
        ;;
    2|02|multi)
        VIEW_FILE="$VIEW_DIR/02_multi_byte_loopback.gtkw"
        ;;
    3|03|stream)
        VIEW_FILE="$VIEW_DIR/03_stream_loopback.gtkw"
        ;;
    4|04|fifo)
        VIEW_FILE="$VIEW_DIR/04_fifo_boundary.gtkw"
        ;;
    5|05|reset)
        VIEW_FILE="$VIEW_DIR/05_reset_recovery.gtkw"
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

if [[ ! -f "$VCD_FILE" ]]; then
    echo "Waveform file not found: $VCD_FILE"
    echo "Run ./build.sh from the project root first."
    exit 1
fi

exec gtkwave "$VCD_FILE" "$VIEW_FILE"
