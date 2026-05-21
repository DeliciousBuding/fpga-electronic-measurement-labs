// =============================================================
//  uart_tx_top.v
//  任务1-4：UART 串口发送模块（独立版）
//  ---------------------------------------------------------
//  功能：K1 按键触发发送固定字节 0x55，波特率 115200，8N1
//  选用 0x55 的原因：二进制 01010101，波形高低交替，示波器易观测
//  包含模块：
//    1. uart_tx_top   — 顶层，连接按键消抖与发送状态机
//    2. key_pulse_low — 低电平按键消抖（20ms）
// =============================================================
module uart_tx_top (
    input  wire clk,              // 50MHz, PIN_E1
    input  wire nrst,             // 低电平复位, PIN_L2
    input  wire tx_en,            // K1按键, 低电平有效, PIN_K1
    output wire tx_dout,          // UART发送输出, PIN_D6
    output wire tx_busy_flag_qn   // 忙标志取反, PIN_A7，空闲为1，发送中为0
);

    // 发送固定数据。0x55 = 0101_0101，波形高低交替，最适合示波器观察
    localparam [7:0] TX_DEFAULT_DATA = 8'h55;

    // 50MHz / 115200 ≈ 434.03
    // 一个 bit 约 434 * 20ns = 8.68us
    localparam integer BAUD_DIV = 434;

    wire tx_start_pulse;

    key_pulse_low u_key_tx (
        .clk   (clk),
        .rst_n (nrst),
        .key_n (tx_en),
        .pulse (tx_start_pulse)
    );

    reg [15:0] baud_cnt;
    reg [3:0]  bit_cnt;
    reg [9:0]  tx_shift;
    reg        sending;
    reg        tx_dout_r;

    assign tx_dout = tx_dout_r;

    // qn: 取反标志。空闲=1，发送中=0
    assign tx_busy_flag_qn = ~sending;

    always @(posedge clk or negedge nrst) begin
        if (!nrst) begin
            baud_cnt  <= 16'd0;
            bit_cnt   <= 4'd0;
            tx_shift  <= 10'b11_1111_1111;
            sending   <= 1'b0;
            tx_dout_r <= 1'b1;   // UART空闲为高电平
        end else begin
            if (!sending) begin
                baud_cnt <= 16'd0;
                bit_cnt  <= 4'd0;
                tx_dout_r <= 1'b1;

                if (tx_start_pulse) begin
                    // UART 8N1 帧格式：
                    // 起始位0 + 8位数据LSB first + 停止位1
                    tx_shift  <= {1'b1, TX_DEFAULT_DATA, 1'b0};
                    sending   <= 1'b1;
                    tx_dout_r <= 1'b0;   // 立即输出起始位
                end
            end else begin
                if (baud_cnt == BAUD_DIV - 1) begin
                    baud_cnt <= 16'd0;

                    if (bit_cnt == 4'd9) begin
                        // 10位发送完成：start + 8 data + stop
                        sending   <= 1'b0;
                        bit_cnt   <= 4'd0;
                        tx_dout_r <= 1'b1;   // 回到空闲高电平
                    end else begin
                        bit_cnt   <= bit_cnt + 4'd1;
                        tx_shift  <= {1'b1, tx_shift[9:1]};
                        tx_dout_r <= tx_shift[1]; // 输出下一位
                    end
                end else begin
                    baud_cnt <= baud_cnt + 16'd1;
                end
            end
        end
    end

endmodule


// =============================================================
//  key_pulse_low — 低电平按键消抖
//  功能：2 级同步器防亚稳态 + 20ms 计数器消抖
//  输出：检测到稳定的按下（高→低）后输出 1 个 clk 周期脉冲
// =============================================================
module key_pulse_low (
    input  wire clk,
    input  wire rst_n,
    input  wire key_n,
    output reg  pulse
);

    // 50MHz下约20ms
    localparam integer DEBOUNCE_MAX = 1_000_000;

    reg [1:0]  key_sync;
    reg        key_state;
    reg [20:0] cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            key_sync <= 2'b11;
        end else begin
            key_sync <= {key_sync[0], key_n};
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            key_state <= 1'b1;
            cnt       <= 21'd0;
            pulse     <= 1'b0;
        end else begin
            pulse <= 1'b0;

            if (key_sync[1] == key_state) begin
                cnt <= 21'd0;
            end else begin
                if (cnt >= DEBOUNCE_MAX - 1) begin
                    cnt <= 21'd0;

                    if (key_state == 1'b1 && key_sync[1] == 1'b0)
                        pulse <= 1'b1;

                    key_state <= key_sync[1];
                end else begin
                    cnt <= cnt + 21'd1;
                end
            end
        end
    end

endmodule