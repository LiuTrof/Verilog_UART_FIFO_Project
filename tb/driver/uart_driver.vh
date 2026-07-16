// ============================================================================
// 文件作用：验证环境的 UART Driver。
// 功能：将并行字节转换为 UART 8N1 串行激励并驱动 tb 顶层 rx；发送前将
// 该字节放入 Scoreboard 的 expected_queue，同时提供统一的复位 task。
// 注意：本文件由 tb_top_loop_test.v include，不是独立 module。
// ============================================================================
`ifndef UART_DRIVER_VH  // 防止同一文件被重复 include。
`define UART_DRIVER_VH  // 定义 include 保护宏。

// 发送一个完整 UART 8N1 帧：空闲高 -> 起始低 -> D0 到 D7（低位先）-> 停止高。
task uart_driver_send_byte;
    input [7:0] data;      // Driver 要发送的并行字节。
    integer bit_idx;       // for 循环索引，对应数据位编号 0 至 7。
    begin
        scoreboard_expect(data);  // 先记录预期值，后续 Monitor 收到时才能按顺序比对。
        driver_data = data;       // 保存到波形观察信号，不参与 DUT 功能。
        $display("[DRV] 发送数据=0x%02h 时间=%0t", data, $time);

        rx <= 1'b1;              // 先保持一个比特时间的空闲高电平。
        #(BIT_PERIOD_NS);        // 等待一个比特周期。
        rx <= 1'b0;              // 拉低，形成 UART 起始位。
        #(BIT_PERIOD_NS);        // 起始位保持一个比特周期。

        for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
            rx <= data[bit_idx];  // UART 规定低位先发送，因此顺序为 data[0] 到 data[7]。
            #(BIT_PERIOD_NS);     // 每一位保持一个完整比特周期。
        end

        rx <= 1'b1;         // 拉高，形成停止位。
        #(BIT_PERIOD_NS);    // 停止位保持一个完整比特周期。
        #(FRAME_GAP_NS);     // 额外保护间隔，让当前 RTL 回环链路稳定处理此帧。
    end
endtask  // uart_driver_send_byte 结束。

// 对 DUT 施加复位：保持 rx 空闲为高，复位 20 个 clk，然后释放后再等 20 个 clk。
task uart_driver_apply_reset;
    begin
        $display("[DRV] 施加复位 时间=%0t", $time);
        rx = 1'b1;                   // UART 在复位及空闲时保持高电平。
        reset = 1'b1;                // 拉高高有效复位。
        repeat (20) @(posedge clk);  // 至少保持 20 个系统时钟。
        reset = 1'b0;                // 释放复位。
        repeat (20) @(posedge clk);  // 等待各状态机进入稳定空闲状态。
    end
endtask  // uart_driver_apply_reset 结束。

`endif  // UART_DRIVER_VH
