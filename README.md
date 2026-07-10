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

回环验证波形图为 `loopback_pass.png`。

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

