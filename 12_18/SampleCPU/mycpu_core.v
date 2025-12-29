// 引入自定义宏定义（总线宽度、控制信号等）
`include "lib/defines.vh"

// CPU核心顶层模块：集成五级流水线+控制单元，实现指令流水线执行
module mycpu_core(
    input wire clk,              // 全局时钟
    input wire rst,              // 全局复位
    input wire [5:0] int,        // 6位外部中断请求

    // 指令SRAM接口信号
    output wire inst_sram_en,    // 指令SRAM使能
    output wire [3:0] inst_sram_wen,  // 指令SRAM字节写使能
    output wire [31:0] inst_sram_addr, // 指令SRAM地址
    output wire [31:0] inst_sram_wdata,// 指令SRAM写数据
    input wire [31:0] inst_sram_rdata, // 指令SRAM读数据

    // 数据SRAM接口信号
    output wire data_sram_en,    // 数据SRAM使能
    output wire [3:0] data_sram_wen,  // 数据SRAM字节写使能
    output wire [31:0] data_sram_addr, // 数据SRAM地址
    output wire [31:0] data_sram_wdata,// 数据SRAM写数据
    input wire [31:0] data_sram_rdata, // 数据SRAM读数据

    // 调试接口信号（回写阶段）
    output wire [31:0] debug_wb_pc,       // 回写阶段PC
    output wire [3:0] debug_wb_rf_wen,    // 回写阶段寄存器写使能
    output wire [4:0] debug_wb_rf_wnum,   // 回写阶段寄存器编号
    output wire [31:0] debug_wb_rf_wdata  // 回写阶段寄存器写数据
);

    // 内部总线/信号定义
    wire [`IF_TO_ID_WD-1:0] if_to_id_bus;   // IF→ID阶段总线（指令、PC等）
    wire [`ID_TO_EX_WD-1:0] id_to_ex_bus;   // ID→EX阶段总线（操作数、控制信号等）
    wire [`EX_TO_MEM_WD-1:0] ex_to_mem_bus; // EX→MEM阶段总线（执行结果、访存控制等）
    wire [`MEM_TO_WB_WD-1:0] mem_to_wb_bus; // MEM→WB阶段总线（访存结果、写回信息等）
    wire [`BR_WD-1:0] br_bus;               // 分支控制总线（跳转地址、判断结果等）
    wire [`DATA_SRAM_WD-1:0] ex_dt_sram_bus;// EX→数据SRAM控制总线（预留）
    wire [`WB_TO_RF_WD-1:0] wb_to_rf_bus;   // WB→寄存器堆写回总线
    wire [`StallBus-1:0] stall;             // 流水线暂停控制信号

    // 实例化取指阶段模块：获取指令、更新PC
    IF u_IF(
    	.clk             (clk             ),
        .rst             (rst             ),
        .stall           (stall           ),
        .br_bus          (br_bus          ),
        .if_to_id_bus    (if_to_id_bus    ),
        .inst_sram_en    (inst_sram_en    ),
        .inst_sram_wen   (inst_sram_wen   ),
        .inst_sram_addr  (inst_sram_addr  ),
        .inst_sram_wdata (inst_sram_wdata )
    );

    // 实例化译码阶段模块：指令译码、读取寄存器、分支判断
    ID u_ID(
    	.clk             (clk             ),
        .rst             (rst             ),
        .stall           (stall           ),
        .stallreq        (stallreq        ),
        .if_to_id_bus    (if_to_id_bus    ),
        .inst_sram_rdata (inst_sram_rdata ),
        .wb_to_rf_bus    (wb_to_rf_bus    ),
        .id_to_ex_bus    (id_to_ex_bus    ),
        .br_bus          (br_bus          )
    );

    // 实例化执行阶段模块：运算执行、地址生成、数据SRAM控制
    EX u_EX(
    	.clk             (clk             ),
        .rst             (rst             ),
        .stall           (stall           ),
        .id_to_ex_bus    (id_to_ex_bus    ),
        .ex_to_mem_bus   (ex_to_mem_bus   ),
        .data_sram_en    (data_sram_en    ),
        .data_sram_wen   (data_sram_wen   ),
        .data_sram_addr  (data_sram_addr  ),
        .data_sram_wdata (data_sram_wdata )
    );

    // 实例化访存阶段模块：数据SRAM访问、结果暂存
    MEM u_MEM(
    	.clk             (clk             ),
        .rst             (rst             ),
        .stall           (stall           ),
        .ex_to_mem_bus   (ex_to_mem_bus   ),
        .data_sram_rdata (data_sram_rdata ),
        .mem_to_wb_bus   (mem_to_wb_bus   )
    );
    
    // 实例化回写阶段模块：结果写回寄存器堆、输出调试信息
    WB u_WB(
    	.clk               (clk               ),
        .rst               (rst               ),
        .stall             (stall             ),
        .mem_to_wb_bus     (mem_to_wb_bus     ),
        .wb_to_rf_bus      (wb_to_rf_bus      ),
        .debug_wb_pc       (debug_wb_pc       ),
        .debug_wb_rf_wen   (debug_wb_rf_wen   ),
        .debug_wb_rf_wnum  (debug_wb_rf_wnum  ),
        .debug_wb_rf_wdata (debug_wb_rf_wdata )
    );

    // 实例化控制单元：流水线暂停控制、系统复位处理
    CTRL u_CTRL(
    	.rst   (rst   ),
        .stall (stall )
    );
    
endmodule
