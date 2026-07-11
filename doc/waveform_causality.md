# UART FIFO RTL 效果与测试场景波形因果关系

## 1. 当前 RTL 能实现什么

当前 `rtl/` 目录中的设计实现的是一个 UART + 双 FIFO 的串口回环路径：

```text
rx 串行输入
  -> UART 接收器
  -> RX FIFO
  -> 顶层搬运控制
  -> TX FIFO
  -> UART 发送器
  -> tx 串行输出
```

关键模块职责：

| RTL 文件 | 当前实现的作用 |
| --- | --- |
| `rtl/uart.v` | 9600 波特率、16 倍采样的 UART 发送与接收；帧格式为 1 个起始位、8 个数据位、1 个停止位，无 parity。 |
| `rtl/fifo.v` | 深度为 8、数据宽度为 8 bit 的 FIFO；提供读写、`full`、`empty` 状态。 |
| `rtl/uart_fifo.v` | UART 接收完成时写入 RX FIFO；TX FIFO 非空时启动 UART 发送；UART 发送完成时读取 TX FIFO。 |
| `rtl/top_looptest.v` | 当 RX FIFO 非空且 TX FIFO 未满时，将 RX FIFO 数据搬运到 TX FIFO，避免在 TX FIFO 满时继续搬运。 |

在当前 testbench 覆盖范围内，设计能够完成 UART 数据回环：输入到 `rx` 的数据经过
接收、FIFO 缓冲和发送后，从 `tx` 输出相同字节。完整回归已经得到：

```text
CHECKED BYTE : 26
PENDING BYTE : 0
ERROR        : 0
RESULT       : TEST PASS
```

这表示当前 RTL 在已覆盖的单字节、多字节、20 字节顺序流、独立 FIFO 边界和 reset 后
恢复场景下能够正确工作。

## 2. 需要如实说明的验证边界

当前结论是“已验证功能正确”，不是“所有极限条件均已证明正确”。特别是：

- `stream` 场景在每个字节之间保留了安全间隔，验证的是顺序回环，不是极限吞吐压力测试。
- `fifo` 场景验证的是 testbench 中独立实例化的 FIFO model，证明 FIFO 模块的基础满/空行为；
  它不是对 DUT 内 RX FIFO / TX FIFO 灌满后的集成压力测试。
- `reset` 场景验证“reset 完成后可以重新传输”，没有覆盖“UART 正在收发过程中突然 reset”。
- UART 当前没有 parity、帧错误或波特率偏差等异常场景验证。

对于个人实践项目，这些边界应在面试中如实说明：已完成基础功能闭环与自动检查，后续可再
扩展压力和异常场景。

## 3. 波形阅读原则

每个 `.gtkw` 只放该场景的最小检查信号集，避免与场景无关的变量干扰阅读。

UART 回环类场景的共同含义：

| 信号 | 含义 |
| --- | --- |
| `rx` | Driver 输入给 DUT 的 UART 串行帧。 |
| `tx` | DUT 回环后输出的 UART 串行帧。 |
| `driver_data` | Driver 当前计划发送的并行字节。 |
| `monitor_data` | Monitor 从 `tx` 采样并恢复出的并行字节。 |
| `w_rx_done` | DUT UART 接收器完成一帧后的脉冲。 |
| `w_tx_done` | DUT UART 发送器完成一帧后的脉冲。 |
| `reset` | 高电平时 DUT 处于复位状态。 |

UART 数据按 **LSB first** 发送。以 `A5 = 8'b1010_0101` 为例，串行数据位顺序为：

```text
data[0] -> data[1] -> ... -> data[7]
1, 0, 1, 0, 0, 1, 0, 1
```

当前精简视图不直接展示 `w_rx_data` 和 `w_tx_fifo_rdata`。这两个是 `uart_fifo` 内部的
数据通路信号；为了使每个场景只保留必要信号，当前使用 `driver_data`、`monitor_data` 与
Scoreboard PASS 来证明端到端数据一致。若需要调试内部搬运，可在临时调试视图中额外加入：

