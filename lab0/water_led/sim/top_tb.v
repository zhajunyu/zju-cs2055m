`timescale 1ns / 1ps

module top_tb;
    reg CLK_i;
    reg RSTn_i;
    wire  [3:0] LED_o;

    top top_uut(
        .CLK_i(CLK_i),
        .RSTn_i(RSTn_i),
        .LED_o(LED_o)
    );

    always #5 CLK_i = ~CLK_i;

    initial begin
        CLK_i = 0;
        RSTn_i = 0;
        #100 RSTn_i = 1;
    end
endmodule
