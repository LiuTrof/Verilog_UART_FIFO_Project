# Verilog UART + FIFO Loopback

## 项目简介

这是一个基于 Verilog 的 UART + FIFO 组合小项目，用于练习数字电路设计、RTL 阅读、testbench 编写和基础仿真验证。

当前项目已经完成：

- UART 收发模块集成
- FIFO 读写缓存集成
- 顶层回环连接
- Icarus Verilog 仿真
- GTKWave 波形查看
- 单字节 UART 回环仿真通过

## 模块结构

### 1. `sources_1/new/uart.v`

包含 UART 的核心模块：

- `baudrate_generator`
- `transmitter`
- `receiver`

功能：完成串口发送、接收和波特率节拍产生。

### 2. `sources_1/new/fifo.v`

包含 FIFO 的核心模块：

- `register_file`
- `fifo_control_unit`

功能：完成数据缓存、读写指针控制、空满状态控制。

### 3. `sources_1/new/uart_fifo.v`

功能：将 UART 与 RX FIFO / TX FIFO 组合，形成串口收发缓存链路。

### 4. `sources_1/new/top_looptest.v`

功能：搭建顶层 loopback 结构，将接收到的数据重新发送出去。

### 5. `sim/uart_fifo_sim/tb_top_loop_test.v`

功能：

- 产生时钟和复位
- 构造 UART 串行输入激励
- 从 `tx` 端采样输出数据
- 自动比对输入输出结果
- 生成 `vcd` 波形文件

## 当前验证结果

当前已跑通单字节回环场景。

Loopback 验证时，在 GTKWave 中打开 `tb_top_loop_test`，将 `sent_byte` 和 `echoed_byte` 加入波形窗口，并切换为 `Hex` 显示，可直接看到：

- 发送数据：`A5`
- 接收数据：`A5`
- PASS

示例结果：

```text
RX0=a5 at 2187605000
PASS: loopback echoed a5
```

说明：发送 1 个字节 `0xA5` 到 `rx`，经过 UART + FIFO 链路后，`tx` 成功回传相同数据。

建议将这张最有说服力的回环验证图保存为 `loopback_pass.png`。

## 运行方式

在项目根目录执行：

```sh
iverilog -g2012 -o sim/uart_fifo_sim/uart_fifo_tb.out \
  sim/uart_fifo_sim/tb_top_loop_test.v \
  sources_1/new/top_looptest.v \
  sources_1/new/uart_fifo.v \
  sources_1/new/uart.v \
  sources_1/new/fifo.v

vvp sim/uart_fifo_sim/uart_fifo_tb.out
```

查看波形：

```sh
gtkwave sim/uart_fifo_sim/tb_top_loop_test.vcd
```

## 波形观察重点

建议在 GTKWave 中重点观察这些信号：

- `clk`
- `reset`
- `rx`
- `tx`
- `dut.U_UART_FIFO.w_rx_done`
- `dut.U_UART_FIFO.w_tx_done`
- `dut.U_UART_FIFO.rx_data`
- `dut.U_UART_FIFO.rx_empty`

面试时可以这样描述波形：

1. `rx` 出现 UART 起始位、8 位数据位、停止位
2. 接收完成后 `w_rx_done` 拉高，数据进入 RX FIFO
3. 顶层回环逻辑读取 RX FIFO 数据
4. UART 发送端重新发出该字节，`tx` 与输入数据一致

## 我做过的调试点

这个项目里已经做过一次比较典型的 RTL 问题定位：

- 修复 FIFO reset 初始化时的越界写入问题
- 修正 FIFO 复位后的 `empty` 初始状态
- 搭建 testbench 并通过仿真验证单字节回环功能

这部分很适合在面试中讲“我是怎么发现问题、怎么用波形定位问题的”。

## 适合简历的写法

### 简历版本 1：偏数字设计

- 基于 Verilog 实现 UART 收发器与 FIFO 缓冲模块，完成串口回环功能设计与仿真验证
- 编写 RTL 顶层连接与回环逻辑，完成 UART + FIFO 数据通路联调
- 使用 Icarus Verilog 与 GTKWave 进行功能仿真和波形分析

### 简历版本 2：偏验证

- 搭建 UART/FIFO 模块级仿真环境，编写 testbench 对串口回环场景进行功能验证
- 通过自动比对和波形分析定位 FIFO 初始化与接口联动问题
- 完成单字节回环场景验证闭环，积累基础 RTL 验证经验

## 面试表达模板

可以这样介绍这个项目：

