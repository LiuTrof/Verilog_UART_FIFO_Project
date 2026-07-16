# UART FIFO 模块级验证项目

这是一个基于 Verilog 的 UART + FIFO 回环验证项目。项目不修改原有 RTL 功能，而是在其外部搭建可重复运行、自检和波形定位的模块级验证环境。

当前完整回归结果：26 个 UART 字节检查完成，预期队列无残留，错误数为 0，结果为 `TEST PASS`。

## 设计与验证架构

![UART FIFO 回环：设计数据路径与验证数据路径](doc/images_cn/uart_fifo_loopback_architecture.png)

设计数据路径：

```text
UART RX 串行输入
  -> UART 接收器
  -> RX FIFO
  -> 顶层回环搬运逻辑
  -> TX FIFO
  -> UART 发送器
  -> UART TX 串行输出
```

验证数据路径：Driver 将字节编码成 `rx` 串行帧，同时把预期字节写入 Scoreboard 队列；
Monitor 只从 `tx` 端独立解码实际字节；Scoreboard 按顺序比较预期与实际并输出 PASS/FAIL。

## 当前代码结构

| 文件 | 作用 |
| --- | --- |
| `rtl/top_looptest.v` | DUT 顶层；控制 RX FIFO 到 TX FIFO 的数据搬运。 |
| `rtl/uart_fifo.v` | UART 与 RX/TX 双 FIFO 的封装。 |
| `rtl/uart.v` | 波特率发生器、UART 发送器、UART 接收器。 |
| `rtl/fifo.v` | 可复用 FIFO；包含存储阵列与指针/满空控制。 |
| `tb/tb_top_loop_test.v` | Testbench 顶层；时钟、DUT、VCD、检查与主流程入口。 |
| `tb/driver/uart_driver.vh` | UART Driver；生成串行激励并施加复位。 |
| `tb/monitor/uart_monitor.vh` | UART Monitor；从 TX 端采样和恢复实际字节。 |
| `tb/scoreboard.vh` | 预期队列与自动比对。 |
| `tb/test_case.vh` | 场景选择与测试用例。 |
| `tb/uart_task.vh` | 未参与当前编译的旧版 task，仅作新旧写法对照。 |

所有实际参与运行的 RTL/TB 文件都已添加中文文件头和逐段注释。系统化学习请从 [RTL 与 TB 初学者指南](doc/rtl_tb_beginner_guide.md) 开始。

## 测试场景

| 场景 | 命令 | 激励与检查 |
| --- | --- | --- |
| `single` | `./run.sh single` | 单字节 `A5` 端到端回环。 |
| `multi` | `./run.sh multi` | `11 22 33 44` 的数据一致性与顺序。 |
| `stream` | `./run.sh stream` | 20 字节递增序列 `00` 至 `13`。 |
| `fifo` | `./run.sh fifo` | 独立 FIFO 连续写 8 次后的 `full`，读 8 次后的 `empty`。 |
| `reset` | `./run.sh reset` | 复位后重新发送 `A5` 的功能恢复。 |
| `all` | `./run.sh all` | 执行完整回归。 |

`multi` 与 `stream` 使用帧间保护间隔，因此验证的是当前设计覆盖范围内的数据一致性和顺序性，不是 FIFO 灌满后的极限吞吐压力测试。

## 运行仿真

依赖工具：Icarus Verilog、GTKWave。

```bash
./run.sh single
./run.sh all
./run.sh multi --wave
```

每次运行会将日志写入 `sim/uart_fifo_sim/log/<场景>.log`。`--wave` 会生成对应 VCD 并打开匹配的 GTKWave 视图；完整回归不导出波形，以避免长时间 VCD 影响运行速度。

GTKWave 场景视图说明见 [gtkwave_views/README.md](gtkwave_views/README.md)。详细测试范围与通过标准见 [验证计划](doc/verification_plan.md)。

## 学习资料

- [RTL 与 TB 初学者指南](doc/rtl_tb_beginner_guide.md)：推荐三小时学习路径、逐文件职责和关键时序。
- `doc/images_cn/`：新增中文架构图、UART 帧图、FIFO 指针图和自检流程图；PNG 可直接预览，SVG 可放大查看。
- `doc/images/`：保留英文原始示意图，不做修改。
- `doc/waveform_causality.md`：将 RTL 行为与波形现象对应起来。
- `doc/steps/`：记录目录整理、testbench 拆分、用例、Scoreboard、检查和运行方式。

## 项目概述

> 基于 Verilog UART/FIFO RTL，完成 UART 收发器、FIFO 缓冲模块及顶层 loopback 数据通路分析，梳理 UART RX -> RX FIFO -> 顶层搬运逻辑 -> TX FIFO -> UART TX 的完整传输链路。在原有单字节仿真基础上，搭建模块级 Verilog 自检验证环境，将 UART 串行发送与接收任务拆分为 Driver 和 Monitor，分别完成 `rx` 端激励生成与 `tx` 端数据采样恢复；引入 Scoreboard 机制，对预期数据与实际输出进行自动比对。设计单字节回环、多字节顺序传输、递增序列传输、FIFO 模块 `full/empty` 边界及 reset recovery 等测试场景，并使用 Icarus Verilog 和 GTKWave 完成场景化回归仿真与波形分析，验证 UART FIFO 回环数据通路的基本功能、数据一致性及复位恢复能力。
