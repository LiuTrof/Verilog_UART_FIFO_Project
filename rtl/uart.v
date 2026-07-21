// ============================================================================
// 文件作用：UART 收发器 RTL。
// 当前生效代码位于本文件下半部分的 uart 模块开始处，包含：uart、baudrate_generator、
// transmitter 和 receiver 四个模块。文件前半段是历史实现，全部以 // 注释
// 掉，不会参与当前编译；阅读时请直接找到下半部分的 "module uart ("。
//
// UART 格式：8N1，即 1 个起始位、8 个数据位、无校验位、1 个停止位；数据低位先发。
// 时钟假设：100 MHz；波特率：9600；每位 16 倍采样。
// ============================================================================

// `timescale 1ns / 1ps

// module uart (
//     input       clk,
//     input       reset,
//     input       tx_start,
//     input [7:0] tx_data,
//     input       rx,

//     output       tx,
//     output       tx_done,
//     output [7:0] rx_data,
//     output       rx_done
// );

//     wire w_br_tick;
//     wire w_tx;
//     // wire w_br_tick_test;


//     baudrate_generator #(
//         .HERZ(9600)
//         //.HERZ(10_000_000 / 16)
//     ) U_BR_Gen (
//         .clk  (clk),
//         .reset(reset),

//         .br_tick(w_br_tick)
//     );

//     // baudrate_generator_test #(
//     //     // .HERZ(9600)
//     //     .HERZ(10_000_000 / 16)
//     // ) U_BR_Gen_test (
//     //     .clk  (clk),
//     //     .reset(reset),

//     //     .br_tick(w_br_tick_test)
//     // );

//     transmitter U_TxD (
//         .clk(clk),
//         .reset(reset),
//         .start(tx_start),
//         .br_tick(w_br_tick),
//         .tx_data(tx_data),

//         .tx(tx),
//         .tx_done(tx_done)
//     );


//     receiver U_RxD (
//         .clk(clk),
//         .reset(reset),
//         .br_tick(w_br_tick),
//         .rx(rx),

//         .rx_data(rx_data),
//         .rx_done(rx_done)
//     );

// endmodule


// module baudrate_generator #(
//     parameter HERZ = 9600
// ) (
//     input clk,
//     input reset,

//     output br_tick
// );

//     // reg [$clog2(100_000_000/9600)-1:0] counter_reg, counter_next;
//     reg [$clog2(100_000_000/HERZ/16)-1:0] counter_reg, counter_next;
//     reg tick_reg, tick_next;

//     assign br_tick = tick_reg;

//     always @(posedge clk, posedge reset) begin
//         if (reset) begin
//             counter_reg <= 0;
//             tick_reg <= 1'b0;
//         end else begin
//             counter_reg <= counter_next;
//             tick_reg <= tick_next;
//         end
//     end

//     always @(*) begin
//         counter_next = counter_reg;
//         if (counter_reg == 100_000_000 / HERZ / 16 - 1) begin
//             // if (counter_reg == 3) begin     // simulation
//             counter_next = 0;
//             tick_next = 1'b1;
//         end else begin
//             counter_next = counter_reg + 1;
//             tick_next = 1'b0;
//         end
//     end
// endmodule

// // module baudrate_generator_test #(
// //     parameter HERZ = 9600
// // ) (
// //     input clk,
// //     input reset,

// //     output br_tick
// // );

// //     // reg [$clog2(100_000_000/9600)-1:0] counter_reg, counter_next;
// //     reg [$clog2(100_000_000/HERZ/16)-1:0] counter_reg, counter_next;
// //     reg tick_reg, tick_next;
// //     reg [3:0] clk_cnt = 0;
// //     reg clk_cnt_reg;

// //     assign br_tick = tick_reg;