> 我做了一个 Verilog 的 UART + FIFO 小项目，重点不是堆很多模块，而是完整走了一遍 RTL 阅读、testbench 编写、仿真运行、波形分析和问题定位的流程。比如我在 FIFO 模块里发现了 reset 初始化越界的问题，也搭了 UART 回环仿真，把单字节场景跑通了。这个过程让我对串行协议、状态机、FIFO 空满判断和基础验证流程有了比较具体的理解。

## 后续可扩展方向

如果继续增强项目，可以往这几个方向扩展：

- 连续多字节回环验证
- FIFO 满/空边界场景验证
- 异常输入场景验证
- SystemVerilog testbench 升级
- 加入自检 scoreboard 思路

对校招 / 转岗初级数字验证岗位来说，先把当前这个版本讲清楚，已经很够用了。

面试八股
UART 是什么？
可以答：
UART 是异步串行通信协议，不需要独立时钟线，通常包含 1 位起始位、8 位数据位、可选奇偶校验位和 1 位停止位。发送和接收双方约定相同波特率，接收端通过固定采样时刻恢复数据。

为什么 UART 接收通常要过采样？
可以答：
因为 UART 是异步通信，没有共享时钟，接收端需要靠检测起始位后，在位中心附近采样来提高容错。常见做法是 16 倍过采样，在起始位中点确认后，再按位周期采样每一位数据。

FIFO 的作用是什么？
可以答：
FIFO 用来做缓存和速率匹配。比如上游数据到得快、下游处理得慢时，可以先暂存在 FIFO 里，避免直接丢数据。它本质上是先进先出的缓冲队列。

FIFO 怎么判断空和满？
可以答：
最基础的方法是维护读指针和写指针。复位时两者相等且为空。写入时写指针前进，读取时读指针前进。空满判断通常结合指针关系和状态位完成，避免“指针相等时到底是空还是满”的歧义。

testbench 一般做什么？
可以答：
主要是产生时钟和复位、构造输入激励、监测输出结果、自动判断 PASS/FAIL、导出波形辅助调试。我的这个项目里 testbench 负责生成 UART 输入帧，并从 tx 端回读数据做比较。

看波形时重点看什么？
可以答：
先看输入是否按预期激励，再看关键状态信号有没有响应，比如 rx_done、tx_done、FIFO 的空满状态、读写指针或者读写使能，最后看输出是不是和输入一致。

结合你这个项目的回答模板
你这个项目做了什么？
答法：
我做的是一个 Verilog 的 UART + FIFO 回环小项目。整体链路是串口输入先进入接收端，再写入 RX FIFO，之后通过顶层回环逻辑送到 TX FIFO，最后由 UART 发送端重新发出。我补了 testbench 来做时钟、复位、UART 激励和输出比对，并用 GTKWave 看波形。

你在这个项目里具体做了什么？
答法：
我主要做了三件事。第一，读懂已有的 UART 和 FIFO RTL 结构。第二，补了 testbench，让这个项目真正能跑仿真。第三，通过仿真输出和波形去定位设计里的问题，比如 FIFO reset 初始化越界这种比较典型的 RTL 问题。

你遇到过什么问题？
答法：
我一开始跑项目时只是能编译，不能形成有效验证。后来补上 testbench 后，先跑通了单字节回环。另外我发现 FIFO 的 reset 初始化里有数组越界访问，这种问题虽然不一定马上炸，但会影响代码质量和后续定位。还有连续多字节场景下，当前组合逻辑里仍然有控制时序问题，这也是我后续准备继续完善的点。

你怎么定位问题？
答法：
我的习惯是先复现问题，再分层看。先看 testbench 的激励是不是对的，再看 UART 输入输出，再看 FIFO 的空满和读写行为，最后定位到具体模块内部。这样比直接盯代码更高效，因为先把现象钉住，再回到 RTL 找原因。

这个项目能体现你适合验证岗的地方是什么？
答法：
我觉得不是项目规模有多大，而是我完整走了一遍验证闭环。包括搭建 testbench、构造输入、自动比对、生成波形、定位问题、修改后重新验证。这个过程比较接近验证工程师真实的日常工作方式。

给你一个适合面试开场的 30 秒版本
你可以直接这样说：
“我最近在补数字电路方向的项目，做了一个 Verilog 的 UART + FIFO 回环仿真。这个项目里我自己搭了 testbench，用 Icarus Verilog 跑仿真、用 GTKWave 看波形，已经把单字节回环场景跑通了。过程中我还定位到了 FIFO reset 初始化越界这类 RTL 问题。这个项目虽然不大，但让我完整练了一遍 RTL 阅读、验证和调试闭环。”
这段对你现在的背景很合适，不装，也不虚。
下一步最顺手的是两件事：我可以继续给你补一份“1 分钟自我介绍，专门往 IC 验证/数字设计岗靠”，或者直接给你整理“10 个高频面试题 + 你的定制答案”。
