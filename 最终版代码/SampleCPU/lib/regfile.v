// 寄存器堆模块：实现MIPS架构中的32个32位通用寄存器
// 提供两个读端口和一个写端口，支持同时读取两个寄存器和写入一个寄存器
// 寄存器$0（编号0）是硬连线为0的只读寄存器，符合MIPS架构规范
module regfile(
    input wire clk,                      // 时钟信号，用于同步写操作
    input wire [4:0] raddr1,              // 第一个读端口的寄存器地址
    output wire [31:0] rdata1,            // 第一个读端口的数据输出
    input wire [4:0] raddr2,              // 第二个读端口的寄存器地址
    output wire [31:0] rdata2,            // 第二个读端口的数据输出
    
    input wire we,                        // 写使能信号，控制寄存器写入
    input wire [4:0] waddr,               // 写端口的寄存器地址
    input wire [31:0] wdata               // 写端口的数据输入
);
    // 32个32位寄存器的数组，索引从0到31
    reg [31:0] reg_array [31:0];
    
    // 写操作：在时钟上升沿进行同步写入
    always @ (posedge clk) begin
        // 只有当写使能有效且写入地址不是0时才执行写操作
        // 寄存器0（$zero）是只读的，不能被修改
        if (we && waddr!=5'b0) begin
            reg_array[waddr] <= wdata;
        end
    end

    // 读端口1：异步读取，直接输出指定寄存器的值
    // 如果读取寄存器0，则直接输出0（符合MIPS架构规范）
    assign rdata1 = (raddr1 == 5'b0) ? 32'b0 : reg_array[raddr1];
    // 注释掉的代码：如果当前周期正在写入同一个寄存器，则直接返回写入的数据（转发）
    // assign rdata1 = (raddr1 == 5'b0) ? 32'b0 : ((raddr1 == waddr) && (we == 1'b1)) ? wdata : reg_array[raddr1]; 
    
    // 读端口2：异步读取，直接输出指定寄存器的值
    // 如果读取寄存器0，则直接输出0（符合MIPS架构规范）
    assign rdata2 = (raddr2 == 5'b0) ? 32'b0 : reg_array[raddr2];
    // 注释掉的代码：如果当前周期正在写入同一个寄存器，则直接返回写入的数据（转发）
    // assign rdata2 = (raddr2 == 5'b0) ? 32'b0 : ((raddr2 == waddr) && (we == 1'b1)) ? wdata : reg_array[raddr2]; 
    
endmodule