// //     always @(posedge clk, posedge reset) begin
// //         if (reset) begin
// //             counter_reg <= 0;
// //             tick_reg <= 1'b0;
// //             clk_cnt = 0;
// //             clk_cnt_reg = 0;
// //         end else begin
// //             counter_reg <= counter_next;
// //             tick_reg <= tick_next;
// //             clk_cnt = clk_cnt + 1;
// //             if(clk_cnt == 5) clk_cnt_reg = 1;
// //         end
// //     end

// //     always @(*) begin
// //         counter_next = counter_reg;
// //         tick_next = tick_reg;

// //         if (clk_cnt_reg) begin
// //             if (counter_reg == 100_000_000 / HERZ / 16 - 1) begin
// //                 // if (counter_reg == 3) begin     // simulation
// //                 counter_next = 0;
// //                 tick_next = 1'b1;
// //             end else begin
// //                 counter_next = counter_reg + 1;
// //                 tick_next = 1'b0;
// //             end
// //         end
// //     end
// // endmodule


// module transmitter (
//     input clk,
//     input reset,
//     input br_tick,
//     input start,
//     input [7:0] tx_data,

//     output tx,
//     output tx_done
// );

//     localparam IDLE = 0, START = 1, DATA = 2, STOP = 3;

//     reg [1:0] state, state_next;
//     reg tx_done_reg, tx_done_next;
//     reg tx_reg, tx_next;
//     reg [7:0] data_tmp_reg, data_tmp_next;
//     reg [3:0]
//         br_cnt_reg, br_cnt_next;  // 波特率 16 倍采样计数器。
//     reg [2:0]
//         data_bit_cnt_reg,
//         data_bit_cnt_next;  // 8 位数据计数器。


//     assign tx = tx_reg;
//     assign tx_done = tx_done_reg;


//     always @(posedge clk, posedge reset) begin
//         if (reset) begin
//             state            <= IDLE;
//             tx_reg           <= 1'b1;
//             tx_done_reg      <= 1'b0;
//             br_cnt_reg       <= 0;
//             data_bit_cnt_reg <= 0;
//             data_tmp_reg     <= 0;
//         end else begin
//             state            <= state_next;
//             tx_reg           <= tx_next;
//             tx_done_reg      <= tx_done_next;
//             br_cnt_reg       <= br_cnt_next;
//             data_bit_cnt_reg <= data_bit_cnt_next;
//             data_tmp_reg     <= data_tmp_next;
//         end
//     end


//     always @(*) begin
//         state_next        = state;
//         tx_next           = tx_reg;
//         tx_done_next      = tx_done_reg;
//         br_cnt_next       = br_cnt_reg;
//         data_bit_cnt_next = data_bit_cnt_reg;
//         data_tmp_next     = data_tmp_reg;

//         case (state)
//             IDLE: begin
//                 tx_done_next = 1'b0;
//                 tx_next = 1'b1;
//                 if (start) begin
//                     state_next        = START;
//                     data_tmp_next     = tx_data;
//                     br_cnt_next       = 0;
//                     data_bit_cnt_next = 0;
//                 end
//             end

//             START: begin
//                 tx_next = 1'b0;
//                 if (br_tick) begin
//                     if (br_cnt_reg == 15) begin
//                         state_next  = DATA;
//                         br_cnt_next = 0;
//                     end else begin
//                         br_cnt_next = br_cnt_reg + 1;
//                     end
//                 end
//             end

//             DATA: begin
//                 tx_next = data_tmp_reg[0];
//                 if (br_tick) begin
//                     if (br_cnt_reg == 15) begin
//                         if (data_bit_cnt_reg == 7) begin
//                             state_next  = STOP;
//                             br_cnt_next = 0;
//                         end else begin
//                             data_bit_cnt_next = data_bit_cnt_reg + 1;
//                             data_tmp_next     = {1'b0, data_tmp_reg[7:1]};
//                             br_cnt_next       = 0;
//                         end
//                     end else begin
//                         br_cnt_next = br_cnt_reg + 1;
//                     end
//                 end
//             end

