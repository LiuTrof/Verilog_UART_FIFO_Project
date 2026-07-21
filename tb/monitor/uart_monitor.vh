// ============================================================================
// 文件作用：验证环境的 UART Monitor。
// 功能：从 tb 顶层 tx 的下降沿识别起始位，按 UART 8N1 时序在每个数据位中心
// 采样，重建实际字节后交给 Scoreboard 自动比较。
// 注意：本文件由 tb_top_loop_test.v include，不是独立 module。
// ============================================================================
`ifndef UART_MONITOR_VH  // 防止同一文件被重复 include。
`define UART_MONITOR_VH  // 定义 include 保护宏。

// 阻塞等待并接收一个 UART 8N1 帧；task 返回时 data 为解码后的实际字节。
task uart_monitor_receive_byte;
    output [7:0] data;     // 输出参数，保存本帧还原出的实际字节。
    integer bit_idx;        // for 循环索引，对应数据位编号 0 至 7。
    begin
        data = 8'h00;  // 清空临时变量，避免上一帧残留影响当前采样。
        @(negedge tx); // 等待 tx 从高变低：UART 起始位的开始。
        #(BIT_PERIOD_NS + HALF_BIT_PERIOD_NS);
        // 从起始沿向后等待 1.5 位：此刻正好落在 D0 的中心，最适合采样。

        for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
            data[bit_idx] = tx;      // 按低位优先的 UART 顺序保存 D0 至 D7。
            #(BIT_PERIOD_NS);        // 移动到下一个数据位中心再采样。
        end

        #(BIT_PERIOD_NS);  // 跨过停止位，确保当前帧已完整结束。
        monitor_data = data;  // 保存到波形观察信号，不参与 DUT 功能。
        $display("[MON] 接收数据=0x%02h 时间=%0t", data, $time);
        scoreboard_check_actual(data);  // 将实际字节交给 Scoreboard 做自动比对。
    end
endtask  // uart_monitor_receive_byte 结束。

`endif  // UART_MONITOR_VH
