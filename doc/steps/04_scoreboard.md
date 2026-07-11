# Step 04 - Scoreboard 自动检查

## 目标

把“人工看波形判断对错”升级成“仿真自动判断 PASS/FAIL”。

## 当前实现

文件：

```text
tb/scoreboard.vh
```

核心逻辑：

```text
expected data -> scoreboard_check -> actual data
```

每收到一个 UART TX byte，testbench 会调用 `scoreboard_check(expected, actual)`。如果一致，打印 PASS；如果不一致，记录 error。

最终打印：

```text
UART FIFO SCOREBOARD
CHECKED BYTE : 26
ERROR        : 0
RESULT       : TEST PASS
```

## 为什么这是核心提升

验证岗位非常看重自动化判断。因为真实芯片验证不可能靠人肉盯几千上万条波形。Scoreboard 的价值就是把期望结果和实际结果自动比较。

## 和 UVM 的关系

当前不是 UVM，但思想相同：

```text
Generator/Driver 产生输入
Monitor 采集输出
Scoreboard 自动比较
```

你面试时可以说：

> 我没有一开始就上 UVM，而是先在 Verilog testbench 中实现了简化版 scoreboard，完成自动比对闭环。

## 小白要记住的点

波形是调试工具，不是最终验收标准。最终验收应该尽量自动化。

