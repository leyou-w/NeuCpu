// 除法器模块：实现32位有符号/无符号整数除法运算
// 使用改进的试商法（不恢复余数法）实现除法运算
// 输入两个32位数，输出64位结果（高32位为商，低32位为余数）
// 支持有符号和无符号除法，具有除零检测和状态控制功能
`include "defines.vh"
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/06/25 13:51:28
// Design Name: 
// Module Name: div
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module div(
	input wire rst,                          // 复位信号，高电平有效
	input wire clk,                          // 时钟信号，上升沿触发
	input wire signed_div_i,                 // 除法类型选择：1为有符号除法，0为无符号除法
	input wire[31:0] opdata1_i,              // 第一个操作数（被除数）
	input wire[31:0] opdata2_i,              // 第二个操作数（除数）
	input wire start_i,                      // 除法启动信号：1为启动除法运算
	input wire annul_i,                      // 除法取消信号：1为取消当前除法运算
	output reg[63:0] result_o,               // 除法运算结果：[63:32]为商，[31:0]为余数
	output reg ready_o                       // 除法完成信号：1为除法完成，结果有效
);
	// 内部信号和寄存器定义
	wire [32:0] div_temp;                   // 临时减法结果：用于比较被除数和除数大小
	reg [5:0] cnt;                          // 计数器：记录试商法进行了几轮（最多32轮）
	reg[64:0] dividend;                     // 被除数寄存器：
	                                       // 低32位[31:0]保存余数，中间结果
	                                       // 中间部分[31:k+1]保存被除数未参与运算的部分
	                                       // 高32位[64:33]是每次迭代时的被减数
	reg [1:0] state;                        // 状态机：控制除法器的工作状态
	reg[31:0] divisor;                      // 除数寄存器：存储处理后的除数
	reg[31:0] temp_op1;                     // 临时操作数1：存储处理后的被除数
	reg[31:0] temp_op2;                     // 临时操作数2：存储处理后的除数
	
	// 计算被除数高位部分与除数的差值，用于判断是否够减
	assign div_temp = {1'b0, dividend[63: 32]} - {1'b0, divisor};
	
	// 除法器主状态机：控制除法运算的各个阶段
	always @ (posedge clk) begin
		if (rst) begin
			// 复位状态：初始化所有寄存器
			state <= `DivFree;                       // 设置为空闲状态
			result_o <= {`ZeroWord,`ZeroWord};       // 清零结果
			ready_o <= `DivResultNotReady;           // 设置为结果未就绪
		end else begin
			case(state)
			
				`DivFree: begin                    // 空闲状态：等待除法启动信号
					if (start_i == `DivStart && annul_i == 1'b0) begin
						// 检测到启动信号且未取消
						if(opdata2_i == `ZeroWord) begin            // 检查除数是否为0
							state <= `DivByZero;                   // 除数为0，跳转到除零错误状态
						end else begin
							// 除数不为0，开始除法运算
							state <= `DivOn;                        // 跳转到除法运算状态
							cnt <= 6'b000000;                       // 初始化计数器
							
							// 处理被除数符号（有符号除法时）
							if(signed_div_i == 1'b1 && opdata1_i[31] == 1'b1) begin
								// 有符号除法且被除数为负数，取其绝对值
								temp_op1 = ~opdata1_i + 1;
							end else begin
								temp_op1 = opdata1_i;               // 无符号除法或正数，直接使用
							end
							
							// 处理除数符号（有符号除法时）
							if (signed_div_i == 1'b1 && opdata2_i[31] == 1'b1 ) begin
								// 有符号除法且除数为负数，取其绝对值
								temp_op2 = ~opdata2_i + 1;
							end else begin
								temp_op2 = opdata2_i;               // 无符号除法或正数，直接使用
							end
							
							// 初始化被除数寄存器
							dividend <= {`ZeroWord, `ZeroWord};     // 清零
							dividend[32: 1] <= temp_op1;            // 将被除数放入[32:1]位
							divisor <= temp_op2;                    // 存储处理后的除数
						end
					end else begin
						// 未收到启动信号，保持空闲状态
						ready_o <= `DivResultNotReady;
						result_o <= {`ZeroWord, `ZeroWord};
					end
				end
				
				`DivByZero: begin				// 除数为0错误状态
					dividend <= {`ZeroWord, `ZeroWord};    // 清零被除数寄存器
					state <= `DivEnd;                     // 跳转到结束状态
				end
				
				`DivOn: begin				// 除法运算状态：执行32轮试商法
					if(annul_i == 1'b0) begin			// 未收到取消信号，继续除法运算
						if(cnt != 6'b100000) begin		// 如果未完成32轮运算
							if (div_temp[32] == 1'b1) begin
								// 不够减：被除数高位部分小于除数
								// 将当前余数左移1位，商位设为0
								dividend <= {dividend[63:0],1'b0};
							end else begin
								// 够减：被除数高位部分大于等于除数
								// 用减法结果替换高位部分，商位设为1
								dividend <= {div_temp[31:0],dividend[31:0], 1'b1};
							end
							cnt <= cnt +1;				// 除法运算次数加1
						end	else begin					// 完成32轮运算
							// 有符号除法结果符号处理
							if ((signed_div_i == 1'b1) && ((opdata1_i[31] ^ opdata2_i[31]) == 1'b1)) begin
								// 被除数和除数符号不同，商为负数，需要取反加1
								dividend[31:0] <= (~dividend[31:0] + 1);
							end
							if ((signed_div_i == 1'b1) && ((opdata1_i[31] ^ dividend[64]) == 1'b1)) begin
								// 被除数和余数符号不同，余数为负数，需要取反加1
								dividend[64:33] <= (~dividend[64:33] + 1);
							end
							state <= `DivEnd;			// 跳转到结束状态
							cnt <= 6'b000000;			// 重置计数器
						end
					end else begin					// 收到取消信号
						state <= `DivFree;			// 返回空闲状态
					end
				end
				
				`DivEnd: begin				// 除法结束状态：输出结果
					result_o <= {dividend[64:33], dividend[31:0]};  // 输出结果：[64:33]为余数，[31:0]为商
					ready_o <= `DivResultReady;				// 设置结果就绪信号
					if (start_i == `DivStop) begin			// 收到停止信号
						state <= `DivFree;				// 返回空闲状态
						ready_o <= `DivResultNotReady;		// 清除结果就绪信号
						result_o <= {`ZeroWord, `ZeroWord};	// 清零结果
					end
				end
				
			endcase
		end
	end


endmodule