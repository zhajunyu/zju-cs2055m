`timescale 1ns/1ps

module mux8to1_32 (
    input  [31:0] I0,
    input  [31:0] I1,
    input  [31:0] I2,
    input  [31:0] I3,
    input  [31:0] I4,
    input  [31:0] I5,
    input  [31:0] I6,
    input  [31:0] I7,
    input  [2:0]  s,
    output reg [31:0] o
);
    always @(*) begin
        case (s)
            3'd0: o = I0;
            3'd1: o = I1;
            3'd2: o = I2;
            3'd3: o = I3;
            3'd4: o = I4;
            3'd5: o = I5;
            3'd6: o = I6;
            3'd7: o = I7;
            default: o = 32'b0;
        endcase
    end
endmodule