`timescale 1ns / 1ps  // 仿真时间单位为 1 ns，时间精度为 1 ps。

// UART 加双 FIFO 的封装模块：将串行 RX 转为缓存字节，交给顶层回环逻辑，
// 再将缓存的 TX 字节重新串行化输出。
module uart_fifo #(
    parameter integer UART_CLK_HZ = 100_000_000,  // 综合默认保持 100 MHz。
    parameter integer UART_BAUD   = 9_600         // UART 目标波特率。
) (
    input        clk,       // 共享设计时钟。
    input        reset,     // 高有效异步复位。
    output       tx,        // 发送器产生的 UART 串行位流。
    input        tx_en,     // 顶层请求：将 tx_data 写入 TX FIFO。
    input  [7:0] tx_data,   // 顶层提供、等待后续发送的并行字节。
    output       tx_full,   // TX FIFO 满，顶层必须暂停搬运 RX 数据。
    input        rx,        // UART 接收器采样的串行位流。
    input        rx_en,     // 顶层请求：消费一个 RX FIFO 字节。
    output [7:0] rx_data,   // RX FIFO 当前读地址指向的字节。
    output       rx_empty   // RX FIFO 为空时为 1，此时 rx_data 不代表有效事务。
);

    wire       w_tx_fifo_empty;  // TX FIFO 没有等待发送的字节。
    wire       w_tx_done;        // UART 发送器完成一帧后产生的单时钟脉冲。
    wire       w_rx_done;        // UART 接收器完成一帧后产生的单时钟脉冲。
    wire [7:0] w_tx_fifo_rdata;  // 从 TX FIFO 读出并送给 UART 发送器的字节。
    wire [7:0] w_rx_data;        // UART 接收器还原、即将写入 RX FIFO 的字节。

    // 一个 uart 实例同时包含发送器和接收器，二者共用一个波特率节拍。
    uart #(
        .CLK_HZ(UART_CLK_HZ),
        .BAUD  (UART_BAUD)
    ) U_UART (
        .clk    (clk),                  // 用系统时钟驱动 UART 状态机。
        .reset  (reset),                // 复位波特率发生器、发送器和接收器。
        .tx     (tx),                   // 导出发送器的串行输出。
        .start  (~w_tx_fifo_empty),     // TX FIFO 非空时持续请求发送器开始发送。
        .tx_data(w_tx_fifo_rdata),      // 提供 TX FIFO 当前读出的字节。
        .tx_done(w_tx_done),            // 用一帧发送完成脉冲弹出 TX FIFO。
        .rx     (rx),                   // 采样外部串行输入。
        .rx_data(w_rx_data),            // 接收还原出的并行字节。
        .rx_done(w_rx_done)             // 一帧接收完成时触发 RX FIFO 写入。
    );

    // RX FIFO 保存每个接收完成的 UART 字节，直到顶层回环控制逻辑将其读走。
    fifo #(
        .ADDR_WIDTH(3),                 // 3 位地址可选择 2^3 = 8 个存储项。
        .DATA_WIDTH(8)                  // 每项存储一个 UART 字节。
    ) U_Rx_Fifo (
        .clk   (clk),                   // 与 UART、顶层控制处于同一时钟域。
        .reset (reset),                 // 复位时清空 FIFO 指针和存储内容。
        .wr_en (w_rx_done),             // 接收器报告完成后，才将该字节入队。
        .full  (),                      // 当前集成版本未将 RX FIFO 满状态接出。
        .wdata (w_rx_data),             // 写入已解码的 UART 字节。
        .rd_en (rx_en),                 // 顶层允许搬运时，将一个字节出队。
        .empty (rx_empty),              // 告知顶层是否存在可搬运的有效字节。
        .rdata (rx_data)                // 输出当前读地址指向的 RX FIFO 字节。
    );

    // TX FIFO 将顶层搬运与较慢的串行发送器解耦。
    fifo #(
        .ADDR_WIDTH(3),                 // FIFO 深度为 8 项。
        .DATA_WIDTH(8)                  // 每项存储一个字节。
    ) U_Tx_Fifo (
        .clk   (clk),                   // 与其余模块使用同一时钟域。
        .reset (reset),                 // 复位时清空 TX 缓冲。
        .wr_en (tx_en),                 // 顶层回环控制选中的字节入队。
        .full  (tx_full),               // 将可用空间状态反馈给顶层控制。
        .wdata (tx_data),               // 从 RX FIFO 搬运过来的字节。
        .rd_en (w_tx_done),             // 当前串行帧发送完成后，才将该字节出队。
        .empty (w_tx_fifo_empty),       // 防止 UART 在没有缓存字节时启动发送。
        .rdata (w_tx_fifo_rdata)        // 将当前 TX FIFO 字节提供给 UART 发送器。
    );

endmodule  // uart_fifo 模块结束。
