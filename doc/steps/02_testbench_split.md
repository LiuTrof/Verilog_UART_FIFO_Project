# Step 02 - Testbench 拆分

## 目标

把原来所有逻辑都堆在一个 testbench 文件里的写法，拆成更像验证环境的结构。

## 当前文件

```text
tb/tb_top_loop_test.v       # TB 顶层：DUT、时钟、复位、VCD、整体流程
tb/driver/uart_driver.vh    # Driver：构造 UART 激励、记录预期数据、施加复位
tb/monitor/uart_monitor.vh  # Monitor：从 tx 解码 UART 帧、上报实际数据
tb/scoreboard.vh            # Scoreboard：expected_queue 与自动 PASS/FAIL
tb/test_case.vh             # Testcase：场景选择与激励序列
tb/uart_task.vh             # 旧版 task 对照文件，当前没有被 include
```

## 验证思想

拆分后可以把 testbench 看成下面几个角色：

```text
Testcase    -> 决定测什么
Driver      -> 负责怎么发
DUT         -> 被测设计
Monitor     -> 负责怎么收
Scoreboard  -> 自动判断对不对
```

这就是简化版验证环境的核心思想：激励、监测、比较分开。虽然不是 UVM，但职责划分已经对应 UVM 中的 Driver、Monitor、Scoreboard 概念。

## 小白要记住的点

验证代码不要只追求“能跑”。能维护、能增加测试、能自动判断，才是验证项目的核心价值。
