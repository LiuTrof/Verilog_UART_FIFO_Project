// ============================================================================
// 文件作用：验证环境的 Scoreboard（自动判定器）。
// 功能：Driver 发送数据前调用 scoreboard_expect() 将预期字节入队；Monitor
// 解码 TX 后调用 scoreboard_check_actual() 取队首比对。它检查错数、意外输出、
// 队列溢出和仿真结束时仍未收到的预期字节。
// 注意：本文件由 tb_top_loop_test.v include，不是独立 module。
// ============================================================================
`ifndef SCOREBOARD_VH  // 防止同一文件被重复 include。
`define SCOREBOARD_VH  // 定义 include 保护宏。

integer total_checked;         // Monitor 已交给 Scoreboard 检查的实际字节总数。
integer total_errors;          // 全局错误总数，也会被顶层 FIFO 非法状态检查累加。
integer expected_count;        // 当前预期环形队列中尚未匹配的字节数。
integer expected_read_index;   // 下一次要取出的队首索引。
integer expected_write_index;  // 下一次要写入的队尾索引。
reg [7:0] expected_queue [0:255];  // 深度 256 的预期字节环形队列。

// 清空所有统计量与队列指针；每次仿真开始时调用一次。
task scoreboard_reset;
    begin
        total_checked         = 0;  // 尚未检查任何实际字节。
        total_errors          = 0;  // 清零错误计数。
        expected_count        = 0;  // 逻辑上清空预期队列。
        expected_read_index   = 0;  // 队首从数组下标 0 开始。
        expected_write_index  = 0;  // 队尾从数组下标 0 开始。
    end
endtask  // scoreboard_reset 结束。

// Driver 调用：记录一个即将被发送的预期字节。
task scoreboard_expect;
    input [7:0] expected;  // 期望最终从 tx 端观察到的字节。
    begin
        if (expected_count == 256) begin
            total_errors = total_errors + 1;  // 队列已满，记录错误而不覆盖原有预期数据。
            $display("[SCB][FAIL] 预期队列溢出 时间=%0t", $time);
        end else begin
            expected_queue[expected_write_index] = expected;  // 在队尾写入预期字节。
            expected_write_index = (expected_write_index + 1) % 256;  // 环形队列索引回绕。
            expected_count = expected_count + 1;  // 记录等待比对的字节增加一个。
            $display("[SCB] 预期数据=0x%02h 队列深度=%0d 时间=%0t",
                     expected, expected_count, $time);
        end
    end
endtask  // scoreboard_expect 结束。

// Monitor 调用：将一个实际接收字节与预期队首比较。
task scoreboard_check_actual;
    input [7:0] actual;  // Monitor 从 tx 串行帧中恢复的实际字节。
    reg [7:0] expected;  // 临时保存从预期队首取出的参考值。
    begin
        total_checked = total_checked + 1;  // 无论成功或失败，都记录一次实际观察。

        if (expected_count == 0) begin
            total_errors = total_errors + 1;  // 没有预期却出现输出，属于意外输出。
            $display("[SCB][FAIL] 意外实际数据=0x%02h 时间=%0t", actual, $time);
        end else begin
            expected = expected_queue[expected_read_index];  // 读取最早尚未匹配的预期数据。
            expected_read_index = (expected_read_index + 1) % 256;  // 队首索引环形前进。
            expected_count = expected_count - 1;  // 该预期数据无论匹配与否都已被消费。

            if (actual !== expected) begin  // 使用 !==，X/Z 也会被认为是不匹配。
                total_errors = total_errors + 1;  // 数据错、丢字节或乱序都会来到这里。
                $display("[SCB][FAIL] 序号=%0d 预期=0x%02h 实际=0x%02h 时间=%0t",
                         total_checked - 1, expected, actual, $time);
            end else begin
                $display("[SCB][PASS] 序号=%0d 数据=0x%02h 时间=%0t",
                         total_checked - 1, actual, $time);
            end
        end
    end
endtask  // scoreboard_check_actual 结束。

// 所有 testcase 执行完后调用：打印汇总，并将未收到的预期字节转化为错误。
task scoreboard_report;
    begin
        $display("====================");
        $display("UART FIFO SCOREBOARD 汇总");
        $display("已检查字节数 : %0d", total_checked);
        $display("未匹配预期数 : %0d", expected_count);
        $display("当前错误数   : %0d", total_errors);
        if (expected_count != 0) begin
            total_errors = total_errors + expected_count;  // 预期没收到，按每字节计一个错误。
            $display("[SCB][FAIL] 仍有 %0d 个预期字节未被观察到", expected_count);
        end
        if (total_errors == 0) begin
            $display("结果         : TEST PASS");
        end else begin
            $display("结果         : TEST FAIL");
        end
        $display("====================");
    end
endtask  // scoreboard_report 结束。

`endif  // SCOREBOARD_VH
