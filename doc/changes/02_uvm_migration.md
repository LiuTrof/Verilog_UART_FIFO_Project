# 02 - UART FIFO UVM 迁移

## 目标

在不修改 `rtl/` 的前提下，将默认验证入口由 module 内 `task` 调用迁移为标准
UVM 1.2 class-based 环境。旧的过程式文件仍保留为学习对照，但 `run.sh` 不再编译它们。

## UVM 结构

```text
uart_fifo_test
  -> uart_fifo_env
       -> uart_agent
            -> sequencer
            -> driver  -- virtual uart_fifo_if --> DUT rx
            -> monitor -- virtual uart_fifo_if --> DUT tx
       -> scoreboard
       -> checker
```

Driver 将每一个 `uart_item` 通过 UART 8N1 帧驱动到 `rx`，并从 analysis port 发出
预期事务。Monitor 独立从 `tx` 解码，将实际事务送到 Scoreboard。Scoreboard 使用队列
按序比对两条事务流，检查错误输出和仿真结束时的未匹配预期。

`uart_fifo_checker` 通过只读状态 interface 检查三个 FIFO 不会同时报告 `full` 与
`empty`。独立的 `fifo_boundary_if` 保留了原先连续写满、连续读空的边界回归。

## 文件

| 文件 | 内容 |
| --- | --- |
| `tb/uvm/uart_fifo_if.sv` | UART pin、FIFO 边界和只读状态 interface。 |
| `tb/uvm/uart_fifo_pkg.sv` | transaction、sequence、agent、scoreboard、checker、env 与 test。 |
| `tb/uvm/tb_top_loop_test_uvm.sv` | DUT 实例、virtual interface 配置和 `run_test()` 入口。 |
| `run.sh` | 自动选择 VCS、Xcelium 或 Questa/ModelSim 的 UVM 启动脚本。 |

## 执行

`run.sh` 支持与旧入口相同的场景：`single`、`multi`、`stream`、`fifo`、`reset` 和
`all`。例如：

```bash
./run.sh all
./run.sh multi --wave
```

需要可运行 UVM 1.2 的 SystemVerilog 仿真器：VCS、Xcelium 或配置好 `UVM_HOME` 的
Questa/ModelSim。Icarus Verilog 不支持此标准 UVM class-based 环境；脚本会明确停止
并提示所需工具，而不会回退执行旧 testbench。