```text
tb_top_loop_test.dut.U_UART_FIFO.w_rx_data[7:0]
tb_top_loop_test.dut.U_UART_FIFO.w_tx_fifo_rdata[7:0]
```

## 4. 场景一：单字节 UART 回环 A5

对应视图：`gtkwave_views/01_single_byte_loopback.gtkw`

运行命令：

```bash
./run.sh single --wave
```

### 需要验证的波形因果关系

1. `reset` 从 `1` 变为 `0` 后，系统离开复位；当前精简视图没有显示它，但该动作发生在
   Driver 的 `uart_driver_apply_reset()` 中。
2. `driver_data` 变为 `A5`，表示 Driver 准备发送 `8'hA5`。
3. `rx` 出现一个 UART 帧：空闲为 `1`，先拉低为起始位，再按 LSB first 传输 8 位数据，
   最后回到 `1` 作为停止位。
4. UART 接收器完成该帧后，`w_rx_done` 产生一个脉冲；此时内部 `w_rx_data` 为 `A5`，并被
   写入 RX FIFO。
5. RX FIFO 变为非空后，顶层控制将数据搬运到 TX FIFO；内部 `w_tx_fifo_rdata` 随后为 `A5`，
   UART 发送器开始发送。
6. `tx` 产生完整 UART 帧，数据位顺序同样对应 `A5`。
7. `tx` 停止位结束后，`w_tx_done` 产生一个脉冲，表示该字节发送完成。
8. Monitor 从 `tx` 恢复出 `A5`，因此 `monitor_data = A5`；Scoreboard 将它与队首预期数据
   `A5` 比较并输出 PASS。

### 一句话判断

```text
driver_data = A5 -> rx 帧 -> w_rx_done -> FIFO 搬运 -> tx 帧 -> w_tx_done
-> monitor_data = A5 -> Scoreboard PASS
```

## 5. 场景二：多字节 UART 回环 11 22 33 44

对应视图：`gtkwave_views/02_multi_byte_loopback.gtkw`

运行命令：

```bash
./run.sh multi --wave
```

### 需要验证的波形因果关系

1. 场景开始前会执行一次 reset，确保从确定状态开始。
2. `driver_data` 依次变为 `11 -> 22 -> 33 -> 44`；每次变化后，`rx` 都产生对应的 UART 帧。
3. 每一个完整 `rx` 帧后均应出现一次 `w_rx_done`，表示接收器已完成对应字节。
4. 每一个字节经过 FIFO 回环后，`tx` 依次输出对应 UART 帧；每帧结束后出现一次 `w_tx_done`。
5. `monitor_data` 必须保持相同顺序：`11 -> 22 -> 33 -> 44`。
6. Scoreboard 必须连续输出四次 PASS，且顺序不能改变。

### 一句话判断

```text
Driver 顺序发送 11/22/33/44
-> DUT 按相同顺序从 tx 输出
-> Monitor 顺序恢复 11/22/33/44
-> Scoreboard 连续 4 次 PASS
```

这个场景重点不是 FIFO 是否满，而是验证多个字节经过 UART + FIFO 链路后没有丢失、重复或
乱序。

## 6. 场景三：20 字节连续流 00 到 13

对应视图：`gtkwave_views/03_stream_loopback.gtkw`

运行命令：

```bash
./run.sh stream --wave
```

### 需要验证的波形因果关系

1. `driver_data` 从 `00` 依次递增到 `13`，共 20 个字节。
2. 每次 Driver 发送一个字节时，`rx` 出现对应 UART 帧。
3. DUT 逐个完成回环后，`tx` 依次输出 20 个 UART 帧。
4. `monitor_data` 必须同样从 `00` 依次递增到 `13`，顺序不能跳变、重复或缺失。
5. Scoreboard 应得到 `CHECKED BYTE : 20`、`ERROR : 0`、`PENDING BYTE : 0`。

