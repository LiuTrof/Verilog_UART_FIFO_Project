`ifndef TEST_CASE_VH
`define TEST_CASE_VH
//测试用例
task run_loopback_sequence;
    input integer length;
    input integer pattern;
    integer idx;
    integer rx_idx;
    reg [7:0] actual_data;
    begin
        fork
            begin
                for (idx = 0; idx < length; idx = idx + 1) begin
                    uart_driver_send_byte(get_test_data(idx, pattern));
                end
            end
            begin
                for (rx_idx = 0; rx_idx < length; rx_idx = rx_idx + 1) begin
                    uart_monitor_receive_byte(actual_data);
                end
            end
        join
    end
endtask

task run_safe_loopback_sequence;
    input integer length;
    input integer pattern;
    integer idx;
    reg [7:0] actual_data;
    begin
        for (idx = 0; idx < length; idx = idx + 1) begin
            fork
                begin
                    uart_driver_send_byte(get_test_data(idx, pattern));
                end
                begin
                    uart_monitor_receive_byte(actual_data);
                end
            join

            #(12 * BIT_PERIOD_NS);
        end
    end
endtask
//增加测试场景，覆盖一下情况：
//单字节回环：A5
// 多字节回环：11 22 33 44
// 20 字节连续数据：00 到 13
// FIFO full/empty 边界模型测试
// reset 后恢复测试

function [7:0] get_test_data;
    input integer index;
    input integer pattern;
    begin
        case (pattern)
            0: get_test_data = 8'hA5;
            1: begin
                case (index)
                    0: get_test_data = 8'h11;
                    1: get_test_data = 8'h22;
                    2: get_test_data = 8'h33;
                    3: get_test_data = 8'h44;
                    default: get_test_data = index[7:0];
                endcase
            end
            2: get_test_data = index[7:0];
            default: get_test_data = 8'h00;
        endcase
    end
endfunction

task test_single_byte;
    begin
        $display("\n[TEST] single byte loopback: A5");
        run_loopback_sequence(1, 0);
    end
endtask

task test_multi_byte;
    begin
        $display("\n[TEST] multi byte loopback: 11 22 33 44");
        uart_driver_apply_reset();
        run_safe_loopback_sequence(4, 1);
    end
endtask

task test_fifo_stream;
    begin
        $display("\n[TEST] stream loopback: 20 bytes 00..13");
        uart_driver_apply_reset();
        run_safe_loopback_sequence(20, 2);
    end
endtask

task test_rx_fifo_fill_level;
    integer idx;
    begin
        $display("\n[TEST] FIFO boundary model: direct fifo full/empty check");
        fifo_boundary_model_reset = 1'b1;
        fifo_boundary_model_wr_en = 1'b0;
        fifo_boundary_model_rd_en = 1'b0;
        fifo_boundary_model_wdata = 8'h00;
        repeat (3) @(posedge clk);
        fifo_boundary_model_reset = 1'b0;
        repeat (2) @(posedge clk);

        for (idx = 0; idx < 8; idx = idx + 1) begin
            fifo_boundary_model_wdata = idx[7:0];
            fifo_boundary_model_wr_en = 1'b1;
            @(posedge clk);
        end
        fifo_boundary_model_wr_en = 1'b0;
        @(posedge clk);

        if (fifo_boundary_model_full !== 1'b1) begin
            total_errors = total_errors + 1;
            $display("[FIFO][FAIL] full expected=1 actual=%0b time=%0t", fifo_boundary_model_full, $time);
        end else begin
            $display("[FIFO][PASS] full asserted after 8 writes at %0t", $time);
        end

        for (idx = 0; idx < 8; idx = idx + 1) begin
            fifo_boundary_model_rd_en = 1'b1;
            @(posedge clk);
        end
        fifo_boundary_model_rd_en = 1'b0;
        @(posedge clk);

        if (fifo_boundary_model_empty !== 1'b1) begin
            total_errors = total_errors + 1;
            $display("[FIFO][FAIL] empty expected=1 actual=%0b time=%0t", fifo_boundary_model_empty, $time);
        end else begin
            $display("[FIFO][PASS] empty asserted after 8 reads at %0t", $time);
        end
    end
endtask

task test_reset_recovery;
    begin
        $display("\n[TEST] reset recovery");
        uart_driver_apply_reset();
        run_safe_loopback_sequence(1, 0);
    end
endtask

task run_selected_test;
    reg [8*16-1:0] selected_test;
    begin
        if (!$value$plusargs("TEST=%s", selected_test)) begin
            selected_test = "all";
        end

        $display("[TEST] selected=%0s", selected_test);
        if (selected_test == "single") begin
            test_single_byte();
        end else if (selected_test == "multi") begin
            test_multi_byte();
        end else if (selected_test == "stream") begin
            test_fifo_stream();
        end else if (selected_test == "fifo") begin
            test_rx_fifo_fill_level();
        end else if (selected_test == "reset") begin
            test_reset_recovery();
        end else if (selected_test == "all") begin
            test_single_byte();
            test_multi_byte();
            test_fifo_stream();
            test_rx_fifo_fill_level();
            test_reset_recovery();
        end else begin
            total_errors = total_errors + 1;
            $display("[TEST][FAIL] unsupported TEST=%0s", selected_test);
        end
    end
endtask

`endif
