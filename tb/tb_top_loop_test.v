`timescale 1ns / 1ps
// 核心入口
module tb_top_loop_test;

    localparam integer CLK_PERIOD_NS = 10;
    localparam integer BIT_PERIOD_NS = 104_160;
    localparam integer HALF_BIT_PERIOD_NS = BIT_PERIOD_NS / 2;
    localparam integer FRAME_GAP_NS = BIT_PERIOD_NS * 6;

    reg clk = 1'b0;
    reg reset = 1'b1;
    reg rx = 1'b1;
    wire tx;

    reg [7:0] driver_data = 8'h00;
    reg [7:0] monitor_data = 8'h00;

    reg fifo_boundary_model_reset = 1'b1;
    reg fifo_boundary_model_wr_en = 1'b0;
    reg fifo_boundary_model_rd_en = 1'b0;
    reg [7:0] fifo_boundary_model_wdata = 8'h00;
    wire fifo_boundary_model_full;
    wire fifo_boundary_model_empty;
    wire [7:0] fifo_boundary_model_rdata;

    top_loop_test dut (
        .clk(clk),
        .reset(reset),
        .rx(rx),
        .tx(tx)
    );

    fifo #(
        .ADDR_WIDTH(3),
        .DATA_WIDTH(8)
    ) fifo_boundary_model (
        .clk(clk),
        .reset(fifo_boundary_model_reset),
        .wr_en(fifo_boundary_model_wr_en),
        .full(fifo_boundary_model_full),
        .wdata(fifo_boundary_model_wdata),
        .rd_en(fifo_boundary_model_rd_en),
        .empty(fifo_boundary_model_empty),
        .rdata(fifo_boundary_model_rdata)
    );

    always #(CLK_PERIOD_NS / 2) clk = ~clk;

    `include "scoreboard.vh"
    `include "driver/uart_driver.vh"
    `include "monitor/uart_monitor.vh"
    `include "test_case.vh"

    always @(posedge clk) begin
        if (!reset) begin
            if (dut.U_UART_FIFO.U_Rx_Fifo.full && dut.U_UART_FIFO.U_Rx_Fifo.empty) begin
                $error("RX FIFO illegal state: full and empty are both high at %0t", $time);
                total_errors = total_errors + 1;
            end

            if (dut.U_UART_FIFO.U_Tx_Fifo.full && dut.U_UART_FIFO.U_Tx_Fifo.empty) begin
                $error("TX FIFO illegal state: full and empty are both high at %0t", $time);
                total_errors = total_errors + 1;
            end

            if (fifo_boundary_model_full && fifo_boundary_model_empty) begin
                $error("FIFO boundary model illegal state: full and empty are both high at %0t", $time);
                total_errors = total_errors + 1;
            end
        end
    end

    initial begin
        reg [8*256-1:0] vcd_file;
        if ($value$plusargs("VCD=%s", vcd_file)) begin
            $dumpfile(vcd_file);
            $dumpvars(0, clk, reset, rx, tx);
            $dumpvars(0, driver_data, monitor_data);
            $dumpvars(0, dut.U_UART_FIFO.w_rx_done, dut.U_UART_FIFO.w_tx_done,
                      dut.U_UART_FIFO.rx_data, dut.U_UART_FIFO.rx_empty,
                      dut.U_UART_FIFO.U_Rx_Fifo.full, dut.U_UART_FIFO.U_Rx_Fifo.empty,
                      dut.U_UART_FIFO.U_Tx_Fifo.full, dut.U_UART_FIFO.U_Tx_Fifo.empty);
            $dumpvars(0, fifo_boundary_model_reset, fifo_boundary_model_wr_en,
                      fifo_boundary_model_rd_en, fifo_boundary_model_wdata,
                      fifo_boundary_model_full, fifo_boundary_model_empty,
                      fifo_boundary_model_rdata);
        end

        scoreboard_reset();
        uart_driver_apply_reset();
        run_selected_test();

        scoreboard_report();

        #(5 * BIT_PERIOD_NS);
        if (total_errors == 0) begin
            $finish;
        end else begin
            $finish_and_return(1);
        end
    end

endmodule
