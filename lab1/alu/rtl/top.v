`timescale 1ns/1ps

module top (
    input  [31:0] A,
    input  [2:0]  ALU_operation,
    input  [31:0] B,
    output [31:0] res,
    output        zero
);

    wire [32:0] addc_32_0_S;

    wire [31:0] SignalExt_32_0_So;
    wire [31:0] xor32_1_res;

    wire [31:0] and32_0_res;
    wire [31:0] or32_0_res;
    wire [31:0] xor32_0_res;
    wire [31:0] nor32_0_res;
    wire [31:0] srl32_0_res;

    wire [31:0] MUX8T1_32_0_o;
    wire        or_bit_32_0_o;


    and32 and32_0 (
        .A   (A),
        .B   (B),
        .res (and32_0_res)
    );

    or32 or32_0 (
        .A   (A),
        .B   (B),
        .res (or32_0_res)
    );

    xor32 xor32_0 (
        .A   (A),
        .B   (B),
        .res (xor32_0_res)
    );

    nor32 nor32_0 (
        .A   (A),
        .B   (B),
        .res (nor32_0_res)
    );

    srl32 srl32_0 (
        .A   (A),
        .B   (B),
        .res (srl32_0_res)
    );

    // B_Ctrl = B ^ {32{ALU_operation[2]}}
    SignalExt_32 SignalExt_32_0 (
        .S  (ALU_operation[2]),
        .So (SignalExt_32_0_So)
    );

    xor32 xor32_1 (
        .A   (SignalExt_32_0_So),
        .B   (B),
        .res (xor32_1_res)
    );

    ADC32 adc_32_0 (
        .A  (A),
        .B  (xor32_1_res),
        .C0 (ALU_operation[2]),
        .S  (addc_32_0_S)
    );

    mux8to1_32 MUX8T1_32_0 (
        .I0 (and32_0_res),                  // 000：AND
        .I1 (or32_0_res),                   // 001：OR
        .I2 (addc_32_0_S[31:0]),            // 010：ADD
        .I3 (xor32_0_res),                  // 011：XOR
        .I4 (nor32_0_res),                  // 100：NOR
        .I5 (srl32_0_res),                  // 101：SRL
        .I6 (addc_32_0_S[31:0]),            // 110：SUB
        .I7 ({31'b0, addc_32_0_S[32]}),     // 111：SLT = {31'b0, S[32]}
        .s  (ALU_operation),
        .o  (MUX8T1_32_0_o)
    );

    assign res = MUX8T1_32_0_o;

    or_bit_32 or_bit_32_0 (
        .A (MUX8T1_32_0_o),
        .o (or_bit_32_0_o)
    );

    assign zero = ~or_bit_32_0_o;

endmodule
