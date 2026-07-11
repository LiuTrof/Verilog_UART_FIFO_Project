`ifndef UART_DRIVER_VH
`define UART_DRIVER_VH

task uart_driver_send_byte;
    input [7:0] data;
    integer bit_idx;
    begin
        scoreboard_expect(data);
        driver_data = data;
        $display("[DRV] send data=0x%02h time=%0t", data, $time);

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

task uart_driver_apply_reset;
    begin
        $display("[DRV] apply reset time=%0t", $time);
        rx = 1'b1;
        reset = 1'b1;
        repeat (20) @(posedge clk);
        reset = 1'b0;
        repeat (20) @(posedge clk);
    end
endtask

`endif
