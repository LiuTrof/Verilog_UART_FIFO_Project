`timescale 1ns / 1ps

import uvm_pkg::*;
import uart_fifo_pkg::*;

module tb_top_loop_test_uvm;
    // Use an equivalent 10 MHz simulation clock; production RTL defaults remain 100 MHz.
    localparam time CLK_PERIOD_NS = 100ns;

    logic clk = 1'b0;

    uart_fifo_if        uart_vif(clk);
    fifo_boundary_if     fifo_vif(clk);

    // UART RX -> RX FIFO -> loopback controller -> TX FIFO -> UART TX.
    top_loop_test #(
        .UART_CLK_HZ(10_000_000),
        .UART_BAUD  (9_600)
    ) dut (
        .clk  (clk),
        .reset(uart_vif.reset),
        .rx   (uart_vif.rx),
        .tx   (uart_vif.tx)
    );

    // A direct FIFO instance keeps the original full/empty boundary test in UVM.
    fifo #(
        .ADDR_WIDTH(3),
        .DATA_WIDTH(8)
    ) fifo_boundary_model (
        .clk  (clk),
        .reset(fifo_vif.reset),
        .wr_en(fifo_vif.wr_en),
        .full (fifo_vif.full),
        .wdata(fifo_vif.wdata),
        .rd_en(fifo_vif.rd_en),
        .empty(fifo_vif.empty),
        .rdata(fifo_vif.rdata)
    );

    uart_fifo_status_if status_vif (
        .clk           (clk),
        .reset         (uart_vif.reset),
        .rx_full       (dut.U_UART_FIFO.U_Rx_Fifo.full),
        .rx_empty      (dut.U_UART_FIFO.U_Rx_Fifo.empty),
        .tx_full       (dut.U_UART_FIFO.U_Tx_Fifo.full),
        .tx_empty      (dut.U_UART_FIFO.U_Tx_Fifo.empty),
        .boundary_full (fifo_vif.full),
        .boundary_empty(fifo_vif.empty)
    );

    always #(CLK_PERIOD_NS / 2) clk = ~clk;

    initial begin
        string vcd_file;

        if ($value$plusargs("VCD=%s", vcd_file)) begin
            $dumpfile(vcd_file);
            // Capture the transaction path and FIFO state, but not the 100 MHz clock.
            // A full-clock VCD turns long UART streams into multi-gigabyte files.
            $dumpvars(0, uart_vif.reset, uart_vif.rx, uart_vif.tx,
                      uart_vif.driver_data, uart_vif.monitor_data,
                      dut.U_UART_FIFO.w_rx_done, dut.U_UART_FIFO.w_tx_done,
                      dut.U_UART_FIFO.rx_data, dut.U_UART_FIFO.rx_empty,
                      dut.U_UART_FIFO.U_Rx_Fifo.full, dut.U_UART_FIFO.U_Rx_Fifo.empty,
                      dut.U_UART_FIFO.U_Tx_Fifo.full, dut.U_UART_FIFO.U_Tx_Fifo.empty,
                      fifo_vif.reset, fifo_vif.wr_en, fifo_vif.rd_en, fifo_vif.wdata,
                      fifo_vif.full, fifo_vif.empty, fifo_vif.rdata);
        end

        uvm_config_db#(virtual uart_fifo_if)::set(null, "uvm_test_top.env.agent*", "vif", uart_vif);
        uvm_config_db#(virtual fifo_boundary_if)::set(null, "uvm_test_top", "fifo_vif", fifo_vif);
        uvm_config_db#(virtual uart_fifo_status_if)::set(null, "uvm_test_top.env.checker", "status_vif", status_vif);
        run_test("uart_fifo_test");
    end
endmodule
