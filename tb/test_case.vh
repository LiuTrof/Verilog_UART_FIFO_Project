// ============================================================================
// 文件作用：验证环境的测试用例集合与 +TEST 场景选择逻辑。
// 功能：定义单字节、多字节、20/64/128 字节序列、数据模式、FIFO 边界和 reset recovery 场景。
// 说明：多字节序列每发送一帧都会等待本帧 Monitor 完成，并保留保护间隔；
// 它们验证端到端数据顺序，不是将 DUT 内部 FIFO 灌满的吞吐压力测试。
// 注意：本文件由 tb_top_loop_test.v include，不是独立 module。
// ============================================================================
`ifndef TEST_CASE_VH  // 防止同一文件被重复 include。
`define TEST_CASE_VH  // 定义 include 保护宏。

// 连续发送 length 个字节，同时并行启动 Driver 和 Monitor。
// 当前仅用于单字节场景；多字节场景使用下面更保守的 safe 版本。
task run_loopback_sequence;
    input integer length;      // 本轮需要发送和接收的总字节数。
    input integer pattern;     // 交给 get_test_data() 的数据模式编号。
    integer idx;               // Driver 循环索引。
    integer rx_idx;            // Monitor 循环索引。
    reg [7:0] actual_data;     // Monitor task 返回的实际字节临时变量。
    begin
        fork  // 两个分支并行：一个发 UART 帧，一个等待并解码 UART 输出帧。
            begin
                for (idx = 0; idx < length; idx = idx + 1) begin
                    uart_driver_send_byte(get_test_data(idx, pattern));  // 依序发送激励数据。
                end
            end
            begin
                for (rx_idx = 0; rx_idx < length; rx_idx = rx_idx + 1) begin
                    uart_monitor_receive_byte(actual_data);  // 依序接收并自动送入 Scoreboard。
                end
            end
        join  // 等待发送和接收两个分支都结束。
    end
endtask  // run_loopback_sequence 结束。

// 保守版多字节回环：每帧都等待 Monitor 解码完成后才发下一帧，减少当前 RTL
// 非完整握手流控带来的时序干扰，便于聚焦端到端功能与顺序检查。
task run_safe_loopback_sequence;
    input integer length;      // 本轮要执行的字节数。
    input integer pattern;     // 数据模式编号。
    integer idx;               // 本轮字节索引。
    reg [7:0] actual_data;     // 当前帧实际接收字节。
    begin
        for (idx = 0; idx < length; idx = idx + 1) begin
            fork  // 一帧内发送和接收并行进行。
                begin
                    uart_driver_send_byte(get_test_data(idx, pattern));  // Driver 串行发送该帧。
                end
                begin
                    uart_monitor_receive_byte(actual_data);  // Monitor 解码该帧并触发自动比对。
                end
            join  // 等到本帧 tx 被完整观察到后再继续下一帧。

            #(12 * BIT_PERIOD_NS);  // 帧间保护时间，不把本测试定义为极限压力场景。
        end
    end
endtask  // run_safe_loopback_sequence 结束。

// 按模式与索引生成每个 testcase 使用的激励数据。
function [7:0] get_test_data;
    input integer index;    // 当前数据在序列中的位置。
    input integer pattern;  // 0=A5，1=固定序列，2=递增，3=混合，4=压力模式。
    begin
        case (pattern)
            0: get_test_data = 8'hA5;  // 单字节与 reset recovery 使用固定 A5。
            1: begin
                case (index)
                    0: get_test_data = 8'h11;  // 多字节场景第 1 个字节。
                    1: get_test_data = 8'h22;  // 多字节场景第 2 个字节。
                    2: get_test_data = 8'h33;  // 多字节场景第 3 个字节。
                    3: get_test_data = 8'h44;  // 多字节场景第 4 个字节。
                    default: get_test_data = index[7:0];  // 超出四字节时备用的递增值。
                endcase
            end
            2: get_test_data = index[7:0];  // 递增序列：00 至 FF 回绕。
            3: begin
                case (index % 16)
                    0:  get_test_data = 8'h00;
                    1:  get_test_data = 8'hFF;
                    2:  get_test_data = 8'h55;
                    3:  get_test_data = 8'hAA;
                    4:  get_test_data = 8'h01;
                    5:  get_test_data = 8'h80;
                    6:  get_test_data = 8'h7F;
                    7:  get_test_data = 8'hFE;
                    8:  get_test_data = 8'h3C;
                    9:  get_test_data = 8'hC3;
                    10: get_test_data = 8'h0F;
                    11: get_test_data = 8'hF0;
                    12: get_test_data = 8'h12;
                    13: get_test_data = 8'h21;
                    14: get_test_data = 8'h96;
                    default: get_test_data = 8'h69;
                endcase
            end
            4: begin
                case (index % 8)
                    0: get_test_data = 8'h00;
                    1: get_test_data = 8'hFF;
                    2: get_test_data = 8'h55;
                    3: get_test_data = 8'hAA;
                    4: get_test_data = 8'h01 << ((index / 8) % 8);
                    5: get_test_data = 8'h80 >> ((index / 8) % 8);
                    6: get_test_data = 8'h0F;
                    default: get_test_data = 8'hF0;
                endcase
            end
            default: get_test_data = 8'h00;  // 未定义模式使用 00。
        endcase
    end
