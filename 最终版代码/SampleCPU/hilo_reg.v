`include "lib/defines.vh"
// HI/LO寄存器模块：用于存储乘除法指令的结果
// MIPS架构中，乘法结果的高32位存储在HI寄存器，低32位存储在LO寄存器
// 除法指令的余数存储在HI寄存器，商存储在LO寄存器
module hilo_reg(
    input wire clk,                      // 时钟信号
    input wire rst,                      // 复位信号
    input wire [`StallBus-1:0] stall,   // 流水线暂停控制信号

    // 各阶段的HI/LO操作信息
    input wire [65:0] ex_hilo_bus,      // EX阶段的HI/LO操作信息
    input wire [65:0] mem_hilo_bus,     // MEM阶段的HI/LO操作信息
    input wire [65:0] hilo_bus,         // WB阶段的HI/LO操作信息

    // HI/LO寄存器当前值，输出给EX阶段使用
    output reg [31:0] hi_data,          // HI寄存器当前值
    output reg [31:0] lo_data           // LO寄存器当前值
);

    // HI/LO寄存器实际存储
    reg [31:0] reg_hi, reg_lo;

    // 解析各阶段的HI/LO操作信息
    // WB阶段信息
    wire wb_hi_we, wb_lo_we;             // WB阶段的HI/LO写使能
    wire [31:0] wb_hi_in, wb_lo_in;      // WB阶段的HI/LO写入数据

    // EX阶段信息
    wire ex_hi_we, ex_lo_we;             // EX阶段的HI/LO写使能
    wire [31:0] ex_hi_in, ex_lo_in;      // EX阶段的HI/LO写入数据

    // MEM阶段信息
    wire mem_hi_we, mem_lo_we;           // MEM阶段的HI/LO写使能
    wire [31:0] mem_hi_in, mem_lo_in;    // MEM阶段的HI/LO写入数据

    // 解析WB阶段的HI/LO操作信息
    assign {
        wb_hi_we, 
        wb_lo_we,
        wb_hi_in,
        wb_lo_in
    } = hilo_bus;

    // 解析EX阶段的HI/LO操作信息
    assign {
        ex_hi_we,
        ex_lo_we,
        ex_hi_in,
        ex_lo_in
    } = ex_hilo_bus;

    // 解析MEM阶段的HI/LO操作信息
    assign {
        mem_hi_we,
        mem_lo_we,
        mem_hi_in,
        mem_lo_in
    } = mem_hilo_bus;

    // HI寄存器更新逻辑
    always @ (posedge clk) begin
        if (rst) begin
            reg_hi <= 32'b0;             // 复位时清零
        end
        else if (wb_hi_we) begin
            reg_hi <= wb_hi_in;          // WB阶段写入HI寄存器
        end
    end

    // LO寄存器更新逻辑
    always @ (posedge clk) begin
        if (rst) begin
            reg_lo <= 32'b0;             // 复位时清零
        end
        else if (wb_lo_we) begin
            reg_lo <= wb_lo_in;          // WB阶段写入LO寄存器
        end
    end

    // 前推逻辑：选择合适的HI/LO数据输出给EX阶段
    // 优先级：EX > MEM > WB > 当前寄存器值
    wire [31:0] hi_temp, lo_temp;
    
    assign hi_temp = ex_hi_we  ? ex_hi_in    // EX阶段有写操作，使用EX阶段的数据
                   : mem_hi_we ? mem_hi_in   // MEM阶段有写操作，使用MEM阶段的数据
                   : wb_hi_we  ? wb_hi_in    // WB阶段有写操作，使用WB阶段的数据
                   : reg_hi;                 // 否则使用当前寄存器值
    
    assign lo_temp = ex_lo_we  ? ex_lo_in    // EX阶段有写操作，使用EX阶段的数据
                   : mem_lo_we ? mem_lo_in   // MEM阶段有写操作，使用MEM阶段的数据
                   : wb_lo_we  ? wb_lo_in    // WB阶段有写操作，使用WB阶段的数据
                   : reg_lo;                 // 否则使用当前寄存器值

    // 根据流水线暂停状态，输出HI/LO数据
    always @ (posedge clk) begin
        if (rst) begin
            {hi_data, lo_data} <= {32'b0, 32'b0};  // 复位时清零
        end
        else if(stall[2] == `Stop && stall[3] == `NoStop) begin
            // EX阶段暂停，MEM阶段不暂停：输出0，避免数据相关
            {hi_data, lo_data} <= {32'b0, 32'b0};
        end
        else if (stall[2] == `NoStop) begin
            // EX阶段不暂停：输出前推的数据
            {hi_data, lo_data} <= {hi_temp, lo_temp};
        end
    end
endmodule