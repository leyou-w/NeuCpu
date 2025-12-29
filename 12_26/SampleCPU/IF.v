// IF模块：流水线中的指令获取阶段
// 负责从指令存储器中获取指令，并计算下一条指令的地址
// 处理分支跳转指令和流水线暂停控制
module IF(
    input wire clk,                      // 时钟信号
    input wire rst,                      // 复位信号
    input wire [`StallBus-1:0] stall,   // 流水线暂停控制信号

    // input wire flush,                   // 流水线刷新信号（当前未使用）
    // input wire [31:0] new_pc,          // 新PC值（当前未使用）

    input wire [`BR_WD-1:0] br_bus,      // 分支指令信息总线

    output wire [`IF_TO_ID_WD-1:0] if_to_id_bus,  // 输出到ID阶段的总线信号

    output wire inst_sram_en,            // 指令存储器使能信号，控制是否取指
    output wire [3:0] inst_sram_wen,     // 指令存储器写使能（字使能），指令存储器通常只读不写
    output wire [31:0] inst_sram_addr,   // 指令存储器访问地址
    output wire [31:0] inst_sram_wdata   // 指令存储器写数据（通常为0，因为指令存储器只读）
);
    reg [31:0] pc_reg;          // 程序计数器寄存器，存储当前指令地址
    reg ce_reg;                 // 芯片使能寄存器，控制指令存储器访问
    wire [31:0] next_pc;        // 下一条指令的地址
    wire br_e;                  // 分支指令使能信号，指示是否发生分支跳转
    wire [31:0] br_addr;        // 分支目标地址

    // 从分支总线中解析出分支使能信号和分支地址
    assign {
        br_e,                   // 分支指令使能信号
        br_addr                 // 分支目标地址
    } = br_bus;         // 跳转指令信息总线

    // PC寄存器更新逻辑：时序逻辑，在时钟上升沿更新
    always @ (posedge clk) begin
        if (rst) begin
            // 复位时，PC设置为初始地址0xbfbf_fffc（MIPS架构的复位向量）
            pc_reg <= 32'hbfbf_fffc;
        end
        else if (stall[0]==`NoStop) begin
            // 如果IF阶段没有被暂停，则更新PC到下一条指令地址
            pc_reg <= next_pc;
        end
        // 如果IF阶段被暂停，PC保持不变
    end

    // 芯片使能寄存器更新逻辑：时序逻辑，在时钟上升沿更新
    always @ (posedge clk) begin
        if (rst) begin
            // 复位时，禁用芯片使能
            ce_reg <= 1'b0;
        end
        else if (stall[0]==`NoStop) begin
            // 如果IF阶段没有被暂停，则启用芯片使能
            ce_reg <= 1'b1;
        end
        // 如果IF阶段被暂停，保持当前使能状态
    end

    // 下一条PC地址计算：组合逻辑
    assign next_pc = br_e ? br_addr             // 如果有分支跳转，下一条PC为分支目标地址
                   : pc_reg + 32'h4;           // 否则，下一条PC为当前PC+4（顺序执行）

    // 指令存储器控制信号
    assign inst_sram_en = ce_reg;               // 指令存储器使能信号
    assign inst_sram_wen = 4'b0;                // 指令存储器写使能，设为0（只读）
    assign inst_sram_addr = pc_reg;             // 指令存储器访问地址为当前PC
    assign inst_sram_wdata = 32'b0;             // 指令存储器写数据，设为0（只读）
    
    // 输出到ID阶段的总线信号：包含指令使能和PC值
    assign if_to_id_bus = {
        ce_reg,                                 // 指令使能信号
        pc_reg                                  // 当前PC值
    };

endmodule