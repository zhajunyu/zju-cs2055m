`timescale 1ns/1ps

module top_tb;
    reg         clk;
    reg         rst;
    reg  [4:0]  Rs1_addr;
    reg  [4:0]  Rs2_addr;
    reg  [4:0]  Wt_addr;
    reg  [31:0] Wt_data;
    reg         RegWrite;
    wire [31:0] Rs1_data;
    wire [31:0] Rs2_data;

    top regfile_uut (
        .clk       (clk),
        .rst       (rst),
        .Rs1_addr  (Rs1_addr),
        .Rs2_addr  (Rs2_addr),
        .Wt_addr   (Wt_addr),
        .Wt_data   (Wt_data),
        .RegWrite  (RegWrite),
        .Rs1_data  (Rs1_data),
        .Rs2_data  (Rs2_data)
    );

    always #10 clk = ~clk;

    initial begin
        clk      = 1'b0;
        rst      = 1'b1;
        RegWrite = 1'b0;
        Wt_addr  = 5'b0;
        Wt_data  = 32'b0;
        Rs1_addr = 5'b0;
        Rs2_addr = 5'b0;

        #100
        rst      = 1'b0;
        RegWrite = 1'b1;
        Wt_addr  = 5'b00101;
        Wt_data  = 32'ha5a5a5a5;

        #50
        Wt_addr  = 5'b01010;
        Wt_data  = 32'h5a5a5a5a;

        #50
        RegWrite = 1'b0;
        Rs1_addr = 5'b00101;
        Rs2_addr = 5'b01010;

        #100
        if ((Rs1_data !== 32'ha5a5a5a5) || (Rs2_data !== 32'h5a5a5a5a))
            $display("FAIL: Rs1_data=%h (expect a5a5a5a5), Rs2_data=%h (expect 5a5a5a5a)",
                     Rs1_data, Rs2_data);
        else
            $display("PASS: Rs1_data=%h, Rs2_data=%h", Rs1_data, Rs2_data);

        $stop;
    end
endmodule
