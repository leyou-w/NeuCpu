// ALU（算术逻辑单元）模块：执行MIPS指令集中的算术和逻辑运算
// 支持加法、减法、比较、逻辑运算、移位和立即数加载等操作
module alu(
    input wire [11:0] alu_control,        // ALU控制信号，指示执行哪种运算
    input wire [31:0] alu_src1,          // 第一个操作数（通常来自rs寄存器）
    input wire [31:0] alu_src2,          // 第二个操作数（通常来自rt寄存器或立即数）
    output wire [31:0] alu_result        // 运算结果
);

    // 各种ALU操作的控制信号
    wire op_add;                          // 加法操作
    wire op_sub;                          // 减法操作
    wire op_slt;                          // 有符号比较小于（set less than）
    wire op_sltu;                         // 无符号比较小于（set less than unsigned）
    wire op_and;                          // 按位与操作
    wire op_nor;                          // 按位或非操作
    wire op_or;                           // 按位或操作
    wire op_xor;                          // 按位异或操作
    wire op_sll;                          // 逻辑左移（shift left logical）
    wire op_srl;                          // 逻辑右移（shift right logical）
    wire op_sra;                          // 算术右移（shift right arithmetic）
    wire op_lui;                          // 立即数加载高位（load upper immediate）

    // 从12位控制信号中解析出各种操作的控制位
    assign {op_add, op_sub, op_slt, op_sltu,
            op_and, op_nor, op_or, op_xor,
            op_sll, op_srl, op_sra, op_lui} = alu_control;
    
    // 各种运算的中间结果
    wire [31:0] add_sub_result;           // 加法/减法结果
    wire [31:0] slt_result;               // 有符号比较结果
    wire [31:0] sltu_result;              // 无符号比较结果
    wire [31:0] and_result;               // 按位与结果
    wire [31:0] nor_result;               // 按位或非结果
    wire [31:0] or_result;                // 按位或结果
    wire [31:0] xor_result;               // 按位异或结果
    wire [31:0] sll_result;               // 逻辑左移结果
    wire [31:0] srl_result;               // 逻辑右移结果
    wire [31:0] sra_result;               // 算术右移结果
    wire [31:0] lui_result;               // 立即数加载高位结果

    // 逻辑运算：直接使用Verilog内置运算符
    assign and_result = alu_src1 & alu_src2;        // 按位与
    assign or_result = alu_src1 | alu_src2;         // 按位或
    assign nor_result = ~or_result;                  // 按位或非（或运算后取反）
    assign xor_result = alu_src1 ^ alu_src2;         // 按位异或
    assign lui_result = {alu_src2[15:0], 16'b0};     // 立即数加载高位：将16位立即数放到高16位，低16位补0

    // 加法器实现：用于加法、减法和比较操作
    wire [31:0] adder_a;                  // 加法器输入A
    wire [31:0] adder_b;                  // 加法器输入B
    wire        adder_cin;                // 加法器进位输入
    wire [31:0] adder_result;            // 加法器结果
    wire        adder_cout;               // 加法器进位输出

    // 加法器输入设置
    assign adder_a = alu_src1;            // 第一个操作数直接连接到加法器
    assign adder_b = (op_sub | op_slt | op_sltu) ? ~alu_src2 : alu_src2;  // 减法/比较时对第二个操作数取反
    assign adder_cin = (op_sub | op_slt | op_sltu) ? 1'b1 : 1'b0;          // 减法/比较时进位输入设为1（实现补码加法）
    assign {adder_cout, adder_result} = adder_a + adder_b + adder_cin;     // 32位加法器，产生进位和结果

    assign add_sub_result = adder_result;  // 加法/减法结果直接使用加法器结果

    // 有符号比较小于（SLT）实现
    assign slt_result[31:1] = 31'b0;       // 高31位设为0
    assign slt_result[0] = (alu_src1[31] & ~alu_src2[31])      // 如果第一个操作数为负，第二个为正，则结果为1
                         | (~(alu_src1[31]^alu_src2[31]) & adder_result[31]);  // 如果符号相同且减法结果为负，则结果为1
    
    // 无符号比较小于（SLTU）实现
    assign sltu_result[31:1] = 31'b0;     // 高31位设为0
    assign sltu_result[0] = ~adder_cout;  // 如果加法器有进位输出，则结果为0，否则为1

    // 移位操作实现
    assign sll_result = alu_src2 << alu_src1[4:0];    // 逻辑左移：第二个操作数左移第一个操作数的低5位指定的位数
    assign srl_result = alu_src2 >> alu_src1[4:0];    // 逻辑右移：第二个操作数右移第一个操作数的低5位指定的位数，高位补0
    assign sra_result = ($signed(alu_src2)) >>> alu_src1[4:0];  // 算术右移：第二个操作数右移，保持符号位

    // 根据控制信号选择最终输出结果
    assign alu_result = ({32{op_add|op_sub  }} & add_sub_result)   // 加法/减法
                      | ({32{op_slt         }} & slt_result)       // 有符号比较小于
                      | ({32{op_sltu        }} & sltu_result)      // 无符号比较小于
                      | ({32{op_and         }} & and_result)       // 按位与
                      | ({32{op_nor         }} & nor_result)       // 按位或非
                      | ({32{op_or          }} & or_result)        // 按位或
                      | ({32{op_xor         }} & xor_result)       // 按位异或
                      | ({32{op_sll         }} & sll_result)       // 逻辑左移
                      | ({32{op_srl         }} & srl_result)       // 逻辑右移
                      | ({32{op_sra         }} & sra_result)       // 算术右移
                      | ({32{op_lui         }} & lui_result);      // 立即数加载高位
                      
endmodule