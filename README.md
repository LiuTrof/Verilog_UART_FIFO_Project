# UART FIFO Verification Project

## 1. Project Overview

这是一个基于 Verilog 的 UART + FIFO 回环验证项目。项目目标不是只把 GitHub RTL 跑起来，而是把它整理成一个面向数字 IC 验证岗位的作品集项目：有清晰目录、有 testbench、有自动检查、有 FIFO 边界测试、有文档记录。

当前验证结果：

```text
CHECKED BYTE : 26
ERROR        : 0
RESULT       : TEST PASS
```

## 2. Architecture

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
tb/tb_top_loop_test.v   # testbench top
tb/uart_task.vh         # UART driver/monitor tasks
tb/test_case.vh         # test cases
tb/scoreboard.vh        # automatic checker
```

验证思想：

```text
Testcase
   |
UART Driver Task
   |
DUT
   |
UART Monitor Task
   |
Scoreboard
   |
PASS / FAIL
```

## 4. Test Cases

| Test Case | Description | Result |
| --- | --- | --- |
| Single byte loopback | Send `0xA5`, receive `0xA5` | PASS |
| Multi-byte loopback | Send `0x11 0x22 0x33 0x44` | PASS |
| Stream loopback | Send 20 bytes: `0x00` to `0x13` | PASS |
| FIFO boundary model | 8 writes trigger full, 8 reads trigger empty | PASS |
| Reset recovery | Reset then send `0xA5` again | PASS |

## 5. Simulation

Tools:

```text
Icarus Verilog
GTKWave
```

Run simulation from project root:

```bash
iverilog -g2012 -I tb -o sim/uart_fifo_sim/uart_fifo_tb.out \
  tb/tb_top_loop_test.v \
  rtl/top_looptest.v \
  rtl/uart_fifo.v \
  rtl/uart.v \
  rtl/fifo.v

vvp sim/uart_fifo_sim/uart_fifo_tb.out
```

Open waveform:

```bash
gtkwave sim/uart_fifo_sim/tb_top_loop_test.vcd
```

## 6. Learning Notes

每一步的处理思路都记录在：

```text
doc/steps/01_project_structure.md
doc/steps/02_testbench_split.md
doc/steps/03_test_cases.md
doc/steps/04_scoreboard.md
doc/steps/05_assertion.md
doc/steps/06_how_to_run.md
```

## 7. Interview Summary

可以这样介绍这个项目：

> 我基于一个 UART FIFO RTL 搭建了模块级验证环境。验证部分包含 UART 激励生成、TX 端监测、scoreboard 自动比对，以及 FIFO full/empty 边界检查。测试覆盖了单字节、多字节连续传输、20 字节数据流、FIFO 边界和 reset recovery 场景。这个项目的重点是从“能跑 RTL”升级到“能自动验证 RTL”。

