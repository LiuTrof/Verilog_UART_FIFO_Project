# UART FIFO Verification Project

## 1. Project Overview

这是一个基于 Verilog 的 UART + FIFO 回环验证项目。项目目标不是只把 GitHub RTL 跑起来，而是把它整理成一个面向数字 IC 验证岗位的作品集项目：有清晰目录、有 testbench、有自动检查、有 FIFO 边界测试、有文档记录。

当前验证结果：

```text
CHECKED BYTE : 26
ERROR        : 0
RESULT       : TEST PASS
```

## 2. DUT Architecture

当前 loopback 数据链路：

```text
UART RX serial input
        |
        v
    UART Receiver
        |
        v
      RX FIFO
        |
        v
  Top Loopback Logic
        |
        v
      TX FIFO
        |
        v
   UART Transmitter
        |
        v
UART TX serial output
```

RTL 入口：

```text
rtl/uart.v
rtl/fifo.v
rtl/uart_fifo.v
rtl/top_looptest.v
```

原 Vivado 风格源码仍保留在：

```text
sources_1/new/
```

## 3. Verification Environment

验证环境结构：

```text
tb/tb_top_loop_test.v       # testbench top
tb/driver/uart_driver.vh    # serial stimulus and reset driver
tb/monitor/uart_monitor.vh  # TX serial monitor and decoder
tb/scoreboard.vh            # expected queue and automatic checker
tb/test_case.vh             # test selection and test cases
```

验证数据流：

```text
                 +-------------------------------+
                 |           Testcase            |
                 +---------------+---------------+
                                 |
                                 v
                 +-------------------------------+
                 | UART Driver                    |
                 | drives rx and queues expected  |
                 +---------------+---------------+
                                 |
                                 v
                 +-------------------------------+
                 | UART FIFO DUT                  |
                 +---------------+---------------+
                                 |
                                 v
                 +-------------------------------+
                 | UART Monitor                   |
                 | decodes tx serial frames       |
                 +---------------+---------------+
                                 |
                                 v
                 +-------------------------------+
                 | Scoreboard                     |
                 | expected queue vs actual bytes |
                 +---------------+---------------+
                                 |
                                 v
                              PASS / FAIL
```

The scoreboard owns an ordered expected-data queue. The driver puts each byte
into that queue before it transmits the serial frame. The monitor decodes each
`tx` frame and gives the decoded byte to the scoreboard. A test fails on data
mismatch, unexpected output, pending expected data, or an internal FIFO illegal
state. GTKWave remains a separate waveform-debug aid and does not decide pass
or fail.

## 4. Verification Plan

The detailed plan is in [`doc/verification_plan.md`](doc/verification_plan.md).

| Scenario | Purpose | Stimulus | Main checks |
| --- | --- | --- |
| `single` | Basic UART loopback | `A5` | `tx` equals `rx` byte |
| `multi` | Ordered multi-byte loopback | `11 22 33 44` | No loss or reordering |
| `stream` | Sequential streaming | `00` through `13` | 20 ordered matches |
| `fifo` | FIFO boundary model | 8 writes, then 8 reads | `full`, then `empty` |
| `reset` | Reset recovery | reset, then `A5` | Normal loopback resumes |
| `all` | Full regression | All scenarios | Zero errors, empty expected queue |

## 5. Interfaces

| Interface | Direction | Description |
| --- | --- | --- |
| `clk` | input | 100 MHz design clock used by RTL and testbench. |
| `reset` | input | Active-high reset. |
| `rx` | input | UART serial input driven by the verification driver. |
| `tx` | output | UART serial output decoded by the verification monitor. |
| `wr_en` / `rd_en` | FIFO control | Write/read enables used by the FIFO boundary model. |
| `full` / `empty` | FIFO status | FIFO flow-control state checked in the boundary test. |
| `wdata` / `rdata` | FIFO data | FIFO write/read data paths. |

## 6. Simulation

Tools:

```text
Icarus Verilog
GTKWave
```

Run a selected scenario from the project root:

```bash
./run.sh single
./run.sh multi
./run.sh stream
./run.sh fifo
./run.sh reset
./run.sh all
```

Each run writes a readable log under `sim/uart_fifo_sim/log/`, for example
`sim/uart_fifo_sim/log/fifo.log`. Logs record test selection, driver activity,
monitor observations, scoreboard results, and the final PASS/FAIL summary.

To generate a VCD and open its matching GTKWave view for an individual scenario:

```bash
./run.sh multi --wave
```

Waveform export is optional because writing every clock transition makes long
regressions unnecessarily slow. Use `--wave` for focused debug; use `all` for
the normal self-checking regression.

`build.sh` remains available as the original full build entry point.

## 7. Learning Notes

每一步的处理思路都记录在：

```text
doc/steps/01_project_structure.md
doc/steps/02_testbench_split.md
doc/steps/03_test_cases.md
doc/steps/04_scoreboard.md
doc/steps/05_assertion.md
doc/steps/06_how_to_run.md
```

## 8. Interview Summary

可以这样介绍这个项目：

> 我基于一个 UART FIFO RTL 搭建了模块级验证环境。验证部分包含 UART 激励生成、TX 端监测、scoreboard 自动比对，以及 FIFO full/empty 边界检查。测试覆盖了单字节、多字节连续传输、20 字节数据流、FIFO 边界和 reset recovery 场景。这个项目的重点是从“能跑 RTL”升级到“能自动验证 RTL”。
