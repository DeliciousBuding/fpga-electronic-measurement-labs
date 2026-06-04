module ws2812_driver (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [23:0] led0_grb, led1_grb, led2_grb, led3_grb,
    input  wire [23:0] led4_grb, led5_grb, led6_grb, led7_grb,
    input  wire        update,
    output wire        led_din,
    output wire        busy
);

    localparam integer BIT_CYCLES   = 63;
    localparam integer T0H_CYCLES   = 18;
    localparam integer T1H_CYCLES   = 35;
    localparam integer RESET_CYCLES = 3000;

    localparam ST_RESET = 1'b0;
    localparam ST_SEND  = 1'b1;

    reg        state;
    reg        led_din_r;
    reg [11:0] reset_cnt;
    reg [5:0]  cycle_cnt;
    reg [4:0]  bit_cnt;
    reg [3:0]  led_cnt;
    reg [23:0] grb_shift;

    reg [23:0] led_grb [0:7];

    assign led_din = led_din_r;
    assign busy = (state != ST_RESET);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= ST_RESET;
            led_din_r <= 1'b0;
            reset_cnt <= 12'd0;
            cycle_cnt <= 6'd0;
            bit_cnt   <= 5'd0;
            led_cnt   <= 4'd0;
            grb_shift <= 24'd0;
            led_grb[0] <= 24'd0;
            led_grb[1] <= 24'd0;
            led_grb[2] <= 24'd0;
            led_grb[3] <= 24'd0;
            led_grb[4] <= 24'd0;
            led_grb[5] <= 24'd0;
            led_grb[6] <= 24'd0;
            led_grb[7] <= 24'd0;
        end else begin
            if (update && state == ST_RESET) begin
                led_grb[0] <= led0_grb;
                led_grb[1] <= led1_grb;
                led_grb[2] <= led2_grb;
                led_grb[3] <= led3_grb;
                led_grb[4] <= led4_grb;
                led_grb[5] <= led5_grb;
                led_grb[6] <= led6_grb;
                led_grb[7] <= led7_grb;
                reset_cnt  <= 12'd0;
                state      <= ST_SEND;
                grb_shift  <= led0_grb;
                led_cnt    <= 4'd0;
                bit_cnt    <= 5'd0;
                cycle_cnt  <= 6'd0;
            end

            case (state)
                ST_RESET: begin
                    led_din_r <= 1'b0;
                    cycle_cnt <= 6'd0;
                    bit_cnt   <= 5'd0;
                    led_cnt   <= 4'd0;

                    if (reset_cnt >= RESET_CYCLES - 1) begin
                        reset_cnt <= 12'd0;
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
                                grb_shift <= led_grb[led_cnt + 4'd1];
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
