// 单时钟同步 FIFO，由存储体 register_file 和控制器 fifo_control_unit 组成。
// 当 ADDR_WIDTH=3 时，FIFO 深度为 2^3=8 项。
module fifo #(
    parameter ADDR_WIDTH = 3,  // 指针/地址宽度，FIFO 深度等于 2^ADDR_WIDTH。
    parameter DATA_WIDTH = 8   // 每个 FIFO 存储项的数据位宽。
) (
    input                  clk,    // 指针更新和存储体写入使用的时钟。
    input                  reset,  // 高有效异步复位。

    input                  wr_en,  // 写请求；仅当 full=0 时写入才会生效。
    output                 full,   // 为 1 表示所有 FIFO 存储项都已占用。
    input [DATA_WIDTH-1:0] wdata,  // 本次有效写入要存储的数据。

    input                  rd_en,  // 读请求；仅当 empty=0 时读操作才会生效。
    output                 empty,  // 为 1 表示 FIFO 中没有有效数据。
    output [DATA_WIDTH-1:0] rdata  // 当前读指针地址对应的组合读数据。
);

    // 控制器根据两个循环指针生成存储体读写地址。
    wire [ADDR_WIDTH-1:0] w_waddr;  // 下一次有效写入要使用的地址。
    wire [ADDR_WIDTH-1:0] w_raddr;  // 当前读指针对应的读取地址。

    // 存储体：在时钟沿写入，按地址异步读出。
    register_file #(
        .ADDR_WIDTH(ADDR_WIDTH),  // 存储体深度必须与 FIFO 控制器保持一致。
        .DATA_WIDTH (DATA_WIDTH)  // 存储体位宽必须与 FIFO 端口保持一致。
    ) U_RegFile (
        .clk  (clk),              // 驱动存储体写入的时钟。
        .reset(reset),            // 本 RTL 模型复位时清零每个存储项。
        .wr_en(wr_en & ~full),    // FIFO 已满时禁止存储体继续写入。
        .waddr(w_waddr),          // 控制器选择的写地址。
        .wdata(wdata),            // 待写入的数据。
        .raddr(w_raddr),          // 控制器选择的读地址。
        .rdata(rdata)             // 立即返回该地址中的数据。
    );

    // 控制器保存读写指针，并将读写请求转换为 FIFO 状态变化。
    fifo_control_unit #(
        .ADDR_WIDTH(ADDR_WIDTH)   // 指针宽度必须与存储体地址宽度一致。
    ) U_FIFO_CU (
        .clk  (clk),              // 在该时钟沿更新指针和状态标志。
        .reset(reset),            // 复位后 empty=1，full=0。

        .wr_en(wr_en),            // 根据写请求更新写指针和 full 标志。
        .full (full),             // 向 FIFO 使用者和存储体写使能门控导出 full。
        .waddr(w_waddr),          // 将当前写指针作为存储体写地址导出。

        .rd_en(rd_en),            // 根据读请求更新读指针和 empty 标志。
        .empty(empty),            // 向 FIFO 使用者导出 empty 标志。
        .raddr(w_raddr)           // 将当前读指针作为存储体读地址导出。
    );

endmodule  // fifo 模块结束。


// 使用寄存器数组实现的 FIFO 存储体。
module register_file #(
    parameter ADDR_WIDTH = 3,  // 3 位地址可选择 2^3=8 个存储位置。
    parameter DATA_WIDTH = 8   // 每个存储位置默认保存一个 8 位字节。
) (
    input                  clk,    // 存储体写时钟。
    input                  reset,  // 高有效异步复位。
    input                  wr_en,  // 经 FIFO 外层校验后的有效写使能。
    input [ADDR_WIDTH-1:0] waddr,  // 写操作发生时，接收 wdata 的地址。
    input [DATA_WIDTH-1:0] wdata,  // 需要存储的数据。
    input [ADDR_WIDTH-1:0] raddr,  // 其内容会反映在 rdata 上的地址。

    output [DATA_WIDTH-1:0] rdata  // 异步读数据；只有 FIFO 非空时才表示有效事务。
);

    reg [DATA_WIDTH-1:0] mem [0:2**ADDR_WIDTH-1];  // 包含 2^ADDR_WIDTH 个数据字的寄存器数组。
    integer i;                                      // 仅在复位清零循环中使用的循环变量。

    // 该 always 块模拟基于寄存器的存储体：复位清零所有数据字；
    // 正常情况下只在上升沿更新被写地址选中的一个数据字。
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            for (i = 0; i < 2**ADDR_WIDTH; i = i + 1) begin
                mem[i] <= 0;                         // 初始化每一项，使仿真结果可预测。
            end
        end else if (wr_en) begin
            mem[waddr] <= wdata;                     // 将输入数据存到写指针选中的地址。
        end
    end

    assign rdata = mem[raddr];                       // 组合读，不额外引入一个时钟周期的读延迟。

