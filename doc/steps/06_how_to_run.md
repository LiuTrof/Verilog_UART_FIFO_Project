# Step 06 - 如何运行仿真

## 运行命令

在 `Verilog_UART_FIFO_0524` 目录下使用统一 UVM 入口。需要 VCS、Questa/ModelSim
（含 UVM）或 Xcelium；Icarus Verilog 不能执行标准 UVM class-based testbench。

```bash
./run.sh single
./run.sh multi
./run.sh stream
./run.sh fifo
./run.sh reset
./run.sh all
```

## 查看波形

为单个场景生成并打开波形：

```bash
./run.sh multi --wave
```

也可以使用 GTKWave 场景启动脚本：

```bash
./gtkwave_views/open_view.sh 2
```

日志会生成在：

```text
sim/uart_fifo_sim/log/<场景名>.log
```

## 本次验证结果

当前仿真结果：

```text
已检查字节数 : 26
未匹配预期数 : 0
当前错误数   : 0
结果         : TEST PASS
```

## 小白要记住的点

每次改 testbench 或 RTL 后，都要重新编译和运行。验证工程师的基本动作是：修改、仿真、看日志、必要时看波形。推荐先运行 `./run.sh single` 快速验证，再运行 `./run.sh all` 做完整回归。
