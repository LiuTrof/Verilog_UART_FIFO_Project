# Step 05 - 加入断言思想

## 目标

用断言检查设计中不应该出现的非法状态。

## 当前检查

在 `tb/tb_top_loop_test.v` 中检查：

```verilog
if (fifo_full && fifo_empty) begin
    $error("FIFO 非法状态：full 与 empty 同时为高");
end
```

检查对象包括：

- DUT 内部 RX FIFO。
- DUT 内部 TX FIFO。
- FIFO 边界模型。

## 为什么 full 和 empty 不能同时为 1

FIFO 的 `full` 表示没有空间继续写，`empty` 表示没有数据可以读。正常 FIFO 不应该同时又满又空。如果同时为 1，说明指针或状态机控制有问题。

## 面试表达

可以这样说：

> 我在 testbench 中加入了 FIFO 非法状态检查，确保 `full` 和 `empty` 不会同时拉高。这是 assertion-based verification 思想的入门实践；当前实现采用 Verilog 过程式检查，而非 SystemVerilog 的 `assert property` 语法。

## 小白要记住的点

Scoreboard 检查“结果对不对”，Assertion 检查“过程中有没有出现非法状态”。两者是互补的。
