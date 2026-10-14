`timescale 1ns/1ps

// 32位自“或”，用于全零判断：o=1 表示 A 中存在 1；o=0 表示 A 全零
module or_bit_32 (
    input  [31:0] A,
    output        o
);
    assign o = |A;
endmodule