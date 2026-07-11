//FIFO = 存储器 + 控制逻辑
// fifo
//  |
//  |-- register_file        存储数据
//  |
//  |-- fifo_control_unit    控制读写指针、full、empty

//              wdata
//                |
//                |
//                v

//        +---------------+
//        | register_file |
//        |               |
//        |  mem[0:7]     |
//        +---------------+
//           ^        |
//           |        |
//        waddr      rdata
//           |
//           |
//        control

//           ^
//           |
// +---------------------+
// | fifo_control_unit   |
// |                     |
// | wr_ptr              |
// | rd_ptr              |
// | full                |
// | empty               |
// +---------------------+

// wr_ptr怎么走
// rd_ptr怎么走
// empty什么时候1
// full什么时候1



// 实际上数字IC RTL设计里面大量代码都是：
// 当前寄存器(reg)
//         |
//         |
// 组合逻辑计算(next)
//         |
//         |
// 下一个clk更新(reg)
module fifo #(
    parameter ADDR_WIDTH = 3,//表示地址宽度。2^3=8 000~111
    DATA_WIDTH = 8//每个数据多少bit。
) (
    input clk,
    input reset,

    input                   wr_en,
    output                  full,//不能再写
    input  [DATA_WIDTH-1:0] wdata,

    input                   rd_en,
    output                  empty, //没有数据可读
    output [DATA_WIDTH-1:0] rdata
);

    // wire w_full;
    wire [ADDR_WIDTH-1:0] w_waddr, w_raddr;

    register_file #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH)  // 3bit address==2^3개 메모리 공간, 8bit data
    ) U_RegFile (
        .clk  (clk),
        .reset(reset),
        .wr_en(wr_en & ~full),
        .waddr(w_waddr),
        .wdata(wdata),
        // .rd_en(rd_en & ~empty),
        .raddr(w_raddr),

        .rdata(rdata)
    );

    fifo_control_unit #(
        .ADDR_WIDTH(ADDR_WIDTH)
    ) U_FIFO_CU (
        .clk  (clk),
        .reset(reset),

        // wrte
        .wr_en(wr_en),
        .full (full),
        .waddr(w_waddr),

        // read
        .rd_en(rd_en),
        .empty(empty),
        .raddr(w_raddr)
    );

endmodule


module register_file #(
    parameter ADDR_WIDTH = 3,
    DATA_WIDTH = 8  // 3bit address==2^3개 메모리 공간, 8bit data
) (
    input                  clk,
    input                  reset,
    input                  wr_en,
    // input                  rd_en,
    input [ADDR_WIDTH-1:0] waddr,
    input [DATA_WIDTH-1:0] wdata,
    input [ADDR_WIDTH-1:0] raddr,

    output [DATA_WIDTH-1:0] rdata
);

    reg [DATA_WIDTH-1:0] mem[0:2**ADDR_WIDTH-1];
    integer i;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            for (i = 0; i < 2**ADDR_WIDTH; i = i + 1) begin
                mem[i] <= 0;
            end
        end else begin
            if (wr_en) mem[waddr] <= wdata;
        end
    end

    assign rdata = mem[raddr];
    // assign rdata = rd_en ? mem[raddr] : 8'bz;   // read enable 1이면 출력, 아니면 High Impedence

endmodule


module fifo_control_unit #(
    parameter ADDR_WIDTH = 3
) (
    input clk,
    input reset,

    // wrte
    input                   wr_en,
    output                  full,
    output [ADDR_WIDTH-1:0] waddr,

    // read
    input rd_en,
    output empty,
    output [ADDR_WIDTH-1:0] raddr
);

    reg [ADDR_WIDTH-1:0] wr_ptr_reg, wr_ptr_next;
    reg [ADDR_WIDTH-1:0] rd_ptr_reg, rd_ptr_next;
    reg full_reg, full_next, empty_reg, empty_next;


    assign waddr = wr_ptr_reg;
    assign raddr = rd_ptr_reg;
    assign full  = full_reg;
    assign empty = empty_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            wr_ptr_reg <= 0;
            rd_ptr_reg <= 0;
            full_reg   <= 1'b0;
            empty_reg  <= 1'b1;
        end else begin
            wr_ptr_reg <= wr_ptr_next;
            rd_ptr_reg <= rd_ptr_next;
            full_reg   <= full_next;
            empty_reg  <= empty_next;
        end
    end

    always @(*) begin
        wr_ptr_next = wr_ptr_reg;
        rd_ptr_next = rd_ptr_reg;
        full_next   = full_reg;
        empty_next  = empty_reg;

        case ({
            wr_en, rd_en
        })
        
            2'b01: begin  // read 比如读完0位置上的数，0位置被释放，fifo不满了；
                if (!empty_reg) begin //FIFO不是空的，说明可以读
                    full_next   = 1'b0;  // read이면 full = 0；读数据以后fifo一定不会满 读一个数据，满状态解除
                    rd_ptr_next = rd_ptr_reg + 1;//可以和上米啊的那一行互换位置，🏁
                    if (rd_ptr_next == wr_ptr_reg) begin//读完了所有的之后就全空了
                        empty_next = 1'b1;  // 모두 읽었으면 empty这里就是全空了
                    end
                end
            end

            2'b10: begin  // write
                if (!full_reg) begin
                    empty_next  = 1'b0;  // write이면 empty = 0 写完一个之后就不会为空；
                    wr_ptr_next = wr_ptr_reg + 1;
                    if (wr_ptr_next == rd_ptr_reg) begin //wr_ptr继续增加。wr_ptr追上rd_ptr,说明全部空间占满，写完了之后空间为满；
                        full_next = 1'b1;  // 모두 썼으면 full
                    end
                end
            end
