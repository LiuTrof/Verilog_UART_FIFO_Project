# UART FIFO 验证闭环与面试准备

本文对应当前项目真正参与仿真的 Testbench：`tb/tb_top_loop_test.v`、`tb/driver/uart_driver.vh`、`tb/monitor/uart_monitor.vh`、`tb/scoreboard.vh` 和 `tb/test_case.vh`。阅读时配合下图：

![自检 Testbench 流程](images_cn/verification_self_checking_flow.png)

目标不是只会说“仿真通过了”，而是能在面试中清楚说明：激励如何产生、预期结果从哪里来、实际结果如何独立采集、比较机制怎样判断 PASS/FAIL，以及当前验证覆盖了什么、还缺什么。

## 1. 一分钟项目讲法

> 我为 UART 加双 FIFO 回环模块搭建了一个 Verilog 自检 Testbench。Driver 在 `rx` 端按 UART 8N1 协议发送字节，并在发送前将该字节写入 Scoreboard 的预期队列；DUT 将数据经过 UART 接收器、RX FIFO、顶层搬运逻辑、TX FIFO 和 UART 发送器后，从 `tx` 端输出。Monitor 不读取 Driver 的变量，而是从 `tx` 的起始位开始，按数据位中心重新采样并恢复实际字节。Scoreboard 按 FIFO 顺序取出预期字节，与实际字节使用 `!==` 比较，因此能报告数据错误、乱序、意外输出和仿真结束时的缺失输出。用例覆盖单字节、多字节顺序、20 字节递增序列、独立 FIFO 的满空边界和复位恢复；完整回归要求错误数为 0 且预期队列为空。

## 2. 验证闭环是什么

一个自检验证闭环至少有四件事：产生激励、建立参考预期、观察 DUT 输出、自动比较并汇总。当前工程的对应关系如下。

| 验证环节 | 当前实现 | 关键接口/行为 | 它避免的问题 |
| --- | --- | --- | --- |
| 场景选择 | `run_selected_test()` | `+TEST=single/multi/stream/fifo/reset/all` | 手工改代码才能切换场景 |
| 激励 | `uart_driver_send_byte()` | 将 `data[0]` 至 `data[7]` 驱动到 `rx` | 只测并行接口，没有测串行协议 |
| 参考模型 | Scoreboard 预期环形队列 | Driver 调用 `scoreboard_expect(data)` | 用 DUT 输出反过来当作“预期” |
| 观察 | `uart_monitor_receive_byte()` | 从 `tx` 独立解码 8N1 帧 | Monitor 偷看 Driver 数据，造成假通过 |
| 判定 | `scoreboard_check_actual()` | 实际数据与队首预期逐项比较 | 人眼逐条看波形或日志 |
| 收尾 | `scoreboard_report()` | 检查 `expected_count` 与 `total_errors` | 只检查收到的数据，遗漏丢包 |

数据和控制关系可以概括为：

```text
Testcase
  -> Driver: scoreboard_expect(data) + UART 8N1 驱动 rx
  -> DUT: RX -> RX FIFO -> loopback -> TX FIFO -> TX
  -> Monitor: 从 tx 采样并恢复 actual
  -> Scoreboard: actual 与 expected_queue 队首比较
  -> Report: total_errors == 0 且 expected_count == 0
```

这里的核心原则是观察路径独立。Driver 知道“送进了什么”，Monitor 只知道“从 `tx` 看到了什么”。两者只在 Scoreboard 中汇合，才能证明 DUT 的端到端行为正确。

## 3. Driver：激励与预期的起点

`uart_driver_send_byte(data)` 在 [uart_driver.vh](/Users/athena/Desktop/File/testDataIC/Verilog_UART_FIFO_0524/tb/driver/uart_driver.vh:13) 做两件事。

