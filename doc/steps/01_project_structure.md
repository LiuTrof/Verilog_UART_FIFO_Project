# Step 01 - 工程目录整理

## 目标

把原来偏 Vivado 生成风格的工程，整理成验证作品集更容易阅读的结构。注意：这一步不是重新找项目，而是在当前 UART FIFO 项目里增加作品集目录。

## 当前调整

当前建议优先关注以下核心目录：

```text
rtl/                  # 当前实际编译的 RTL 源码入口，已补中文注释
tb/                   # 当前实际编译的验证环境入口，已补中文注释
doc/                  # 验证计划、波形因果说明、初学者指南和学习笔记
```

同时保留原始目录：

```text
sources_1/new/        # 原 Vivado 风格源码备份；run.sh 不编译该目录
sim/uart_fifo_sim/    # 仿真输出目录
png/                  # 波形截图目录
doc/images_cn/        # 中文架构图与流程图（PNG、SVG）
```

## 为什么这样做

面试官看项目时，最希望快速看到三件事：

1. RTL 在哪里。
2. Testbench 在哪里。
3. 你怎么证明它是对的。

所以作品集工程不要只按工具自动生成目录来摆放，而要主动突出：设计、验证、文档、仿真结果。

## 小白要记住的点

工程目录本身就是表达能力的一部分。一个清晰目录能让别人感觉你不是“只会跑代码”，而是在按工程方法管理项目。

## 推荐阅读顺序

1. [README.md](../../README.md)：先了解项目目标、回归命令和当前验证边界。
2. [RTL 与 TB 初学者指南](../rtl_tb_beginner_guide.md)：按三小时路线建立完整心智模型。
3. [`rtl/top_looptest.v`](../../rtl/top_looptest.v)：理解何时发生 RX FIFO 到 TX FIFO 的搬运。
4. [`rtl/uart_fifo.v`](../../rtl/uart_fifo.v)：理解 UART、RX FIFO、TX FIFO 三者如何连接。
5. [`rtl/uart.v`](../../rtl/uart.v) 与 [`rtl/fifo.v`](../../rtl/fifo.v)：理解 UART 时序和 FIFO 指针。
6. [`tb/tb_top_loop_test.v`](../../tb/tb_top_loop_test.v)：理解验证环境入口和主流程。
7. [`tb/driver/uart_driver.vh`](../../tb/driver/uart_driver.vh)、[`tb/monitor/uart_monitor.vh`](../../tb/monitor/uart_monitor.vh)、[`tb/scoreboard.vh`](../../tb/scoreboard.vh)：理解自检闭环。
