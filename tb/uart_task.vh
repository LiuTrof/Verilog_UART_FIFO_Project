`ifndef UART_TASK_VH
`define UART_TASK_VH
//UART 发送/接收 task
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

task send_uart_byte_no_gap;
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

task apply_reset;
    begin
        rx = 1'b1;
        reset = 1'b1;
        repeat (20) @(posedge clk);
        reset = 1'b0;
        repeat (20) @(posedge clk);
    end
endtask

`endif
