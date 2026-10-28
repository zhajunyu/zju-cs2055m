`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/02/29 13:40:50
// Design Name: 
// Module Name: VgaDisplay
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module VgaDisplay(
    input wire clk,
    input wire video_on,
    input wire [9:0] vga_x,
    input wire [8:0] vga_y,
    output wire [3:0] vga_r,
    output wire [3:0] vga_g,
    output wire [3:0] vga_b,
    input wire wen,
    input wire [11:0] w_addr,
    input wire [7:0] w_data
);

    // 两个 .mem 初始化文件与本源文件一起放在 rtl/vga/ 下。
    // Vivado 综合时按运行目录 <proj>/<proj>.runs/synth_1 解析相对路径，
    // 故这里的 "../../rtl/vga/" 指向工程目录下的同名拷贝（create_project.tcl
    // 会自动拷贝一份，见 README）。若手动建工程，请把这两个 .mem 放到
    // <工程目录>/rtl/vga/ 下，或直接把下面的路径改成 .mem 的绝对路径。
    (* ram_style = "block" *) reg [7:0] display_data[0:4095];
    initial $readmemh("../../rtl/vga/vga_debugger.mem", display_data);

    wire [11:0] text_index = (vga_y / 16) * 80 + vga_x / 8;
    // I don't know why I need this '- (vga_y / 16)' ...
    wire [7:0] text_ascii = display_data[text_index] - (vga_y / 16);
    wire [2:0] font_x = vga_x % 8;
    wire [3:0] font_y = vga_y % 16;
    wire [11:0] font_addr = text_ascii * 16 + font_y;

    (* ram_style = "block" *) reg [7:0] fonts_data[0:4095];
    initial $readmemh("../../rtl/vga/font_8x16.mem", fonts_data);
    wire [7:0] font_data = fonts_data[font_addr];

    assign { vga_r, vga_g, vga_b } = (video_on & font_data[7 - font_x]) ? 12'hfff : 12'h0;

    always @(posedge clk) begin
        if (wen) begin
            display_data[w_addr] <= w_data;
        end
    end
    
endmodule

