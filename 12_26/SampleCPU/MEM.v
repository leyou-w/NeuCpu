// MEM模块：流水线中的存储器访问阶段
// 负责处理数据存储器访问操作，包括加载(load)和存储(store)指令
// 同时处理HI/LO寄存器的写回操作，以及数据转发到ID阶段
`include "lib/defines.vh"
module MEM(
    input wire clk,                      // 时钟信号
    input wire rst,                      // 复位信号
    // input wire flush,                   // 流水线刷新信号（当前未使用）
    input wire [`StallBus-1:0] stall,   // 流水线暂停控制信号

    // 来自EX阶段的总线信号，包含所有控制信息和数据
    input wire [`EX_TO_MEM_WD-1:0] ex_to_mem_bus,
    input wire [31:0] data_sram_rdata,  // 从数据存储器读取的数据

    // 输出到下一阶段(WB)的HI/LO寄存器数据总线
    output wire [65:0] mem_hilo_bus,
    // 输出到WB阶段的总线信号，包含写回寄存器堆的所有信息
    output wire [`MEM_TO_WB_WD-1:0] mem_to_wb_bus,
    // 输出到ID阶段的数据转发总线，用于解决数据相关
    output wire [`MEM_TO_RF_WD-1:0] mem_to_rf_bus       //前推线路
);

    reg [`EX_TO_MEM_WD-1:0] ex_to_mem_bus_r;  // EX到MEM阶段的流水线寄存器

    // 流水线寄存器控制逻辑：处理流水线暂停和指令缓存
    always @ (posedge clk) begin
        if (rst) begin
            // 复位时，清空流水线寄存器
            ex_to_mem_bus_r <= `EX_TO_MEM_WD'b0;
        end
        // else if (flush) begin
        //     // 流水线刷新时，清空寄存器（当前未使用）
        //     ex_to_mem_bus_r <= `EX_TO_MEM_WD'b0;
        // end
        else if (stall[3]==`Stop && stall[4]==`NoStop) begin
            // MEM阶段暂停但WB阶段不暂停时，插入空操作（NOP）
            ex_to_mem_bus_r <= `EX_TO_MEM_WD'b0;
        end
        else if (stall[3]==`NoStop) begin
            // MEM阶段不暂停时，正常接收来自EX阶段的数据
            ex_to_mem_bus_r <= ex_to_mem_bus;
        end
        // MEM阶段暂停时，保持当前寄存器值不变
    end

    // 从EX阶段总线中解析出的各个控制信号和数据
wire [31:0] mem_pc;                     // 程序计数器值
wire data_ram_en;                       // 数据存储器访问使能信号
wire [3:0] data_ram_wen;                // 数据存储器写使能（字节级控制）
wire [3:0] data_ram_sel;                // 数据存储器字节选择信号
wire sel_rf_res;                        // 选择写回数据来源（ALU结果或存储器数据）
wire rf_we;                             // 寄存器堆写使能
wire [4:0] rf_waddr;                    // 写回的寄存器地址
wire [31:0] rf_wdata;                   // 写回的数据
wire [31:0] ex_result;                  // EX阶段计算结果（ALU输出）
wire [31:0] mem_result;                 // MEM阶段处理后的结果（存储器数据）
wire [7:0] mem_op;                      // MEM阶段操作码（加载/存储指令类型）
wire [65:0] hilo_bus;                   // HI/LO寄存器数据总线

// 从EX阶段总线中解析出各个信号
assign {
    hilo_bus,                           // 65:0  - HI/LO寄存器数据
    mem_op,                             // 73:66 - MEM操作码
    mem_pc,          // 79:48           - 程序计数器
    data_ram_en,    // 47              - 数据存储器使能
    data_ram_wen,   // 46:43           - 数据存储器写使能
//        data_ram_sel,   // 42:39           - 数据存储器字节选择（未使用）
    sel_rf_res,     // 38              - 写回数据选择
    rf_we,          // 37              - 寄存器堆写使能
    rf_waddr,       // 36:32           - 写回寄存器地址
    ex_result       // 31:0            - EX阶段结果
} =  ex_to_mem_bus_r;

    // 指令类型判断信号：判断当前指令是否为特定类型的加载指令
wire inst_lw, inst_lb, inst_lbu, inst_lh, inst_lhu;
wire inst_sw, inst_sb, inst_sh;