endfunction  // get_test_data 结束。

// 基础端到端回环：发送 A5，并检查 TX 端最终是否恢复 A5。
task test_single_byte;
    begin
        $display("\n[TEST] 单字节回环：A5");
        run_loopback_sequence(1, 0);  // 发送 1 个 pattern=0 的 A5。
    end
endtask  // test_single_byte 结束。

// 顺序性回环：发送 11、22、33、44，检查是否存在错序、丢失或错误数据。
task test_multi_byte;
    begin
        $display("\n[TEST] 多字节回环：11 22 33 44");
        uart_driver_apply_reset();          // 各场景独立从已知状态开始。
        run_safe_loopback_sequence(4, 1);  // 发送 4 个 pattern=1 的固定字节。
    end
endtask  // test_multi_byte 结束。

// 长一些的顺序流：发送 00 至 13 共 20 字节，检查顺序与数据一致性。
task test_fifo_stream;
    begin
        $display("\n[TEST] 递增序列回环：20 字节 00 至 13");
        uart_driver_apply_reset();           // 场景前复位，排除前一场景残留状态。
        run_safe_loopback_sequence(20, 2);  // 发送 20 个 pattern=2 的递增字节。
    end
endtask  // test_fifo_stream 结束。

// 中等长度混合序列：覆盖全零、全一、交替位、边界值和非对称数据。
task test_multi16_byte;
    begin
        $display("\n[TEST] 混合顺序回环：16 字节 corner-value 序列");
        uart_driver_apply_reset();
        run_safe_loopback_sequence(16, 3);
    end
endtask  // test_multi16_byte 结束。

// 较长递增流：用于展示跨多轮 FIFO 搬运的数据顺序保持。
task test_stream64_byte;
    begin
        $display("\n[TEST] 长递增流回环：64 字节 00 至 3F");
        uart_driver_apply_reset();
        run_safe_loopback_sequence(64, 2);
    end
endtask  // test_stream64_byte 结束。

// 深度流回归：128 字节覆盖多个 FIFO 周期和字节值范围。
task test_stream128_byte;
    begin
        $display("\n[TEST] 深度递增流回环：128 字节 00 至 7F");
        uart_driver_apply_reset();
        run_safe_loopback_sequence(128, 2);
    end
endtask  // test_stream128_byte 结束。

// 模式流覆盖交替数据、walking bit 与逻辑角落值，检查串行位序和数据完整性。
task test_data_patterns;
    begin
        $display("\n[TEST] 数据模式回环：32 字节 alternating/walking/corner values");
        uart_driver_apply_reset();
        run_safe_loopback_sequence(32, 4);
    end
endtask  // test_data_patterns 结束。

