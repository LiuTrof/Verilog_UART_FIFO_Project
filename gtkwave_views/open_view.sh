#!/usr/bin/env bash

# ============================================================================
# 文件作用：GTKWave 场景视图快捷启动器。
# 功能：将数字或场景名映射为 run.sh 的 +TEST 场景，再以 --wave 方式重新仿真并打开波形。
# 用法：./gtkwave_views/open_view.sh {1|2|3|4|5}
# ============================================================================
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"  # 项目根目录。

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
        echo "用法：$0 {1|2|3|4|5}"
        echo "  1：单字节回环"
        echo "  2：多字节回环"
        echo "  3：递增序列回环"
        echo "  4：FIFO 满空边界"
        echo "  5：复位恢复"
        exit 1
        ;;
esac

exec "$PROJECT_DIR/run.sh" "$CASE_NAME" --wave  # 用统一脚本重跑并打开对应视图。