1. 先执行 `scoreboard_expect(data)`，把预期字节放入队列。
2. 再按 8N1 格式驱动 `rx`：空闲高电平、一个比特时间的起始位低电平、`data[0]` 到 `data[7]`、一个比特时间的停止位高电平。

本工程的 `BIT_PERIOD_NS=104_160`，对应约 9600 baud；数据位低位先发送，这是 UART 的 LSB-first 规则。Driver 发送后还等待 `FRAME_GAP_NS`，为当前设计的回环处理保留保护时间。

**为什么先入队再发数据？**

仿真中多个过程可以并行执行。若先驱动 `rx`，再记录预期值，在极端的零延迟或快速 DUT 中可能出现 Monitor 已经观察到输出、但 Scoreboard 队列还没有预期数据的竞争。先建立预期，再施加激励，顺序更稳健。

**Driver 的面试表述：**

> Driver 负责把抽象事务 `byte` 转换为引脚级 UART 8N1 波形，同时将该事务送给参考模型。它不检查输出，避免把激励和判定耦合在一起。

## 4. Monitor：独立观察实际输出

`uart_monitor_receive_byte(data)` 在 [uart_monitor.vh](/Users/athena/Desktop/File/testDataIC/Verilog_UART_FIFO_0524/tb/monitor/uart_monitor.vh:13) 的采样流程如下：

1. `@(negedge tx)` 等待 UART 起始位开始。
2. 延迟 `1.5 * BIT_PERIOD_NS`，到达 D0 的中心。
3. 每隔一个 `BIT_PERIOD_NS` 采样一次，共采样 D0 到 D7。
4. 等待停止位结束，将恢复出的 `actual` 交给 Scoreboard。

选择数据位中心采样而非边沿采样，是 UART 接收中常见的抗抖动思路：位边界附近最可能有传播延迟、抖动或相位误差，中心点的采样裕量最大。

当前 Monitor 使用 Testbench 已知的固定比特周期，因此适合这个确定波特率的 RTL 验证。若要扩展到更通用的验证环境，可以把波特率、数据位、停止位、校验位配置化，并加入起始位合法性和停止位合法性检查。

**Monitor 的面试表述：**

> Monitor 是被动组件，不驱动 DUT。它从接口信号中重建事务，不能直接读取 Driver 的输入变量或 DUT 内部数据，否则会绕过真实接口，降低验证可信度。

## 5. Scoreboard：为什么能发现错序

Scoreboard 在 [scoreboard.vh](/Users/athena/Desktop/File/testDataIC/Verilog_UART_FIFO_0524/tb/scoreboard.vh:13) 使用深度为 256 的环形数组：

```text
Driver:  expected_queue[expected_write_index] <- expected
Monitor: actual 与 expected_queue[expected_read_index] 比较
```

它维护以下状态：

| 状态 | 含义 |
| --- | --- |
| `expected_count` | 尚未与输出匹配的预期事务数 |
| `expected_write_index` | 下一个预期字节写入的位置 |
| `expected_read_index` | 下一个应当被观察到的预期字节位置 |
| `total_checked` | 已观察并尝试比较的实际字节数 |
| `total_errors` | 数据比较、队列状态和 FIFO 安全检查累计的错误数 |

以 `multi` 的 `11 22 33 44` 为例，理想过程为：

| 时间顺序 | 预期队列 | Monitor 实际输出 | 比较结果 |
| --- | --- | --- | --- |
| Driver 发送 `11` 前 | `[11]` | - | 等待输出 |
| 收到第 1 个字节 | `[11]` | `11` | PASS，队列变空 |
| Driver 发送 `22` 前 | `[22]` | - | 等待输出 |
| 收到第 2 个字节 | `[22]` | `22` | PASS，队列变空 |

若 RTL 把前两个字节颠倒，队列顺序仍是 `[11, 22]`，但 Monitor 首先看到 `22`：

```text
队首 expected = 8'h11
实际 actual  = 8'h22
actual !== expected  -> [SCB][FAIL]
```

