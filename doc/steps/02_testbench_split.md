# Step 02 - Testbench 拆分

## 目标

把原来所有逻辑都堆在一个 testbench 文件里的写法，拆成更像验证环境的结构。

## 当前文件

```text
tb/tb_top_loop_test.v   # 顶层 testbench，负责实例化 DUT、时钟、复位、整体流程
tb/uart_task.vh         # UART 发送和接收 task，相当于简化 driver/monitor
tb/test_case.vh         # 测试用例集合
tb/scoreboard.vh        # 自动比较 expected 和 actual
```

## 验证思想

拆分后可以把 testbench 看成下面几个角色：

```text
Testcase  -> 决定测什么
Task      -> 负责怎么发、怎么收
DUT       -> 被测设计
Scoreboard -> 自动判断对不对
```

这就是简化版的验证环境思想。虽然还不是 UVM，但思想已经接近：激励、监测、比较分开。

## 小白要记住的点

验证代码不要只追求“能跑”。能维护、能增加测试、能自动判断，才是验证项目的核心价值。

