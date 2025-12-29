// CPU顶层模块：连接CPU核心与外部存储器和调试接口
// 包含MMU（内存管理单元）用于地址转换，以及调试接口用于监控CPU状态
module mycpu_top(
    input wire clk,                      // 时钟信号
    input wire resetn,                   // 低电平复位信号（注意：内部使用~resetn作为高电平复位）
    input wire [5:0] ext_int,            // 外部中断信号

    // 指令存储器接口
    output wire inst_sram_en,             // 指令存储器使能信号
    output wire [3:0] inst_sram_wen,     // 指令存储器写使能（字使能）
    output wire [31:0] inst_sram_addr,   // 指令存储器访问地址
    output wire [31:0] inst_sram_wdata,  // 指令存储器写数据
    input wire [31:0] inst_sram_rdata,   // 指令存储器读数据

    // 数据存储器接口
    output wire data_sram_en,            // 数据存储器使能信号
    output wire [3:0] data_sram_wen,     // 数据存储器写使能（字使能）
    output wire [31:0] data_sram_addr,   // 数据存储器访问地址
    output wire [31:0] data_sram_wdata,  // 数据存储器写数据
    input wire [31:0] data_sram_rdata,   // 数据存储器读数据

    // 调试接口：用于监控CPU写回阶段的状态
    output wire [31:0] debug_wb_pc,       // 写回阶段的PC值
    output wire [3:0] debug_wb_rf_wen,   // 写回阶段的寄存器堆写使能
    output wire [4:0] debug_wb_rf_wnum,  // 写回阶段的寄存器号
    output wire [31:0] debug_wb_rf_wdata // 写回阶段的数据
);

    // CPU核心与MMU之间的内部地址信号
    wire [31:0] inst_sram_addr_v, data_sram_addr_v;

    // CPU核心实例化：实现五级流水线的MIPS处理器
    mycpu_core u_mycpu_core(
        .clk               (clk               ),            // 时钟信号
        .rst               (~resetn           ),            // 复位信号（取反，因为resetn是低电平有效）
        .int               (ext_int           ),            // 外部中断信号
        .inst_sram_en      (inst_sram_en      ),            // 指令存储器使能信号
        .inst_sram_wen     (inst_sram_wen     ),            // 指令存储器写使能
        .inst_sram_addr    (inst_sram_addr_v  ),            // 指令存储器内部地址（经过MMU转换前）
        .inst_sram_wdata   (inst_sram_wdata   ),            // 指令存储器写数据
        .inst_sram_rdata   (inst_sram_rdata   ),            // 指令存储器读数据
        .data_sram_en      (data_sram_en      ),            // 数据存储器使能信号
        .data_sram_wen     (data_sram_wen     ),            // 数据存储器写使能
        .data_sram_addr    (data_sram_addr_v  ),            // 数据存储器内部地址（经过MMU转换前）
        .data_sram_wdata   (data_sram_wdata   ),            // 数据存储器写数据
        .data_sram_rdata   (data_sram_rdata   ),            // 数据存储器读数据
        .debug_wb_pc       (debug_wb_pc       ),            // 调试用：写回阶段的PC值
        .debug_wb_rf_wen   (debug_wb_rf_wen   ),            // 调试用：写回阶段的寄存器堆写使能
        .debug_wb_rf_wnum  (debug_wb_rf_wnum  ),            // 调试用：写回阶段的寄存器号
        .debug_wb_rf_wdata (debug_wb_rf_wdata )             // 调试用：写回阶段的数据
    );

    // 指令存储器MMU实例化：用于指令地址转换
    mmu u0_mmu(
        .addr_i (inst_sram_addr_v ),          // 输入：CPU核心产生的指令地址
        .addr_o (inst_sram_addr   )           // 输出：转换后的实际物理地址
    );

    // 数据存储器MMU实例化：用于数据地址转换
    mmu u1_mmu(
        .addr_i (data_sram_addr_v ),          // 输入：CPU核心产生的数据地址
        .addr_o (data_sram_addr   )           // 输出：转换后的实际物理地址
    );
    
    
    
    
endmodule 