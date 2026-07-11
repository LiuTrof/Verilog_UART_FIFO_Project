`ifndef SCOREBOARD_VH
`define SCOREBOARD_VH
//自动比较
integer total_checked;
integer total_errors;

task scoreboard_reset;
    begin
        total_checked = 0;
        total_errors = 0;
    end
endtask

task scoreboard_check;
    input [7:0] expected;
    input [7:0] actual;
    begin
        total_checked = total_checked + 1;

        if (actual !== expected) begin
            total_errors = total_errors + 1;
            $display("[SCB][FAIL] index=%0d expected=0x%02h actual=0x%02h time=%0t",
                     total_checked - 1, expected, actual, $time);
        end else begin
            $display("[SCB][PASS] index=%0d data=0x%02h time=%0t",
                     total_checked - 1, actual, $time);
        end
    end
endtask

task scoreboard_report;
    begin
        $display("====================");
        $display("UART FIFO SCOREBOARD");
        $display("CHECKED BYTE : %0d", total_checked);
        $display("ERROR        : %0d", total_errors);
        if (total_errors == 0) begin
            $display("RESULT       : TEST PASS");
        end else begin
            $display("RESULT       : TEST FAIL");
        end
        $display("====================");
    end
endtask

`endif