下一次再看到 `11` 时，队首已经前进到 `22`，因此通常会再次失败。这正是顺序型 Scoreboard 的意义：它不只是检查“这些数据有没有出现”，也检查“是否以预期先后关系出现”。

Scoreboard 当前可以自动发现四类问题：

| 问题类型 | 触发条件 | 现象 |
| --- | --- | --- |
| 数据错误或错序 | `actual !== expected` | `[SCB][FAIL] 预期=... 实际=...` |
| 意外输出 | `expected_count == 0` 时收到实际数据 | `[SCB][FAIL] 意外实际数据` |
| 输出缺失 | 仿真收尾时 `expected_count != 0` | 每个残留预期计入错误 |
| 预期队列溢出 | `expected_count == 256` | 不覆盖旧预期，直接报错 |

使用 case inequality `!==` 而不是逻辑不等 `!=` 很关键。`!==` 会把 `X` 和 `Z` 当成不匹配，避免未知态被普通条件判断悄悄放过。

**一个需要如实说明的实现细节：**当前 `multi` 和 `stream` 在每一帧的 `join` 后才发送下一帧，故 Scoreboard 的队列在这两个场景通常只积压一个字节。它仍然逐帧验证数据及顺序，但不是制造“多笔事务同时悬挂”的高并发乱序压力。真正测试队列积压和吞吐时，应使用连续发送、独立持续运行的 Monitor，并加超时和更强的流控/背压检查。

## 6. 当前 `+TEST` 场景：测到什么，没测到什么

| 场景 | 命令 | 已验证 | 尚未验证 |
| --- | --- | --- | --- |
| 单字节 | `./run.sh single` | `A5` 端到端串行收发、基本回环 | 多字节连续性、边界值、吞吐 |
| 多字节 | `./run.sh multi` | `11 22 33 44` 的端到端数据和顺序 | 无帧间保护的连续突发、FIFO 灌满 |
| 递增序列 | `./run.sh stream` | `00` 到 `13` 共 20 个字节的重复传输与顺序 | 随机数据、长时间稳定性、极限压力 |
| FIFO 边界 | `./run.sh fifo` | 独立 `fifo` 写 8 次后 `full`，读 8 次后 `empty` | DUT 内 RX/TX FIFO 在 UART 流量下的满/空、溢出/下溢恢复、并发读写组合 |
| 复位恢复 | `./run.sh reset` | 空闲状态复位后重新发送 `A5` 能正常回环 | 传输中复位、FIFO 非空/非满时复位、复位释放时序扫掠 |
| 完整回归 | `./run.sh all` | 上述场景串行执行，26 个 UART 字节检查以及独立 FIFO 边界 | 覆盖率闭环、错误注入、随机约束、协议异常输入 |

`all` 的 26 个 UART 字节来自 `single` 的 1 个、`multi` 的 4 个、`stream` 的 20 个和 `reset` 的 1 个；`fifo` 是单独对满空标志的直接检查，不贡献 UART 端到端字节数。

除 Scoreboard 外，[tb_top_loop_test.v](/Users/athena/Desktop/File/testDataIC/Verilog_UART_FIFO_0524/tb/tb_top_loop_test.v:76) 还在每个时钟沿检查三个 FIFO：DUT RX FIFO、DUT TX FIFO 与独立边界模型。任意一个出现 `full=1` 且 `empty=1` 会记入 `total_errors`。这是一个基础安全属性检查，不是完整的 SVA 属性集。

## 7. 如何阅读一次回归结果

运行：

```bash
./run.sh multi
./run.sh all
```

`multi` 的正确日志应有四次 `[SCB][PASS]`，顺序为 `11`、`22`、`33`、`44`；汇总显示：

```text
已检查字节数 : 4
未匹配预期数 : 0
当前错误数   : 0
结果         : TEST PASS
```

`all` 的通过条件不是只看到 `TEST PASS` 一行，而是同时满足：