// 直接驱动独立 fifo_boundary_model：连续写 8 次检查 full，再连续读 8 次检查 empty。
task test_rx_fifo_fill_level;
    integer idx;  // 写入/读取次数索引。
    begin
        $display("\n[TEST] FIFO 边界模型：直接检查 full/empty");
        fifo_boundary_model_reset = 1'b1;  // 先复位独立 FIFO。
        fifo_boundary_model_wr_en = 1'b0;  // 复位期间不写。
        fifo_boundary_model_rd_en = 1'b0;  // 复位期间不读。
        fifo_boundary_model_wdata = 8'h00; // 初始化写数据。
        repeat (3) @(posedge clk);         // 复位至少保持 3 个时钟。
        fifo_boundary_model_reset = 1'b0;  // 释放独立 FIFO 复位。
        repeat (2) @(posedge clk);         // 等待状态稳定。

        for (idx = 0; idx < 8; idx = idx + 1) begin
            fifo_boundary_model_wdata = idx[7:0];  // 依次准备 00 至 07。
            fifo_boundary_model_wr_en = 1'b1;      // 请求写入。
            @(posedge clk);                        // 每个上升沿完成一次写入。
        end
        fifo_boundary_model_wr_en = 1'b0;  // 停止写入。
        @(posedge clk);                    // 等一拍读取更新后的 full。

        if (fifo_boundary_model_full !== 1'b1) begin
            total_errors = total_errors + 1;  // 写满后未见 full，记为错误。
            $display("[FIFO][FAIL] full 预期=1 实际=%0b 时间=%0t", fifo_boundary_model_full, $time);
        end else begin
            $display("[FIFO][PASS] 连续写入 8 次后 full 正确拉高，时间=%0t", $time);
        end

        for (idx = 0; idx < 8; idx = idx + 1) begin
            fifo_boundary_model_rd_en = 1'b1;  // 请求读取。
            @(posedge clk);                    // 每个上升沿完成一次读指针推进。
        end
        fifo_boundary_model_rd_en = 1'b0;  // 停止读取。
        @(posedge clk);                    // 等一拍读取更新后的 empty。

        if (fifo_boundary_model_empty !== 1'b1) begin
            total_errors = total_errors + 1;  // 读空后未见 empty，记为错误。
            $display("[FIFO][FAIL] empty 预期=1 实际=%0b 时间=%0t", fifo_boundary_model_empty, $time);
        end else begin
            $display("[FIFO][PASS] 连续读取 8 次后 empty 正确拉高，时间=%0t", $time);
        end
    end
endtask  // test_rx_fifo_fill_level 结束。

// 恢复性场景：再次复位整个 DUT，再发送 A5，确认功能可恢复。
task test_reset_recovery;
    begin
        $display("\n[TEST] 复位恢复");
        uart_driver_apply_reset();         // 将 UART 状态机和两级 FIFO 复位。
        run_safe_loopback_sequence(1, 0);  // 复位释放后发送 A5，检查能否正确回环。
    end
endtask  // test_reset_recovery 结束。

// 复位后不只验证单字节，而是验证一段混合数据流仍能被完整恢复和保持顺序。
task test_reset_stream_recovery;
    begin
        $display("\n[TEST] 复位后混合流恢复：16 字节 corner-value 序列");
        uart_driver_apply_reset();
        run_safe_loopback_sequence(16, 3);
    end
endtask  // test_reset_stream_recovery 结束。

// 从命令行读取 +TEST=<名称>；未指定时默认运行 all 完整回归。
task run_selected_test;
    reg [8*16-1:0] selected_test;  // 最多容纳 16 个 ASCII 字符的测试名字符串。
    begin
        if (!$value$plusargs("TEST=%s", selected_test)) begin
            selected_test = "all";  // 未传 +TEST 时运行全部场景。
        end

        $display("[TEST] 选择场景=%0s", selected_test);
        if (selected_test == "single") begin
            test_single_byte();          // 单字节 A5 回环。
        end else if (selected_test == "multi") begin
            test_multi_byte();           // 11/22/33/44 顺序回环。
        end else if (selected_test == "stream") begin
            test_fifo_stream();          // 00 至 13 递增序列回环。
        end else if (selected_test == "multi16") begin
            test_multi16_byte();         // 16 字节混合值顺序回环。
        end else if (selected_test == "stream64") begin
            test_stream64_byte();        // 64 字节递增流。
        end else if (selected_test == "stream128") begin
            test_stream128_byte();       // 128 字节递增流。
        end else if (selected_test == "patterns") begin
            test_data_patterns();        // 32 字节模式流。
        end else if (selected_test == "fifo") begin
            test_rx_fifo_fill_level();   // 独立 FIFO 满空边界测试。
        end else if (selected_test == "reset") begin
            test_reset_recovery();       // 复位后恢复传输。
        end else if (selected_test == "reset_stream") begin
            test_reset_stream_recovery(); // 复位后 16 字节混合流恢复。
        end else if (selected_test == "all") begin
            test_single_byte();          // 共检查 1 个 UART 字节。
            test_multi_byte();           // 共检查 4 个 UART 字节。
            test_fifo_stream();          // 共检查 20 个 UART 字节。
            test_multi16_byte();         // 共检查 16 个 UART 字节。
            test_stream64_byte();        // 共检查 64 个 UART 字节。
            test_stream128_byte();       // 共检查 128 个 UART 字节。
            test_data_patterns();        // 共检查 32 个 UART 字节。
            test_rx_fifo_fill_level();   // 直接检查 FIFO 的满空边界。
            test_reset_recovery();       // 再检查 1 个 UART 字节。
            test_reset_stream_recovery(); // 再检查 16 个 UART 字节。
        end else begin
            total_errors = total_errors + 1;  // 未支持名称属于测试配置错误。
            $display("[TEST][FAIL] 不支持的 TEST=%0s", selected_test);
        end
    end
endtask  // run_selected_test 结束。

`endif  // TEST_CASE_VH
