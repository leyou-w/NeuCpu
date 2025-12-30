// CPU设计中的常量定义文件
// 定义了各个模块之间的总线宽度、控制信号和状态常量

// 总线宽度定义：定义各阶段之间传递数据的总线宽度
`define IF_TO_ID_WD 33        // IF到ID阶段的总线宽度（1位使能 + 32位PC）
`define ID_TO_EX_WD 176       // ID到EX阶段的总线宽度
`define EX_TO_MEM_WD 150      // EX到MEM阶段的总线宽度
`define MEM_TO_WB_WD 136      // MEM到WB阶段的总线宽度
`define BR_WD 33              // 分支指令信息总线宽度（1位使能 + 32位地址）
`define DATA_SRAM_WD 69        // 数据存储器总线宽度
`define WB_TO_RF_WD 38        // WB到寄存器堆的总线宽度
`define MEM_TO_RF_WD 38       // MEM到寄存器堆的总线宽度（数据转发）
`define EX_TO_RF_WD 38        // EX到寄存器堆的总线宽度（数据转发）

// 流水线暂停控制相关定义
`define StallBus 6            // 流水线暂停控制总线宽度（6位，对应6个阶段）
`define NoStop 1'b0           // 不暂停信号
`define Stop 1'b1             // 暂停信号

// 常用值定义
`define ZeroWord 32'b0        // 32位零值常量

// 除法器状态定义
`define DivFree 2'b00         // 除法器空闲状态
`define DivByZero 2'b01       // 除零错误状态
`define DivOn 2'b10           // 除法器正在计算状态
`define DivEnd 2'b11           // 除法器计算完成状态

// 除法器结果状态定义
`define DivResultReady 1'b1    // 除法结果已准备好
`define DivResultNotReady 1'b0 // 除法结果未准备好

// 除法器控制信号定义
`define DivStart 1'b1         // 启动除法运算信号
`define DivStop 1'b0          // 停止除法运算信号