//             STOP: begin
//                 tx_next = 1'b1;
//                 if (br_tick) begin
//                     if (br_cnt_reg == 15) begin
//                         tx_done_next = 1'b1;
//                         state_next   = IDLE;
//                     end else begin
//                         br_cnt_next = br_cnt_reg + 1;
//                     end
//                 end
//             end
//         endcase
//     end

// endmodule


// module receiver (
//     input clk,
//     input reset,
//     input br_tick,
//     input rx,

//     output [7:0] rx_data,
//     output rx_done
// );

//     localparam IDLE = 0, START = 1, DATA = 2, STOP = 3;

//     reg [1:0] state, state_next;
//     reg [7:0] rx_data_reg, rx_data_next;
//     reg rx_done_reg, rx_done_next;
//     reg [4:0]
//         br_cnt_reg,
//         br_cnt_next;  // 波特率 16 倍采样计数器（0 至 15）。
//     reg [2:0]
//         data_bit_cnt_reg,
//         data_bit_cnt_next;  // 8 位数据计数器（0 至 7）。


//     assign rx_data = rx_data_reg;
//     assign rx_done = rx_done_reg;


//     always @(posedge clk, posedge reset) begin
//         if (reset) begin
//             state            <= IDLE;
//             rx_data_reg      <= 0;
//             rx_done_reg      <= 1'b0;
//             br_cnt_reg       <= 0;
//             data_bit_cnt_reg <= 0;
//         end else begin
//             state            <= state_next;
//             rx_data_reg      <= rx_data_next;
//             rx_done_reg      <= rx_done_next;
//             br_cnt_reg       <= br_cnt_next;
//             data_bit_cnt_reg <= data_bit_cnt_next;
//         end
//     end


//     always @(*) begin
//         state_next = state;
//         br_cnt_next = br_cnt_reg;
//         data_bit_cnt_next = data_bit_cnt_reg;
//         rx_data_next = rx_data_reg;
//         rx_done_next = rx_done_reg;

//         case (state)
//             IDLE: begin
//                 rx_done_next = 1'b0;
//                 if (rx == 1'b0) begin
//                     br_cnt_next       = 0;
//                     data_bit_cnt_next = 0;
//                     rx_data_next      = 0;
//                     state_next        = START;
//                 end
//             end

//             START: begin
//                 if (br_tick) begin
//                     if (br_cnt_reg == 7) begin
//                         br_cnt_next = 0;
//                         state_next  = DATA;
//                     end else begin
//                         br_cnt_next = br_cnt_reg + 1;
//                     end
//                 end
//             end

//             DATA: begin
//                 if (br_tick) begin
//                     if (br_cnt_reg == 15) begin
//                         br_cnt_next  = 0;
//                         rx_data_next = {rx, rx_data_reg[7:1]};  // right shift
//                         if (data_bit_cnt_reg == 7) begin
//                             state_next  = STOP;
//                             br_cnt_next = 0;
//                         end else begin
//                             data_bit_cnt_next = data_bit_cnt_reg + 1;
//                         end
//                     end else begin
//                         br_cnt_next = br_cnt_next + 1;
//                     end
//                 end
//             end

//             STOP: begin
//                 if (br_tick) begin
//                     if (br_cnt_reg == 23) begin
//                         br_cnt_next  = 0;
//                         state_next   = IDLE;
//                         rx_done_next = 1'b1;
//                     end else begin
//                         br_cnt_next = br_cnt_reg + 1;
//                     end
//                 end
//             end
//         endcase
//     end

// endmodule


