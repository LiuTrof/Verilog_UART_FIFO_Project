#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SIM_DIR="$PROJECT_DIR/sim/uart_fifo_sim"
OUTPUT="$SIM_DIR/uart_fifo_tb_new.out"
VCD_FILE="$SIM_DIR/tb_top_loop_test.vcd"

cd "$PROJECT_DIR"
mkdir -p "$SIM_DIR"

echo "========================================"
echo "UART FIFO simulation build"
echo "========================================"
echo "[1/2] Compiling rtl design and tb testbench..."

iverilog -g2012 -I tb -o "$OUTPUT" \
    tb/tb_top_loop_test.v \
    rtl/top_looptest.v \
    rtl/uart_fifo.v \
    rtl/uart.v \
    rtl/fifo.v

echo "[2/2] Running simulation..."
vvp "$OUTPUT"

echo "========================================"
echo "Simulation completed successfully"
echo "Executable: $OUTPUT"
echo "Waveform:   $VCD_FILE"
echo "========================================"

if command -v gtkwave >/dev/null 2>&1; then
    read -r -p "Open waveform in GTKWave? [y/N] " open_wave
    if [[ "$open_wave" =~ ^[Yy]$ ]]; then
        gtkwave "$VCD_FILE" >/dev/null 2>&1 &
        echo "GTKWave opened: $VCD_FILE"
    fi
else
    echo "GTKWave is not installed. Open the VCD file with another waveform viewer."
fi
