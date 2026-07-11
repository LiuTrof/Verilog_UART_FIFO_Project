#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SIM_DIR="$PROJECT_DIR/sim/uart_fifo_sim"
LOG_DIR="$SIM_DIR/log"
CASE_NAME="${1:-all}"
OPEN_WAVE=0

if [[ "${2:-}" == "--wave" ]]; then
    OPEN_WAVE=1
fi

if [[ "$CASE_NAME" == "all" && "$OPEN_WAVE" == "1" ]]; then
    echo "Waveform export is available for individual scenarios only."
    echo "Run ./run.sh {single|multi|stream|fifo|reset} --wave"
    exit 2
fi

case "$CASE_NAME" in
    all|single|multi|stream|fifo|reset) ;;
    *)
        echo "Usage: $0 {all|single|multi|stream|fifo|reset} [--wave]"
        exit 2
        ;;
esac

mkdir -p "$SIM_DIR" "$LOG_DIR"

OUTPUT="$SIM_DIR/uart_fifo_${CASE_NAME}.out"
VCD_FILE="$SIM_DIR/${CASE_NAME}.vcd"
LOG_FILE="$LOG_DIR/${CASE_NAME}.log"
VVP_ARGS=("+TEST=$CASE_NAME")

if [[ "$OPEN_WAVE" == "1" ]]; then
    VVP_ARGS+=("+VCD=$VCD_FILE")
fi

cd "$PROJECT_DIR"
iverilog -g2012 -I tb -o "$OUTPUT" \
    tb/tb_top_loop_test.v \
    rtl/top_looptest.v \
    rtl/uart_fifo.v \
    rtl/uart.v \
    rtl/fifo.v

echo "[RUN] case=$CASE_NAME" | tee "$LOG_FILE"
vvp "$OUTPUT" "${VVP_ARGS[@]}" 2>&1 | tee -a "$LOG_FILE"
echo "[RUN] log=$LOG_FILE"
if [[ "$OPEN_WAVE" == "1" ]]; then
    echo "[RUN] waveform=$VCD_FILE"
fi

if [[ "$OPEN_WAVE" == "1" ]]; then
    if ! command -v gtkwave >/dev/null 2>&1; then
        echo "GTKWave is not installed."
        exit 1
    fi

    case "$CASE_NAME" in
        single) VIEW_FILE="$PROJECT_DIR/gtkwave_views/01_single_byte_loopback.gtkw" ;;
        multi) VIEW_FILE="$PROJECT_DIR/gtkwave_views/02_multi_byte_loopback.gtkw" ;;
        stream) VIEW_FILE="$PROJECT_DIR/gtkwave_views/03_stream_loopback.gtkw" ;;
        fifo) VIEW_FILE="$PROJECT_DIR/gtkwave_views/04_fifo_boundary.gtkw" ;;
        reset) VIEW_FILE="$PROJECT_DIR/gtkwave_views/05_reset_recovery.gtkw" ;;
        all) VIEW_FILE="" ;;
    esac

    if [[ -n "$VIEW_FILE" ]]; then
        gtkwave "$VCD_FILE" "$VIEW_FILE" >/dev/null 2>&1 &
    else
        gtkwave "$VCD_FILE" >/dev/null 2>&1 &
    fi
fi
