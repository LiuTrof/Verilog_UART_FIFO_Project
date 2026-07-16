// ============================================================================
// 文件作用：当前自检验证环境的顶层入口。
// 功能：产生时钟、实例化 DUT 与独立 FIFO 边界模型、包含 Driver/Monitor/
// Scoreboard/Testcase，并在仿真结束时汇总 PASS/FAIL。
// 编译入口：run.sh 会首先编译本文件。
// ============================================================================
`timescale 1ns / 1ps  // 仿真时间单位为 1 ns，时间精度为 1 ps。

module tb_top_loop_test;

    localparam integer CLK_PERIOD_NS      = 10;                   // 100 MHz 时钟周期：10 ns。
    localparam integer BIT_PERIOD_NS      = 104_160;              // 9600 波特率下一个 UART 比特约 104.16 us。
    localparam integer HALF_BIT_PERIOD_NS = BIT_PERIOD_NS / 2;    // 用于 Monitor 在数据位中间采样。
    localparam integer FRAME_GAP_NS       = BIT_PERIOD_NS * 6;    // Driver 在帧之间保留的额外保护间隔。

    reg  clk   = 1'b0;  // Testbench 产生的设计时钟。
    reg  reset = 1'b1;  // DUT 高有效复位，仿真开始时先保持复位。
    reg  rx    = 1'b1;  // UART 空闲线为高，由 Driver 后续驱动。
    wire tx;            // DUT 串行输出，由 Monitor 后续采样。

    reg [7:0] driver_data  = 8'h00;  // 仅供波形观察：Driver 当前准备发送的并行字节。
    reg [7:0] monitor_data = 8'h00;  // 仅供波形观察：Monitor 刚刚还原出的并行字节。

    // 以下信号属于独立 FIFO 边界模型，不是 DUT 内部 FIFO 的外部接口。
    // 它用于直接验证 fifo.v 的 8 写满、8 读空行为。
    reg       fifo_boundary_model_reset = 1'b1;   // 边界模型独立复位。
    reg       fifo_boundary_model_wr_en = 1'b0;   // 边界模型写请求。
    reg       fifo_boundary_model_rd_en = 1'b0;   // 边界模型读请求。
    reg [7:0] fifo_boundary_model_wdata = 8'h00;  // 边界模型写入数据。
    wire      fifo_boundary_model_full;           // 边界模型满标志。
    wire      fifo_boundary_model_empty;          // 边界模型空标志。
    wire [7:0] fifo_boundary_model_rdata;         // 边界模型读出数据。

    // 实例化待测设计：UART RX -> RX FIFO -> loopback -> TX FIFO -> UART TX。
    top_loop_test dut (
        .clk  (clk),    // 提供时钟。
        .reset(reset),  // 提供复位。
        .rx   (rx),     // Driver 产生的串行输入。
        .tx   (tx)      // Monitor 观察的串行输出。
    );

    // 额外实例化一个独立 FIFO，用于边界测试；避免通过 UART 慢速链路灌满 FIFO。
    fifo #(
        .ADDR_WIDTH(3),  // 3 位地址，对应 8 深度。
        .DATA_WIDTH(8)   // 每项为 8 位。
    ) fifo_boundary_model (
        .clk  (clk),                       // 与 DUT 使用同一仿真时钟。
        .reset(fifo_boundary_model_reset), // 独立控制其复位。
        .wr_en(fifo_boundary_model_wr_en), // 直接驱动写请求。
        .full (fifo_boundary_model_full),  // 观察写满状态。
        .wdata(fifo_boundary_model_wdata), // 直接提供写数据。
        .rd_en(fifo_boundary_model_rd_en), // 直接驱动读请求。
        .empty(fifo_boundary_model_empty), // 观察读空状态。
        .rdata(fifo_boundary_model_rdata)  // 保留读数据供波形调试。
    );

    // 每隔半个周期翻转一次，因此完整时钟周期为 CLK_PERIOD_NS=10 ns。
    always #(CLK_PERIOD_NS / 2) clk = ~clk;

    // `include 相当于把这些文件内容直接插入本 module 内；这些 task 可直接访问 rx、tx、
    // BIT_PERIOD_NS 和 total_errors 等顶层变量。
    `include "scoreboard.vh"
    `include "driver/uart_driver.vh"
    `include "monitor/uart_monitor.vh"
    `include "test_case.vh"

    // 简单的过程检查：任意 FIFO 同时 full=1 与 empty=1 都是非法状态。
    // 这不是 SystemVerilog assertion 语法，而是 Verilog 过程式检查。
    always @(posedge clk) begin
        if (!reset) begin  // 复位期不检查，避免状态刚初始化时造成干扰。
            if (dut.U_UART_FIFO.U_Rx_Fifo.full && dut.U_UART_FIFO.U_Rx_Fifo.empty) begin
                $error("RX FIFO 非法状态：full 与 empty 同时为高，时间=%0t", $time);
                total_errors = total_errors + 1;  // 与 Scoreboard 共用错误计数器。
            end

            if (dut.U_UART_FIFO.U_Tx_Fifo.full && dut.U_UART_FIFO.U_Tx_Fifo.empty) begin
                $error("TX FIFO 非法状态：full 与 empty 同时为高，时间=%0t", $time);
                total_errors = total_errors + 1;
            end

            if (fifo_boundary_model_full && fifo_boundary_model_empty) begin
                $error("FIFO 边界模型非法状态：full 与 empty 同时为高，时间=%0t", $time);
                total_errors = total_errors + 1;
            end
        end
    end

    // 主仿真流程：可选 VCD -> 初始化 Scoreboard -> 复位 -> 运行指定场景 -> 汇总结果 -> 退出。
    initial begin
        reg [8*256-1:0] vcd_file;  // 保存 +VCD=<文件名> 传入的 VCD 路径字符串。
        if ($value$plusargs("VCD=%s", vcd_file)) begin
            $dumpfile(vcd_file);  // 指定 VCD 输出文件。
            $dumpvars(0, clk, reset, rx, tx);  // 导出顶层时钟、复位和串行线。
            $dumpvars(0, driver_data, monitor_data);  // 导出验证层两侧的并行字节。
            $dumpvars(0, dut.U_UART_FIFO.w_rx_done, dut.U_UART_FIFO.w_tx_done,
                      dut.U_UART_FIFO.rx_data, dut.U_UART_FIFO.rx_empty,
                      dut.U_UART_FIFO.U_Rx_Fifo.full, dut.U_UART_FIFO.U_Rx_Fifo.empty,
                      dut.U_UART_FIFO.U_Tx_Fifo.full, dut.U_UART_FIFO.U_Tx_Fifo.empty);
            // 导出 DUT 内部关键完成脉冲、FIFO 状态，便于定位数据没有回环的具体阶段。
            $dumpvars(0, fifo_boundary_model_reset, fifo_boundary_model_wr_en,
                      fifo_boundary_model_rd_en, fifo_boundary_model_wdata,
                      fifo_boundary_model_full, fifo_boundary_model_empty,
                      fifo_boundary_model_rdata);  // 导出独立 FIFO 边界测试信号。
        end

        scoreboard_reset();        // 清空预期队列及所有统计量。
        uart_driver_apply_reset(); // 先让 DUT 和 UART 回到已知初始状态。
        run_selected_test();       // 根据 +TEST 参数运行 single/multi/stream/fifo/reset/all。

        scoreboard_report();  // 检查队列残留并打印最终 PASS/FAIL。

        #(5 * BIT_PERIOD_NS);  // 留出少量时间，便于波形中观察结束位置。
        if (total_errors == 0) begin
            $finish;                // 零错误：以成功状态结束仿真。
        end else begin
            $finish_and_return(1);  // 有错误：返回非零状态给 run.sh。
        end
    end

endmodule  // tb_top_loop_test 顶层结束。
