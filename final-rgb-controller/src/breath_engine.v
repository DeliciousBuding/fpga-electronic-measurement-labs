module breath_engine #(
    parameter [24:0] MIN_STEP_CYCLES    = 25'd750_000,
    parameter [24:0] PERIOD_STEP_CYCLES = 25'd20_000
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] r_in, g_in, b_in,
    input  wire [7:0] period,
    input  wire       enable,
    output reg [7:0]  r_out, g_out, b_out
);
    reg [24:0] phase_cnt;
    reg [5:0] lut_idx;
    wire [24:0] period_scaled = {17'd0, period} * PERIOD_STEP_CYCLES;
    wire [24:0] step_cycles = MIN_STEP_CYCLES + period_scaled;

    function [7:0] sin_lut_value;
        input [5:0] idx;
        begin
            case (idx)
            6'd0: sin_lut_value = 8'd127;
            6'd1: sin_lut_value = 8'd139;
            6'd2: sin_lut_value = 8'd152;
            6'd3: sin_lut_value = 8'd164;
            6'd4: sin_lut_value = 8'd176;
            6'd5: sin_lut_value = 8'd187;
            6'd6: sin_lut_value = 8'd198;
            6'd7: sin_lut_value = 8'd208;
            6'd8: sin_lut_value = 8'd217;
            6'd9: sin_lut_value = 8'd226;
            6'd10: sin_lut_value = 8'd233;
            6'd11: sin_lut_value = 8'd239;
            6'd12: sin_lut_value = 8'd245;
            6'd13: sin_lut_value = 8'd249;
            6'd14: sin_lut_value = 8'd252;
            6'd15: sin_lut_value = 8'd254;
            6'd16: sin_lut_value = 8'd255;
            6'd17: sin_lut_value = 8'd254;
            6'd18: sin_lut_value = 8'd252;
            6'd19: sin_lut_value = 8'd249;
            6'd20: sin_lut_value = 8'd245;
            6'd21: sin_lut_value = 8'd239;
            6'd22: sin_lut_value = 8'd233;
            6'd23: sin_lut_value = 8'd226;
            6'd24: sin_lut_value = 8'd217;
            6'd25: sin_lut_value = 8'd208;
            6'd26: sin_lut_value = 8'd198;
            6'd27: sin_lut_value = 8'd187;
            6'd28: sin_lut_value = 8'd176;
            6'd29: sin_lut_value = 8'd164;
            6'd30: sin_lut_value = 8'd152;
            6'd31: sin_lut_value = 8'd139;
            6'd32: sin_lut_value = 8'd127;
            6'd33: sin_lut_value = 8'd115;
            6'd34: sin_lut_value = 8'd102;
            6'd35: sin_lut_value = 8'd90;
            6'd36: sin_lut_value = 8'd78;
            6'd37: sin_lut_value = 8'd67;
            6'd38: sin_lut_value = 8'd56;
            6'd39: sin_lut_value = 8'd46;
            6'd40: sin_lut_value = 8'd37;
            6'd41: sin_lut_value = 8'd28;
            6'd42: sin_lut_value = 8'd21;
            6'd43: sin_lut_value = 8'd15;
            6'd44: sin_lut_value = 8'd9;
            6'd45: sin_lut_value = 8'd5;
            6'd46: sin_lut_value = 8'd2;
            6'd47: sin_lut_value = 8'd0;
            6'd48: sin_lut_value = 8'd0;
            6'd49: sin_lut_value = 8'd0;
            6'd50: sin_lut_value = 8'd2;
            6'd51: sin_lut_value = 8'd5;
            6'd52: sin_lut_value = 8'd9;
            6'd53: sin_lut_value = 8'd15;
            6'd54: sin_lut_value = 8'd21;
            6'd55: sin_lut_value = 8'd28;
            6'd56: sin_lut_value = 8'd37;
            6'd57: sin_lut_value = 8'd46;
            6'd58: sin_lut_value = 8'd56;
            6'd59: sin_lut_value = 8'd67;
            6'd60: sin_lut_value = 8'd78;
            6'd61: sin_lut_value = 8'd90;
            6'd62: sin_lut_value = 8'd102;
            6'd63: sin_lut_value = 8'd115;
                default: sin_lut_value = 8'd127;
            endcase
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase_cnt <= 25'd0;
            lut_idx   <= 6'd0;
        end else if (!enable) begin
            phase_cnt <= 25'd0;
            lut_idx   <= 6'd0;
        end else begin
            if (phase_cnt >= step_cycles) begin
                phase_cnt <= 25'd0;
                lut_idx   <= lut_idx + 6'd1;
            end else begin
                phase_cnt <= phase_cnt + 25'd1;
            end
        end
    end

    wire [7:0] lut_val = sin_lut_value(lut_idx);

    wire [15:0] mult_r = r_in * lut_val;
    wire [15:0] mult_g = g_in * lut_val;
    wire [15:0] mult_b = b_in * lut_val;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_out <= 8'd0;
            g_out <= 8'd0;
            b_out <= 8'd0;
        end else if (!enable) begin
            r_out <= r_in;
            g_out <= g_in;
            b_out <= b_in;
        end else begin
            r_out <= mult_r[15:8] + {7'd0, mult_r[7]} + {7'd0, mult_r[6]};
            g_out <= mult_g[15:8] + {7'd0, mult_g[7]} + {7'd0, mult_g[6]};
            b_out <= mult_b[15:8] + {7'd0, mult_b[7]} + {7'd0, mult_b[6]};
        end
    end

endmodule
