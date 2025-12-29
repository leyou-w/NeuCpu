`include "lib/defines.vh"
module EX(
    input wire clk,
    input wire rst,
    // input wire flush,
    input wire [`StallBus-1:0] stall,
    input wire [31:0] hi_data,
    input wire [31:0] lo_data,
    

    input wire [`ID_TO_EX_WD-1:0] id_to_ex_bus,

    output wire [`EX_TO_MEM_WD-1:0] ex_to_mem_bus,
    
    output wire [7:0] memop_from_ex,
    output wire [65:0] ex_hilo_bus,
    output wire stallreq_for_ex,

    output wire data_sram_en,
    output wire [3:0] data_sram_wen,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    output wire [`EX_TO_RF_WD-1:0] ex_to_rf_bus       //前推线路
);

    reg [`ID_TO_EX_WD-1:0] id_to_ex_bus_r;

    // 流水线寄存器：在时钟上升沿锁存ID阶段传来的信息
    // 这样可以在下一个时钟周期使用稳定的数据执行EX阶段操作
    always @ (posedge clk) begin
        if (rst) begin
            // 复位时清零流水线寄存器
            id_to_ex_bus_r <= `ID_TO_EX_WD'b0;
        end
        // else if (flush) begin
        //     id_to_ex_bus_r <= `ID_TO_EX_WD'b0;
        // end
        else if (stall[2]==`Stop && stall[3]==`NoStop) begin
            // EX阶段暂停但MEM阶段不暂停：插入空操作（NOP）
            // 避免数据相关，确保流水线正确执行
            id_to_ex_bus_r <= `ID_TO_EX_WD'b0;
        end
        else if (stall[2]==`NoStop) begin
            // EX阶段不暂停：正常接收ID阶段的数据
            id_to_ex_bus_r <= id_to_ex_bus;
        end
    end

    wire [31:0] ex_pc, inst;
    wire [11:0] alu_op;
    wire [2:0] sel_alu_src1;
    wire [3:0] sel_alu_src2;
    wire data_ram_en;
    wire [3:0] data_ram_wen;
    wire rf_we;
    wire [4:0] rf_waddr;
    wire sel_rf_res;
    wire [31:0] rf_rdata1, rf_rdata2;
    reg is_in_delayslot;
    wire [7:0] mem_op;
    wire [8:0] hilo_op;

    // 从ID阶段传来的总线中解包各个控制信号和数据
    // 总线包含了EX阶段执行指令所需的所有信息
    assign {
        hilo_op,        // HI/LO寄存器操作控制信号
        mem_op,         // 存储器操作控制信号（load/store指令）
        ex_pc,          // 当前指令的PC值（148:117位）
        inst,           // 当前指令的机器码（116:85位）
        alu_op,         // ALU操作控制信号（84:83位）
        sel_alu_src1,   // ALU源操作数1选择信号（82:80位）
        sel_alu_src2,   // ALU源操作数2选择信号（79:76位）
        data_ram_en,    // 数据存储器使能信号（75位）
        data_ram_wen,   // 数据存储器写使能信号（74:71位）
        rf_we,          // 寄存器文件写使能信号（70位）
        rf_waddr,       // 寄存器文件写地址（69:65位）
        sel_rf_res,     // 寄存器文件结果选择信号（64位）
        rf_rdata1,      // 寄存器文件读数据1（63:32位）
        rf_rdata2       // 寄存器文件读数据2（31:0位）
    } = id_to_ex_bus_r;


    // ALU运算单元：准备ALU的源操作数
    // 根据指令类型，ALU的源操作数可能来自寄存器、立即数、PC值或移位量
    
    // 立即数扩展：将16位立即数扩展为32位
    wire [31:0] imm_sign_extend, imm_zero_extend, sa_zero_extend;
    assign imm_sign_extend = {{16{inst[15]}},inst[15:0]};  // 符号扩展：用于有符号立即数
    assign imm_zero_extend = {16'b0, inst[15:0]};         // 零扩展：用于无符号立即数
    assign sa_zero_extend = {27'b0,inst[10:6]};            // 移位量扩展：用于移位指令

    wire [31:0] alu_src1, alu_src2;      // ALU的两个源操作数
    wire [31:0] alu_result, ex_result, hilo_result;  // 各种运算结果
    wire [65:0] hilo_bus;                // HI/LO操作总线

    // ALU源操作数1选择逻辑
    // 根据sel_alu_src1信号选择ALU的第一个源操作数
    assign alu_src1 = sel_alu_src1[1] ? ex_pc :           // 选择PC值（用于跳转指令的地址计算）
                      sel_alu_src1[2] ? sa_zero_extend :  // 选择移位量（用于移位指令）
                      rf_rdata1;                          // 默认选择寄存器rs的值

    // ALU源操作数2选择逻辑
    // 根据sel_alu_src2信号选择ALU的第二个源操作数
    assign alu_src2 = sel_alu_src2[1] ? imm_sign_extend :  // 选择符号扩展立即数
                      sel_alu_src2[2] ? 32'd8 :             // 选择常数8（用于跳转指令的PC+8）
                      sel_alu_src2[3] ? imm_zero_extend :  // 选择零扩展立即数
                      rf_rdata2;                           // 默认选择寄存器rt的值
    
    alu u_alu(
    	.alu_control (alu_op ),
        .alu_src1    (alu_src1    ),
        .alu_src2    (alu_src2    ),
        .alu_result  (alu_result  )
    );

    // 存储指令处理：支持字节、半字、字存储操作
    // 根据指令类型生成相应的存储器控制信号
    
    // 存储器操作指令解码
    wire inst_lb, inst_lbu,  inst_lh, inst_lhu, inst_lw;  // 加载指令
    wire inst_sb, inst_sh,   inst_sw;                      // 存储指令

    // 从存储器操作控制信号中解码具体指令类型
    assign {inst_lb, inst_lbu, inst_lh, inst_lhu,
            inst_lw, inst_sb,  inst_sh, inst_sw} = mem_op;

    // 数据存储器地址：使用ALU计算结果作为存储器地址
    assign data_sram_addr   = alu_result; 

    // 数据存储器使能信号：直接使用ID阶段传来的使能信号
    assign data_sram_en = data_ram_en;
    
    // 数据存储器写使能信号生成：根据存储指令类型和地址对齐
    // 写使能信号为4位，对应32位字的4个字节
    assign data_sram_wen = inst_sw ? 4'b1111 :                    // 字存储：所有4个字节都使能
                           inst_sb & alu_result[1:0]==2'b00 ? 4'b0001 :  // 字节存储到地址0：使能最低字节
                           inst_sb & alu_result[1:0]==2'b01 ? 4'b0010 :  // 字节存储到地址1：使能第1字节
                           inst_sb & alu_result[1:0]==2'b10 ? 4'b0100 :  // 字节存储到地址2：使能第2字节
                           inst_sb & alu_result[1:0]==2'b11 ? 4'b1000 :  // 字节存储到地址3：使能最高字节
                           inst_sh & alu_result[1:0]==2'b00 ? 4'b0011 :  // 半字存储到地址0：使能低2字节
                           inst_sh & alu_result[1:0]==2'b10 ? 4'b1100 :  // 半字存储到地址2：使能高2字节
                           4'b0;                                        // 其他情况：不使能写操作
                           
    // 数据存储器写数据准备：根据存储指令类型进行数据扩展
    assign data_sram_wdata = inst_sw ? rf_rdata2 :                    // 字存储：直接使用寄存器值
                             inst_sb ? {4{rf_rdata2[7:0]}} :          // 字节存储：将字节复制4次到32位字
                             inst_sh ? {2{rf_rdata2[15:0]}} :          // 半字存储：将半字复制2次到32位字
                             32'b0;                                    // 其他情况：写数据为0
                           

    // EX阶段到MEM阶段的流水线寄存器输出总线
    // 将EX阶段的计算结果和控制信号传递给MEM阶段
    assign ex_to_mem_bus = {
        hilo_bus,       // 87:22 - HI/LO操作总线（66位）
        mem_op,         // 21:14 - 存储器操作控制信号（8位）
        ex_pc,          // 13:0  - 程序计数器值（32位）
        data_ram_en,    // 13    - 数据存储器使能信号（1位）
        data_ram_wen,   // 12:9  - 数据存储器写使能信号（4位）
        sel_rf_res,     // 8     - 寄存器文件结果选择信号（1位）
        rf_we,          // 7     - 寄存器文件写使能信号（1位）
        rf_waddr,       // 6:2   - 目标寄存器地址（5位）
        ex_result       // 1:0   - ALU计算结果（32位）
    };

    
    
    assign memop_from_ex = mem_op;

    //forwarding线路，解决数据相关的
    assign ex_to_rf_bus = {
        // hilo_bus,
        rf_we,
        rf_waddr,
        ex_result
    };

    // 前推线路：解决数据冒险问题
    // 当后续指令需要读取前面指令的结果时，通过前推机制直接提供最新数据
    
    // 前推选择信号和结果总线
    wire [31:0] fwd_mux1, fwd_mux2;  // 前推后的寄存器数据
    wire [1:0] fwd_sel1, fwd_sel2;   // 前推选择信号

    // 寄存器rs的前推选择逻辑
    // 检查是否存在数据冒险，优先选择更近流水线阶段的数据
    assign fwd_sel1 = (rf_we_mem & (rf_waddr_mem == rf_raddr1) & |rf_waddr_mem) ? 2'b01 :  // MEM阶段前推：地址匹配且非零地址
                      (rf_we_wb  & (rf_waddr_wb  == rf_raddr1) & |rf_waddr_wb)  ? 2'b10 :  // WB阶段前推：地址匹配且非零地址
                      2'b00;                                                                // 无前推：使用寄存器文件数据

    // 寄存器rt的前推选择逻辑
    // 与rs类似，检查rt寄存器的数据冒险情况
    assign fwd_sel2 = (rf_we_mem & (rf_waddr_mem == rf_raddr2) & |rf_waddr_mem) ? 2'b01 :  // MEM阶段前推
                      (rf_we_wb  & (rf_waddr_wb  == rf_raddr2) & |rf_waddr_wb)  ? 2'b10 :  // WB阶段前推
                      2'b00;                                                                // 无前推

    // 寄存器rs数据前推多路选择器
    // 根据前推选择信号选择正确的数据源
    assign fwd_mux1 = (fwd_sel1 == 2'b01) ? rf_wdata_mem :  // 选择MEM阶段的结果（最近的数据）
                      (fwd_sel1 == 2'b10) ? rf_wdata_wb  :   // 选择WB阶段的结果
                      rf_rdata1;                             // 默认使用寄存器文件读取的数据

    // 寄存器rt数据前推多路选择器
    // 与rs类似，为rt选择正确的数据源
    assign fwd_mux2 = (fwd_sel2 == 2'b01) ? rf_wdata_mem :  // 选择MEM阶段的结果
                      (fwd_sel2 == 2'b10) ? rf_wdata_wb  :   // 选择WB阶段的结果
                      rf_rdata2;                             // 默认使用寄存器文件数据

    // HI/LO寄存器操作：支持乘除法指令的64位结果存储
    // MIPS架构中，乘除法指令的结果存储在专用的HI和LO寄存器中
    
    // HI/LO操作指令解码
    wire inst_mfhi, inst_mflo,  inst_mthi,  inst_mtlo;  // HI/LO操作指令
    wire [31:0] hi, lo;                                 // HI和LO寄存器当前值
    wire [1:0]  hilo_we;                                // HI/LO写使能信号
    wire [65:0] hilo_wdata;                             // HI/LO写数据总线

    // 从HI/LO操作控制信号中解码具体指令类型
    assign {inst_mfhi, inst_mflo, inst_mthi, inst_mtlo} = hilo_op;

    // HI/LO写使能信号生成
    // inst_mthi：将寄存器值写入HI寄存器
    // inst_mtlo：将寄存器值写入LO寄存器
    assign hilo_we = {inst_mthi | inst_mtlo, 1'b0};  // 高2位为写使能，低2位保留
    assign hilo_wdata = {rf_rdata2, rf_rdata2};      // 写数据：将寄存器值复制到64位总线

    // 实例化HI/LO寄存器模块
    // 该模块负责管理HI和LO寄存器的读写操作
    hilo_reg u_hilo_reg(
        .clk(clk),           // 时钟信号
        .rst(rst),           // 复位信号
        .we(hilo_we),        // 写使能信号
        .wdata(hilo_wdata),  // 写数据总线
        .rdata(hilo_bus)     // 读数据总线
    );

    // 从HI/LO总线中分离出HI和LO寄存器值
    assign {hi, lo} = hilo_bus;  // 高32位为HI，低32位为LO

    // HI/LO结果选择：根据指令类型选择输出数据
    assign hilo_result = inst_mfhi ? hi :   // mfhi指令：输出HI寄存器值
                         inst_mflo ? lo :   // mflo指令：输出LO寄存器值
                         32'b0;             // 其他情况：输出0

    assign ex_result = (inst_mfhi | inst_mflo) ? hilo_result :alu_result;

    assign ex_hilo_bus = hilo_bus;

    // 乘除法器接口：支持有符号/无符号乘除法运算
    // 乘除法指令需要多周期完成，通过专用模块实现
    
    // 乘除法指令解码
    wire inst_mult, inst_multu, inst_div,   inst_divu;  // 乘除法指令
    wire inst_mul;                                     // 乘法指令（32位结果）

    // 从HI/LO操作控制信号中解码乘除法指令类型
    assign {
        inst_mult, inst_multu, inst_div, inst_divu,
        inst_mul
    } = hilo_op;

    // 乘除法操作类型判断
    wire op_div = inst_div | inst_divu;  // 除法操作：有符号或无符号除法
    wire op_mul = inst_mult | inst_multu; // 乘法操作：有符号或无符号乘法

    // 乘除法器结果和状态信号
    wire [63:0] mul_result, div_result;  // 64位乘除法结果
    wire mul_ready, div_ready;            // 乘除法器完成信号
    wire mul_start, div_start;            // 乘除法器启动信号

    // 乘除法器启动信号生成
    assign mul_start = op_mul;  // 乘法操作时启动乘法器
    assign div_start = op_div;  // 除法操作时启动除法器

    // 实例化乘法器模块
    // 支持有符号和无符号乘法，输出64位结果
    mul u_mul(
        .clk(clk),                    // 时钟信号
        .rst(rst),                    // 复位信号
        .mul_signed(inst_mult),       // 有符号乘法标志
        .x(fwd_mux1),                 // 被乘数（前推后的rs值）
        .y(fwd_mux2),                 // 乘数（前推后的rt值）
        .result(mul_result),          // 64位乘法结果
        .ready(mul_ready),            // 乘法完成信号
        .start(mul_start)             // 乘法启动信号
    );

    // 实例化除法器模块
    // 支持有符号和无符号除法，输出64位结果（商和余数）
    div u_div(
        .clk(clk),                    // 时钟信号
        .rst(rst),                    // 复位信号
        .div_signed(inst_div),        // 有符号除法标志
        .x(fwd_mux1),                 // 被除数（前推后的rs值）
        .y(fwd_mux2),                 // 除数（前推后的rt值）
        .result(div_result),          // 64位除法结果
        .ready(div_ready),            // 除法完成信号
        .start(div_start)             // 除法启动信号
    );

    // 乘除法器暂停请求逻辑
    reg stallreq_for_div;
    assign stallreq_for_ex = stallreq_for_div;

    // 除法器暂停控制：除法操作需要多周期，需要暂停流水线
    always @ (*) begin
        if (rst) begin
            stallreq_for_div = `NoStop;
        end
        else begin
            stallreq_for_div = `NoStop;
            if (op_div && !div_ready) begin
                stallreq_for_div = `Stop;  // 除法未完成时请求暂停
            end
        end
    end

    // mul_result 和 div_result 可以直接使用
    
    
endmodule