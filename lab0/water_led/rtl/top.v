`timescale 1ns / 1ps

module top(
   input CLK_i,
   input RSTn_i,
   output reg [3:0] LED_o
);
    reg [31:0]C0;
    
    always @(posedge CLK_i) begin
        if (!RSTn_i) begin
            LED_o <= 4'b1;
            C0 <= 32'h0;
        end else begin
            if (C0 == 32'd100_000_000) begin
                C0 <= 32'h0;
                if (LED_o == 4'b1000) begin
                    LED_o <= 4'b1;
                end else begin 
                    LED_o <= LED_o << 1;
                end
            end else begin 
                C0 <= C0 + 1'b1; 
                LED_o <= LED_o; 
            end
        end
    end
endmodule
