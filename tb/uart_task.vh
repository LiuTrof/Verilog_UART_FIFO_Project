// ============================================================================
// 文件作用：早期 task 版本的 UART 发送/接收辅助代码。
// 当前状态：tb_top_loop_test.v 没有 include 本文件；当前验证环境实际使用
// tb/driver/uart_driver.vh 与 tb/monitor/uart_monitor.vh。保留此文件仅供与旧版
// 单 task testbench 对照学习，不应与新 Driver/Monitor 同时接入。
// ============================================================================
`ifndef UART_TASK_VH  // 防止同一文件被重复 include。
`define UART_TASK_VH  // 定义 include 保护宏。

// 旧版：发送一个带额外帧间间隔的 UART 8N1 帧。
task send_uart_byte;
    input [7:0] data;  // 待发送字节。
    integer bit_idx;   // 数据位索引。
    begin
        rx <= 1'b1;           // 空闲高电平。
        #(BIT_PERIOD_NS);     // 保持一个比特时间。
        rx <= 1'b0;           // 起始位低电平。
        #(BIT_PERIOD_NS);     // 保持一个比特时间。

        for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
            rx <= data[bit_idx];  // 低位优先发送。
            #(BIT_PERIOD_NS);     // 每位持续一个比特时间。
        end

        rx <= 1'b1;          // 停止位。
        #(BIT_PERIOD_NS);    // 保持停止位。
        #(FRAME_GAP_NS);     // 帧间额外间隔。
    end
endtask  // send_uart_byte 结束。

// 旧版：发送一个不额外等待 FRAME_GAP_NS 的 UART 帧。
task send_uart_byte_no_gap;
    input [7:0] data;  // 待发送字节。
    integer bit_idx;   // 数据位索引。
    begin
        rx <= 1'b1;           // 空闲高电平。
        #(BIT_PERIOD_NS);     // 保持一个比特时间。
        rx <= 1'b0;           // 起始位低电平。
        #(BIT_PERIOD_NS);     // 保持一个比特时间。

        for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
            rx <= data[bit_idx];  // 低位优先发送。
            #(BIT_PERIOD_NS);     // 每位持续一个比特时间。
        end

        rx <= 1'b1;          // 停止位。
        #(BIT_PERIOD_NS);    // 保持停止位，无额外保护间隔。
    end
endtask  // send_uart_byte_no_gap 结束。

// 旧版：从 tx 的起始位开始，按位中心采样并返回一个字节；不调用 Scoreboard。
task receive_uart_byte;
    output [7:0] data;  // 解码后的数据。
    integer bit_idx;    // 数据位索引。
    begin
        data = 8'h00;  // 清空临时数据。
        @(negedge tx); // 等待起始位开始。
        #(BIT_PERIOD_NS + HALF_BIT_PERIOD_NS);  // 跳到 D0 中心。

        for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
            data[bit_idx] = tx;  // 低位优先保存采样值。
            #(BIT_PERIOD_NS);    // 移动到下一位中心。
        end

        #(BIT_PERIOD_NS);  // 跨过停止位。
    end
endtask  // receive_uart_byte 结束。

// 旧版：对 DUT 施加统一复位。
task apply_reset;
    begin
        rx = 1'b1;                   // UART 空闲电平。
        reset = 1'b1;                // 拉高复位。
        repeat (20) @(posedge clk);  // 保持 20 拍。
        reset = 1'b0;                // 释放复位。
        repeat (20) @(posedge clk);  // 等待稳定。
    end
endtask  // apply_reset 结束。

`endif  // UART_TASK_VH
