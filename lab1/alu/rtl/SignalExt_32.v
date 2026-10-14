`timescale 1ns/1ps

// 1 位信号算术扩展成 32 位

module SignalExt_32 (
    input         S,
    output [31:0] So
);
    assign So = {32{S}};
endmodule