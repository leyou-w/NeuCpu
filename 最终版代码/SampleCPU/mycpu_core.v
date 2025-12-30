`include "lib/defines.vh"
// CPU核心模块：实现五级流水线（IF、ID、EX、MEM、WB）的MIPS处理器
// 增加了数据前推和暂停控制机制，解决数据相关和控制相关问题
module mycpu_core(          
    input wire clk,                      // 时钟信号
    input wire rst,                      // 复位信号
    input wire [5:0] int,                // 中断信号

    // 指令存储器接口
    output wire inst_sram_en,             // 指令存储器使能信号
    output wire [3:0] inst_sram_wen,      // 指令存储器写使能（字使能）
    output wire [31:0] inst_sram_addr,    // 指令存储器地址
    output wire [31:0] inst_sram_wdata,   // 指令存储器写数据
    input wire [31:0] inst_sram_rdata,    // 指令存储器读数据

    // 数据存储器接口
    output wire data_sram_en,             // 数据存储器使能信号
    output wire [3:0] data_sram_wen,      // 数据存储器写使能（字使能）
    output wire [31:0] data_sram_addr,    // 数据存储器地址
    output wire [31:0] data_sram_wdata,   // 数据存储器写数据
    input wire [31:0] data_sram_rdata,    // 数据存储器读数据

    // 调试接口
    output wire [31:0] debug_wb_pc,       // 写回阶段的PC值
    output wire [3:0] debug_wb_rf_wen,    // 寄存器堆写使能
    output wire [4:0] debug_wb_rf_wnum,  // 写回的寄存器号
    output wire [31:0] debug_wb_rf_wdata  // 写回的数据
);
    
    // 流水线各阶段之间的数据总线
    wire [`IF_TO_ID_WD-1:0] if_to_id_bus;    // IF到ID的数据通路
    wire [`ID_TO_EX_WD-1:0] id_to_ex_bus;    // ID到EX的数据通路
    wire [`EX_TO_MEM_WD-1:0] ex_to_mem_bus;  // EX到MEM的数据通路
    wire [`MEM_TO_WB_WD-1:0] mem_to_wb_bus;  // MEM到WB的数据通路
    
    // 控制信号
    wire [`BR_WD-1:0] br_bus;                // 分支跳转控制信号
    wire [`DATA_SRAM_WD-1:0] ex_dt_sram_bus; // EX阶段的数据存储器控制信号
    
    // 数据前推通路（解决RAW数据相关）
    wire [`WB_TO_RF_WD-1:0] wb_to_rf_bus;    // WB段前递到ID段的信息
    wire [`EX_TO_RF_WD-1:0] ex_to_rf_bus;    // EX段前递到ID段的信息
    wire [`MEM_TO_RF_WD-1:0] mem_to_rf_bus;  // MEM段前递到ID段的信息
    
    // HI/LO寄存器相关信号
    wire [65:0] ex_hilo_bus;                // EX阶段的HI/LO操作信息
    wire [65:0] mem_hilo_bus;               // MEM阶段的HI/LO操作信息
    wire [65:0] hilo_bus;                   // WB阶段的HI/LO操作信息
    
    // 暂停控制相关信号
    wire [`StallBus-1:0] stall;             // 流水线暂停控制信号
    wire [7:0] memop_from_ex;               // EX阶段的内存操作信息，用于检测load指令
    wire stallreq;                           // 暂停请求信号（load相关）
    wire stallreq_ex;                        // 暂停请求信号（EX相关）
    
    // HI/LO寄存器数据
    wire [31:0] hi_data, lo_data;           // 当前HI/LO寄存器的值

    // IF阶段实例：取指阶段
    IF u_IF(
    	.clk             (clk             ),
        .rst             (rst             ),
        .stall           (stall           ),             // 流水线暂停控制信号
        .br_bus          (br_bus          ),             // 分支跳转控制信号
        .if_to_id_bus    (if_to_id_bus    ),             // IF段输出到ID段的数据
        .inst_sram_en    (inst_sram_en    ),             // 指令存储器使能
        .inst_sram_wen   (inst_sram_wen   ),             // 指令存储器写使能
        .inst_sram_addr  (inst_sram_addr  ),             // 指令存储器地址
        .inst_sram_wdata (inst_sram_wdata )              // 指令存储器写数据
    );
    
    // ID阶段实例：译码与寄存器读取阶段
    // 增加了数据前推和暂停控制逻辑
    ID u_ID(
    	.clk             (clk             ),
        .rst             (rst             ),
        .stall           (stall           ),             // 流水线暂停控制信号
        .stallreq_for_load  (stallreq     ),             // load指令引起的暂停请求
        .memop_from_ex   (memop_from_ex   ),             // EX阶段的内存操作信息，用于检测load指令
        .ex_ram_read     (ex_to_mem_bus[38]),             // EX阶段的内存读信号
        .if_to_id_bus    (if_to_id_bus    ),             // IF段输入到ID段的数据
        .inst_sram_rdata (inst_sram_rdata ),             // 指令存储器读数据
        .wb_to_rf_bus    (wb_to_rf_bus    ),             // WB段前递到ID段的数据（数据前推）
        .ex_to_rf_bus    (ex_to_rf_bus    ),             // EX段前递到ID段的数据（数据前推）
        .mem_to_rf_bus   (mem_to_rf_bus   ),             // MEM段前递到ID段的数据（数据前推）
        .id_to_ex_bus    (id_to_ex_bus    ),             // ID段输出到EX段的数据
        .br_bus          (br_bus          )              // 分支跳转控制信号
    );

    // EX阶段实例：执行阶段
    // 增加了HI/LO寄存器支持和暂停控制逻辑
    EX u_EX(
    	.clk             (clk             ),
        .rst             (rst             ),
        .stall           (stall           ),             // 流水线暂停控制信号
        .id_to_ex_bus    (id_to_ex_bus    ),             // ID段输入到EX段的数据
        .ex_to_mem_bus   (ex_to_mem_bus   ),             // EX段输出到MEM段的数据
        .memop_from_ex   (memop_from_ex   ),             // EX阶段的内存操作信息，传递给ID段
        .ex_hilo_bus     (ex_hilo_bus     ),             // EX段输出的HI/LO操作信息
        .stallreq_for_ex (stallreq_ex     ),             // EX阶段引起的暂停请求
        .hi_data         (hi_data         ),             // HI寄存器当前值
        .lo_data         (lo_data         ),             // LO寄存器当前值
        .data_sram_en    (data_sram_en    ),             // 数据存储器使能
        .data_sram_wen   (data_sram_wen   ),             // 数据存储器写使能
        .data_sram_addr  (data_sram_addr  ),             // 数据存储器地址
        .data_sram_wdata (data_sram_wdata ),             // 数据存储器写数据
        .ex_to_rf_bus    (ex_to_rf_bus    )              // EX段前递到ID段的数据（数据前推）
    );

    // MEM阶段实例：内存访问阶段
    // 增加了内存访问处理和数据前推逻辑
    MEM u_MEM(
    	.clk             (clk             ),
        .rst             (rst             ),
        .stall           (stall           ),             // 流水线暂停控制信号
        .ex_to_mem_bus   (ex_to_mem_bus   ),             // EX段输入到MEM段的数据
        .mem_hilo_bus    (mem_hilo_bus    ),             // MEM段输出的HI/LO操作信息
        .data_sram_rdata (data_sram_rdata ),             // 数据存储器读数据
        .mem_to_wb_bus   (mem_to_wb_bus   ),             // MEM段输出到WB段的数据
        .mem_to_rf_bus   (mem_to_rf_bus   )              // MEM段前递到ID段的数据（数据前推）
    );
    
    // WB阶段实例：写回阶段
    // 增加了HI/LO寄存器支持
    WB u_WB(
    	.clk               (clk               ),
        .rst               (rst               ),
        .stall             (stall             ),             // 流水线暂停控制信号
        .mem_to_wb_bus     (mem_to_wb_bus     ),             // MEM段输入到WB段的数据
        .wb_to_rf_bus      (wb_to_rf_bus      ),             // WB段输出到寄存器堆的数据
        .hilo_bus          (hilo_bus          ),             // WB段输出的HI/LO操作信息
        .debug_wb_pc       (debug_wb_pc       ),             // 调试用：写回阶段的PC值
        .debug_wb_rf_wen   (debug_wb_rf_wen   ),             // 调试用：寄存器堆写使能
        .debug_wb_rf_wnum  (debug_wb_rf_wnum  ),             // 调试用：写回的寄存器号
        .debug_wb_rf_wdata (debug_wb_rf_wdata )              // 调试用：写回的数据
    );

    // CTRL模块实例：流水线控制单元
    // 增加了暂停请求处理逻辑
    CTRL u_CTRL(
    	.rst               (rst               ),
    	.stallreq_for_load (stallreq          ),             // load指令引起的暂停请求
    	.stallreq_for_ex   (stallreq_ex       ),             // EX阶段引起的暂停请求
        .stall             (stall             )              // 输出的流水线暂停控制信号
    );

    // HI/LO寄存器模块实例
    // 用于乘除法指令的高低位结果存储
    hilo_reg u_hilo_reg(
        .clk                (clk                   ),
        .rst                (rst                   ),
        .stall              (stall                 ),             // 流水线暂停控制信号

        .ex_hilo_bus        (ex_hilo_bus           ),             // EX阶段的HI/LO操作信息
        .mem_hilo_bus       (mem_hilo_bus          ),             // MEM阶段的HI/LO操作信息

        .hilo_bus           (hilo_bus              ),             // WB阶段的HI/LO操作信息

        .hi_data            (hi_data               ),             // HI寄存器当前值
        .lo_data            (lo_data               )              // LO寄存器当前值
    );
    
endmodule