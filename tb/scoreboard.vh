`ifndef SCOREBOARD_VH
`define SCOREBOARD_VH
// Expected-data queue plus actual-data comparison.
integer total_checked;
integer total_errors;
integer expected_count;
integer expected_read_index;
integer expected_write_index;
reg [7:0] expected_queue [0:255];

task scoreboard_reset;
    begin
        total_checked = 0;
        total_errors = 0;
        expected_count = 0;
        expected_read_index = 0;
        expected_write_index = 0;
    end
endtask

task scoreboard_expect;
    input [7:0] expected;
    begin
        if (expected_count == 256) begin
            total_errors = total_errors + 1;
            $display("[SCB][FAIL] expected queue overflow time=%0t", $time);
        end else begin
            expected_queue[expected_write_index] = expected;
            expected_write_index = (expected_write_index + 1) % 256;
            expected_count = expected_count + 1;
            $display("[SCB] expected data=0x%02h queued=%0d time=%0t",
                     expected, expected_count, $time);
        end
    end
endtask

task scoreboard_check_actual;
    input [7:0] actual;
    reg [7:0] expected;
    begin
        total_checked = total_checked + 1;

        if (expected_count == 0) begin
            total_errors = total_errors + 1;
            $display("[SCB][FAIL] unexpected actual=0x%02h time=%0t", actual, $time);
        end else begin
            expected = expected_queue[expected_read_index];
            expected_read_index = (expected_read_index + 1) % 256;
            expected_count = expected_count - 1;

        if (actual !== expected) begin
            total_errors = total_errors + 1;
            $display("[SCB][FAIL] index=%0d expected=0x%02h actual=0x%02h time=%0t",
                     total_checked - 1, expected, actual, $time);
        end else begin
            $display("[SCB][PASS] index=%0d data=0x%02h time=%0t",
                     total_checked - 1, actual, $time);
        end
        end
    end
endtask

task scoreboard_report;
    begin
        $display("====================");
        $display("UART FIFO SCOREBOARD");
        $display("CHECKED BYTE : %0d", total_checked);
        $display("PENDING BYTE : %0d", expected_count);
        $display("ERROR        : %0d", total_errors);
        if (expected_count != 0) begin
            total_errors = total_errors + expected_count;
            $display("[SCB][FAIL] %0d expected byte(s) were not observed", expected_count);
        end
        if (total_errors == 0) begin
            $display("RESULT       : TEST PASS");
        end else begin
            $display("RESULT       : TEST FAIL");
        end
        $display("====================");
    end
endtask

`endif
