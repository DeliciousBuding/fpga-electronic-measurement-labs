module rgb_controller_top (
    input  wire clk,
    input  wire nrst,
    input  wire rx_din,
    output wire tx_dout,
    output wire led_din
);

    localparam integer BAUD_DIV = 434;
    localparam [2:0] MODE_STATIC   = 3'd0;
    localparam [2:0] MODE_BREATH   = 3'd1;
    localparam [2:0] MODE_FLOW     = 3'd2;
    localparam [2:0] MODE_GRADIENT = 3'd3;
    localparam [2:0] MODE_MUSIC    = 3'd4;

    // =====================================================
    // Registers (declared BEFORE any use)
    // =====================================================
    reg [7:0] cur_r, cur_g, cur_b, cur_brightness, cur_flow_speed, cur_breath_period;
    reg [2:0] cur_mode;

    // =====================================================
    // UART RX
    // =====================================================
    wire [7:0] rx_data;
    wire       rx_ready;

    uart_rx_byte #(
        .BAUD_DIV(BAUD_DIV)
    ) u_rx (
        .clk      (clk),
        .rst_n    (nrst),
        .rx_din   (rx_din),
        .rx_data  (rx_data),
        .rx_ready (rx_ready)
    );

    // =====================================================
    // cmd_parser
    // =====================================================
    wire        color_valid, brightness_valid, mode_valid;
    wire        flow_speed_valid, breath_period_valid;
    wire        scene_save_valid, scene_load_valid;
    wire [7:0]  cp_color_r, cp_color_g, cp_color_b, cp_brightness;
    wire [2:0]  cp_mode;
    wire [7:0]  cp_flow_speed, cp_breath_period;
    wire [2:0]  cp_scene_save_slot, cp_scene_load_slot;
    wire        cp_tx_start, tx_busy;
    wire [7:0]  cp_tx_data;

    cmd_parser u_cmd (
        .clk               (clk),
        .rst_n             (nrst),
        .rx_ready          (rx_ready),
        .rx_data           (rx_data),
        .tx_busy           (tx_busy),
        .color_valid       (color_valid),
        .color_r           (cp_color_r),
        .color_g           (cp_color_g),
        .color_b           (cp_color_b),
        .brightness_valid  (brightness_valid),
        .brightness        (cp_brightness),
        .mode_valid        (mode_valid),
        .mode              (cp_mode),
        .flow_speed_valid  (flow_speed_valid),
        .flow_speed        (cp_flow_speed),
        .breath_period_valid(breath_period_valid),
        .breath_period     (cp_breath_period),
        .scene_save_valid  (scene_save_valid),
        .scene_save_slot   (cp_scene_save_slot),
        .scene_load_valid  (scene_load_valid),
        .scene_load_slot   (cp_scene_load_slot),
        .status_mode       (cur_mode),
        .status_r          (cur_r),
        .status_g          (cur_g),
        .status_b          (cur_b),
        .status_brightness (cur_brightness),
        .tx_start          (cp_tx_start),
        .tx_data           (cp_tx_data)
    );

    // =====================================================
    // scene_store
    // =====================================================
    wire [7:0] scene_load_r, scene_load_g, scene_load_b, scene_load_br;
    wire       scene_load_done;

    scene_store u_scene (
        .clk            (clk),
        .rst_n          (nrst),
        .save           (scene_save_valid),
        .save_slot      (cp_scene_save_slot),
        .save_r         (cur_r),
        .save_g         (cur_g),
        .save_b         (cur_b),
        .save_brightness(cur_brightness),
        .load           (scene_load_valid),
        .load_slot      (cp_scene_load_slot),
        .load_r         (scene_load_r),
        .load_g         (scene_load_g),
        .load_b         (scene_load_b),
        .load_brightness(scene_load_br),
        .load_valid     (scene_load_done)
    );

    // =====================================================
    // Register update
    // =====================================================
    always @(posedge clk or negedge nrst) begin
        if (!nrst) begin
            cur_r            <= 8'd0;
            cur_g            <= 8'd0;
            cur_b            <= 8'd0;
            cur_brightness   <= 8'd128;
            cur_mode         <= 3'd0;
            cur_flow_speed   <= 8'd128;
            cur_breath_period <= 8'd128;
        end else begin
            if (scene_load_done) begin
                cur_r          <= scene_load_r;
                cur_g          <= scene_load_g;
                cur_b          <= scene_load_b;
                cur_brightness <= scene_load_br;
            end else begin
                if (color_valid) begin
                    cur_r <= cp_color_r;
                    cur_g <= cp_color_g;
                    cur_b <= cp_color_b;
                end
                if (brightness_valid)
                    cur_brightness <= cp_brightness;
                if (mode_valid)
                    cur_mode <= cp_mode;
                if (flow_speed_valid)
                    cur_flow_speed <= cp_flow_speed;
                if (breath_period_valid)
                    cur_breath_period <= cp_breath_period;
            end
        end
    end

    // =====================================================
    // breath engine
    // =====================================================
    wire [7:0] breath_r, breath_g, breath_b;

    breath_engine u_breath (
        .clk    (clk),
        .rst_n  (nrst),
        .r_in   (cur_r),
        .g_in   (cur_g),
        .b_in   (cur_b),
        .period (cur_breath_period),
        .enable (cur_mode == MODE_BREATH),
        .r_out  (breath_r),
        .g_out  (breath_g),
        .b_out  (breath_b)
    );

    // =====================================================
    // flow engine
    // =====================================================
    wire [7:0] flow_mask;

    flow_engine u_flow (
        .clk      (clk),
        .rst_n    (nrst),
        .speed    (cur_flow_speed),
        .enable   (cur_mode == MODE_FLOW),
        .led_mask (flow_mask)
    );

    // =====================================================
    // gradient engine
    // =====================================================
    wire [7:0] grad_r, grad_g, grad_b;

    gradient_engine u_grad (
        .clk    (clk),
        .rst_n  (nrst),
        .speed  (cur_flow_speed),
        .enable (cur_mode == MODE_GRADIENT),
        .r_out  (grad_r),
        .g_out  (grad_g),
        .b_out  (grad_b)
    );

    // =====================================================
    // Mode mux: select source RGB
    // =====================================================
    reg [7:0] src_r, src_g, src_b;

    always @(posedge clk or negedge nrst) begin
        if (!nrst) begin
            src_r <= 8'd0;
            src_g <= 8'd0;
            src_b <= 8'd0;
        end else begin
            case (cur_mode)
                MODE_BREATH: begin
                    src_r <= breath_r;
                    src_g <= breath_g;
                    src_b <= breath_b;
                end
                MODE_GRADIENT: begin
                    src_r <= grad_r;
                    src_g <= grad_g;
                    src_b <= grad_b;
                end
                default: begin
                    src_r <= cur_r;
                    src_g <= cur_g;
                    src_b <= cur_b;
                end
            endcase
        end
    end

    // =====================================================
    // Brightness scaling
    // =====================================================
    wire [15:0] bmult_r = src_r * cur_brightness;
    wire [15:0] bmult_g = src_g * cur_brightness;
    wire [15:0] bmult_b = src_b * cur_brightness;

    wire [7:0] final_r = bmult_r[15:8] + {7'd0, bmult_r[7]} + {7'd0, bmult_r[6]};
    wire [7:0] final_g = bmult_g[15:8] + {7'd0, bmult_g[7]} + {7'd0, bmult_g[6]};
    wire [7:0] final_b = bmult_b[15:8] + {7'd0, bmult_b[7]} + {7'd0, bmult_b[6]};

    // =====================================================
    // Per-LED GRB assembly
    // =====================================================
    wire [7:0] led_en = (cur_mode == MODE_FLOW) ? flow_mask : 8'hFF;

    wire [23:0] led0_grb = led_en[0] ? {final_g, final_r, final_b} : 24'd0;
    wire [23:0] led1_grb = led_en[1] ? {final_g, final_r, final_b} : 24'd0;
    wire [23:0] led2_grb = led_en[2] ? {final_g, final_r, final_b} : 24'd0;
    wire [23:0] led3_grb = led_en[3] ? {final_g, final_r, final_b} : 24'd0;
    wire [23:0] led4_grb = led_en[4] ? {final_g, final_r, final_b} : 24'd0;
    wire [23:0] led5_grb = led_en[5] ? {final_g, final_r, final_b} : 24'd0;
    wire [23:0] led6_grb = led_en[6] ? {final_g, final_r, final_b} : 24'd0;
    wire [23:0] led7_grb = led_en[7] ? {final_g, final_r, final_b} : 24'd0;

    // =====================================================
    // ws2812 driver
    // =====================================================
    wire ws2812_busy;
    reg  ws2812_update;

    ws2812_driver u_ws2812 (
        .clk      (clk),
        .rst_n    (nrst),
        .led0_grb (led0_grb),
        .led1_grb (led1_grb),
        .led2_grb (led2_grb),
        .led3_grb (led3_grb),
        .led4_grb (led4_grb),
        .led5_grb (led5_grb),
        .led6_grb (led6_grb),
        .led7_grb (led7_grb),
        .update   (ws2812_update),
        .led_din  (led_din),
        .busy     (ws2812_busy)
    );

    // Periodic update: trigger ws2812 refresh when idle
    reg [25:0] update_cnt;

    always @(posedge clk or negedge nrst) begin
        if (!nrst)
            update_cnt <= 26'd0;
        else if (update_cnt >= 26'd2_499_999)
            update_cnt <= 26'd0;
        else
            update_cnt <= update_cnt + 26'd1;
    end

    always @(posedge clk or negedge nrst) begin
        if (!nrst)
            ws2812_update <= 1'b0;
        else
            ws2812_update <= (update_cnt == 26'd2_499_999) && !ws2812_busy;
    end

    // =====================================================
    // UART TX
    // =====================================================
    uart_tx_byte #(
        .BAUD_DIV(BAUD_DIV)
    ) u_tx (
        .clk      (clk),
        .rst_n    (nrst),
        .tx_start (cp_tx_start),
        .tx_data  (cp_tx_data),
        .tx_dout  (tx_dout),
        .tx_busy  (tx_busy)
    );

endmodule
