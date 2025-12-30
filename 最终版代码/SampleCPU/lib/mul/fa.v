// 全加器模块：实现1位全加器功能
// 计算三个1位输入的和与进位输出
// 采用两级逻辑门实现，支持高速运算
module fa (
  input a,      // 第一个1位输入
  input b,      // 第二个1位输入
  input cin,    // 进位输入
  output s,     // 和输出
  output c      // 进位输出
);
  // 内部中间信号
  wire s1, t1, t2, t3;
  
  // 计算a和b的异或（半加器的和）
  assign s1 = a^b;
  // 计算最终的和：s1与cin的异或
  assign s = s1^cin;
  
  // 计算进位：a和b的与（半加器的进位）
  assign t3 = a&b;
  // 计算进位：a和cin的与
  assign t2 = a&cin;
  // 计算进位：b和cin的与
  assign t1 = b&cin;
  // 计算最终的进位：三个进位信号的或
  assign c = t1|t2|t3;
endmodule