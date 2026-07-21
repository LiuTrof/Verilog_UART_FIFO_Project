// Shared pin-level view used by the UVM UART agent.
interface uart_fifo_if (input logic clk);
    logic reset;
    logic rx;
    wire  tx;

    logic [7:0] driver_data;
    logic [7:0] monitor_data;

    initial begin
        reset        = 1'b1;
        rx           = 1'b1;
        driver_data  = '0;
        monitor_data = '0;
    end
endinterface

// Direct interface for the standalone FIFO boundary regression.
interface fifo_boundary_if (input logic clk);
    logic       reset;
    logic       wr_en;
    logic       rd_en;
    logic [7:0] wdata;
    wire        full;
    wire        empty;
    wire [7:0]  rdata;

    initial begin
        reset = 1'b1;
        wr_en = 1'b0;
        rd_en = 1'b0;
        wdata = '0;
    end
endinterface

// Observability-only interface. The UVM checker never drives these signals.
interface uart_fifo_status_if (
    input logic clk,
    input logic reset,
    input logic rx_full,
    input logic rx_empty,
    input logic tx_full,
    input logic tx_empty,
    input logic boundary_full,
    input logic boundary_empty
);
endinterface
