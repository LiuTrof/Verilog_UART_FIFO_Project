# GTKWave 场景波形视图

本目录包含 5 个 GTKWave 保存文件（`.gtkw`）。每个文件对应一个独立场景的 VCD，
只加载判断该场景所需的关键信号，不修改 DUT RTL。

使用 `./run.sh <场景> --wave` 或下面的启动脚本。脚本会先重新运行所选场景，保证
VCD 与当前 testbench 结构一致。

## 打开场景

在 GTKWave 中选择 **File -> Read Save File**，然后打开下列文件之一：

| 保存文件 | 场景 |
| --- | --- |
| `01_single_byte_loopback.gtkw` | 单字节 UART 回环：`A5` |
| `02_multi_byte_loopback.gtkw` | 多字节 UART 回环：`11 22 33 44` |
| `03_stream_loopback.gtkw` | 20 字节递增序列：`00` 至 `13` |
| `04_fifo_boundary.gtkw` | FIFO 连续写满，再连续读空 |
| `05_reset_recovery.gtkw` | 复位后再次执行 `A5` 回环 |

每个视图使用独立 VCD，因此时间轴都从 0 开始。

## 显示信号

每个视图只保留判断对应场景所必需的信号，避免波形窗口过于杂乱：

| 视图 | 用于判断场景的信号 |
| --- | --- |
| 单字节 | `rx`、`tx`、RX/TX 完成脉冲、`driver_data`、`monitor_data` |
| 多字节 | `rx`、`tx`、RX/TX 完成脉冲、`driver_data`、`monitor_data` |
| 递增序列 | `rx`、`tx`、`driver_data`、`monitor_data` |
| FIFO 边界 | FIFO 复位、读写使能、`full`、`empty`、写数据 |
| 复位恢复 | `reset`、`rx`、`tx`、RX/TX 完成脉冲、`driver_data`、`monitor_data` |

## 切换视图

GTKWave 的 **File -> Read Save File** 会将新视图信号追加到当前信号列表。若要在同一标签页
替换视图，先单击信号名称区域，再选择 **Edit -> Highlight All** 和 **Edit -> Delete** 清空列表，
最后通过 **File -> Read Save File** 加载下一个场景。

若希望用一条命令重新运行某场景并打开完全匹配的视图，可在项目根目录执行：

```bash
./gtkwave_views/open_view.sh 1
./gtkwave_views/open_view.sh 2
./gtkwave_views/open_view.sh 3
./gtkwave_views/open_view.sh 4
./gtkwave_views/open_view.sh 5
```
