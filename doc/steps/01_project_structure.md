# Step 01 - 工程目录整理

## 目标

把原来偏 Vivado 生成风格的工程，整理成验证作品集更容易阅读的结构。注意：这一步不是重新找项目，而是在当前 UART FIFO 项目里增加作品集目录。

## 当前调整

新增了三个核心目录：

```text
rtl/                  # 作品集视角下的 RTL 源码入口
tb/                   # 验证环境入口
doc/steps/            # 每一步学习笔记和方法论
```

同时保留原始目录：

```text
sources_1/new/        # 原 Vivado 风格源码目录
sim/uart_fifo_sim/    # 仿真输出目录
png/                  # 波形截图目录
```

## 为什么这样做

面试官看项目时，最希望快速看到三件事：

1. RTL 在哪里。
2. Testbench 在哪里。
3. 你怎么证明它是对的。

所以作品集工程不要只按工具自动生成目录来摆放，而要主动突出：设计、验证、文档、仿真结果。

## 小白要记住的点

工程目录本身就是表达能力的一部分。一个清晰目录能让别人感觉你不是“只会跑代码”，而是在按工程方法管理项目。

八、现在推荐你怎么看这个项目
你可以按这个顺序理解：
先看 [README.md](/Users/athena/Desktop/myself/testDataIC/Verilog_UART_FIFO_0524/README.md)
明白这个项目现在整体长什么样。

再看 [doc/steps/01_project_structure.md](/Users/athena/Desktop/myself/testDataIC/Verilog_UART_FIFO_0524/doc/steps/01_project_structure.md)
明白为什么要整理目录。

再看 [tb/tb_top_loop_test.v](/Users/athena/Desktop/myself/testDataIC/Verilog_UART_FIFO_0524/tb/tb_top_loop_test.v)
这是验证入口。

再看 [tb/test_case.vh](/Users/athena/Desktop/myself/testDataIC/Verilog_UART_FIFO_0524/tb/test_case.vh)
这里能看到具体测了什么。

再看 [tb/scoreboard.vh](/Users/athena/Desktop/myself/testDataIC/Verilog_UART_FIFO_0524/tb/scoreboard.vh)
这里是自动判断 PASS/FAIL 的核心。

最后看 [rtl/top_looptest.v](/Users/athena/Desktop/myself/testDataIC/Verilog_UART_FIFO_0524/rtl/top_looptest.v)
理解 DUT 顶层怎么把 RX FIFO 搬到 TX FIFO。