endmodule  // register_file 模块结束。


// FIFO 的指针与状态标志控制逻辑。
module fifo_control_unit #(
    parameter ADDR_WIDTH = 3  // 循环读写指针的位宽。
) (
    input                  clk,    // 指针和状态标志寄存器的时钟。
    input                  reset,  // 高有效异步复位。

    input                  wr_en,  // 请求写入一个数据字。
    output                 full,   // 为 1 时 FIFO 不可再接受新的写入。
    output [ADDR_WIDTH-1:0] waddr, // 当前写指针。

    input                  rd_en,  // 请求读取/消费一个数据字。
    output                 empty,  // 为 1 时 FIFO 中没有可消费的数据字。
    output [ADDR_WIDTH-1:0] raddr  // 当前读指针。
);

    reg [ADDR_WIDTH-1:0] wr_ptr_reg, wr_ptr_next;  // 当前与下一拍的循环写地址。
    reg [ADDR_WIDTH-1:0] rd_ptr_reg, rd_ptr_next;  // 当前与下一拍的循环读地址。
    reg                  full_reg, full_next;       // 当前与下一拍的满状态。
    reg                  empty_reg, empty_next;     // 当前与下一拍的空状态。

    assign waddr = wr_ptr_reg;  // 存储体写入使用当前写指针。
    assign raddr = rd_ptr_reg;  // 存储体读出使用当前读指针。
    assign full  = full_reg;    // 导出寄存器保存的满状态。
    assign empty = empty_reg;   // 导出寄存器保存的空状态。

    // 时序部分：在时钟沿将组合逻辑计算出的 next 状态写入寄存器。
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            wr_ptr_reg <= 0;      // 第一次有效写入使用地址 0。
            rd_ptr_reg <= 0;      // 第一次有效读取同样从地址 0 开始。
            full_reg   <= 1'b0;   // 复位后的 FIFO 不可能为满。
            empty_reg  <= 1'b1;   // 复位后的 FIFO 没有有效数据。
        end else begin
            wr_ptr_reg <= wr_ptr_next;  // 提交组合逻辑计算出的写指针。
            rd_ptr_reg <= rd_ptr_next;  // 提交组合逻辑计算出的读指针。
            full_reg   <= full_next;    // 提交组合逻辑计算出的满标志。
            empty_reg  <= empty_next;   // 提交组合逻辑计算出的空标志。
        end
    end

    // 组合部分：根据本拍读写请求计算下一拍应进入的状态。
    always @(*) begin
        wr_ptr_next = wr_ptr_reg;  // 默认保持原状态，防止综合出锁存器。
        rd_ptr_next = rd_ptr_reg;  // 默认保持读指针。
        full_next   = full_reg;    // 默认保持满标志。
        empty_next  = empty_reg;   // 默认保持空标志。

        case ({wr_en, rd_en})      // 00=无操作，01=仅读，10=仅写，11=同时读写。
            2'b01: begin           // 仅有读请求。
                if (!empty_reg) begin             // FIFO 为空时忽略读请求，避免下溢。
                    full_next   = 1'b0;           // 读走一个数据后一定不再是满。
                    rd_ptr_next = rd_ptr_reg + 1; // 读指针前进到下一个已存储数据。
                    if (rd_ptr_next == wr_ptr_reg) begin
                        empty_next = 1'b1;        // 读指针追上写指针，说明 FIFO 已读空。
                    end
                end
            end

            2'b10: begin           // 仅有写请求。
                if (!full_reg) begin              // FIFO 已满时忽略写请求，避免溢出。
                    empty_next  = 1'b0;           // 写入一个数据后一定不再是空。
                    wr_ptr_next = wr_ptr_reg + 1; // 写指针前进到下一个空闲存储位置。
                    if (wr_ptr_next == rd_ptr_reg) begin
                        full_next = 1'b1;         // 写指针追上读指针，说明 FIFO 已写满。
                    end
                end
            end

            2'b11: begin           // 同时收到读写请求。
                if (empty_reg) begin              // 空 FIFO 没有数据可读，因此只接受写入。
                    wr_ptr_next = wr_ptr_reg + 1;
                    empty_next  = 1'b0;
                end else if (full_reg) begin      // 满 FIFO 无空间可写，因此只接受读取。
                    rd_ptr_next = rd_ptr_reg + 1;
                    full_next   = 1'b0;
                end else begin                    // 非空且非满时，读写操作可同时完成。
                    wr_ptr_next = wr_ptr_reg + 1; // 写指针为新数据前进一格。
                    rd_ptr_next = rd_ptr_reg + 1; // 读指针为被消费数据前进一格。
                end
            end
        endcase
    end
endmodule  // fifo_control_unit 模块结束。
