`timescale 1ns / 1ps

module uart_fifo (
    input clk,
    input reset,
    output tx,
    input tx_en,
    input [7:0] tx_data,
    output tx_full,
    input rx,
    input rx_en,
    output [7:0] rx_data,
    output rx_empty
);

    wire w_tx_fifo_empty;
    wire w_tx_done;
    wire w_rx_done;
    wire [7:0] w_tx_fifo_rdata;
    wire [7:0] w_rx_data;

    uart U_UART (
        .clk(clk),
        .reset(reset),
        .tx(tx),
        .start(~w_tx_fifo_empty),
        .tx_data(w_tx_fifo_rdata),
        .tx_done(w_tx_done),
        .rx(rx),
        .rx_data(w_rx_data),
        .rx_done(w_rx_done)
    );

    fifo #(
        .ADDR_WIDTH(3),
        .DATA_WIDTH(8)
    ) U_Rx_Fifo (
        .clk(clk),
        .reset(reset),
        .wr_en(w_rx_done),
        .full(),
        .wdata(w_rx_data),
        .rd_en(rx_en),
        .empty(rx_empty),
        .rdata(rx_data)
    );

    fifo #(
        .ADDR_WIDTH(3),
        .DATA_WIDTH(8)
    ) U_Tx_Fifo (
        .clk(clk),
        .reset(reset),
        .wr_en(tx_en),
        .full(tx_full),
        .wdata(tx_data),
        .rd_en(w_tx_done),
        .empty(w_tx_fifo_empty),
        .rdata(w_tx_fifo_rdata)
    );

endmodule
