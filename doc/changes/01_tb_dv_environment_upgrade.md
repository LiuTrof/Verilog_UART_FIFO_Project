# 01 - UART FIFO TB 模块级 DV 环境升级

## 本次提交主题

在**不修改任何 RTL 文件**的前提下，将原本以 task 为主的 Verilog
testbench 整理为一个轻量、可自检、适合个人学习和面试展示的模块级验证环境。

本次改动范围只包括：`tb/`、运行脚本、验证文档、日志和 GTKWave 波形视图。

不修改以下设计文件：

```text
rtl/uart.v
rtl/fifo.v
rtl/uart_fifo.v
rtl/top_looptest.v
```

## 一、本次做了什么

### 1. 将发送与接收任务拆成 Driver 和 Monitor

原来的 testbench 将 UART 发送和接收 task 放在同一个文件中。现在将职责拆分为：

- `tb/driver/uart_driver.vh`
  - 负责产生 reset。
  - 负责通过 `rx` 发送 UART 串行帧。
  - 记录当前发送字节到 `driver_data`，便于波形观察。

- `tb/monitor/uart_monitor.vh`
  - 负责从 `tx` 下降沿开始采样。
  - 按 UART 帧格式恢复 8 位数据。
  - 记录当前接收字节到 `monitor_data`，便于波形观察。
  - 将恢复出的实际数据交给 Scoreboard。

### 2. 增加 expected queue 形式的 Scoreboard

`tb/scoreboard.vh` 不再只是直接比较两个 task 变量，而是维护一个按顺序存放
预期数据的 `expected_queue`。

验证流程如下：

```text
Driver 发送数据
    |
    +--> 将预期数据写入 Scoreboard 的 expected_queue
    |
    +--> 通过 rx 发送 UART 串行帧

DUT 回环处理后从 tx 输出
    |
    +--> Monitor 采样并恢复实际字节
    |
    +--> Scoreboard 取出队首预期数据进行比较
    |
    +--> 输出 PASS / FAIL
```

Scoreboard 会检查：

- 实际数据是否与队首预期数据一致。
- 是否收到没有对应预期数据的额外输出。
- 仿真结束时是否还有未收到的预期数据。
- 预期队列是否发生溢出。

### 3. 增加五个可独立运行的测试场景

`tb/test_case.vh` 支持通过 `+TEST=<场景名>` 选择测试；`run.sh` 将该参数封装为
易用命令。

| 命令场景 | 测试内容 | 主要检查点 |
| --- | --- | --- |
| `single` | 单字节回环 `A5` | UART 基本收发链路正确 |
| `multi` | 多字节 `11 22 33 44` | 数据顺序正确、无丢失 |
| `stream` | 连续 20 字节 `00` 到 `13` | 连续数据均被正确回环 |
| `fifo` | FIFO 写 8 次、读 8 次 | `full` 与 `empty` 边界状态正确 |
| `reset` | reset 后再次发送 `A5` | reset 后能够恢复正常传输 |
| `all` | 依次执行全部场景 | 完整回归测试 |

### 4. 增加统一运行脚本和仿真日志

新增 `run.sh`，负责：

- 使用 Icarus Verilog 编译 RTL 和 testbench。
- 运行指定测试场景。
- 将终端输出保存到 `sim/uart_fifo_sim/log/<场景名>.log`。
- 可选生成对应 VCD，并打开匹配的 GTKWave 视图。

常用命令：

```bash
./run.sh single
./run.sh multi
./run.sh stream
./run.sh fifo
./run.sh reset
./run.sh all
```

查看单个场景波形：

```bash
./run.sh multi --wave
```

### 5. 更新五套独立 GTKWave 视图

每个 `.gtkw` 文件现在都对应一个独立场景 VCD，而不是依赖同一个总回归波形：

| GTKWave 文件 | 对应 VCD | 场景 |
| --- | --- | --- |
| `01_single_byte_loopback.gtkw` | `single.vcd` | 单字节 `A5` 回环 |
| `02_multi_byte_loopback.gtkw` | `multi.vcd` | `11 22 33 44` 回环 |
| `03_stream_loopback.gtkw` | `stream.vcd` | 20 字节连续流 |
| `04_fifo_boundary.gtkw` | `fifo.vcd` | FIFO 写满、读空 |
| `05_reset_recovery.gtkw` | `reset.vcd` | reset 后恢复传输 |

波形中新增两个验证层观测信号：

- `driver_data`：Driver 当前准备发送的字节。
- `monitor_data`：Monitor 从 `tx` 恢复出的字节。

因此可以在 GTKWave 中直接确认：

```text
driver_data == monitor_data
```

