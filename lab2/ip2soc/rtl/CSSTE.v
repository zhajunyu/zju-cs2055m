`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// 实验二：建立 CPU 调试测试环境（基本 SOC 系统）顶层
//
// 按参考原理图 CSSTE.pdf，在顶层用结构化描述调用 11 个子模块并连线：
//   U1  SCPU         RISC-V CPU（本实验用固核网表，Lab4 中替换为自研 SCPU）
//   U2  Rom_D        指令存储器 1024x32，由 I_mem.coe 初始化
//   U3  RAM_B        数据存储器 1024x32
//   U4  MIO_BUS      总线接口（含 SW/BTN/LED/计数器的读写）
//   U5  Multi_8CH32  8 通道显示选择：通道 0 为 CPU 写显示设备，通道 1~7 为调试信号
//   U6  Seg7_Dev     七段数码管驱动
//   U7  SPIO         GPIO / LED 输出设备
//   U8  clk_div      32 位分频 + CPU 单步时钟
//   U9  SAnti_jitter 按键、拨码开关去抖与复位产生
//   U10 Counter_x    三通道通用计数器
//   U11 VGA          VGA 调试显示（PC / inst / ALU 结果等）
//
// 拨码开关用法：
//   SW[8],SW[2] = 00   CPU 全速 100MHz
//   SW[8],SW[2] = 01   CPU 自动单步（2^24 分频）
//   SW[8]       = 1    CPU 手动单步，SW[10] 由 0 拨到 1 执行一条指令
//   SW[7:5]            数码管显示通道选择，见 Multi_8CH32 的 data0~data7
//////////////////////////////////////////////////////////////////////////////////

module CSSTE(
    input         clk_100mhz,
    input         RSTN,
    input  [3:0]  BTN_y,
    input  [15:0] SW,
    output [3:0]  Blue,
    output [3:0]  Green,
    output [3:0]  Red,
    output        HSYNC,
    output        VSYNC,
    output [15:0] LED_out,
    output [7:0]  AN,
    output [7:0]  segment
);

//------------------------------------------------------------------------------
// 时钟与复位
//------------------------------------------------------------------------------
wire        rst;            // 去抖后的复位，高有效
wire [15:0] SW_OK;          // 去抖后的拨码开关
wire [3:0]  BTN_OK;         // 去抖后的按键

wire [31:0] clkdiv;         // 32 位分频计数器
wire        Clk_CPU;        // CPU 时钟：全速 / 自动单步 / 手动单步
wire        Clk_CPU_n;      // ~Clk_CPU
wire        clk_100mhz_n;   // ~clk_100mhz
wire        clk_25m;        // VGA 像素时钟

// 由分频计数器取不同位得到各外设时钟（参考原理图中的 divN 切片）：
//   clkdiv[k] 的翻转周期为 2^k 个主时钟，即频率 50MHz/2^k
//   clkdiv[1]  = 25MHz  -> VGA 像素时钟
//   clkdiv[6]  = 781kHz, clkdiv[9] = 97.7kHz, clkdiv[11] = 24.4kHz -> 计数器通道时钟
//   clkdiv[20] = 47.7Hz -> SPIO 串行扫描节拍
//   clkdiv[16..18]      -> 数码管动态扫描
assign Clk_CPU_n    = ~Clk_CPU;
assign clk_100mhz_n = ~clk_100mhz;      // 存储器时钟与 CPU 反向
assign clk_25m      = clkdiv[1];

//------------------------------------------------------------------------------
// CPU 与存储器总线
//------------------------------------------------------------------------------
wire [31:0] PC_out;         // CPU 输出的 PC（字节地址）
wire [31:0] Inst_in;        // ROM 输出的指令
wire [31:0] Addr_out;       // CPU 访存地址，即 ALU 输出
wire [31:0] Data_out;       // CPU 写数据
wire [31:0] Data_in;        // CPU 读数据
wire        MemRW;          // 存储器读写控制

wire [31:0] ram_data_in;    // 写入 RAM 的数据
wire [31:0] ram_data_out;   // 从 RAM 读出的数据
wire [9:0]  ram_addr;       // RAM 地址
wire        data_ram_we;    // RAM 写使能

//------------------------------------------------------------------------------
// 外设总线
//------------------------------------------------------------------------------
wire        GPIOf0000000_we;    // 写 SPIO / LED
wire        GPIOe0000000_we;    // 写 Seg7 显示设备
wire        counter_we;         // 写计数器
wire [31:0] Cpu_data4bus;       // MIO_BUS 送给 CPU 的读数据
wire [31:0] Peripheral_in;      // 外设读数据

wire [31:0] counter_out;        // 计数器当前值
wire        counter0_out;
wire        counter1_out;
wire        counter2_out;
wire [1:0]  counter_set;        // 计数器通道设置

wire [7:0]  point_out;          // 数码管小数点
wire [7:0]  LE_out;             // 数码管闪烁使能
wire [31:0] Disp_num;           // 数码管待显示数据

assign Data_in = Cpu_data4bus;

//------------------------------------------------------------------------------
// U1：SCPU
//------------------------------------------------------------------------------
SCPU U1(
    .Addr_out  (Addr_out),
    .Data_in   (Data_in),
    .Data_out  (Data_out),
    .MIO_ready (1'b0),
    .MemRW     (MemRW),
    .PC_out    (PC_out),
    .clk       (Clk_CPU),
    .inst_in   (Inst_in),
    .rst       (rst),
    .CPU_MIO   ()               // 本实验不使用中断
);

//------------------------------------------------------------------------------
// U2：Rom_D，指令存储器
//------------------------------------------------------------------------------
Rom_D U2(
    .a   (PC_out[11:2]),        // PC 字地址，1024 条指令
    .spo (Inst_in)
);

//------------------------------------------------------------------------------
// U3：RAM_B，数据存储器
//------------------------------------------------------------------------------
RAM_B U3(
    .addra (ram_addr),
    .clka  (clk_100mhz_n),
    .dina  (ram_data_in),
    .douta (ram_data_out),
    .wea   (data_ram_we)
);

//------------------------------------------------------------------------------
// U4：MIO_BUS，总线接口
//------------------------------------------------------------------------------
MIO_BUS U4(
    .clk             (clk_100mhz),
    .rst             (rst),
    .BTN             (BTN_OK),
    .SW              (SW_OK),
    .mem_w           (MemRW),
    .Cpu_data2bus    (Data_out),
    .addr_bus        (Addr_out),
    .ram_data_out    (ram_data_out),
    .led_out         (LED_out),
    .counter_out     (counter_out),
    .counter0_out    (counter0_out),
    .counter1_out    (counter1_out),
    .counter2_out    (counter2_out),
    .Cpu_data4bus    (Cpu_data4bus),
    .ram_data_in     (ram_data_in),
    .ram_addr        (ram_addr),
    .data_ram_we     (data_ram_we),
    .GPIOf0000000_we (GPIOf0000000_we),
    .GPIOe0000000_we (GPIOe0000000_we),
    .counter_we      (counter_we),
    .Peripheral_in   (Peripheral_in)
);

//------------------------------------------------------------------------------
// U5：Multi_8CH32，8 通道显示选择
//   Test = SW[7:5] 选择通道：
//     000 data0  CPU 通过 GPIOe0000000_we 写入的显示数据
//     001 data1  PC 字地址        PC_out[31:2]
//     010 data2  指令字          Inst_in
//     011 data3  计数器值        counter_out
//     100 data4  RAM 地址 = ALU 输出  Addr_out
//     101 data5  CPU 数据输出    Data_out（寄存器 B）
//     110 data6  CPU 数据输入    Data_in（RAM 输出）
//     111 data7  PC 字节地址     PC_out
//------------------------------------------------------------------------------
Multi_8CH32 U5(
    .clk       (Clk_CPU_n),
    .rst       (rst),
    .EN        (GPIOe0000000_we),
    .Test      (SW_OK[7:5]),
    .point_in  ({clkdiv, clkdiv}),
    .LES       (64'b0),
    .Data0     (Peripheral_in),
    .data1     ({2'b00, PC_out[31:2]}),
    .data2     (Inst_in),
    .data3     (counter_out),
    .data4     (Addr_out),
    .data5     (Data_out),
    .data6     (Data_in),
    .data7     (PC_out),
    .point_out (point_out),
    .LE_out    (LE_out),
    .Disp_num  (Disp_num)
);

//------------------------------------------------------------------------------
// U6：Seg7_Dev，七段数码管驱动
//------------------------------------------------------------------------------
Seg7_Dev U6(
    .disp_num (Disp_num),
    .point    (point_out),
    .les      (LE_out),
    .scan     ({clkdiv[16], clkdiv[17], clkdiv[18]}),
    .AN       (AN),
    .segment  (segment)
);

//------------------------------------------------------------------------------
// U7：SPIO，GPIO / LED 输出设备
//------------------------------------------------------------------------------
SPIO U7(
    .clk         (Clk_CPU_n),
    .rst         (rst),
    .Start       (clkdiv[20]),
    .EN          (GPIOf0000000_we),
    .P_Data      (Peripheral_in),
    .counter_set (counter_set),
    .LED_out     (LED_out),
    .led_clk     (),
    .led_sout    (),
    .led_clrn    (),
    .LED_PEN     (),
    .GPIOf0      ()
);

//------------------------------------------------------------------------------
// U8：clk_div，分频与 CPU 单步时钟
//------------------------------------------------------------------------------
clk_div U8(
    .clk     (clk_100mhz),
    .rst     (rst),
    .SW2     (SW_OK[2]),
    .SW8     (SW_OK[8]),
    .STEP    (SW_OK[10]),
    .clkdiv  (clkdiv),
    .Clk_CPU (Clk_CPU)
);

//------------------------------------------------------------------------------
// U9：SAnti_jitter，按键 / 开关去抖与复位产生
//------------------------------------------------------------------------------
SAnti_jitter U9(
    .clk       (clk_100mhz),
    .RSTN      (RSTN),
    .readn     (1'b1),          // 本实验不做键盘扫描，固定为无效
    .Key_y     (BTN_y),
    .SW        (SW),
    .Key_x     (),
    .Key_out   (),
    .Key_ready (),
    .pulse_out (),
    .BTN_OK    (BTN_OK),
    .SW_OK     (SW_OK),
    .CR        (),
    .rst       (rst)
);

//------------------------------------------------------------------------------
// U10：Counter_x，三通道通用计数器
//------------------------------------------------------------------------------
Counter_x U10(
    .clk          (Clk_CPU_n),
    .rst          (rst),
    .clk0         (clkdiv[6]),
    .clk1         (clkdiv[9]),
    .clk2         (clkdiv[11]),
    .counter_we   (counter_we),
    .counter_val  (Peripheral_in),
    .counter_ch   (counter_set),
    .counter0_OUT (counter0_out),
    .counter1_OUT (counter1_out),
    .counter2_OUT (counter2_out),
    .counter_out  (counter_out)
);

//------------------------------------------------------------------------------
// U11：VGA，调试信息显示
//------------------------------------------------------------------------------
VGA U11(
    .clk_25m     (clk_25m),
    .clk_100m    (clk_100mhz),
    .rst         (rst),
    .pc          (PC_out),
    .inst        (Inst_in),
    .alu_res     (Addr_out),
    .mem_wen     (MemRW),
    .dmem_o_data (ram_data_out),
    .dmem_i_data (ram_data_in),
    .dmem_addr   (Addr_out),
    .hs          (HSYNC),
    .vs          (VSYNC),
    .vga_r       (Red),
    .vga_g       (Green),
    .vga_b       (Blue)
);

endmodule
