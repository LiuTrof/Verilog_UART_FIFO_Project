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
//         br_cnt_reg, br_cnt_next;  // baudrate 16 sampling 카운터 레지스터
//     reg [2:0]
//         data_bit_cnt_reg,
//         data_bit_cnt_next;  // 8비트 데이터 카운트 레지스터


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
//         br_cnt_next;  // baudrate 16 sampling 카운터 레지스터(0~15)
//     reg [2:0]
//         data_bit_cnt_reg,
//         data_bit_cnt_next;  // 8비트 데이터 카운트 레지스터(0~7)


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


`timescale 1ns / 1ps


// | 变量                 | 作用              |
// | ------------------ | --------------- |
// | `br_tick`          | 16倍波特率时钟        |
// | `br_cnt_reg`       | 当前bit内部计数(0~15) |
// | `data_bit_cnt_reg` | 当前收到第几个数据位(0~7) |


module uart (

    input clk,
    input reset,
    // Transmitter
    input start,
    input [7:0] tx_data,
    output tx,
    output tx_done,
    //Receiver
    input rx,
    output [7:0] rx_data,
    output rx_done


);

    wire w_br_tick;   

    baudrate_generator U_BAUDRATE_GEN (
        .clk(clk),
        .reset(reset),
        .br_tick(w_br_tick)
    );


    transmitter U_Trnasmitter (
        .clk(clk),
        .reset(reset),
        .br_tick(w_br_tick),
        .start(start),
        .tx_data(tx_data),
        .tx(tx),
        .tx_done(tx_done)
    );


    receiver U_Receiver (
        .clk(clk),
        .reset(reset),
        .br_tick(w_br_tick),
        .rx(rx),
        .rx_data(rx_data),
        .rx_done(rx_done)
    );


endmodule


module baudrate_generator (
    input  clk,
    input  reset,
    output br_tick
);

    reg [$clog2(100_000_000 / 9600 / 16) - 1:0] counter_reg, counter_next;
    reg tick_reg, tick_next;

    assign br_tick = tick_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            counter_reg <= 0;
            tick_reg <= 1'b0;

        end else begin
            counter_reg <= counter_next;
            tick_reg <= tick_next;
        end
    end

    always @(*) begin
        counter_next = counter_reg;
       // if (counter_reg == 3) begin  // 시뮬레이션용
            if(counter_reg == 100_000_000 / 9600 / 16 - 1) begin // 기존 9600hz에 16배 한 값
            // 100_000_000 / 9600 / 16 - 1 이 값은 컴파일러에서 상수이기 때문에 계산 된 값으로 회로가 만들어진다. 상수이기때문에. 회로가 더 만들어지진 않는다. 
            counter_next = 0;
            tick_next = 1'b1;
        end else begin
            counter_next <= counter_reg + 1;
            tick_next = 1'b0;

        end
    end

    // 단일 always 블록으로 다시 작성한 참고용 버전
    // reg [$clog2(100_000_000 / 9600 / 16) - 1:0] counter_reg_alt;
    // reg tick_reg_alt;
    //
    // always @(posedge clk, posedge reset) begin
    //     if (reset) begin
    //         counter_reg_alt <= 0;
    //         tick_reg_alt    <= 1'b0;
    //     end else begin
    //         tick_reg_alt <= 1'b0;
    //         // if (counter_reg_alt == 3) begin  // 시뮬레이션용
    //         if (counter_reg_alt == 100_000_000 / 9600 / 16 - 1) begin
    //             counter_reg_alt <= 0;
    //             tick_reg_alt    <= 1'b1;
    //         end else begin
    //             counter_reg_alt <= counter_reg_alt + 1;
    //         end
    //     end
    // end

endmodule


//0524 
module transmitter (
    input clk,
    input reset,
    input br_tick,
    input start,
    input [7:0] tx_data,
    output tx,
    output tx_done
);

    localparam IDLE = 0, START = 1, DATA = 2, STOP = 3;
    reg [1:0] state, state_next;  //경우의수가 4가지 이므로 2비트
    reg tx_reg, tx_next;
    reg tx_done_reg, tx_done_next;
    reg [7:0] data_tmp_reg, data_tmp_next;
    reg [3:0] br_cnt_reg, br_cnt_next;  //16번 카운트이므로 4비트
    reg [2:0] data_bit_cnt_reg, data_bit_cnt_next;

    assign tx = tx_reg;
    assign tx_done = tx_done_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            state            <= IDLE;
            tx_reg           <= 1'b1;
            tx_done_reg      <= 1'b0;
            br_cnt_reg       <= 0;
            data_bit_cnt_reg <= 0;
            data_tmp_reg     <= 0;
        end else begin
            state            <= state_next;
            tx_reg           <= tx_next;
            tx_done_reg      <= tx_done_next;
            br_cnt_reg       <= br_cnt_next;
            data_bit_cnt_reg <= data_bit_cnt_next;
            data_tmp_reg     <= data_tmp_next;
        end
    end

    always @(*) begin

        //latch방지용 -> 밑의 경우의수를 제외한 경우를 정의 해 줌
        state_next        = state;
        data_tmp_next     = data_tmp_reg;
        tx_next           = tx_reg;
        br_cnt_next       = br_cnt_reg;
        data_bit_cnt_next = data_bit_cnt_reg;
        tx_done_next      = tx_done_reg;

        case (state)
            IDLE: begin
                tx_done_next = 1'b0;
                tx_next      = 1'b1;

                if (start) begin
                    state_next        = START;
                    data_tmp_next     = tx_data;
                    br_cnt_next       = 0;
                    data_bit_cnt_next = 0;
                end
            end
            START: begin
                tx_next = 1'b0;

                if (br_tick) begin
                    if (br_cnt_reg == 15) begin
                        state_next  = DATA;
                        br_cnt_next = 0;  ////////////
                    end else begin
                        br_cnt_next = br_cnt_reg + 1;
                    end
                end
            end
            DATA: begin
                tx_next = data_tmp_reg[0];

                if (br_tick) begin
                    if (br_cnt_reg == 15) begin
                        if (data_bit_cnt_reg == 7) begin
                            state_next  = STOP;
                            br_cnt_next = 0;
                        end else begin
                            data_bit_cnt_next = data_bit_cnt_reg + 1;
                            data_tmp_next = {
                                1'b0, data_tmp_reg[7:1]
                            };  // right shift
                            br_cnt_next = 0;
                        end
                    end else begin
                        br_cnt_next = br_cnt_reg + 1;

                    end
                end
            end
            STOP: begin
                tx_next = 1'b1;
                if (br_tick) begin
                    if (br_cnt_reg == 15) begin
                        tx_done_next = 1'b1;
                        state_next   = IDLE;
                    end else begin
                        br_cnt_next = br_cnt_reg + 1;
                    end
                end
            end

        endcase
    end

    // 단일 always 블록으로 다시 작성한 참고용 버전
    // reg [1:0] state_alt;
    // reg tx_reg_alt;
    // reg tx_done_reg_alt;
    // reg [7:0] data_tmp_reg_alt;
    // reg [3:0] br_cnt_reg_alt;
    // reg [2:0] data_bit_cnt_reg_alt;
    //
    // always @(posedge clk, posedge reset) begin
    //     if (reset) begin
    //         state_alt            <= IDLE;
    //         tx_reg_alt           <= 1'b1;
    //         tx_done_reg_alt      <= 1'b0;
    //         br_cnt_reg_alt       <= 0;
    //         data_bit_cnt_reg_alt <= 0;
    //         data_tmp_reg_alt     <= 0;
    //     end else begin
    //         case (state_alt)
    //             IDLE: begin
    //                 state_alt            <= state_alt;
    //                 tx_reg_alt           <= 1'b1;
    //                 tx_done_reg_alt      <= 1'b0;
    //                 br_cnt_reg_alt       <= br_cnt_reg_alt;
    //                 data_bit_cnt_reg_alt <= data_bit_cnt_reg_alt;
    //                 data_tmp_reg_alt     <= data_tmp_reg_alt;
    //
    //                 if (start) begin
    //                     state_alt            <= START;
    //                     data_tmp_reg_alt     <= tx_data;
    //                     br_cnt_reg_alt       <= 0;
    //                     data_bit_cnt_reg_alt <= 0;
    //                 end
    //             end
    //
    //             START: begin
    //                 state_alt            <= state_alt;
    //                 tx_reg_alt           <= 1'b0;
    //                 tx_done_reg_alt      <= tx_done_reg_alt;
    //                 br_cnt_reg_alt       <= br_cnt_reg_alt;
    //                 data_bit_cnt_reg_alt <= data_bit_cnt_reg_alt;
    //                 data_tmp_reg_alt     <= data_tmp_reg_alt;
    //
    //                 if (br_tick) begin
    //                     if (br_cnt_reg_alt == 15) begin
    //                         state_alt      <= DATA;
    //                         br_cnt_reg_alt <= 0;
    //                     end else begin
    //                         br_cnt_reg_alt <= br_cnt_reg_alt + 1;
    //                     end
    //                 end
    //             end
    //
    //             DATA: begin
    //                 state_alt            <= state_alt;
    //                 tx_reg_alt           <= data_tmp_reg_alt[0];
    //                 tx_done_reg_alt      <= tx_done_reg_alt;
    //                 br_cnt_reg_alt       <= br_cnt_reg_alt;
    //                 data_bit_cnt_reg_alt <= data_bit_cnt_reg_alt;
    //                 data_tmp_reg_alt     <= data_tmp_reg_alt;
    //
    //                 if (br_tick) begin
    //                     if (br_cnt_reg_alt == 15) begin
    //                         if (data_bit_cnt_reg_alt == 7) begin
    //                             state_alt      <= STOP;
    //                             br_cnt_reg_alt <= 0;
    //                         end else begin
    //                             data_bit_cnt_reg_alt <= data_bit_cnt_reg_alt + 1;
    //                             data_tmp_reg_alt <= {1'b0, data_tmp_reg_alt[7:1]};
    //                             br_cnt_reg_alt <= 0;
    //                         end
    //                     end else begin
    //                         br_cnt_reg_alt <= br_cnt_reg_alt + 1;
    //                     end
    //                 end
    //             end
    //
    //             STOP: begin
    //                 state_alt            <= state_alt;
    //                 tx_reg_alt           <= 1'b1;
    //                 tx_done_reg_alt      <= tx_done_reg_alt;
    //                 br_cnt_reg_alt       <= br_cnt_reg_alt;
    //                 data_bit_cnt_reg_alt <= data_bit_cnt_reg_alt;
    //                 data_tmp_reg_alt     <= data_tmp_reg_alt;
    //
    //                 if (br_tick) begin
    //                     if (br_cnt_reg_alt == 15) begin
    //                         tx_done_reg_alt <= 1'b1;
    //                         state_alt       <= IDLE;
    //                     end else begin
    //                         br_cnt_reg_alt <= br_cnt_reg_alt + 1;
    //                     end
    //                 end
    //             end
    //
    //             default: begin
    //                 state_alt            <= IDLE;
    //                 tx_reg_alt           <= 1'b1;
    //                 tx_done_reg_alt      <= 1'b0;
    //                 br_cnt_reg_alt       <= 0;
    //                 data_bit_cnt_reg_alt <= 0;
    //                 data_tmp_reg_alt     <= 0;
    //             end
    //         endcase
    //     end
    // end
endmodule


module receiver (
    input clk,
    input reset,
    input br_tick,
    input rx,
    output [7:0] rx_data,
    output rx_done
);

    localparam IDLE = 0, START = 1, DATA = 2, STOP = 3;

    reg [1:0] state, state_next;
    reg [7:0] rx_data_reg, rx_data_next;
    reg rx_done_reg, rx_done_next;
    reg [3:0] br_cnt_reg, br_cnt_next; // 
    reg [2:0] data_bit_cnt_reg, data_bit_cnt_next;
    reg       rx_sync1_reg, rx_sync1_next;
    reg       rx_sync2_reg, rx_sync2_next;

    assign rx_data = rx_data_reg;
    assign rx_done = rx_done_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            state            <= IDLE;
            rx_data_reg      <= 0;
            rx_done_reg      <= 1'b0;
            br_cnt_reg       <= 0;
            data_bit_cnt_reg <= 0;
            rx_sync1_reg     <= 1'b1;
            rx_sync2_reg     <= 1'b1;
        end else begin
            state            <= state_next;
            rx_data_reg      <= rx_data_next;
            rx_done_reg      <= rx_done_next;
            br_cnt_reg       <= br_cnt_next;
            data_bit_cnt_reg <= data_bit_cnt_next;
            rx_sync1_reg     <= rx_sync1_next;
            rx_sync2_reg     <= rx_sync2_next;
        end
    end

    always @(*) begin
        state_next        = state;
        br_cnt_next       = br_cnt_reg;
        data_bit_cnt_next = data_bit_cnt_reg;
        rx_data_next      = rx_data_reg;
        rx_done_next      = rx_done_reg;
        rx_sync1_next     = rx;
        rx_sync2_next     = rx_sync1_reg;

        case (state)
            IDLE: begin
                rx_done_next = 1'b0;
                if (rx_sync2_reg == 1'b0) begin
                    br_cnt_next       = 0;
                    data_bit_cnt_next = 0;
                    rx_data_next      = 0;
                    state_next        = START;
                end
            end

            START: begin
                if (br_tick) begin
                    if (br_cnt_reg == 7) begin
                        br_cnt_next = 0;
                        state_next  = DATA;
                    end else begin
                        br_cnt_next = br_cnt_reg + 1;
                    end
                end
            end

            DATA: begin
                if (br_tick) begin
                    if (br_cnt_reg == 15) begin
                        br_cnt_next  = 0;
                        rx_data_next = {rx_sync2_reg, rx_data_reg[7:1]};
                        if (data_bit_cnt_reg == 7) begin
                            state_next  = STOP;
                            br_cnt_next = 0;
                        end else begin
                            data_bit_cnt_next = data_bit_cnt_reg + 1;
                        end
                    end else begin
                        br_cnt_next = br_cnt_reg + 1;
                    end
                end
            end

            STOP: begin
                if (br_tick) begin
                    if (br_cnt_reg == 15) begin
                        br_cnt_next  = 0;
                        rx_done_next = 1'b1;
                        state_next   = IDLE;
                    end else begin
                        br_cnt_next = br_cnt_reg + 1;
                    end
                end
            end
        endcase
    end

    // 单一时序 always 块写法参考版本，使用 _alt 寄存器避免与上面的正式逻辑冲突。
    // reg [1:0] state_alt;
    // reg [7:0] rx_data_reg_alt;
    // reg rx_done_reg_alt;
    // reg [3:0] br_cnt_reg_alt;
    // reg [2:0] data_bit_cnt_reg_alt;
    // reg rx_sync1_reg_alt;
    // reg rx_sync2_reg_alt;
    //
    // always @(posedge clk, posedge reset) begin
    //     if (reset) begin
    //         state_alt            <= IDLE;
    //         rx_data_reg_alt      <= 0;
    //         rx_done_reg_alt      <= 1'b0;
    //         br_cnt_reg_alt       <= 0;
    //         data_bit_cnt_reg_alt <= 0;
    //         rx_sync1_reg_alt     <= 1'b1;
    //         rx_sync2_reg_alt     <= 1'b1;
    //     end else begin
    //         rx_sync1_reg_alt <= rx;
    //         rx_sync2_reg_alt <= rx_sync1_reg_alt;
    //
    //         case (state_alt)
    //             IDLE: begin
    //                 state_alt            <= state_alt;
    //                 rx_data_reg_alt      <= rx_data_reg_alt;
    //                 rx_done_reg_alt      <= 1'b0;
    //                 br_cnt_reg_alt       <= br_cnt_reg_alt;
    //                 data_bit_cnt_reg_alt <= data_bit_cnt_reg_alt;
    //
    //                 if (rx_sync2_reg_alt == 1'b0) begin
    //                     state_alt            <= START;
    //                     br_cnt_reg_alt       <= 0;
    //                     data_bit_cnt_reg_alt <= 0;
    //                     rx_data_reg_alt      <= 0;
    //                 end
    //             end
    //
    //             START: begin
    //                 state_alt            <= state_alt;
    //                 rx_data_reg_alt      <= rx_data_reg_alt;
    //                 rx_done_reg_alt      <= rx_done_reg_alt;
    //                 br_cnt_reg_alt       <= br_cnt_reg_alt;
    //                 data_bit_cnt_reg_alt <= data_bit_cnt_reg_alt;
    //
    //                 if (br_tick) begin
    //                     if (br_cnt_reg_alt == 7) begin
    //                         state_alt      <= DATA;
    //                         br_cnt_reg_alt <= 0;
    //                     end else begin
    //                         br_cnt_reg_alt <= br_cnt_reg_alt + 1;
    //                     end
    //                 end
    //             end
    //
    //             DATA: begin
    //                 state_alt            <= state_alt;
    //                 rx_data_reg_alt      <= rx_data_reg_alt;
    //                 rx_done_reg_alt      <= rx_done_reg_alt;
    //                 br_cnt_reg_alt       <= br_cnt_reg_alt;
    //                 data_bit_cnt_reg_alt <= data_bit_cnt_reg_alt;
    //
    //                 if (br_tick) begin
    //                     if (br_cnt_reg_alt == 15) begin
    //                         br_cnt_reg_alt  <= 0;
    //                         rx_data_reg_alt <= {rx_sync2_reg_alt, rx_data_reg_alt[7:1]};
    //                         if (data_bit_cnt_reg_alt == 7) begin
    //                             state_alt <= STOP;
    //                         end else begin
    //                             data_bit_cnt_reg_alt <= data_bit_cnt_reg_alt + 1;
    //                         end
    //                     end else begin
    //                         br_cnt_reg_alt <= br_cnt_reg_alt + 1;
    //                     end
    //                 end
    //             end
    //
    //             STOP: begin
    //                 state_alt            <= state_alt;
    //                 rx_data_reg_alt      <= rx_data_reg_alt;
    //                 rx_done_reg_alt      <= rx_done_reg_alt;
    //                 br_cnt_reg_alt       <= br_cnt_reg_alt;
    //                 data_bit_cnt_reg_alt <= data_bit_cnt_reg_alt;
    //
    //                 if (br_tick) begin
    //                     if (br_cnt_reg_alt == 15) begin
    //                         state_alt       <= IDLE;
    //                         rx_done_reg_alt <= 1'b1;
    //                         br_cnt_reg_alt  <= 0;
    //                     end else begin
    //                         br_cnt_reg_alt <= br_cnt_reg_alt + 1;
    //                     end
    //                 end
    //             end
    //
    //             default: begin
    //                 state_alt            <= IDLE;
    //                 rx_data_reg_alt      <= 0;
    //                 rx_done_reg_alt      <= 1'b0;
    //                 br_cnt_reg_alt       <= 0;
    //                 data_bit_cnt_reg_alt <= 0;
    //             end
    //         endcase
    //     end
    // end

endmodule
