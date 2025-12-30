// WB模块：流水线中的写回阶段
// 负责将计算结果写回到寄存器堆，同时处理HI/LO寄存器的写回操作
// 提供调试接口用于与龙芯实验平台进行指令比对
`include "lib/defines.vh"
module WB(
    input wire clk,                              // 时钟信号
    input wire rst,                              // 复位信号
    // input wire flush,                         // 流水线刷新信号（当前未使用）
    input wire [`StallBus-1:0] stall,           // 流水线暂停控制信号

    input wire [`MEM_TO_WB_WD-1:0] mem_to_wb_bus, // 来自MEM阶段的总线信号

    output wire [`WB_TO_RF_WD-1:0] wb_to_rf_bus, // 输出到寄存器堆的写回总线
    output wire [65:0] hilo_bus,                 // HI/LO寄存器数据总线

    // 调试接口：用于与龙芯实验平台进行指令比对
    output wire [31:0] debug_wb_pc,              // 调试用程序计数器
    output wire [3:0] debug_wb_rf_wen,           // 调试用寄存器写使能
    output wire [4:0] debug_wb_rf_wnum,          // 调试用寄存器编号
    output wire [31:0] debug_wb_rf_wdata         // 调试用寄存器写数据
);

    reg [`MEM_TO_WB_WD-1:0] mem_to_wb_bus_r;  // MEM到WB阶段的流水线寄存器

    // 流水线寄存器控制逻辑：处理流水线暂停和指令缓存
    always @ (posedge clk) begin
        if (rst) begin
            // 复位时，清空流水线寄存器
            mem_to_wb_bus_r <= `MEM_TO_WB_WD'b0;
        end
        // else if (flush) begin
        //     // 流水线刷新时，清空寄存器（当前未使用）
        //     mem_to_wb_bus_r <= `MEM_TO_WB_WD'b0;
        // end
        else if (stall[4]==`Stop && stall[5]==`NoStop) begin
            // WB阶段暂停但后续阶段不暂停时，插入空操作（NOP）
            mem_to_wb_bus_r <= `MEM_TO_WB_WD'b0;
        end
        else if (stall[4]==`NoStop) begin
            // WB阶段不暂停时，正常接收来自MEM阶段的数据
            mem_to_wb_bus_r <= mem_to_wb_bus;
        end
        // WB阶段暂停时，保持当前寄存器值不变
    end

    // 从MEM阶段总线中解析出的各个控制信号和数据
    wire [31:0] wb_pc;          // 程序计数器值
    wire rf_we;                 // 寄存器堆写使能信号
    wire [4:0] rf_waddr;        // 写回的寄存器地址
    wire [31:0] rf_wdata;       // 写回的数据

    // 从MEM阶段总线中解析出各个信号
    assign {
        hilo_bus,               // HI/LO寄存器数据总线
        wb_pc,                  // 程序计数器
        rf_we,                  // 寄存器堆写使能
        rf_waddr,               // 写回寄存器地址
        rf_wdata                // 写回数据
    } = mem_to_wb_bus_r;

    // 输出到寄存器堆的写回总线：包含写回所需的所有信息
    assign wb_to_rf_bus = {
        rf_we,                  // 寄存器堆写使能
        rf_waddr,               // 写回寄存器地址
        rf_wdata                // 写回数据
    };

    // 调试接口：用于与龙芯实验平台进行指令比对
    // 这些信号会被实验平台捕获，用于验证指令执行是否正确
    assign debug_wb_pc = wb_pc;                         // 当前指令的PC值
    assign debug_wb_rf_wen = {4{rf_we}};                // 寄存器写使能（扩展到4位）
    assign debug_wb_rf_wnum = rf_waddr;                 // 目标寄存器编号
    assign debug_wb_rf_wdata = rf_wdata;                // 写入寄存器的数据

    
endmodule