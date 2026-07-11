`ifndef UART_MONITOR_VH
`define UART_MONITOR_VH

task uart_monitor_receive_byte;
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
        monitor_data = data;
        $display("[MON] receive data=0x%02h time=%0t", data, $time);
        scoreboard_check_actual(data);
    end
endtask

`endif
