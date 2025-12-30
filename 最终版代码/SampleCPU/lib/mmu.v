// MMU（内存管理单元）模块：实现MIPS架构中的地址映射
// 主要功能是将虚拟地址映射到物理地址，处理不同内存段的地址转换
// 在MIPS架构中，Kseg0和Kseg1是内核空间段，需要映射到物理内存
module mmu (
    input wire[31:0] addr_i,               // 输入的虚拟地址
    output wire [31:0] addr_o              // 输出的物理地址
);
    // 地址段标识信号
    wire [2:0] addr_head_i, addr_head_o;   // 输入和输出地址的高3位（段标识）
    wire kseg0, kseg1, other_seg;          // 段类型标识信号

    // 获取输入地址的高3位，用于判断地址属于哪个内存段
    assign addr_head_i = addr_i[31:29];
    
    // 判断地址是否属于Kseg0段（内核空间段0，地址范围：0x80000000-0x9FFFFFFF）
    // Kseg0段是可直接映射到物理内存的缓存段，物理地址 = 虚拟地址 - 0x80000000
    assign kseg0 = addr_head_i == 3'b100;
    
    // 判断地址是否属于Kseg1段（内核空间段1，地址范围：0xA0000000-0xBFFFFFFF）
    // Kseg1段是可直接映射到物理内存的非缓存段，物理地址 = 虚拟地址 - 0xA00000000
    assign kseg1 = addr_head_i == 3'b101;

    // 判断地址是否属于其他段（非Kseg0和Kseg1）
    assign other_seg = ~kseg0 & ~kseg1;

    // 根据地址段类型设置输出地址的高3位
    // Kseg0和Kseg1段映射到物理内存，高3位设为000
    // 其他段保持原地址的高3位不变
    assign addr_head_o = {3{kseg0}}&3'b000 | {3{kseg1}}&3'b000 | {3{other_seg}}&addr_head_i;
    
    // 构造最终的物理地址
    // 对于Kseg0和Kseg1，物理地址为虚拟地址的低29位前面补000
    // 对于其他段，保持原地址不变
    assign addr_o = {addr_head_o, addr_i[28:0]};

endmodule