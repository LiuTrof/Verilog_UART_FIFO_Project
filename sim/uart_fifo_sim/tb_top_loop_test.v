`timescale 1ns / 1ps

module tb_top_loop_test;

    localparam integer CLK_PERIOD_NS = 10;
    localparam integer BIT_PERIOD_NS = 104_160;
    localparam integer HALF_BIT_PERIOD_NS = BIT_PERIOD_NS / 2;
    localparam integer FRAME_GAP_NS = BIT_PERIOD_NS * 6;

    reg clk = 1'b0;
    reg reset = 1'b1;
    reg rx = 1'b1;
    wire tx;

    reg [7:0] sent_byte;
    reg [7:0] echoed_byte;

    top_loop_test dut (
        .clk(clk),
        .reset(reset),
        .rx(rx),
        .tx(tx)
    );

    always #(CLK_PERIOD_NS / 2) clk = ~clk;

    task send_uart_byte;
        input [7:0] data;
        integer bit_idx;
        begin
            rx <= 1'b1;
            #(BIT_PERIOD_NS);
            rx <= 1'b0;
            #(BIT_PERIOD_NS);
            for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
                rx <= data[bit_idx];
                #(BIT_PERIOD_NS);
            end
            rx <= 1'b1;
            #(BIT_PERIOD_NS);
            #(FRAME_GAP_NS);
        end
    endtask

    task receive_uart_byte;
        output [7:0] data;
        integer bit_idx;
        begin
            data = 8'h00;
            @(negedge tx);
            #(BIT_PERIOD_NS + HALF_BIT_PERIOD_NS);
            for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
                data[bit_idx] = tx;
                #(BIT_PERIOD_NS);
            end
            #(BIT_PERIOD_NS);
        end
    endtask

    initial begin
        $dumpfile("sim/uart_fifo_sim/tb_top_loop_test.vcd");
        $dumpvars(0, tb_top_loop_test);

        sent_byte = 8'hA5;

        #(20 * CLK_PERIOD_NS);
        reset = 1'b0;
        #(20 * CLK_PERIOD_NS);

        fork
            begin
                send_uart_byte(sent_byte);
            end
            begin
                receive_uart_byte(echoed_byte);
                $display("RX0=%02h at %0t", echoed_byte, $time);
            end
        join

        if (echoed_byte !== sent_byte) begin
            $display("FAIL: expected %02h, got %02h", sent_byte, echoed_byte);
            $finish_and_return(1);
        end

        $display("PASS: loopback echoed %02h", echoed_byte);
        #(5 * BIT_PERIOD_NS);
        $finish;
    end

endmodule