// 从指令操作码中解析指令类型
assign {inst_lw, inst_lb, inst_lbu, inst_lh, inst_lhu} = (inst[31:26] == 6'b100000) ? {inst[3:0]} : 5'b0;
assign {inst_sw, inst_sb, inst_sh} = (inst[31:26] == 6'b101000) ? {inst[3:1]} : 3'b0;

// 数据存储器访问使能信号：当指令为加载或存储指令时使能
assign data_sram_en = (inst_lw | inst_lb | inst_lbu | inst_lh | inst_lhu | inst_sw | inst_sb | inst_sh) & mem_ce;

// 数据存储器写使能信号：只有存储指令才需要写存储器
assign data_sram_wen[3:0] = {4{inst_sw & mem_ce}} | {inst_sh & mem_ce, inst_sh & mem_ce, 1'b0, 1'b0} | {inst_sb & mem_ce, 1'b0, 1'b0, 1'b0};

// 数据存储器访问地址：使用EX阶段计算的结果作为地址
assign data_sram_addr = mem_addr;

// 写入存储器的数据：来自EX阶段传递的rs寄存器数据
assign data_sram_wdata = mem_wdata;

// 传递指令信息到WB阶段
assign mem_inst = inst;

// 从存储器读取的数据（对于加载指令）
assign mem_rdata = data_sram_rdata;

// HI/LO寄存器数据转发逻辑：如果WB阶段将要写HI/LO且当前指令需要读取HI/LO，则使用转发数据
assign hi_data_o = (wb_hi_we == 1'b1) ? wb_hi_data : hi_data;
assign lo_data_o = (wb_lo_we == 1'b1) ? wb_lo_data : lo_data;

// 写回寄存器堆的数据选择
assign rf_wdata = (inst[31:26] == 6'b100000) ? mem_rdata : mem_addr;  // 加载指令使用存储器数据，其他使用ALU结果

// 写回寄存器堆的地址：目标寄存器地址（rt字段）
assign rf_waddr = inst[20:16];

// 寄存器堆写使能：加载指令或算术逻辑指令需要写回
assign rf_we = (inst[31:26] == 6'b100000) ? mem_ce : (inst[31:26] != 6'b101000) ? 1'b1 : 1'b0;

// 输出到WB阶段的HI/LO数据总线
assign mem_hilo_bus = {
    hi_we,                     // HI寄存器写使能
    5'b0,                      // HI写地址（未使用，设为0）
    hi_data_o,                 // HI数据
    lo_we,                     // LO寄存器写使能
    5'b0,                      // LO写地址（未使用，设为0）
    lo_data_o                  // LO数据
};

// 输出到WB阶段的总线信号：包含写回寄存器堆所需的所有信息
assign mem_to_wb_bus = {
    mem_hilo_bus,              // HI/LO数据总线
    mem_op,                    // MEM操作码
    mem_pc,                    // 程序计数器
    data_sram_en,              // 数据存储器使能
    data_sram_wen,             // 数据存储器写使能
    1'b0,                      // 写回数据选择（未使用）
    rf_we,                     // 寄存器堆写使能
    rf_waddr,                  // 写回寄存器地址
    rf_wdata                   // 写回数据
};

// 数据转发总线：将MEM阶段的写回信息转发到ID阶段，用于解决数据相关
// 这样ID阶段可以提前获取到将要写回的数据，避免流水线停顿
assign mem_to_rf_bus = {
    rf_we,                     // 寄存器堆写使能
    rf_waddr,                  // 写回寄存器地址
    rf_wdata                   // 写回数据
};



    // 加载指令数据处理：根据不同的加载指令类型和地址对齐，对存储器数据进行符号扩展或零扩展
    assign mem_result = inst_lw ? data_sram_rdata:                        // lw指令：直接读取32位字数据
                        inst_lb  & ex_result[1:0]==2'b00 ? {{24{data_sram_rdata[7]}},data_sram_rdata[7:0]}:     // lb指令：字节加载，地址对齐00，符号扩展
                        inst_lb  & ex_result[1:0]==2'b01 ? {{24{data_sram_rdata[15]}},data_sram_rdata[15:8]}:   // lb指令：字节加载，地址对齐01，符号扩展
                        inst_lb  & ex_result[1:0]==2'b10 ? {{24{data_sram_rdata[23]}},data_sram_rdata[23:16]}:  // lb指令：字节加载，地址对齐10，符号扩展
                        inst_lb  & ex_result[1:0]==2'b11 ? {{24{data_sram_rdata[31]}},data_sram_rdata[31:24]}:  // lb指令：字节加载，地址对齐11，符号扩展
                        inst_lbu & ex_result[1:0]==2'b00 ? {{24{1'b0}},data_sram_rdata[7:0]}:                   // lbu指令：无符号字节加载，地址对齐00，零扩展
                        inst_lbu & ex_result[1:0]==2'b01 ? {{24{1'b0}},data_sram_rdata[15:8]}:                 // lbu指令：无符号字节加载，地址对齐01，零扩展
                        inst_lbu & ex_result[1:0]==2'b10 ? {{24{1'b0}},data_sram_rdata[23:16]}:                // lbu指令：无符号字节加载，地址对齐10，零扩展
                        inst_lbu & ex_result[1:0]==2'b11 ? {{24{1'b0}},data_sram_rdata[31:24]}:                // lbu指令：无符号字节加载，地址对齐11，零扩展
                        inst_lh  & ex_result[1:0]==2'b00 ? {{16{data_sram_rdata[15]}},data_sram_rdata[15:0]}:  // lh指令：半字加载，地址对齐00，符号扩展
                        inst_lh  & ex_result[1:0]==2'b10 ? {{16{data_sram_rdata[31]}},data_sram_rdata[31:16]}: // lh指令：半字加载，地址对齐10，符号扩展
                        inst_lhu & ex_result[1:0]==2'b00 ? {{16{1'b0}},data_sram_rdata[15:0]}:                 // lhu指令：无符号半字加载，地址对齐00，零扩展
                        inst_lhu & ex_result[1:0]==2'b10 ? {{16{1'b0}},data_sram_rdata[31:16]}:               // lhu指令：无符号半字加载，地址对齐10，零扩展
                        32'b0;                                                                                // 其他情况：返回0


    assign rf_wdata = sel_rf_res & data_ram_en ? mem_result : ex_result;

    assign mem_to_wb_bus = {
        hilo_bus,
        mem_pc,     // 69:38
        rf_we,      // 37
        rf_waddr,   // 36:32
        rf_wdata    // 31:0
    };

    assign mem_hilo_bus = hilo_bus;

    //forwarding线路,解决数据相关的,其实就是把是否要写回（rf_we），写回到哪儿(rf_waddr)，写回的内容(rf_wdata)等信息封装成一条线,在ID段解包
    assign mem_to_rf_bus = {
        // hilo_bus,
        rf_we,
        rf_waddr,
        rf_wdata
    };


endmodule