1. `total_errors == 0`。
2. `expected_count == 0`，没有未收到的预期事务。
3. 没有 FIFO `full` 与 `empty` 同时为高的过程检查错误。
4. 仿真以成功状态结束，脚本返回零退出码。

出现失败时，推荐按数据路径定位：先看 Driver 是否正确驱动 `rx`，再看 `w_rx_done` 和 RX FIFO 是否入队，检查 `rx_empty`/`tx_full` 与回环搬运条件，再看 TX FIFO、`w_tx_done` 和 `tx`；最后确认 Monitor 的采样时间和 Scoreboard 队列状态。运行 `./run.sh <case> --wave` 可导出相关信号的 VCD 波形。

## 8. 面试高频问题与回答要点

### Q1：为什么需要 Scoreboard，直接看波形不行吗？

波形适合定位，不适合规模化判定。Scoreboard 将预期与实际自动比较，可以在回归中稳定发现错误、提供事务序号和具体预期/实际值，也能检查输出遗漏与额外输出。实际项目里波形通常用于 Scoreboard 报错后的根因分析。

### Q2：为什么 Monitor 不能直接读取 Driver 的 data？

因为这会让参考路径绕过 DUT 输出接口。即便 `tx` 被错误编码、位宽错误或次序错误，Monitor 仍可能拿到 Driver 原始数据而错误通过。Monitor 应只基于被观察接口重建实际事务。

### Q3：Scoreboard 怎样判断乱序？能否给一个例子？

预期队列按 Driver 发送顺序入队，Monitor 的实际数据按观察顺序出队比较。例如预期是 `11,22`，如果实际先到 `22`，它会和队首 `11` 比较并立即失败。顺序错乱不会因为“两个值最终都出现过”而通过。

### Q4：`!=` 和 `!==` 有什么区别？这里为什么用 `!==`？

`!=` 是四态逻辑比较，含 `X/Z` 的结果可能是未知，放到 `if` 条件中不一定会进入失败分支；`!==` 是 case inequality，把 `X/Z` 也作为明确不一致处理。验证中通常希望未知值暴露为失败，所以使用 `!==`。

### Q5：这个 Scoreboard 是否是参考模型？

它是一个基于输入输出一致性的 in-order reference checker：参考结果就是端到端回环应原样输出的输入字节。对于会变换数据、重排数据或有复杂协议语义的 DUT，应单独建立行为级 reference model，再将模型预测结果送入 Scoreboard。

### Q6：为什么 Monitor 在 1.5 bit 后开始采样？

起始沿发生在起始位开头；再经过 1 bit 到达 D0 开头，再经过半个 bit 到 D0 中心。中心采样远离边沿，时序裕量更大。之后每 1 bit 采样一次对应 D1 到 D7。

### Q7：`multi`/`stream` 是否真正压满了 DUT 内 FIFO？

没有。它们每一帧结束后等待 Monitor，并增加保护间隔，因此重点是端到端数据和顺序。FIFO `full/empty` 只在独立 `fifo_boundary_model` 中直接覆盖。面试中应主动说明这个限制，而不是把它包装成压力测试。

### Q8：当前验证环境最大的缺口是什么？如何完善？

主要缺口有四类：

1. 没有超时保护。若 DUT 不输出，Monitor 会永久等待 `@(negedge tx)`，无法及时报“丢失输出”。可在每笔事务或测试总时长加入 watchdog；超时后打印未完成事务并计错。
2. 没有功能覆盖率。可统计数据值、首尾字节、复位前后、FIFO 满空转换、连续长度和读写组合的 coverpoint/cross，形成 coverage closure。
3. 没有随机约束激励。可随机化数据、帧间隔、复位时刻，结合定向 corner case，提高状态空间探索能力。
4. 缺少 DUT 集成级 FIFO 压力和协议异常测试。可连续发送足以填满缓冲的数据、检查 `tx_full` 反压和 RX 溢出策略，并注入错误停止位、毛刺起始位等 UART 异常。

