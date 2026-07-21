#!/usr/bin/env bash

# ============================================================================
# 文件作用：项目统一 UVM 仿真入口。
# 功能：使用 VCS、Questa 或 Xcelium 编译 RTL/UVM testbench，运行 +TEST 指定的
# 场景并保存日志；可选生成 VCD 和打开对应 GTKWave 视图。
# 用法：./run.sh {single|multi|stream|multi16|stream64|stream128|patterns|fifo|reset|reset_stream|all} [--wave | --vcd <路径>]
# 说明：all 是完整回归；--wave 只支持单独场景，避免大 VCD 拖慢回归。
# ============================================================================
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"  # 项目根目录。
SIM_DIR="$PROJECT_DIR/sim/uart_fifo_sim"                         # 仿真生成物目录。
LOG_DIR="$SIM_DIR/log"                                           # 每个场景的日志目录。
CASE_NAME="${1:-all}"                                            # 第一个参数；缺省时运行完整回归。
OPEN_WAVE=0                                                       # 是否生成并打开波形的开关。
VCD_FILE=""                                                      # 仅导出 VCD 时由调用方指定。

case "${2:-}" in
    "") ;;
    --wave)
        OPEN_WAVE=1
        ;;
    --vcd)
        VCD_FILE="${3:-}"
        if [[ -z "$VCD_FILE" ]]; then
            echo "--vcd 需要指定输出文件路径。"
            exit 2
        fi
        ;;
    *)
        echo "用法：$0 {single|multi|stream|multi16|stream64|stream128|patterns|fifo|reset|reset_stream|all} [--wave | --vcd <路径>]"
        exit 2
        ;;
esac

if [[ "$CASE_NAME" == "all" && "$OPEN_WAVE" == "1" ]]; then
    echo "波形导出只支持单独场景。"
    echo "请运行：./run.sh {single|multi|stream|multi16|stream64|stream128|patterns|fifo|reset|reset_stream} --wave"
    exit 2
fi

case "$CASE_NAME" in
    all|single|multi|stream|multi16|stream64|stream128|patterns|fifo|reset|reset_stream) ;;
    *)
        echo "用法：$0 {all|single|multi|stream|multi16|stream64|stream128|patterns|fifo|reset|reset_stream} [--wave | --vcd <路径>]"
        exit 2
        ;;
esac

mkdir -p "$SIM_DIR" "$LOG_DIR"  # 首次运行时自动创建输出目录。

OUTPUT="$SIM_DIR/uart_fifo_${CASE_NAME}.out"  # VCS 编译生成的仿真可执行文件。
LOG_FILE="$LOG_DIR/${CASE_NAME}.log"           # 场景运行日志路径。
SIM_ARGS=("+TEST=$CASE_NAME")                   # 传给 Testbench 的 plusarg。

if [[ "$OPEN_WAVE" == "1" ]]; then
    VCD_FILE="$SIM_DIR/${CASE_NAME}.vcd"
fi

if [[ -n "$VCD_FILE" ]]; then
    mkdir -p "$(dirname "$VCD_FILE")"
    SIM_ARGS+=("+VCD=$VCD_FILE")
fi

RTL_FILES=(
    rtl/top_looptest.v
    rtl/uart_fifo.v
    rtl/uart.v
    rtl/fifo.v
)
UVM_FILES=(
    tb/uvm/uart_fifo_if.sv
    tb/uvm/uart_fifo_pkg.sv
    tb/uvm/tb_top_loop_test_uvm.sv
)

cd "$PROJECT_DIR"  # 保证包含路径和生成物路径都相对项目根目录。
if command -v vcs >/dev/null 2>&1; then
    vcs -sverilog -ntb_opts uvm-1.2 -timescale=1ns/1ps -top tb_top_loop_test_uvm \
        -Mdir="$SIM_DIR/vcs_csrc" -o "$OUTPUT" \
        "${UVM_FILES[@]}" "${RTL_FILES[@]}"
    RUN_SIM=("$OUTPUT")
elif command -v xrun >/dev/null 2>&1; then
    RUN_SIM=(xrun -64bit -uvm -access +rwc -timescale 1ns/1ps -top tb_top_loop_test_uvm \
        -xmlibdirname "$SIM_DIR/xcelium.d" \
        "${UVM_FILES[@]}" "${RTL_FILES[@]}")
elif command -v vsim >/dev/null 2>&1 && command -v vlib >/dev/null 2>&1; then
    if [[ -z "${UVM_HOME:-}" || ! -f "$UVM_HOME/src/uvm_pkg.sv" ]]; then
        echo "Questa/ModelSim 需要设置 UVM_HOME，且其中应包含 src/uvm_pkg.sv。"
        echo "示例：export UVM_HOME=/path/to/uvm-1.2"
        exit 127
    fi
    WORK_LIB="$SIM_DIR/work"
    rm -rf "$WORK_LIB"
    vlib "$WORK_LIB"
    vlog -work "$WORK_LIB" -sv +define+UVM_NO_DPI \
        "+incdir+$UVM_HOME/src" "$UVM_HOME/src/uvm_pkg.sv" \
        "${UVM_FILES[@]}" "${RTL_FILES[@]}"
    RUN_SIM=(vsim -c -lib "$WORK_LIB" tb_top_loop_test_uvm -do "run -all; quit -f")
else
    echo "未检测到支持 UVM 1.2 的仿真器。"
    echo "请安装或配置 VCS、Questa/ModelSim（含 UVM）或 Xcelium，然后重新运行。"
    echo "当前检测到的 Icarus Verilog 不能运行标准 UVM class-based testbench。"
    exit 127
fi

echo "[RUN] 场景=$CASE_NAME" | tee "$LOG_FILE"  # 新建日志并记录场景名。
"${RUN_SIM[@]}" "${SIM_ARGS[@]}" 2>&1 | tee -a "$LOG_FILE"  # 运行并同时输出到终端和日志。
echo "[RUN] 日志=$LOG_FILE"
if [[ -n "$VCD_FILE" ]]; then
    echo "[RUN] 波形=$VCD_FILE"
fi

if [[ "$OPEN_WAVE" == "1" ]]; then
    if ! command -v gtkwave >/dev/null 2>&1; then
        echo "未安装 GTKWave。"
        exit 1
    fi

    case "$CASE_NAME" in  # 为每个场景匹配其信号精简的 GTKWave 保存视图。
        single) VIEW_FILE="$PROJECT_DIR/gtkwave_views/01_single_byte_loopback.gtkw" ;;
        multi) VIEW_FILE="$PROJECT_DIR/gtkwave_views/02_multi_byte_loopback.gtkw" ;;
        stream) VIEW_FILE="$PROJECT_DIR/gtkwave_views/03_stream_loopback.gtkw" ;;
        multi16|stream64|stream128|patterns|reset_stream) VIEW_FILE="$PROJECT_DIR/gtkwave_views/03_stream_loopback.gtkw" ;;
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
