// =============================================================
//  uart_loopback_top.v
//  任务2-1：UART 收发回环 + WS2812 LED 控制
//  ---------------------------------------------------------
//  功能：PC 通过蓝牙(CH9143) 发送命令字符到 FPGA，
//        FPGA 接收后回传同一字节，并根据命令控制 WS2812 彩灯。
//  包含模块：
//    1. uart_loopback_top — 顶层，连接收发器与控制逻辑
//    2. uart_tx_byte      — UART 8N1 发送器（参数化波特率）
//    3. uart_rx_byte      — UART 8N1 接收器（中心采样）
//    4. ws2812_8led       — WS2812 8 灯驱动（GRB, MSB first）
//    5. key_pulse_low     — 低电平按键消抖
//  =============================================================
module uart_loopback_top (
    input  wire clk,              // 50MHz, PIN_E1
    input  wire nrst,             // 低电平复位, PIN_L2
    input  wire tx_en,            // K1按键, 低电平有效, PIN_K1

    input  wire rx_din,           // UART RX 输入, PIN_B11, 接 CH9143 TX
    output wire tx_dout,          // UART TX 输出, PIN_D6, 接 CH9143 RX

    output wire tx_busy_flag_qn,  // 空闲为1，发送中为0, PIN_A7
    output wire led_din           // WS2812 数据输入, PIN_T2
);

    // 50MHz / 115200 ≈ 434.03
    // Tbit ≈ 434 * 20ns = 8.68us
    localparam integer BAUD_DIV = 434;

    // K1 手动发送 'U'（0x55，波形高低交替，示波器易观测）
    localparam [7:0] TX_DEFAULT_DATA = 8'h55;

    // =====================================================
    // 按键消抖
    // =====================================================
    wire tx_start_pulse;

    key_pulse_low u_key_tx (
        .clk   (clk),
        .rst_n (nrst),
        .key_n (tx_en),
        .pulse (tx_start_pulse)
    );

    // =====================================================
    // UART 接收
    // =====================================================
    wire [7:0] rx_data;
    wire       rx_ready;

    uart_rx_byte #(
        .BAUD_DIV(BAUD_DIV)
    ) u_uart_rx (
        .clk      (clk),
        .rst_n    (nrst),
        .rx_din   (rx_din),
        .rx_data  (rx_data),
        .rx_ready (rx_ready)
    );

    // =====================================================
    // UART 发送
    // =====================================================
    wire       tx_start_req;
    wire [7:0] tx_data_req;
    wire       tx_busy;

    uart_tx_byte #(
        .BAUD_DIV(BAUD_DIV)
    ) u_uart_tx (
        .clk      (clk),
        .rst_n    (nrst),
        .tx_start (tx_start_req),
        .tx_data  (tx_data_req),
        .tx_dout  (tx_dout),
        .tx_busy  (tx_busy)
    );

    assign tx_busy_flag_qn = ~tx_busy;

    // =====================================================
    // 双层 FSM + 仲裁：rx_ready 优先，K1 手动发送次之
    // =====================================================
    wire [2:0] led_mode;

    dual_layer_fsm u_dual_layer_fsm (
        .clk      (clk),
        .rst_n    (nrst),
        .rx_ready (rx_ready),
        .rx_data  (rx_data),
        .tx_busy  (tx_busy),
        .req      (tx_start_pulse),
        .req_data (TX_DEFAULT_DATA),
        .tx_start (tx_start_req),
        .tx_data  (tx_data_req),
        .led_mode (led_mode)
    );

    // =====================================================
    // LED 闪烁节拍
    // =====================================================
    reg [25:0] blink_cnt;
    reg        blink_on;

    always @(posedge clk or negedge nrst) begin
        if (!nrst) begin
            blink_cnt <= 26'd0;
            blink_on  <= 1'b0;
        end else begin
            // 约0.5秒翻转一次
            if (blink_cnt >= 26'd24_999_999) begin
                blink_cnt <= 26'd0;
                blink_on  <= ~blink_on;
            end else begin
                blink_cnt <= blink_cnt + 26'd1;
            end
        end
    end

    ws2812_8led u_ws2812_8led (
        .clk      (clk),
        .rst_n    (nrst),
        .mode     (led_mode),
        .blink_on (blink_on),
        .led_din  (led_din)
    );

endmodule


// =============================================================
//  uart_tx_byte — UART 8N1 发送器
//  功能：收到 tx_start 脉冲后，按 LSB first 发送 tx_data 的 8 位数据
//  帧格式：起始位(0) + 8位数据 + 停止位(1)，共 10 位
// =============================================================
module uart_tx_byte #(
    parameter integer BAUD_DIV = 434
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       tx_start,
    input  wire [7:0] tx_data,
    output wire       tx_dout,
    output wire       tx_busy
);

    reg [15:0] baud_cnt;
    reg [3:0]  bit_cnt;
    reg [9:0]  tx_shift;
    reg        sending;
    reg        tx_dout_r;

    assign tx_dout = tx_dout_r;
    assign tx_busy = sending;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            baud_cnt  <= 16'd0;
            bit_cnt   <= 4'd0;
            tx_shift  <= 10'b11_1111_1111;
            sending   <= 1'b0;
            tx_dout_r <= 1'b1;
        end else begin
            if (!sending) begin
                baud_cnt  <= 16'd0;
                bit_cnt   <= 4'd0;
                tx_dout_r <= 1'b1;

                if (tx_start) begin
                    // start=0, data[7:0] LSB first, stop=1
                    tx_shift  <= {1'b1, tx_data, 1'b0};
                    sending   <= 1'b1;
                    tx_dout_r <= 1'b0;
                end
            end else begin
                if (baud_cnt == BAUD_DIV - 1) begin
                    baud_cnt <= 16'd0;

                    if (bit_cnt == 4'd9) begin
                        sending   <= 1'b0;
                        bit_cnt   <= 4'd0;
                        tx_dout_r <= 1'b1;
                    end else begin
                        bit_cnt   <= bit_cnt + 4'd1;
                        tx_shift  <= {1'b1, tx_shift[9:1]};
                        tx_dout_r <= tx_shift[1];
                    end
                end else begin
                    baud_cnt <= baud_cnt + 16'd1;
                end
            end
        end
    end

endmodule


// =============================================================
//  uart_rx_byte — UART 8N1 接收器
//  功能：检测起始位下降沿 → 起始位中心确认 → 数据位中心采样 → 停止位确认
//  流程：IDLE → (检测下降沿) → START(半位确认) → DATA(8位采样) → STOP(停止位校验)
// =============================================================
module uart_rx_byte #(
    parameter integer BAUD_DIV = 434
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       rx_din,
    output reg [7:0]  rx_data,
    output reg        rx_ready
);

    localparam integer HALF_BAUD = BAUD_DIV / 2;

    localparam [1:0] RX_IDLE  = 2'd0;
    localparam [1:0] RX_START = 2'd1;
    localparam [1:0] RX_DATA  = 2'd2;
    localparam [1:0] RX_STOP  = 2'd3;

    reg [1:0]  state;
    reg [15:0] baud_cnt;
    reg [2:0]  bit_cnt;
    reg [7:0]  rx_shift;

    reg [2:0] rx_sync;
    reg       rx_prev;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_sync <= 3'b111;
            rx_prev <= 1'b1;
        end else begin
            rx_sync <= {rx_sync[1:0], rx_din};
            rx_prev <= rx_sync[2];
        end
    end

    wire rx = rx_sync[2];

    // 只有从高到低才认为可能是起始位
    wire start_falling = (rx_prev == 1'b1) && (rx == 1'b0);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= RX_IDLE;
            baud_cnt <= 16'd0;
            bit_cnt  <= 3'd0;
            rx_shift <= 8'd0;
            rx_data  <= 8'd0;
            rx_ready <= 1'b0;
        end else begin
            rx_ready <= 1'b0;

            case (state)
                RX_IDLE: begin
                    baud_cnt <= 16'd0;
                    bit_cnt  <= 3'd0;

                    if (start_falling) begin
                        state    <= RX_START;
                        baud_cnt <= 16'd0;
                    end
                end

                RX_START: begin
                    // 到起始位中心确认仍为低
                    if (baud_cnt == HALF_BAUD - 1) begin
                        baud_cnt <= 16'd0;

                        if (rx == 1'b0) begin
                            state <= RX_DATA;
                        end else begin
                            state <= RX_IDLE;
                        end
                    end else begin
                        baud_cnt <= baud_cnt + 16'd1;
                    end
                end

                RX_DATA: begin
                    if (baud_cnt == BAUD_DIV - 1) begin
                        baud_cnt <= 16'd0;

                        rx_shift[bit_cnt] <= rx;

                        if (bit_cnt == 3'd7) begin
                            bit_cnt <= 3'd0;
                            state   <= RX_STOP;
                        end else begin
                            bit_cnt <= bit_cnt + 3'd1;
                        end
                    end else begin
                        baud_cnt <= baud_cnt + 16'd1;
                    end
                end

                RX_STOP: begin
                    if (baud_cnt == BAUD_DIV - 1) begin
                        baud_cnt <= 16'd0;
                        state    <= RX_IDLE;

                        // 停止位必须为高，否则丢弃
                        if (rx == 1'b1) begin
                            rx_data  <= rx_shift;
                            rx_ready <= 1'b1;
                        end
                    end else begin
                        baud_cnt <= baud_cnt + 16'd1;
                    end
                end

                default: begin
                    state <= RX_IDLE;
                end
            endcase
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

    localparam integer DEBOUNCE_MAX = 1_000_000; // 约20ms

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

                    if (key_state == 1'b1 && key_sync[1] == 1'b0) begin
                        pulse <= 1'b1;
                    end

                    key_state <= key_sync[1];
                end else begin
                    cnt <= cnt + 21'd1;
                end
            end
        end
    end

endmodule


// =============================================================
//  ws2812_8led — WS2812 8 灯驱动
//  功能：根据 mode 和 blink_on 信号生成 8 颗 LED 的 GRB 数据
//  编码：GRB 顺序, MSB first; T0H=18周期, T1H=35周期, 复位>60us
//  mode: 0=全灭, 1=红闪, 2=绿闪, 3=蓝闪, 4=全白闪
// =============================================================
module ws2812_8led (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [2:0] mode,
    input  wire       blink_on,
    output wire       led_din
);

    // 50MHz: 20ns/cycle
    // WS2812 bit周期约1.25us，这里取63周期=1.26us
    localparam integer BIT_CYCLES   = 63;
    localparam integer T0H_CYCLES   = 18;
    localparam integer T1H_CYCLES   = 35;
    localparam integer RESET_CYCLES = 3000;  // 约60us

    localparam ST_RESET = 1'b0;
    localparam ST_SEND  = 1'b1;

    reg        state;
    reg        led_din_r;
    reg [11:0] reset_cnt;
    reg [5:0]  cycle_cnt;
    reg [4:0]  bit_cnt;
    reg [3:0]  led_cnt;
    reg [23:0] grb_shift;

    assign led_din = led_din_r;

    function [23:0] grb_for_led;
        input [3:0] idx;
        input [2:0] md;
        input       blink;
        begin
            case (md)
                3'd0: begin
                    grb_for_led = 24'h00_00_00;
                end

                3'd1: begin
                    // LED1 红闪：GRB = G,R,B
                    if (blink && idx == 4'd0)
                        grb_for_led = 24'h00_20_00;
                    else
                        grb_for_led = 24'h00_00_00;
                end

                3'd2: begin
                    // LED2 绿闪
                    if (blink && idx == 4'd1)
                        grb_for_led = 24'h20_00_00;
                    else
                        grb_for_led = 24'h00_00_00;
                end

                3'd3: begin
                    // LED3 蓝闪
                    if (blink && idx == 4'd2)
                        grb_for_led = 24'h00_00_20;
                    else
                        grb_for_led = 24'h00_00_00;
                end

                3'd4: begin
                    // 全部白闪
                    if (blink)
                        grb_for_led = 24'h10_10_10;
                    else
                        grb_for_led = 24'h00_00_00;
                end

                default: begin
                    grb_for_led = 24'h00_00_00;
                end
            endcase
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= ST_RESET;
            led_din_r <= 1'b0;
            reset_cnt <= 12'd0;
            cycle_cnt <= 6'd0;
            bit_cnt   <= 5'd0;
            led_cnt   <= 4'd0;
            grb_shift <= 24'd0;
        end else begin
            case (state)
                ST_RESET: begin
                    led_din_r <= 1'b0;
                    cycle_cnt <= 6'd0;
                    bit_cnt   <= 5'd0;
                    led_cnt   <= 4'd0;

                    if (reset_cnt >= RESET_CYCLES - 1) begin
                        reset_cnt <= 12'd0;
                        state     <= ST_SEND;
                        grb_shift <= grb_for_led(4'd0, mode, blink_on);
                    end else begin
                        reset_cnt <= reset_cnt + 12'd1;
                    end
                end

                ST_SEND: begin
                    if (grb_shift[23]) begin
                        led_din_r <= (cycle_cnt < T1H_CYCLES);
                    end else begin
                        led_din_r <= (cycle_cnt < T0H_CYCLES);
                    end

                    if (cycle_cnt == BIT_CYCLES - 1) begin
                        cycle_cnt <= 6'd0;

                        if (bit_cnt == 5'd23) begin
                            bit_cnt <= 5'd0;

                            if (led_cnt == 4'd7) begin
                                led_cnt   <= 4'd0;
                                state     <= ST_RESET;
                                led_din_r <= 1'b0;
                                reset_cnt <= 12'd0;
                            end else begin
                                led_cnt   <= led_cnt + 4'd1;
                                grb_shift <= grb_for_led(led_cnt + 4'd1, mode, blink_on);
                            end
                        end else begin
                            bit_cnt   <= bit_cnt + 5'd1;
                            grb_shift <= {grb_shift[22:0], 1'b0};
                        end
                    end else begin
                        cycle_cnt <= cycle_cnt + 6'd1;
                    end
                end

                default: begin
                    state <= ST_RESET;
                end
            endcase
        end
    end

endmodule


// =============================================================
//  dual_layer_fsm — 双层状态机 + 收发仲裁
//  功能：
//    1. 接收合法命令后，底层 FSM 更新 led_mode；
//    2. 等待 UART TX 空闲后回显命令；
//    3. K1 外部发送请求作为低优先级 req，发送 0x55；
//    4. rx_ready 优先于 req；忙碌期间用 1 字节 pending 缓冲避免接收完成字节丢失。
// =============================================================
module dual_layer_fsm (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       rx_ready,
    input  wire [7:0] rx_data,
    input  wire       tx_busy,
    input  wire       req,
    input  wire [7:0] req_data,
    output reg        tx_start,
    output reg [7:0]  tx_data,
    output reg [2:0]  led_mode
);
    localparam [2:0] TOP_IDLE      = 3'd0;
    localparam [2:0] TOP_LATCH_RX  = 3'd1;
    localparam [2:0] TOP_START_SUB = 3'd2;
    localparam [2:0] TOP_WAIT_SUB  = 3'd3;
    localparam [2:0] TOP_SEND_ACK  = 3'd4;
    localparam [2:0] TOP_SEND_REQ  = 3'd5;
    localparam [2:0] TOP_DONE      = 3'd6;

    localparam [1:0] SUB_IDLE  = 2'd0;
    localparam [1:0] SUB_APPLY = 2'd1;
    localparam [1:0] SUB_HOLD  = 2'd2;
    localparam [1:0] SUB_DONE  = 2'd3;

    reg [2:0] top_state;
    reg [1:0] sub_state;
    reg [7:0] cmd_reg;
    reg       rx_pending_valid;
    reg [7:0] rx_pending_data;
    reg       sub_start;
    reg       sub_done;
    reg [3:0] hold_cnt;

    wire cmd_reg_valid =
        (cmd_reg == 8'h30) ||  // '0'
        (cmd_reg == 8'h31) ||  // '1'
        (cmd_reg == 8'h32) ||  // '2'
        (cmd_reg == 8'h33) ||  // '3'
        (cmd_reg == 8'h41) ||  // 'A'
        (cmd_reg == 8'h61);    // 'a'

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            top_state <= TOP_IDLE;
            cmd_reg   <= 8'h00;
            rx_pending_valid <= 1'b0;
            rx_pending_data  <= 8'h00;
            sub_start <= 1'b0;
            tx_start  <= 1'b0;
            tx_data   <= 8'h00;
        end else begin
            sub_start <= 1'b0;
            tx_start  <= 1'b0;

            if (rx_ready &&
                top_state != TOP_IDLE &&
                top_state != TOP_SEND_REQ &&
                !rx_pending_valid) begin
                rx_pending_valid <= 1'b1;
                rx_pending_data  <= rx_data;
            end

            case (top_state)
                TOP_IDLE: begin
                    if (rx_pending_valid) begin
                        cmd_reg          <= rx_pending_data;
                        rx_pending_valid <= 1'b0;
                        top_state        <= TOP_LATCH_RX;
                    end else if (rx_ready) begin
                        cmd_reg   <= rx_data;
                        top_state <= TOP_LATCH_RX;
                    end else if (req) begin
                        cmd_reg   <= req_data;
                        top_state <= TOP_SEND_REQ;
                    end
                end

                TOP_LATCH_RX: begin
                    if (cmd_reg_valid) begin
                        top_state <= TOP_START_SUB;
                    end else begin
                        top_state <= TOP_IDLE;
                    end
                end

                TOP_START_SUB: begin
                    sub_start <= 1'b1;
                    top_state <= TOP_WAIT_SUB;
                end

                TOP_WAIT_SUB: begin
                    if (sub_done)
                        top_state <= TOP_SEND_ACK;
                end

                TOP_SEND_ACK: begin
                    if (!tx_busy) begin
                        tx_data   <= cmd_reg;
                        tx_start  <= 1'b1;
                        top_state <= TOP_DONE;
                    end
                end

                TOP_SEND_REQ: begin
                    if (rx_ready) begin
                        cmd_reg   <= rx_data;
                        top_state <= TOP_LATCH_RX;
                    end else if (!tx_busy) begin
                        tx_data   <= cmd_reg;
                        tx_start  <= 1'b1;
                        top_state <= TOP_DONE;
                    end
                end

                TOP_DONE: begin
                    top_state <= TOP_IDLE;
                end

                default: begin
                    top_state <= TOP_IDLE;
                end
            endcase
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sub_state <= SUB_IDLE;
            led_mode  <= 3'd0;
            sub_done  <= 1'b0;
            hold_cnt  <= 4'd0;
        end else begin
            sub_done <= 1'b0;

            case (sub_state)
                SUB_IDLE: begin
                    hold_cnt <= 4'd0;
                    if (sub_start)
                        sub_state <= SUB_APPLY;
                end

                SUB_APPLY: begin
                    case (cmd_reg)
                        8'h30: led_mode <= 3'd0;
                        8'h31: led_mode <= 3'd1;
                        8'h32: led_mode <= 3'd2;
                        8'h33: led_mode <= 3'd3;
                        8'h41: led_mode <= 3'd4;
                        8'h61: led_mode <= 3'd4;
                        default: led_mode <= led_mode;
                    endcase
                    sub_state <= SUB_HOLD;
                end

                SUB_HOLD: begin
                    if (hold_cnt >= 4'd5) begin
                        hold_cnt  <= 4'd0;
                        sub_state <= SUB_DONE;
                    end else begin
                        hold_cnt <= hold_cnt + 4'd1;
                    end
                end

                SUB_DONE: begin
                    sub_done  <= 1'b1;
                    sub_state <= SUB_IDLE;
                end

                default: begin
                    sub_state <= SUB_IDLE;
                end
            endcase
        end
    end
endmodule
