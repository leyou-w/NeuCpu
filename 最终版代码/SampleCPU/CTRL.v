`include "lib/defines.vh"
// 流水线控制模块：负责处理流水线暂停控制
// 根据不同阶段的暂停请求，生成相应的流水线暂停控制信号
module CTRL(
    input wire rst,                      // 复位信号
    input wire stallreq_for_ex,          // EX阶段的暂停请求（如乘除法指令需要多周期执行）
    input wire stallreq_for_load,        // load指令引起的暂停请求（解决数据相关）

    // output reg flush,                  // 流水线刷新信号（未使用）
    // output reg [31:0] new_pc,          // 新PC值（未使用）
    output reg [`StallBus-1:0] stall     // 流水线暂停控制信号
);  
    // 组合逻辑：根据暂停请求生成流水线暂停控制信号
    always @ (*) begin
        if (rst) begin
            stall = `StallBus'b0;        // 复位时，不暂停流水线
        end
        else if (stallreq_for_load==`Stop) begin
            // load指令引起的暂停：暂停IF和ID阶段，EX、MEM、WB阶段继续执行
            // 这样可以避免load指令后的指令使用未加载的数据
            stall = `StallBus'b000111;   // [5:0] = 000111，表示IF和ID阶段暂停
        end
        else if (stallreq_for_ex==`Stop) begin
            // EX阶段引起的暂停：暂停IF、ID和EX阶段，MEM、WB阶段继续执行
            // 适用于需要多周期执行的指令（如乘除法）
            stall = `StallBus'b001111;   // [5:0] = 001111，表示IF、ID和EX阶段暂停
        end
        else begin
            stall = `StallBus'b0;        // 无暂停请求，流水线正常运行
        end
    end
endmodule