### 一句话判断

```text
00 -> 01 -> ... -> 13 进入 Driver
-> 00 -> 01 -> ... -> 13 从 Monitor 输出
-> 20 次顺序比较全部 PASS
```

当前 testcase 在每个字节后加入了安全等待，因此它证明的是“连续顺序数据可以稳定回环”，
而不是故意将 FIFO 推到满状态的极限压力测试。

## 7. 场景四：FIFO 写满 full、读空 empty 边界

对应视图：`gtkwave_views/04_fifo_boundary.gtkw`

运行命令：

```bash
./run.sh fifo --wave
```

### 需要验证的波形因果关系

1. `fifo_boundary_model_reset` 从 `1` 变为 `0` 后，独立 FIFO model 离开复位，
   `empty` 应为 `1`、`full` 应为 `0`。
2. `fifo_boundary_model_wr_en` 连续有效 8 个时钟周期，`fifo_boundary_model_wdata` 依次为
   `00` 到 `07`。
3. 第 8 次写入完成后，`fifo_boundary_model_full` 变为 `1`，表示 8 深度 FIFO 已写满。
4. 随后 `fifo_boundary_model_wr_en` 变为 `0`，`fifo_boundary_model_rd_en` 连续有效 8 个
   时钟周期。
5. 第 8 次读取完成后，`fifo_boundary_model_empty` 变为 `1`，表示 FIFO 已读空。
6. 整个过程中 `full` 与 `empty` 不应同时为 `1`；testbench 也对此做了非法状态检查。

### 一句话判断

```text
8 次写入 -> full = 1 -> 8 次读取 -> empty = 1
```

注意：这个场景针对 testbench 中独立实例化的 `fifo_boundary_model`，用于验证 FIFO 基础
控制逻辑，不是通过 UART 输入灌满 DUT 内部 FIFO 的压力场景。

## 8. 场景五：reset 后恢复并再次传输 A5

对应视图：`gtkwave_views/05_reset_recovery.gtkw`

运行命令：

```bash
./run.sh reset --wave
```

### 需要验证的波形因果关系

1. testbench 初始复位完成后，`test_reset_recovery` 再次将 `reset` 拉高；波形中能看到第二次
   reset 脉冲。
2. `reset` 重新变为 `0` 后，UART 状态机和两个 FIFO 都回到可工作状态：UART TX 空闲为高，
   FIFO 处于 empty 状态。
3. `driver_data` 变为 `A5`，随后 `rx` 输出 `A5` 的 UART 帧。
4. `w_rx_done` 表示接收完成，数据经 RX FIFO、顶层搬运和 TX FIFO 进入发送器。
5. `tx` 输出 `A5` UART 帧，停止位结束后 `w_tx_done` 出现。
6. `monitor_data = A5`，Scoreboard 输出 PASS。

### 一句话判断

```text
第二次 reset -> reset 释放 -> 发送 A5 -> 接收 A5 -> Scoreboard PASS
```

该场景验证的是 reset 结束后功能恢复；它没有验证在 UART 帧传输中途拉 reset 的行为。

## 9. 面试时的简要说明

> RTL 实现了 UART 接收、RX FIFO 缓冲、顶层回环搬运、TX FIFO 缓冲和 UART 发送。验证时我
> 不只看最终 tx，而是按因果链观察：Driver 发送什么、RX 是否完成、数据是否进入 FIFO、TX
> 是否完成、Monitor 恢复什么，以及 Scoreboard 是否通过。五个场景分别覆盖基础回环、顺序
> 多字节、20 字节数据流、FIFO 满空边界和 reset 后恢复。当前功能回归通过，但我也明确它
> 还没有覆盖极限 FIFO 压力和传输中 reset 等扩展场景。
