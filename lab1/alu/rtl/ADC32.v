`timescale 1ns/1ps

// 带进位的 33 位加法器（对应原理图的 addc_32，即参考设计 addc_32.v）
// 减法在顶层完成：B 端接 B_Ctrl = B ^ {32{ALU_operation[2]}}，C0 = ALU_operation[2]
// B 用 C0 扩展一位（{C0,B}，即原理图 S(32:0) 处的“扩展符号位”注记）：
//   加法（C0=0）：S = A + B，低 32 位就是无符号加法结果
//   减法（C0=1）：S = A + ~B + 1 + 2^32，低 33 位正好是 A - B，
//                于是 S[32] = (A < B) 的借位，供 SLT = {31'b0, S[32]} 使用

module ADC32 (
    input  [31:0] A,
    input  [31:0] B,
    input         C0,
    output [32:0] S
);
    wire B_Notation = C0 ^ 1'b0;    // = C0，作为 B 的扩展位
    assign S = {1'b0, A} + {B_Notation, B} + C0;
endmodule