### 6. 增加验证计划与项目说明

- 新增 `doc/verification_plan.md`，说明验证范围、测试矩阵和通过标准。
- 更新 `README.md`，加入验证架构图、场景说明、接口说明、运行方式。
- 新增 `.gitignore`，避免 VCD、仿真可执行文件和日志被提交到 Git。

## 二、为什么要这样做

本项目是从普通 Verilog testbench 走向数字 IC 验证岗位实践项目的第一步。目标不是
堆叠复杂框架，而是建立一个自己能理解、能运行、能演示、能在面试中解释清楚的验证闭环。

这样改造后，可以清楚说明：

1. **Driver 做什么**：构造 UART 输入激励并驱动 `rx`。
2. **Monitor 做什么**：从 DUT 的 `tx` 输出中采样并恢复字节。
3. **Scoreboard 做什么**：保存预期数据，并自动比较实际数据。
4. **Testcase 做什么**：定义不同验证场景与输入数据。
5. **脚本和日志做什么**：让测试可重复运行，结果可追踪。
6. **GTKWave 做什么**：在 PASS/FAIL 之外，辅助定位时序和数据路径问题。

最终形成的验证结构为：

```text
Testcase
   |
   v
Driver -> UART FIFO DUT -> Monitor -> Scoreboard -> PASS / FAIL
   |                                      ^
   +---- expected queue ------------------+

GTKWave：观察 rx、tx、Driver、Monitor 与 DUT 内部关键状态
```

## 三、怎么验证本次改动

### 1. 单独运行五个测试场景

```bash
./run.sh single
./run.sh multi
./run.sh stream
./run.sh fifo
./run.sh reset
```

五个场景均返回：

```text
ERROR        : 0
RESULT       : TEST PASS
```

其中：

```text
single : CHECKED BYTE 1
multi  : CHECKED BYTE 4
stream : CHECKED BYTE 20
fifo   : FIFO full/empty boundary PASS
reset  : CHECKED BYTE 1
```

### 2. 运行完整回归

```bash
./run.sh all
```

完整回归结果：

```text
CHECKED BYTE : 26
PENDING BYTE : 0
ERROR        : 0
RESULT       : TEST PASS
```

说明 26 个 UART 数据字节均由 Monitor 正确恢复，并与 Scoreboard 的 expected queue
逐个匹配，仿真结束时没有遗留预期数据。

### 3. 查看波形

以多字节场景为例：

```bash
./run.sh multi --wave
```

在波形中依次确认：

```text
driver_data:  11 -> 22 -> 33 -> 44
rx:           对应的 UART 串行帧
w_rx_done:    UART 接收完成脉冲
rx_data:      接收恢复的并行数据
tx:           回环后的 UART 串行帧
w_tx_done:    UART 发送完成脉冲
monitor_data: 11 -> 22 -> 33 -> 44
```

`driver_data` 与 `monitor_data` 一致，同时日志中 Scoreboard 输出 PASS，即可确认
验证激励、DUT 回环路径、Monitor 解码和自动比对均正常工作。

## 四、本次涉及文件

| 文件 | 本次作用 |
| --- | --- |
| `tb/tb_top_loop_test.v` | Testbench 顶层集成、场景选择、可选波形导出 |
| `tb/driver/uart_driver.vh` | UART Driver 与 reset task |
| `tb/monitor/uart_monitor.vh` | UART Monitor 与 TX 字节恢复 |
| `tb/scoreboard.vh` | expected queue 与自动比较 |
| `tb/test_case.vh` | 五类场景与 `+TEST=` 选择 |
| `run.sh` | 编译、运行、日志、可选波形入口 |
| `doc/verification_plan.md` | 验证范围、测试矩阵和通过标准 |
| `gtkwave_views/*.gtkw` | 每个场景各自的波形视图 |
| `gtkwave_views/open_view.sh` | 场景波形启动脚本 |
| `gtkwave_views/README.md` | GTKWave 使用说明 |
| `README.md` | 项目整体说明与验证架构 |
| `.gitignore` | 忽略仿真生成物 |

## 五、面试时可以怎么介绍

> 我没有修改 UART FIFO 的 RTL，而是在它外面搭建了一个轻量的 Verilog 自检验证环境。
> Driver 负责生成 UART 串行输入，Monitor 从 TX 端采样并恢复输出字节，Scoreboard 使用
> expected queue 自动比对预期数据和实际数据。测试覆盖单字节、多字节、20 字节连续流、
> FIFO full/empty 边界以及 reset recovery；同时通过脚本、日志和 GTKWave 波形让每个
> 场景都可以重复运行和定位问题。
