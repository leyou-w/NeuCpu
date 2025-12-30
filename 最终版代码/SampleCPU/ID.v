`include "lib/defines.vh"
// 指令译码模块（ID阶段）
// 功能：对IF阶段取到的指令进行译码，生成控制信号和操作数
// 支持：指令解码、寄存器读取、数据前推、跳转判断、流水线暂停请求
module ID(
    input wire clk,                            // 时钟信号
    input wire rst,                            // 复位信号
    // input wire flush,                       // 流水线刷新信号（保留）
    input wire [`StallBus-1:0] stall,          // 流水线暂停控制信号
    input wire [7:0] memop_from_ex,            // EX阶段的存储器操作信号（用于数据冒险检测）
    
    output wire stallreq_for_load,             // 加载指令暂停请求信号
//    input wire ex_ram_read,                   // EX阶段存储器读取信号（保留）
//    output stall_for_load,                    // 加载暂停信号（保留）

    input wire [`IF_TO_ID_WD-1:0] if_to_id_bus,     // IF阶段到ID阶段的流水线总线

    input wire [31:0] inst_sram_rdata,          // 指令存储器读取的数据（当前指令）
    input wire ex_ram_read,                     // EX阶段存储器读取标志

    input wire [`WB_TO_RF_WD-1:0] wb_to_rf_bus, // WB阶段到寄存器文件的前推总线
    input wire [`EX_TO_RF_WD-1:0] ex_to_rf_bus, // EX阶段到寄存器文件的前推总线
    input wire [`MEM_TO_RF_WD-1:0] mem_to_rf_bus, // MEM阶段到寄存器文件的前推总线

    output wire [`ID_TO_EX_WD-1:0] id_to_ex_bus,        // ID阶段到EX阶段的流水线总线

    output wire [`BR_WD-1:0] br_bus         // 跳转指令总线（跳转使能+目标地址）
);

    // 流水线寄存器：存储IF阶段传递到ID阶段的信息
    reg [`IF_TO_ID_WD-1:0] if_to_id_bus_r;      // IF到ID的流水线寄存器
    wire [31:0] inst;           // 当前译码的指令
    wire [31:0] id_pc;          // ID阶段的程序计数器值
    wire ce;                    // 指令存储器使能信号

    // 前推总线解包：从各流水线阶段获取寄存器写回信息
    wire wb_rf_we;              // WB阶段寄存器写使能信号
    wire [4:0] wb_rf_waddr;     // WB阶段目标寄存器地址
    wire [31:0] wb_rf_wdata;    // WB阶段写回数据

    wire ex_rf_we;              // EX阶段寄存器写使能信号
    wire [4:0] ex_rf_waddr;     // EX阶段目标寄存器地址
    wire [31:0] ex_rf_wdata;    // EX阶段写回数据

    wire mem_rf_we;              // MEM阶段寄存器写使能信号
    wire [4:0] mem_rf_waddr;     // MEM阶段目标寄存器地址
    wire [31:0] mem_rf_wdata;    // MEM阶段写回数据
    
    // 流水线暂停处理标志和指令缓存
    reg  flag;                  // 暂停标志：用于处理流水线暂停时的指令缓存
    reg [31:0] buf_inst;        // 指令缓存：在暂停时保存当前指令

    // 流水线寄存器控制逻辑：处理流水线暂停和指令缓存
    always @ (posedge clk) begin
        if (rst) begin
            // 复位时清空所有寄存器和标志
            if_to_id_bus_r <= `IF_TO_ID_WD'b0; 
            flag <= 1'b0;    
            buf_inst <= 32'b0;   
        end
//         else if (flush) begin
//             // 流水线刷新：清空流水线寄存器（保留功能）
//             ic_to_id_bus <= `IC_TO_ID_WD'b0;
//         end
        else if (stall[1]==`Stop && stall[2]==`NoStop) begin
            // ID阶段暂停但IF阶段不暂停：清空ID寄存器，插入空操作
            if_to_id_bus_r <= `IF_TO_ID_WD'b0;
            flag <= 1'b0; 
        end
        else if (stall[1]==`NoStop) begin
            // ID阶段不暂停：正常接收IF阶段传递的指令
            if_to_id_bus_r <= if_to_id_bus;
            flag <= 1'b0; 
        end
        else if (stall[1]==`Stop && stall[2]==`Stop && ~flag) begin
            // ID和IF阶段都暂停且未缓存指令：缓存当前指令
            flag <= 1'b1;
            buf_inst <= inst_sram_rdata;
        end
    end
    
    // 指令选择逻辑：根据流水线状态选择当前译码的指令
    // 优先使用缓存的指令，其次使用指令存储器读取的指令
    assign inst = ce ? flag ? buf_inst : inst_sram_rdata : 32'b0;
