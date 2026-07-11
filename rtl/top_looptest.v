`timescale 1ns / 1ps
//与原版本有变动
//  .tx_en(~w_rx_empty),
// .rx_en(~w_rx_empty),
// .tx_full(),
// 改成
// wire w_tx_full;

// .tx_en(~w_rx_empty & ~w_tx_full),
// .tx_full(w_tx_full),
// .rx_en(~w_rx_empty & ~w_tx_full),
// 只有 RX FIFO 非空，并且 TX FIFO 没满时，才允许把 RX FIFO 的数据搬到 TX FIFO。
//这是一个很基础的流控保护。否则如果 TX FIFO 满了，顶层还继续读 RX FIFO、写 TX FIFO，就可能导致数据丢失或时序不稳定。
//我没有大改 RTL，只是在顶层 loopback 加了 TX FIFO full 保护，避免在 TX FIFO 满时继续搬运数据。
module top_loop_test (
    input clk,
    input reset,
    input rx,
    output tx
);
    wire w_rx_empty;
    wire w_tx_full;
    wire [7:0] w_rx_data;

    uart_fifo U_UART_FIFO (
        .clk(clk),
        .reset(reset),
        .tx(tx),
        .tx_en(~w_rx_empty & ~w_tx_full),
        .tx_data(w_rx_data),
        .tx_full(w_tx_full),
        .rx(rx),
        .rx_en(~w_rx_empty & ~w_tx_full),
        .rx_data(w_rx_data),
        .rx_empty(w_rx_empty)
    );

endmodule
