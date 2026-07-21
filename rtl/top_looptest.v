`timescale 1ns / 1ps  // 仿真时间单位为 1 ns，时间精度为 1 ps。

// Testbench 连接的 DUT 顶层：当 RX FIFO 有数据且 TX FIFO 未满时，
// 将 RX FIFO 的字节搬运到 TX FIFO，从而构成回环通路。
module top_loop_test #(
    parameter integer UART_CLK_HZ = 100_000_000,  // 综合默认保持 100 MHz 系统时钟。
    parameter integer UART_BAUD   = 9_600         // UART 目标波特率。
) (
    input  clk,    // 100 MHz 设计时钟。
    input  reset,  // 高有效异步复位。
    input  rx,     // 由 testbench Driver 驱动的 UART 串行输入。
    output tx      // 由 testbench Monitor 观察的 UART 串行输出。
);
    wire       w_rx_empty;  // 为 1 表示 RX FIFO 没有可搬运的字节。
    wire       w_tx_full;   // 为 1 表示 TX FIFO 没有空闲存储位置。
    wire [7:0] w_rx_data;   // RX FIFO 当前读地址指向的字节，将送往 TX FIFO。

    // uart_fifo 内部包含一个 UART 核、一个 RX FIFO 和一个 TX FIFO。
    uart_fifo #(
        .UART_CLK_HZ(UART_CLK_HZ),
        .UART_BAUD  (UART_BAUD)
    ) U_UART_FIFO (
        .clk     (clk),                         // 全部子模块使用同一个系统时钟。
        .reset   (reset),                       // 同时复位全部子模块。
        .tx      (tx),                          // 将 UART 串行输出连接至顶层端口。
        .tx_en   (~w_rx_empty & ~w_tx_full),    // RX 有数据且 TX 有空间时，写入 TX FIFO。
        .tx_data (w_rx_data),                   // 搬运 RX FIFO 当前输出的字节。
        .tx_full (w_tx_full),                   // 获取 TX FIFO 反压状态。
        .rx      (rx),                          // 将顶层串行输入送入 UART 接收器。
        .rx_en   (~w_rx_empty & ~w_tx_full),    // 同一搬运条件下读取 RX FIFO。
        .rx_data (w_rx_data),                   // 接收 RX FIFO 的并行字节。
        .rx_empty(w_rx_empty)                   // 获取 RX FIFO 是否有有效数据。
    );

endmodule  // top_loop_test 顶层模块结束。