### Q9：如果 DUT 丢了一个字节，Scoreboard 会怎样？

如果后续字节仍然到达，后续实际字节会与错位的队首预期不匹配，产生比较失败；若最后一个或唯一字节丢失，当前环境会在 `scoreboard_report()` 中看到 `expected_count` 非零，并按残留字节计错。更成熟的环境还要靠 watchdog 更早报出超时。

### Q10：复位测试应关注什么？

要确认复位期间输出和状态是否进入定义值，复位释放后状态机和 FIFO 是否从已知状态恢复，以及复位前挂起的事务预期如何处理。当前项目只覆盖空闲时复位后的恢复发送；下一步应增加接收中、发送中、FIFO 非空和 FIFO 满时的异步复位测试，并明确 Scoreboard 队列在 reset 时的 flush 策略。

### Q11：你如何区分 assertion、Scoreboard 和 coverage？

Scoreboard 检查事务级最终结果，例如输入字节是否按序从 `tx` 输出；assertion 检查时钟周期级、不可被违反的局部性质，例如 FIFO 不应同时满和空；coverage 量化哪些功能场景已经被激励和观察。三者分别回答“结果对不对”“时序/协议有没有违法”“测全了没有”。

### Q12：如果要用 UVM 重构这个环境，会怎样分层？

将 UART transaction 定义为 sequence item；sequence 产生定向或随机事务；driver 将事务编码到 `rx`；monitor 从 `tx` 恢复 transaction 并通过 analysis port 发送；scoreboard 维护 expected FIFO；agent 封装 driver、monitor、sequencer；environment 集成 agent、scoreboard、coverage 和配置；test 选择 sequence。核心验证思想不变，只是组件通信、可复用性和随机化能力更规范。

## 9. 面试中可以主动提出的改进计划

当面试官问“下一步怎么完善”时，可以按优先级回答：

1. **先加 watchdog 和失败定位信息。** 防止无输出时仿真挂住，并打印队列深度、最后一个事务和关键 FIFO 状态。
2. **再增加 DUT 集成级 burst 测试。** 连续发送不同长度的数据，覆盖 RX/TX FIFO 的接近满、满、接近空和空状态，检查回压和数据完整性。
3. **补协议异常和复位打断。** 覆盖错误停止位、窄起始毛刺、发送中复位、接收中复位，以及复位后的 Scoreboard flush 策略。
4. **用覆盖率闭环。** 定义功能覆盖点和交叉覆盖，明确哪些状态组合已经命中、哪些仍需要定向用例。
5. **需要可复用性时迁移至 SystemVerilog/UVM。** 保持 Driver、Monitor、Scoreboard 的职责边界，用 transaction 和 analysis port 替代当前的直接 task 调用。

这种回答比泛泛地说“加随机测试、加覆盖率”更有说服力，因为它同时说明了缺口、风险和落地顺序。

## 10. 面试前自测清单

你应能不看代码解释下面每一项：

- `scoreboard_expect()` 为什么在 Driver 驱动 `rx` 之前调用。
- Monitor 为什么从 `tx` 的下降沿开始、在 1.5 bit 后采样。
- 环形队列中读写指针和 `expected_count` 分别解决什么问题。
- 错序、丢失、额外输出和 `X/Z` 在当前 Scoreboard 中分别如何失败。
- `multi`/`stream` 的验证价值和非压力测试的边界。
- `fifo` 场景为什么实例化独立 FIFO，而不通过 UART 将 DUT 内 FIFO 灌满。
- `all` 的通过条件为何必须同时检查错误数和预期队列残留。
- 当前环境缺少哪些工程化机制，以及你会怎样按优先级补上。

掌握这些内容后，你可以把这个项目讲成一个有自检闭环、有边界意识、知道如何继续完善的数字验证项目，而不只是“写了几个 task 跑通仿真”。
