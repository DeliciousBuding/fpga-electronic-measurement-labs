// =============================================================
//  ws2812_stub.v
//  任务1-1：WS2812 灰盒 IP 核 — 综合用黑盒声明
//  ---------------------------------------------------------
//  说明：此文件仅用于 Quartus 综合阶段，告诉编译器 ws2812 模块的
//        端口接口。实际功能由课程提供的 ws2812-u_ws2812.qxp 实现。
//        下载到 FPGA 时，qxp 中的网表会替代此空壳。
// =============================================================
module ws2812 (
    input  wire       clk,
    input  wire [3:0] led_brightness,
    input  wire [7:0] led_data_in10,
    input  wire [7:0] led_data_in32,
    input  wire       mode,
    input  wire       rst_n,
    output wire       led_out
);

/* synthesis syn_black_box */

endmodule