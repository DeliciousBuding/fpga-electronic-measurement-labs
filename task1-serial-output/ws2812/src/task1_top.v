// =============================================================
//  task1_top.v
//  任务1-1：WS2812 彩灯控制器
//  ---------------------------------------------------------
//  功能：通过 3 个按键控制 8 颗 WS2812 RGB LED
//    K1 — 亮度减（0~15 级）  K2 — 亮度加  L1 — 模式切换
//  包含模块：
//    1. task1_top      — 顶层，连接按键消抖/亮度控制/流水节拍/灰盒IP
//    2. key_pulse_low  — 低电平按键消抖（20ms）
//  依赖：
//    ws2812 (灰盒IP, ws2812-u_ws2812.qxp)
// =============================================================
module task1_top (
    input  wire clk,                  // 50MHz, PIN_E1
    input  wire key_brightness_down,  // PIN_K1, 按下为低
    input  wire key_brightness_up,    // PIN_K2, 按下为低
    input  wire key_led_mode,         // PIN_L1, 按下为低
    input  wire rst_n,                // PIN_L2, 低电平复位
    output wire led_out               // PIN_T2
);

    // =========================
    // 1. 按键消抖，产生单周期脉冲
    // =========================
    wire key_down_pulse;
    wire key_up_pulse;
    wire key_mode_pulse;

    key_pulse_low u_key_down (
        .clk   (clk),
        .rst_n (rst_n),
        .key_n (key_brightness_down),
        .pulse (key_down_pulse)
    );

    key_pulse_low u_key_up (
        .clk   (clk),
        .rst_n (rst_n),
        .key_n (key_brightness_up),
        .pulse (key_up_pulse)
    );

    key_pulse_low u_key_mode (
        .clk   (clk),
        .rst_n (rst_n),
        .key_n (key_led_mode),
        .pulse (key_mode_pulse)
    );


    // =========================
    // 2. 亮度控制和模式切换
    // =========================
    reg [3:0] led_brightness;
    reg       mode;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            led_brightness <= 4'd8;   // 初始中等亮度
            mode           <= 1'b0;   // 初始 LED 模式
        end else begin
            if (key_up_pulse && led_brightness < 4'd15)
                led_brightness <= led_brightness + 4'd1;

            if (key_down_pulse && led_brightness > 4'd0)
                led_brightness <= led_brightness - 4'd1;

            if (key_mode_pulse)
                mode <= ~mode;
        end
    end


    // =========================
    // 3. 产生流水节拍
    // =========================
    // 50MHz 下，10_000_000 个周期约等于 0.2s
    localparam integer FLOW_DIV = 10_000_000;

    reg [23:0] flow_cnt;
    reg [2:0]  flow_pos;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            flow_cnt <= 24'd0;
            flow_pos <= 3'd0;
        end else begin
            if (flow_cnt == FLOW_DIV - 1) begin
                flow_cnt <= 24'd0;
                flow_pos <= flow_pos + 3'd1;
            end else begin
                flow_cnt <= flow_cnt + 24'd1;
            end
        end
    end


    // =========================
    // 4. 生成送给灰盒 ws2812 的数据
    // =========================
    reg [7:0] led_data_in10;
    reg [7:0] led_data_in32;

    always @(*) begin
        led_data_in10 = 8'h00;
        led_data_in32 = 8'h00;

        if (mode == 1'b0) begin
            // mode = 0：8 个灯的二进制亮灭模式
            // 课件说明映射大概是 [3210_4567]
            // 这里做一个从 0 -> 7 的单灯流水
            case (flow_pos)
                3'd0: led_data_in10 = 8'b0001_0000; // LED0
                3'd1: led_data_in10 = 8'b0010_0000; // LED1
                3'd2: led_data_in10 = 8'b0100_0000; // LED2
                3'd3: led_data_in10 = 8'b1000_0000; // LED3
                3'd4: led_data_in10 = 8'b0000_1000; // LED4
                3'd5: led_data_in10 = 8'b0000_0100; // LED5
                3'd6: led_data_in10 = 8'b0000_0010; // LED6
                3'd7: led_data_in10 = 8'b0000_0001; // LED7
                default: led_data_in10 = 8'b0000_0000;
            endcase

            led_data_in32 = 8'h00;
        end else begin
            // mode = 1：四进制颜色模式
            // 00: 灭, 01: 绿, 10: 红, 11: 蓝
            // 这里给一个简单变色效果
            case (flow_pos[1:0])
                2'd0: begin
                    led_data_in32 = 8'b01_10_11_00;
                    led_data_in10 = 8'b00_01_10_11;
                end
                2'd1: begin
                    led_data_in32 = 8'b10_11_00_01;
                    led_data_in10 = 8'b01_10_11_00;
                end
                2'd2: begin
                    led_data_in32 = 8'b11_00_01_10;
                    led_data_in10 = 8'b10_11_00_01;
                end
                2'd3: begin
                    led_data_in32 = 8'b00_01_10_11;
                    led_data_in10 = 8'b11_00_01_10;
                end
            endcase
        end
    end


    // =========================
    // 5. 调用老师提供的 qxp 灰盒模块
    // =========================
    ws2812 u_ws2812 (
        .clk            (clk),
        .led_brightness (led_brightness),
        .led_data_in10  (led_data_in10),
        .led_data_in32  (led_data_in32),
        .mode           (mode),
        .rst_n          (rst_n),
        .led_out        (led_out)
    );

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

    // 50MHz 下 1_000_000 周期约 20ms
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

                    // 从松开状态 1 变成按下状态 0，产生脉冲
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