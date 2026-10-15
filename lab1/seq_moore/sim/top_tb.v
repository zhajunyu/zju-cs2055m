`timescale 1ns/1ps

// 激励与 Lab1-2“仿真波形”一致（对应参考工程 OExp01-seq_moore 的 tb.v）：
//   clk 周期 40ns；reset 0ns-20ns 为低（复位），之后拉高
//   输入序列 011100101：in 从 0 开始，按下表翻转
//     30ns:1  70ns:1  110ns:1  150ns:0  190ns:0  230ns:1  270ns:0  310ns:1
//   300ns 时第 7 个有效输入（0）被采样，检测到 “1110010”，out 拉高一个时钟周期

module top_tb;
    reg  clk;
    reg  reset;
    reg  in;
    wire out;

    top seq_uut (
        .clk   (clk),
        .reset (reset),
        .in    (in),
        .out   (out)
    );

    always #20 clk = ~clk;

    initial begin
        clk   = 1'b0;
        reset = 1'b0;

        #20
        reset = 1'b1;
    end

    initial begin
        in = 1'b0;          // 011100101

        #30
        in = 1'b1;
        #40
        in = 1'b1;
        #40
        in = 1'b1;
        #40
        in = 1'b0;
        #40
        in = 1'b0;
        #40
        in = 1'b1;
        #40
        in = 1'b0;
        #40
        in = 1'b1;
        #40
        $finish;
    end

    // 自检：检测到序列后 out 应保持一个时钟周期高电平（300ns-340ns）
    initial begin
        #305
        if (out === 1'b1)
            $display("PASS: t=305ns, out=1（检测到序列 1110010）");
        else
            $display("FAIL: t=305ns, out 应为 1，实际为 %b", out);

        #40
        if (out === 1'b0)
            $display("PASS: t=345ns, out=0（一个时钟周期后恢复低电平）");
        else
            $display("FAIL: t=345ns, out 应为 0，实际为 %b", out);
    end
endmodule
