# Step 06 - 如何运行仿真

## 运行命令

在 `Verilog_UART_FIFO_0524` 目录下执行：

```bash
iverilog -g2012 -I tb -o sim/uart_fifo_sim/uart_fifo_tb.out \
  tb/tb_top_loop_test.v \
  rtl/top_looptest.v \
  rtl/uart_fifo.v \
  rtl/uart.v \
  rtl/fifo.v

vvp sim/uart_fifo_sim/uart_fifo_tb.out
```

## 查看波形

仿真会生成：

```text
sim/uart_fifo_sim/tb_top_loop_test.vcd
```

用 GTKWave 打开：

```bash
gtkwave sim/uart_fifo_sim/tb_top_loop_test.vcd
```

## 本次验证结果

当前仿真结果：

```text
CHECKED BYTE : 26
ERROR        : 0
RESULT       : TEST PASS
```

## 小白要记住的点

每次改 testbench 或 RTL 后，都要重新编译和运行。验证工程师的基本动作是：修改、仿真、看 log、必要时看波形。