//    assign inst = inst_sram_rdata;  // 直接使用指令存储器数据（简化版本）
    
//    assign stall_for_load = ex_ram_read &((ex_rf_we && (ex_rf_waddr == rs)) | (ex_rf_we && (ex_rf_waddr==rt)));
    
    assign {
        ce,
        id_pc
    } = if_to_id_bus_r;


    // 前推总线解包：从各流水线阶段获取寄存器写回信息
    // 用于解决数据冒险问题，优先使用最新数据
    assign {            // WB阶段前推总线解包
        wb_rf_we,       // WB阶段寄存器写使能
        wb_rf_waddr,    // WB阶段目标寄存器地址
        wb_rf_wdata     // WB阶段写回数据
    } = wb_to_rf_bus;

    assign {            // EX阶段前推总线解包
        ex_rf_we,       // EX阶段寄存器写使能
        ex_rf_waddr,    // EX阶段目标寄存器地址
        ex_rf_wdata     // EX阶段写回数据
    } = ex_to_rf_bus;

    assign {            // MEM阶段前推总线解包
        mem_rf_we,      // MEM阶段寄存器写使能
        mem_rf_waddr,   // MEM阶段目标寄存器地址
        mem_rf_wdata    // MEM阶段写回数据
    } = mem_to_rf_bus;


    // 指令字段解码：提取指令中的各个字段
    wire [5:0] opcode;      // 操作码（31:26位）
    wire [4:0] rs,rt,rd,sa; // 寄存器地址字段：rs(25:21), rt(20:16), rd(15:11), sa(10:6)
    wire [5:0] func;        // 功能码（5:0位）
    wire [15:0] imm;        // 立即数（15:0位）
    wire [25:0] instr_index; // 跳转目标地址（25:0位）
    wire [19:0] code;        // 特殊指令代码（25:6位）
    wire [4:0] base;        // 基址寄存器（25:21位）
    wire [15:0] offset;      // 偏移量（15:0位）
    wire [2:0] sel;          // 选择字段（2:0位）

    // 译码器输出：用于指令识别
    wire [63:0] op_d, func_d;   // 操作码和功能码译码结果
    wire [31:0] rs_d, rt_d, rd_d, sa_d; // 寄存器地址译码结果

    // 控制信号：用于EX阶段的操作控制
    wire [2:0] sel_alu_src1;    // ALU源操作数1选择信号
    wire [3:0] sel_alu_src2;    // ALU源操作数2选择信号
    wire [11:0] alu_op;         // ALU操作类型控制信号
    wire [7:0]  mem_op;         // 存储器操作控制信号

    // 存储器控制信号
    wire data_ram_en;           // 数据存储器使能信号
    wire [3:0] data_ram_wen;   // 数据存储器写使能信号
    
    // 寄存器文件控制信号
    wire rf_we;                // 寄存器文件写使能信号
    wire [4:0] rf_waddr;       // 目标寄存器地址
    wire sel_rf_res;           // 寄存器结果选择信号
    wire [2:0] sel_rf_dst;     // 目标寄存器选择信号

    // 寄存器读取数据
    wire [31:0] rdata1, rdata2; // 前推后的寄存器数据
    wire [31:0] rf_data1, rf_data2; // 寄存器文件读取的原始数据

    // 寄存器文件实例化：管理32个32位通用寄存器
    regfile u_regfile(
    	.clk    (clk    ),        // 时钟信号
        .raddr1 (rs ),           // 读取地址1（rs寄存器）
        .rdata1 (rf_data1 ),     // 读取数据1
        .raddr2 (rt ),           // 读取地址2（rt寄存器）
        .rdata2 (rf_data2 ),     // 读取数据2
        .we     (wb_rf_we     ), // 写使能信号（来自WB阶段）
        .waddr  (wb_rf_waddr  ), // 写地址
        .wdata  (wb_rf_wdata  )  // 写数据
    );
    
    // 前推逻辑：解决数据冒险，优先使用最新数据
    // 检查是否存在数据冒险，按流水线阶段优先级选择数据源
    assign rdata1 = (ex_rf_we && (ex_rf_waddr == rs)) ? ex_rf_wdata:  // EX阶段前推：最高优先级
                    (mem_rf_we && (mem_rf_waddr == rs)) ? mem_rf_wdata: // MEM阶段前推
                    (wb_rf_we && (wb_rf_waddr == rs)) ? wb_rf_wdata:    // WB阶段前推
                                                        rf_data1;       // 默认：寄存器文件数据
    assign rdata2 = (ex_rf_we && (ex_rf_waddr == rt)) ? ex_rf_wdata:  // rt寄存器前推逻辑
                    (mem_rf_we && (mem_rf_waddr == rt)) ? mem_rf_wdata:
                    (wb_rf_we && (wb_rf_waddr == rt)) ? wb_rf_wdata:
                                                        rf_data2;  
                                                        
    wire ex_inst_lb, ex_inst_lbu,  ex_inst_lh, ex_inst_lhu, ex_inst_lw;
    wire ex_inst_sb, ex_inst_sh,   ex_inst_sw;   
    
    assign {ex_inst_lb, ex_inst_lbu, ex_inst_lh, ex_inst_lhu,
            ex_inst_lw, ex_inst_sb,  ex_inst_sh, ex_inst_sw} = memop_from_ex;                                                                                                   

    wire stallreq1_loadrelate;
    wire stallreq2_loadrelate;
    
    wire pre_inst_is_load;
    
    assign pre_inst_is_load = ex_inst_lb | ex_inst_lbu | ex_inst_lh | ex_inst_lhu
                             |ex_inst_lw | ex_inst_sb |  ex_inst_sh | ex_inst_sw ? 1'b1 : 1'b0;
                             
    assign stallreq1_loadrelate = (ex_rf_we == 1'b1 && ex_rf_waddr == rs) ? `Stop : `NoStop;
    assign stallreq2_loadrelate = (ex_rf_we == 1'b1 && ex_rf_waddr == rt) ? `Stop : `NoStop;
    
//    assign stallreq_for_load = (stallreq1_loadrelate | stallreq2_loadrelate) ? `Stop : `NoStop;
    assign stallreq_for_load = ex_ram_read & (stallreq1_loadrelate | stallreq2_loadrelate);

    //hi & lo reg for mul and div(to do)



//decode inst   
    //locate content of inst
    assign opcode = inst[31:26];        //对于ori指令只需要通过判断26-31bit的值，即可判断是否是ori指令
    assign rs = inst[25:21];            //rs寄存器
    assign rt = inst[20:16];            //rt寄存器
    assign rd = inst[15:11];
    assign sa = inst[10:6];
    assign func = inst[5:0];
    assign imm = inst[15:0];            //立即数
    assign instr_index = inst[25:0];
    assign code = inst[25:6];
    assign base = inst[25:21];
    assign offset = inst[15:0];         //偏移量
    assign sel = inst[2:0];


    //candidate inst & opetion      操作：如果判断当前inst是某条指令，则对应指令的wire变为1,如判断当前inst是add指令，则inst_add <=2'b1
    wire inst_add,  inst_addi,  inst_addu,  inst_addiu;
    wire inst_sub,  inst_subu,  inst_slt,   inst_slti;
    wire inst_sltu, inst_sltiu, inst_div,   inst_divu;
    wire inst_mult, inst_multu, inst_and,   inst_andi;
    wire inst_lui,  inst_nor,   inst_or,    inst_ori;
    wire inst_xor,  inst_xori,  inst_sllv,  inst_sll;
    wire inst_srav, inst_sra,   inst_srlv,  inst_srl;
    wire inst_beq,  inst_bne,   inst_bgez,  inst_bgtz;
    wire inst_blez, inst_bltz,  inst_bgezal,inst_bltzal;
    wire inst_j,    inst_jal,   inst_jr,    inst_jalr;
    wire inst_mfhi, inst_mflo,  inst_mthi,  inst_mtlo;
    wire inst_break,inst_syscall;
    wire inst_lb,   inst_lbu,   inst_lh,    inst_lhu,   inst_lw;
    wire inst_sb,   inst_sh,    inst_sw;
    wire inst_eret, inst_nfc0,  inst_mtc0;
    wire inst_mul;

    //控制alu运算单元的
    wire op_add, op_sub, op_slt, op_sltu;
    wire op_and, op_nor, op_or, op_xor;
    wire op_sll, op_srl, op_sra, op_lui;
    //解码器
    decoder_6_64 u0_decoder_6_64(   
    	.in  (opcode  ),      //假如opcode的前六位都是0，则可以判断是ori指令      
        .out (op_d )            //输出一个64bit的信号
    );

    decoder_6_64 u1_decoder_6_64(
    	.in  (func  ),
        .out (func_d )
    );
    
    decoder_5_32 u0_decoder_5_32(
    	.in  (rs  ),
        .out (rs_d )
    );

    decoder_5_32 u1_decoder_5_32(
    	.in  (rt  ),
        .out (rt_d )
    );

     decoder_5_32 u2_decoder_5_32(
    	.in  (rd  ),
        .out (rd_d )
    );

     decoder_5_32 u3_decoder_5_32(
    	.in  (sa  ),
        .out (sa_d )
    );

    //操作码
    assign inst_ori     = op_d[6'b00_1101];
    assign inst_lui     = op_d[6'b00_1111];
    assign inst_addiu   = op_d[6'b00_1001];
    assign inst_addi    = op_d[6'b00_1000];
    assign inst_addu    = op_d[6'b00_0000] & func_d[6'b10_0001];
    assign inst_add     = op_d[6'b00_0000] & func_d[6'b10_0000];
    assign inst_beq     = op_d[6'b00_0100];
    assign inst_sub     = op_d[6'b00_0000] & func_d[6'b10_0010];
    assign inst_subu    = op_d[6'b00_0000] & func_d[6'b10_0011];
    assign inst_j       = op_d[6'b00_0010];  
    assign inst_jal     = op_d[6'b00_0011];
    assign inst_jr      = op_d[6'b00_0000] & func_d[6'b00_1000];
    assign inst_jalr    = op_d[6'b00_0000] & func_d[6'b00_1001];
    assign inst_sll     = op_d[6'b00_0000] & func_d[6'b00_0000];
    assign inst_sllv    = op_d[6'b00_0000] & func_d[6'b00_0100];
    assign inst_or      = op_d[6'b00_0000] & func_d[6'b10_0101];  
    assign inst_lw      = op_d[6'b10_0011];
    assign inst_lb      = op_d[6'b10_0000];
    assign inst_lbu     = op_d[6'b10_0100];
    assign inst_lh      = op_d[6'b10_0001];
    assign inst_lhu     = op_d[6'b10_0101];
    assign inst_sb      = op_d[6'b10_1000];
    assign inst_sh      = op_d[6'b10_1001];
    assign inst_sw      = op_d[6'b10_1011];
    assign inst_xor     = op_d[6'b00_0000] & func_d[6'b10_0110];
    assign inst_xori    = op_d[6'b00_1110];
    assign inst_sltu    = op_d[6'b00_0000] & func_d[6'b10_1011];
    assign inst_slt     = op_d[6'b00_0000] & func_d[6'b10_1010];
    assign inst_slti    = op_d[6'b00_1010];
    assign inst_sltiu   = op_d[6'b00_1011];
    assign inst_srav    = op_d[6'b00_0000] & func_d[6'b00_0111];
    assign inst_sra     = op_d[6'b00_0000] & func_d[6'b00_0011];
    assign inst_bne     = op_d[6'b00_0101];
    assign inst_bgez    = op_d[6'b00_0001] & rt_d[5'b0_0001];
    assign inst_bgtz    = op_d[6'b00_0111];
    assign inst_blez    = op_d[6'b00_0110];
    assign inst_bltz    = op_d[6'b00_0001] & rt_d[5'b0_0000];
    assign inst_bltzal  = op_d[6'b00_0001] & rt_d[5'b1_0000];
    assign inst_bgezal  = op_d[6'b00_0001] & rt_d[5'b1_0001];
    assign inst_and     = op_d[6'b00_0000] & func_d[6'b10_0100];
    assign inst_andi    = op_d[6'b00_1100];
    assign inst_nor     = op_d[6'b00_0000] & func_d[6'b10_0111];
    assign inst_srl     = op_d[6'b00_0000] & func_d[6'b00_0010];
    assign inst_srlv    = op_d[6'b00_0000] & func_d[6'b00_0110];
    assign inst_mfhi    = op_d[6'b00_0000] & func_d[6'b01_0000];
    assign inst_mflo    = op_d[6'b00_0000] & func_d[6'b01_0010];
    assign inst_mthi    = op_d[6'b00_0000] & func_d[6'b01_0001];
    assign inst_mtlo    = op_d[6'b00_0000] & func_d[6'b01_0011];
    
    assign inst_div     = op_d[6'b00_0000] & func_d[6'b01_1010];
    assign inst_divu    = op_d[6'b00_0000] & func_d[6'b01_1011];
    
    assign inst_mult    = op_d[6'b00_0000] & func_d[6'b01_1000];
    assign inst_multu   = op_d[6'b00_0000] & func_d[6'b01_1001];

    wire [8:0] hilo_op;
    assign hilo_op = {
        inst_mfhi, inst_mflo, inst_mthi, inst_mtlo,
        inst_mult, inst_multu,inst_div,  inst_divu,
        inst_mul
    };


    //选操作数      这里src1和src2分别是两个存储操作数的寄存器，具体怎么选操作数，在ex段写
    // rs to reg1
    assign sel_alu_src1[0] =  inst_ori| inst_addiu | inst_sub | inst_subu | inst_addu | inst_slti
                            | inst_or | inst_xor   | inst_sw  | inst_srav | inst_sltu | inst_slt
                            | inst_lw | inst_sltiu | inst_add | inst_addi | inst_and  | inst_andi
                            | inst_nor| inst_xori  | inst_sllv| inst_srlv | inst_div  | inst_divu
                            | inst_mult | inst_multu | inst_lb| inst_lbu  | inst_lh   | inst_lhu
                            | inst_sb | inst_sh;

    // pc to reg1
    assign sel_alu_src1[1] = inst_jal | inst_jalr | inst_bltzal | inst_bgezal;

    // sa_zero_extend to reg1
    assign sel_alu_src1[2] = inst_sll | inst_sra | inst_srl;

    
    // rt to reg2
    assign sel_alu_src2[0] = inst_sub | inst_subu | inst_addu | inst_sll | inst_or | inst_xor
                            |inst_srav| inst_sltu | inst_slt  | inst_add | inst_and| inst_nor
                            |inst_sllv| inst_sra  | inst_srl  | inst_srlv| inst_div| inst_divu
                            | inst_mult | inst_multu;
    
    // imm_sign_extend to reg2
    assign sel_alu_src2[1] = inst_lui | inst_addiu | inst_lw  | inst_sw  | inst_slti| inst_sltiu | inst_addi
                            |inst_lb  | inst_lbu   | inst_lh  | inst_lhu | inst_sh | inst_sb;

    // 32'b8 to reg2
    assign sel_alu_src2[2] = inst_jal | inst_jalr | inst_bltzal | inst_bgezal;

    // imm_zero_extend to reg2
    assign sel_alu_src2[3] = inst_ori | inst_andi | inst_xori;


    //choose the op to be applied   选操作逻辑
    assign op_add = inst_addiu | inst_jal | inst_jalr | inst_addu | inst_lw | inst_sw | inst_add | inst_addi | inst_bltzal
                   |inst_bgezal| inst_lb  | inst_lbu  | inst_lh   | inst_lhu| inst_sh | inst_sb;
    assign op_sub = inst_sub | inst_subu;
    assign op_slt = inst_slt | inst_slti;
    assign op_sltu = inst_sltu | inst_sltiu;
    assign op_and = inst_and | inst_andi;
    assign op_nor = inst_nor;
    assign op_or = inst_ori | inst_or;
    assign op_xor = inst_xor| inst_xori;
    assign op_sll = inst_sll| inst_sllv;
    assign op_srl = inst_srl| inst_srlv;
    assign op_sra = inst_srav| inst_sra;
    assign op_lui = inst_lui;

    assign alu_op = {op_add, op_sub, op_slt, op_sltu,
                     op_and, op_nor, op_or, op_xor,
                     op_sll, op_srl, op_sra, op_lui};

    assign mem_op = {inst_lb, inst_lbu, inst_lh, inst_lhu,
                     inst_lw, inst_sb,  inst_sh, inst_sw};

    


    //关于指令写回的内容
    // load and store enable
    assign data_ram_en = inst_lw | inst_sw | inst_lb | inst_lbu 
                        |inst_lh | inst_lhu| inst_sb | inst_sh ;

    // write enable
    assign data_ram_wen = inst_sw| inst_sb | inst_sh;


    //一些写回数的操作,包括是否要写回regfile寄存器堆、要存在哪一位里
    // regfile store enable
    assign rf_we = inst_ori | inst_lui | inst_addiu | inst_addu | inst_sub | inst_subu | inst_jal | inst_jalr
                  |inst_sll | inst_or  | inst_lw | inst_xor | inst_srav | inst_sltu | inst_slt | inst_slti | inst_sltiu
                  |inst_add | inst_addi| inst_and| inst_andi| inst_nor  | inst_xori | inst_sllv| inst_sra  | inst_srl
                  |inst_srlv| inst_bltzal | inst_bgezal | inst_mfhi | inst_mflo | inst_lb | inst_lbu | inst_lh |inst_lhu;



    // store in [rd]
    assign sel_rf_dst[0] = inst_sub | inst_subu |inst_addu | inst_sll | inst_or | inst_xor | inst_srav | inst_sltu | inst_slt
                          |inst_add | inst_and  |inst_nor  | inst_sllv| inst_sra| inst_srl | inst_srlv | inst_mfhi | inst_mflo;        //例如要是想存在rd堆里
    // store in [rt] 
    assign sel_rf_dst[1] = inst_ori | inst_lui | inst_addiu| inst_lw | inst_slti| inst_sltiu | inst_addi | inst_andi | inst_xori
                          |inst_lb  | inst_lbu | inst_lh | inst_lhu;
    // store in [31]
    assign sel_rf_dst[2] = inst_jal | inst_jalr| inst_bltzal | inst_bgezal;            //jalr不是存在rd中吗？ --默认先存到31位寄存器中

    // sel for regfile address
    assign rf_waddr = {5{sel_rf_dst[0]}} & rd   //则会把他扩展成5位
                    | {5{sel_rf_dst[1]}} & rt
                    | {5{sel_rf_dst[2]}} & 32'd31;

    // 0 from alu_res ; 1 from ld_res
    assign sel_rf_res = inst_lw | inst_lb | inst_lbu | inst_lh | inst_lhu; 
    
//    assign stallreq_for_load = inst_lw ;

    //一条指令解码结束，把信息封装好，传给EX段
    assign id_to_ex_bus = {
        hilo_op,
        mem_op,
        id_pc,          // 158:127
        inst,           // 126:95
        alu_op,         // 94:83
        sel_alu_src1,   // 82:80
        sel_alu_src2,   // 79:76
        data_ram_en,    // 75
        data_ram_wen,   // 74:71
        rf_we,          // 70
        rf_waddr,       // 69:65
        sel_rf_res,     // 64
        rdata1,         // 63:32
        rdata2          // 31:0
    };

    //跳转模块
    wire br_e;
    wire [31:0] br_addr;
    wire rs_eq_rt;
    wire rs_ge_z;
    wire rs_gt_z;
    wire rs_le_z;
    wire rs_lt_z;
    wire [31:0] pc_plus_4;
    assign pc_plus_4 = id_pc + 32'h4;

    assign rs_eq_rt = (rdata1 == rdata2);
    assign rs_ge_z = ~rdata1[31];
    assign rs_gt_z = ($signed(rdata1)>0);
    assign rs_le_z  = (rdata1[31]==1'b1||rdata1==32'b0);
    assign rs_lt_z = rdata1[31];

    assign br_e = inst_beq & rs_eq_rt 
                | inst_bne & ~rs_eq_rt
                | inst_bgez & rs_ge_z
                | inst_bgezal & rs_ge_z
                | inst_bgtz & rs_gt_z
                | inst_blez & rs_le_z
                | inst_bltz & rs_lt_z
                | inst_bltzal & rs_lt_z
                | inst_j |inst_jal | inst_jalr | inst_jr;
    assign br_addr = inst_beq  ? (pc_plus_4 + {{14{inst[15]}},inst[15:0],2'b0}) 
                    :inst_bne  ? (pc_plus_4 + {{14{inst[15]}},inst[15:0],2'b0}) 
                    :inst_bgez ? (pc_plus_4 + {{14{inst[15]}},inst[15:0],2'b0}) 
                    :inst_bgtz ? (pc_plus_4 + {{14{inst[15]}},inst[15:0],2'b0}) 
                    :inst_blez ? (pc_plus_4 + {{14{inst[15]}},inst[15:0],2'b0})
                    :inst_bltz ? (pc_plus_4 + {{14{inst[15]}},inst[15:0],2'b0})  
                    :inst_bltzal ? (pc_plus_4 + {{14{inst[15]}},inst[15:0],2'b0})  
                    :inst_bgezal ? (pc_plus_4 + {{14{inst[15]}},inst[15:0],2'b0}) 
                    :inst_j    ? {id_pc[31:28],instr_index,2'b0}
                    :inst_jal  ? {id_pc[32:28],instr_index,2'b0}
                    :inst_jr   ? rdata1
                    :inst_jalr ? rdata1 
                    :32'b0;

    assign br_bus = {
        br_e,
        br_addr
    };
    


endmodule