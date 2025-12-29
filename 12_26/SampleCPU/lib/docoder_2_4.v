// 2-4译码器模块：将2位输入信号译码为4位输出信号
// 用于CPU控制单元中的地址译码或指令译码
module decoder_2_4 (
    input wire [1:0] in,      // 2位输入信号
    output reg [3:0] out      // 4位输出信号，独热码形式
);
    
    // 组合逻辑电路，根据输入值产生对应的独热码输出
    always @ (*) begin
        case(in)
            2'b00:begin out = 4'b0001; end    // 输入00，输出第0位为1
            2'b01:begin out = 4'b0010; end    // 输入01，输出第1位为1
            2'b10:begin out = 4'b0100; end    // 输入10，输出第2位为1
            2'b11:begin out = 4'b1000; end    // 输入11，输出第3位为1
            default:begin
                out = 4'b0000;                // 默认情况，全输出0
            end
        endcase
    end
endmodule 
