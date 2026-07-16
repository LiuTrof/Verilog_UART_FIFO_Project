#!/usr/bin/env bash

# ============================================================================
# 文件作用：项目统一仿真入口。
# 功能：编译当前 rtl/ 和 tb/，运行 +TEST 指定的验证场景，将终端输出保存为日志；
# 可选生成 VCD 并打开对应 GTKWave 视图。
# 用法：./run.sh {single|multi|stream|fifo|reset|all} [--wave]
# 说明：all 是完整回归；--wave 只支持单独场景，避免大 VCD 拖慢回归。
# ============================================================================
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"  # 项目根目录。
SIM_DIR="$PROJECT_DIR/sim/uart_fifo_sim"                         # 仿真生成物目录。
LOG_DIR="$SIM_DIR/log"                                           # 每个场景的日志目录。
CASE_NAME="${1:-all}"                                            # 第一个参数；缺省时运行完整回归。
OPEN_WAVE=0                                                       # 是否生成并打开波形的开关。

if [[ "${2:-}" == "--wave" ]]; then
    OPEN_WAVE=1  # 第二个参数为 --wave 时启用 VCD 与 GTKWave。
fi

if [[ "$CASE_NAME" == "all" && "$OPEN_WAVE" == "1" ]]; then
    echo "波形导出只支持单独场景。"
    echo "请运行：./run.sh {single|multi|stream|fifo|reset} --wave"
    exit 2
fi

case "$CASE_NAME" in
    all|single|multi|stream|fifo|reset) ;;
    *)
        echo "用法：$0 {all|single|multi|stream|fifo|reset} [--wave]"
        exit 2
        ;;
esac

mkdir -p "$SIM_DIR" "$LOG_DIR"  # 首次运行时自动创建输出目录。

OUTPUT="$SIM_DIR/uart_fifo_${CASE_NAME}.out"  # Icarus 编译生成的仿真可执行文件。
VCD_FILE="$SIM_DIR/${CASE_NAME}.vcd"           # 可选波形文件路径。
LOG_FILE="$LOG_DIR/${CASE_NAME}.log"           # 场景运行日志路径。
VVP_ARGS=("+TEST=$CASE_NAME")                   # 传给 Testbench 的 plusarg。

if [[ "$OPEN_WAVE" == "1" ]]; then
    VVP_ARGS+=("+VCD=$VCD_FILE")
fi

cd "$PROJECT_DIR"  # 保证包含路径和生成物路径都相对项目根目录。
iverilog -g2012 -I tb -o "$OUTPUT" \
    tb/tb_top_loop_test.v \
    rtl/top_looptest.v \
    rtl/uart_fifo.v \
    rtl/uart.v \
    rtl/fifo.v

echo "[RUN] 场景=$CASE_NAME" | tee "$LOG_FILE"  # 新建日志并记录场景名。
vvp "$OUTPUT" "${VVP_ARGS[@]}" 2>&1 | tee -a "$LOG_FILE"  # 运行并同时输出到终端和日志。
echo "[RUN] 日志=$LOG_FILE"
if [[ "$OPEN_WAVE" == "1" ]]; then
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
