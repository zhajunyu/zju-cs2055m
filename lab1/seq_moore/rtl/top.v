`timescale 1ns/1ps

// 任务：设计序列检测器（检测序列 “1110010”），采用三段式 Moore 状态机
// 功能：输入 in 依次出现 “1110010” 时，out 输出一个时钟周期的高电平，否则为低电平
//
// 状态含义（Si 表示已匹配序列的前 i 位）：
//   S0: 初始     S1: 1        S2: 11       S3: 111
//   S4: 1110     S5: 11100    S6: 111001   S7: 1110010（检测成功）
//
// 复位信号 reset 低电平有效、异步复位

module top (
    input  clk,       // 系统时钟
    input  reset,     // 系统复位（低电平有效）
    input  in,        // 序列输入
    output out        // 检测结果输出
);

    // 状态定义和编码（二进制码）
    parameter [2:0] S0 = 3'b000,
                    S1 = 3'b001,
                    S2 = 3'b010,
                    S3 = 3'b011,
                    S4 = 3'b100,
                    S5 = 3'b101,
                    S6 = 3'b110,
                    S7 = 3'b111;

    // 内部变量：当前状态与次态（Moore 型输出只与当前状态有关）
    reg [2:0] curr_state;
    reg [2:0] next_state;

    // 第一段：状态跳转（时序逻辑，非阻塞赋值）
    always @(posedge clk or negedge reset) begin
        if (!reset)
            curr_state <= S0;
        else
            curr_state <= next_state;
    end

    // 第二段：次态判断（组合逻辑，阻塞赋值，if/else 配对避免 latch）
    always @(*) begin
        case (curr_state)
            S0: begin
                if (in == 1'b0) next_state = S0;
                else            next_state = S1;    // 匹配 “1”
            end
            S1: begin
                if (in == 1'b0) next_state = S0;
                else            next_state = S2;    // 匹配 “11”
            end
            S2: begin
                if (in == 1'b0) next_state = S0;
                else            next_state = S3;    // 匹配 “111”
            end
            S3: begin
                if (in == 1'b0) next_state = S4;    // 匹配 “1110”
                else            next_state = S3;    // “1111” 末尾仍为 “111”
            end
            S4: begin
                if (in == 1'b0) next_state = S5;    // 匹配 “11100”
                else            next_state = S1;    // “11101” 末尾为 “1”
            end
            S5: begin
                if (in == 1'b0) next_state = S0;    // “111000” 没有可用后缀
                else            next_state = S6;    // 匹配 “111001”
            end
            S6: begin
                if (in == 1'b0) next_state = S7;    // 匹配 “1110010”，检测成功
                else            next_state = S2;    // “1110011” 末尾为 “11”
            end
            S7: begin
                if (in == 1'b0) next_state = S0;
                else            next_state = S1;    // 末尾为 “1”，可作为下次匹配的开头
            end
            default: next_state = S0;
        endcase
    end

    // 第三段：输出（Moore 型，只与当前状态有关）
    assign out = (curr_state == S7) ? 1'b1 : 1'b0;

endmodule