// 这是FIFO设计里面经常考的问题。同时读写
            2'b11: begin  // write, read
                if (empty_reg) begin //fifo为空，没有数据读，只能写；
                    wr_ptr_next = wr_ptr_reg + 1;
                    empty_next  = 1'b0;
                end else if (full_reg) begin//fifo为满、不能写，只能读；
                    rd_ptr_next = rd_ptr_reg + 1;
                    full_next   = 1'b0;
                end else begin
                    wr_ptr_next = wr_ptr_reg + 1;
                    rd_ptr_next = rd_ptr_reg + 1;
                end
            end
        endcase
    end

    // 单一时序 always 块写法参考版本，使用 _alt 寄存器避免与上面的正式逻辑冲突。
    // reg [ADDR_WIDTH-1:0] wr_ptr_reg_alt;
    // reg [ADDR_WIDTH-1:0] rd_ptr_reg_alt;
    // reg full_reg_alt;
    // reg empty_reg_alt;
    //
    // always @(posedge clk, posedge reset) begin
    //     if (reset) begin
    //         wr_ptr_reg_alt <= 0;
    //         rd_ptr_reg_alt <= 0;
    //         full_reg_alt   <= 1'b0;
    //         empty_reg_alt  <= 1'b1;
    //     end else begin
    //         case ({wr_en, rd_en})
    //             2'b01: begin  // read
    //                 wr_ptr_reg_alt <= wr_ptr_reg_alt;
    //                 rd_ptr_reg_alt <= rd_ptr_reg_alt;
    //                 full_reg_alt   <= full_reg_alt;
    //                 empty_reg_alt  <= empty_reg_alt;
    //
    //                 if (!empty_reg_alt) begin
    //                     full_reg_alt   <= 1'b0;
    //                     rd_ptr_reg_alt <= rd_ptr_reg_alt + 1;
    //                     if (rd_ptr_reg_alt + 1 == wr_ptr_reg_alt) begin
    //                         empty_reg_alt <= 1'b1;
    //                     end
    //                 end
    //             end
    //
    //             2'b10: begin  // write
    //                 wr_ptr_reg_alt <= wr_ptr_reg_alt;
    //                 rd_ptr_reg_alt <= rd_ptr_reg_alt;
    //                 full_reg_alt   <= full_reg_alt;
    //                 empty_reg_alt  <= empty_reg_alt;
    //
    //                 if (!full_reg_alt) begin
    //                     empty_reg_alt  <= 1'b0;
    //                     wr_ptr_reg_alt <= wr_ptr_reg_alt + 1;
    //                     if (wr_ptr_reg_alt + 1 == rd_ptr_reg_alt) begin
    //                         full_reg_alt <= 1'b1;
    //                     end
    //                 end
    //             end
    //
    //             2'b11: begin  // write, read
    //                 wr_ptr_reg_alt <= wr_ptr_reg_alt;
    //                 rd_ptr_reg_alt <= rd_ptr_reg_alt;
    //                 full_reg_alt   <= full_reg_alt;
    //                 empty_reg_alt  <= empty_reg_alt;
    //
    //                 if (empty_reg_alt) begin
    //                     wr_ptr_reg_alt <= wr_ptr_reg_alt + 1;
    //                     empty_reg_alt  <= 1'b0;
    //                 end else if (full_reg_alt) begin
    //                     rd_ptr_reg_alt <= rd_ptr_reg_alt + 1;
    //                     full_reg_alt   <= 1'b0;
    //                 end else begin
    //                     wr_ptr_reg_alt <= wr_ptr_reg_alt + 1;
    //                     rd_ptr_reg_alt <= rd_ptr_reg_alt + 1;
    //                 end
    //             end
    //
    //             default: begin
    //                 wr_ptr_reg_alt <= wr_ptr_reg_alt;
    //                 rd_ptr_reg_alt <= rd_ptr_reg_alt;
    //                 full_reg_alt   <= full_reg_alt;
    //                 empty_reg_alt  <= empty_reg_alt;
    //             end
    //         endcase
    //     end
    // end
endmodule