`timescale 1ns / 1ps  // 仿真时间单位为 1 ns，时间精度为 1 ps。

// UART 顶层：实例化波特率发生器、发送器和接收器。
module uart #(
    parameter integer CLK_HZ = 100_000_000,  // 系统时钟频率，默认对应综合目标。
    parameter integer BAUD   = 9_600         // UART 目标波特率。
) (
    input        clk,      // 100 MHz 系统时钟。
    input        reset,    // 高有效异步复位。
    //Transmitter 
    input        start,    // 为 1 时请求发送器开始发送 tx_data。
    input  [7:0] tx_data,  // 待发送的并行字节。
    output       tx,       // UART 串行发送输出。
    output       tx_done,  // 一帧发送完成后拉高一个时钟周期。
    //Receiver 
    input        rx,       // UART 串行接收输入。
    output [7:0] rx_data,  // 接收器还原出的并行字节。
    output       rx_done   // 一帧接收完成后拉高一个时钟周期。
);

    wire w_br_tick;  // 16 倍波特率节拍，发送器和接收器共用。

    // 将系统时钟分频为 BAUD * 16 Hz 的节拍。
    baudrate_generator #(
        .CLK_HZ(CLK_HZ),
        .BAUD  (BAUD)
    ) U_BAUDRATE_GEN (
        .clk    (clk),       // 输入系统时钟。
        .reset  (reset),     // 复位分频计数器。
        .br_tick(w_br_tick)  // 输出单周期节拍脉冲。
    );

    // 发送器按 UART 8N1 格式将 tx_data 串行化为 tx。
    transmitter U_Transmitter (
        .clk    (clk),       // 系统时钟。
        .reset  (reset),     // 复位发送状态机。
        .br_tick(w_br_tick), // 每 1/16 比特时间推进一次计数。
        .start  (start),     // 请求开始一帧发送。
        .tx_data(tx_data),   // 本帧待发送字节。
        .tx     (tx),        // 串行输出。
        .tx_done(tx_done)    // 停止位完成时输出完成脉冲。
    );

    // 接收器检测 rx 的起始位，按位中心采样并恢复 rx_data。
    receiver U_Receiver (
        .clk    (clk),       // 系统时钟。
        .reset  (reset),     // 复位接收状态机和两级同步器。
        .br_tick(w_br_tick), // 16 倍采样节拍。
        .rx     (rx),        // 外部异步串行输入。
        .rx_data(rx_data),   // 恢复出的并行字节。
        .rx_done(rx_done)    // 停止位结束后输出完成脉冲。
    );

endmodule  // uart 顶层模块结束。


// 波特率发生器：把 100 MHz 系统时钟分频为 UART 的 16 倍采样节拍。
module baudrate_generator #(
    parameter integer CLK_HZ = 100_000_000,
    parameter integer BAUD   = 9_600
) (
    input  clk,      // 100 MHz 系统时钟。
    input  reset,    // 高有效异步复位。
    output br_tick   // 每 CLOCKS_PER_TICK 个系统时钟拉高一次的单周期脉冲。
);

    // 每个 16 倍采样节拍需要的系统时钟数。综合默认值为 651。
    localparam integer CLOCKS_PER_TICK = CLK_HZ / BAUD / 16;
    reg [$clog2(CLOCKS_PER_TICK) - 1:0] counter_reg, counter_next;
    reg tick_reg, tick_next;  // 将组合判断结果寄存后作为稳定的单周期节拍。

    assign br_tick = tick_reg;  // 对外导出当前寄存的节拍脉冲。

    // 时序部分：在时钟沿保存下一拍计数值与节拍值。
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            counter_reg <= 0;      // 复位时从 0 重新计数。
            tick_reg    <= 1'b0;   // 复位期间不产生波特率节拍。
        end else begin
            counter_reg <= counter_next;  // 更新分频计数器。
            tick_reg    <= tick_next;     // 更新节拍输出。
        end
    end

    // 组合部分：达到分频终值时清零并产生一个节拍，否则继续计数。
    always @(*) begin
        counter_next = counter_reg;  // 默认保持，避免综合出锁存器。
        tick_next    = 1'b0;         // 默认不产生节拍，保证节拍宽度只有一个 clk。
        if (counter_reg == CLOCKS_PER_TICK - 1) begin
            counter_next = 0;        // 计满后从头开始下一轮分频。
            tick_next    = 1'b1;     // 本轮结束，输出一个采样节拍。
        end else begin
            counter_next = counter_reg + 1;  // 尚未计满，继续计数。
        end
    end

endmodule  // baudrate_generator 模块结束。


// UART 发送器：用 IDLE/START/DATA/STOP 四态状态机按 8N1 格式发送一个字节。
module transmitter (
    input       clk,      // 系统时钟。
    input       reset,    // 高有效异步复位。
    input       br_tick,  // 16 倍波特率节拍。
    input       start,    // IDLE 状态收到该信号后锁存 tx_data 并开始发送。
    input [7:0] tx_data,  // 待发送的 8 位并行字节。
    output      tx,       // 串行输出：空闲和停止位为 1，起始位为 0。
    output      tx_done   // 一帧停止位结束后产生的单周期完成脉冲。
);

    localparam IDLE = 0, START = 1, DATA = 2, STOP = 3;  // 四个 UART 帧阶段。
    reg [1:0] state, state_next;                          // 当前与下一拍状态。
    reg       tx_reg, tx_next;                            // 当前与下一拍串行输出。
    reg       tx_done_reg, tx_done_next;                  // 当前与下一拍发送完成标志。
    reg [7:0] data_tmp_reg, data_tmp_next;                // 锁存待发送字节并在发送时右移。
    reg [3:0] br_cnt_reg, br_cnt_next;                    // 一个比特内的 16 倍采样计数器（0 至 15）。
    reg [2:0] data_bit_cnt_reg, data_bit_cnt_next;        // 已发送的数据位计数器（0 至 7）。

    assign tx      = tx_reg;       // 向顶层导出寄存后的串行位。
    assign tx_done = tx_done_reg;  // 向 FIFO 控制导出帧发送完成脉冲。

    // 时序部分：复位时回到空闲线高；否则在每个时钟沿保存 next 状态。
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            state            <= IDLE;  // 空闲状态。
            tx_reg           <= 1'b1;  // UART 空闲线必须保持高电平。
            tx_done_reg      <= 1'b0;  // 复位时没有完成事件。
            br_cnt_reg       <= 0;     // 清除每位计数。
            data_bit_cnt_reg <= 0;     // 清除数据位计数。
            data_tmp_reg     <= 0;     // 清除发送移位寄存器。
        end else begin
            state            <= state_next;            // 更新发送状态。
            tx_reg           <= tx_next;               // 更新串行输出。
            tx_done_reg      <= tx_done_next;          // 更新完成脉冲。
            br_cnt_reg       <= br_cnt_next;           // 更新每位计数。
            data_bit_cnt_reg <= data_bit_cnt_next;     // 更新数据位编号。
            data_tmp_reg     <= data_tmp_next;         // 更新移位寄存器内容。
        end
    end

    // 组合部分：根据当前状态和节拍计算下一拍应输出什么。
    always @(*) begin
        state_next        = state;             // 默认保持状态，避免推导锁存器。
        data_tmp_next     = data_tmp_reg;      // 默认保持待发数据。
        tx_next           = tx_reg;            // 默认保持输出电平。
        br_cnt_next       = br_cnt_reg;        // 默认保持节拍计数。
        data_bit_cnt_next = data_bit_cnt_reg;  // 默认保持数据位计数。
        tx_done_next      = tx_done_reg;       // 默认保持完成标志。

        case (state)
            IDLE: begin
                tx_done_next = 1'b0;  // 新帧开始前清除上一帧的完成脉冲。
                tx_next      = 1'b1;  // UART 空闲线输出高电平。

                if (start) begin
                    state_next        = START;    // 看到发送请求后进入起始位状态。
                    data_tmp_next     = tx_data;  // 锁存本帧字节，防止外部数据变化影响发送。
                    br_cnt_next       = 0;        // 从起始位第 0 个采样节拍开始计数。
                    data_bit_cnt_next = 0;        // 下一阶段先发送 D0。
                end
            end
            START: begin
                tx_next = 1'b0;  // 起始位固定为低电平。

                if (br_tick) begin
                    if (br_cnt_reg == 15) begin
                        state_next  = DATA;  // 起始位已保持 16 个节拍，进入数据位阶段。
                        br_cnt_next = 0;     // 为 D0 的 16 节拍重新计数。
                    end else begin
                        br_cnt_next = br_cnt_reg + 1;  // 起始位尚未结束，继续计数。
                    end
                end
            end
            DATA: begin
                tx_next = data_tmp_reg[0];  // 始终先输出最低位，实现 LSB first。

                if (br_tick) begin
                    if (br_cnt_reg == 15) begin
                        if (data_bit_cnt_reg == 7) begin
                            state_next  = STOP;  // D7 已保持完整一个比特时间，进入停止位。
                            br_cnt_next = 0;     // 停止位从第 0 个节拍开始计数。
                        end else begin
                            data_bit_cnt_next = data_bit_cnt_reg + 1;  // 下一个数据位编号。
                            data_tmp_next = {
                                1'b0, data_tmp_reg[7:1]  // 右移后原 D1 移到 bit[0]，等待下次发送。
                            };
                            br_cnt_next = 0;  // 新数据位重新开始 16 节拍计数。
                        end
                    end else begin
                        br_cnt_next = br_cnt_reg + 1;  // 当前数据位尚未发送满一个比特时间。
                    end
                end
            end
            STOP: begin
                tx_next = 1'b1;  // 停止位与空闲线均为高电平。
                if (br_tick) begin
                    if (br_cnt_reg == 15) begin
                        tx_done_next = 1'b1;  // 停止位完成，通知外部一帧已发送完毕。
                        state_next   = IDLE;  // 返回空闲，等待下一帧。
                    end else begin
                        br_cnt_next = br_cnt_reg + 1;  // 停止位尚未保持完整一个比特时间。
                    end
                end
            end
        endcase
    end
endmodule  // transmitter 模块结束。


// UART 接收器：检测起始位，在每个数据位中心附近采样，并使用右移方式重建字节。
module receiver (
    input       clk,      // 系统时钟。
    input       reset,    // 高有效异步复位。
    input       br_tick,  // 16 倍波特率节拍。
    input       rx,       // 外部 UART 串行输入，可能相对 clk 异步。
    output [7:0] rx_data, // 已重建的接收字节。
    output      rx_done   // 停止位结束后产生的单周期完成脉冲。
);

    localparam IDLE = 0, START = 1, DATA = 2, STOP = 3;  // 接收的四个帧阶段。

    reg [1:0] state, state_next;                          // 当前与下一拍接收状态。
    reg [7:0] rx_data_reg, rx_data_next;                  // 当前与下一拍的接收数据移位寄存器。
    reg       rx_done_reg, rx_done_next;                  // 当前与下一拍的接收完成标志。
    reg [3:0] br_cnt_reg, br_cnt_next;                    // 一个比特内的 16 倍采样计数器。
    reg [2:0] data_bit_cnt_reg, data_bit_cnt_next;        // 已采样数据位计数器。
    reg       rx_sync1_reg, rx_sync1_next;                // 异步 rx 的第一级同步寄存器。
    reg       rx_sync2_reg, rx_sync2_next;                // 异步 rx 的第二级同步寄存器。

    assign rx_data = rx_data_reg;  // 向外导出已接收完成的并行字节。
    assign rx_done = rx_done_reg;  // 向 RX FIFO 写使能逻辑导出完成脉冲。

    // 时序部分：寄存状态、数据、计数器和两级同步器。
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            state            <= IDLE;  // 从空闲状态开始接收。
            rx_data_reg      <= 0;     // 清空接收数据寄存器。
            rx_done_reg      <= 1'b0;  // 清除完成标志。
            br_cnt_reg       <= 0;     // 清除每位采样计数。
            data_bit_cnt_reg <= 0;     // 清除数据位计数。
            rx_sync1_reg     <= 1'b1;  // UART 空闲线是高电平。
            rx_sync2_reg     <= 1'b1;  // UART 空闲线是高电平。
        end else begin
            state            <= state_next;            // 更新接收状态。
            rx_data_reg      <= rx_data_next;          // 更新接收数据。
            rx_done_reg      <= rx_done_next;          // 更新完成脉冲。
            br_cnt_reg       <= br_cnt_next;           // 更新每位采样计数。
            data_bit_cnt_reg <= data_bit_cnt_next;     // 更新数据位编号。
            rx_sync1_reg     <= rx_sync1_next;         // rx 输入第一级同步。
            rx_sync2_reg     <= rx_sync2_next;         // rx 输入第二级同步。
        end
    end

    // 组合部分：同步 rx，同时计算状态机的 next 状态。
    always @(*) begin
        state_next        = state;             // 默认保持状态，防止综合出锁存器。
        br_cnt_next       = br_cnt_reg;        // 默认保持节拍计数。
        data_bit_cnt_next = data_bit_cnt_reg;  // 默认保持数据位计数。
        rx_data_next      = rx_data_reg;       // 默认保持已接收数据。
        rx_done_next      = rx_done_reg;       // 默认保持完成标志。
        rx_sync1_next     = rx;                // 第一级在下个 clk 采样原始异步 rx。
        rx_sync2_next     = rx_sync1_reg;      // 第二级在下个 clk 采样第一级，降低亚稳态传播风险。

        case (state)
            IDLE: begin
                rx_done_next = 1'b0;  // 每次回到空闲态后，清除上一帧的完成脉冲。
                if (rx_sync2_reg == 1'b0) begin
                    br_cnt_next       = 0;      // 检测到低电平起始位，开始半位确认计数。
                    data_bit_cnt_next = 0;      // 准备从 D0 开始采样。
                    rx_data_next      = 0;      // 清空移位寄存器，避免上一帧残留。
                    state_next        = START;  // 进入起始位确认阶段。
                end
            end

            START: begin
                if (br_tick) begin
                    if (br_cnt_reg == 7) begin
                        br_cnt_next = 0;     // 半个比特（8/16）后开始数据位计数。
                        state_next  = DATA;  // 从 D0 的中心附近开始等待完整数据位采样。
                    end else begin
                        br_cnt_next = br_cnt_reg + 1;  // 未到半位，继续等待。
                    end
                end
            end
            DATA: begin
                if (br_tick) begin
                    if (br_cnt_reg == 15) begin
                        br_cnt_next  = 0;  // 一个数据位结束，准备计数下一个数据位。
                        rx_data_next = {rx_sync2_reg, rx_data_reg[7:1]};
                        // 右移并将最新采样位放到 bit[7]；由于 UART 低位先到，
                        // 连续采样 8 次后，D0 最终移动到 bit[0]，得到正确字节顺序。
                        if (data_bit_cnt_reg == 7) begin
                            state_next  = STOP;  // 已采样 D0 至 D7，进入停止位等待。
                            br_cnt_next = 0;     // 停止位重新开始计数。
                        end else begin
                            data_bit_cnt_next = data_bit_cnt_reg + 1;  // 继续采样下一个数据位。
                        end
                    end else begin
                        br_cnt_next = br_cnt_reg + 1;  // 当前数据位尚未结束。
                    end
                end
            end
            STOP: begin
                if (br_tick) begin
                    if (br_cnt_reg == 15) begin
                        br_cnt_next  = 0;     // 停止位时间结束。
                        rx_done_next = 1'b1;  // 宣告一帧接收完成，RX FIFO 将据此写入。
                        state_next   = IDLE;  // 返回空闲状态，等待下一帧。
                    end else begin
                        br_cnt_next = br_cnt_reg + 1;  // 继续等待停止位结束。
                    end
                end
            end
        endcase
    end

endmodule  // receiver 模块结束。
