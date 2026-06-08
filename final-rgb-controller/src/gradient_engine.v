module gradient_engine (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] speed,
    input  wire       enable,
    output reg [7:0]  r_out, g_out, b_out
);
    function [23:0] rainbow_lut_value;
        input [6:0] idx;
        begin
            case (idx)
            7'd0: rainbow_lut_value = 24'hFF0000;
            7'd1: rainbow_lut_value = 24'hFF0B00;
            7'd2: rainbow_lut_value = 24'hFF1700;
            7'd3: rainbow_lut_value = 24'hFF2300;
            7'd4: rainbow_lut_value = 24'hFF2F00;
            7'd5: rainbow_lut_value = 24'hFF3B00;
            7'd6: rainbow_lut_value = 24'hFF4700;
            7'd7: rainbow_lut_value = 24'hFF5300;
            7'd8: rainbow_lut_value = 24'hFF5F00;
            7'd9: rainbow_lut_value = 24'hFF6B00;
            7'd10: rainbow_lut_value = 24'hFF7700;
            7'd11: rainbow_lut_value = 24'hFF8300;
            7'd12: rainbow_lut_value = 24'hFF8F00;
            7'd13: rainbow_lut_value = 24'hFF9B00;
            7'd14: rainbow_lut_value = 24'hFFA700;
            7'd15: rainbow_lut_value = 24'hFFB300;
            7'd16: rainbow_lut_value = 24'hFFBF00;
            7'd17: rainbow_lut_value = 24'hFFCB00;
            7'd18: rainbow_lut_value = 24'hFFD700;
            7'd19: rainbow_lut_value = 24'hFFE300;
            7'd20: rainbow_lut_value = 24'hFFEF00;
            7'd21: rainbow_lut_value = 24'hFFFB00;
            7'd22: rainbow_lut_value = 24'hF7FF00;
            7'd23: rainbow_lut_value = 24'hEBFF00;
            7'd24: rainbow_lut_value = 24'hDFFF00;
            7'd25: rainbow_lut_value = 24'hD3FF00;
            7'd26: rainbow_lut_value = 24'hC7FF00;
            7'd27: rainbow_lut_value = 24'hBBFF00;
            7'd28: rainbow_lut_value = 24'hAFFF00;
            7'd29: rainbow_lut_value = 24'hA3FF00;
            7'd30: rainbow_lut_value = 24'h97FF00;
            7'd31: rainbow_lut_value = 24'h8BFF00;
            7'd32: rainbow_lut_value = 24'h7FFF00;
            7'd33: rainbow_lut_value = 24'h73FF00;
            7'd34: rainbow_lut_value = 24'h67FF00;
            7'd35: rainbow_lut_value = 24'h5BFF00;
            7'd36: rainbow_lut_value = 24'h4FFF00;
            7'd37: rainbow_lut_value = 24'h43FF00;
            7'd38: rainbow_lut_value = 24'h37FF00;
            7'd39: rainbow_lut_value = 24'h2BFF00;
            7'd40: rainbow_lut_value = 24'h1FFF00;
            7'd41: rainbow_lut_value = 24'h13FF00;
            7'd42: rainbow_lut_value = 24'h07FF00;
            7'd43: rainbow_lut_value = 24'h00FF03;
            7'd44: rainbow_lut_value = 24'h00FF0F;
            7'd45: rainbow_lut_value = 24'h00FF1B;
            7'd46: rainbow_lut_value = 24'h00FF27;
            7'd47: rainbow_lut_value = 24'h00FF33;
            7'd48: rainbow_lut_value = 24'h00FF3F;
            7'd49: rainbow_lut_value = 24'h00FF4B;
            7'd50: rainbow_lut_value = 24'h00FF57;
            7'd51: rainbow_lut_value = 24'h00FF63;
            7'd52: rainbow_lut_value = 24'h00FF6F;
            7'd53: rainbow_lut_value = 24'h00FF7B;
            7'd54: rainbow_lut_value = 24'h00FF87;
            7'd55: rainbow_lut_value = 24'h00FF93;
            7'd56: rainbow_lut_value = 24'h00FF9F;
            7'd57: rainbow_lut_value = 24'h00FFAB;
            7'd58: rainbow_lut_value = 24'h00FFB7;
            7'd59: rainbow_lut_value = 24'h00FFC3;
            7'd60: rainbow_lut_value = 24'h00FFCF;
            7'd61: rainbow_lut_value = 24'h00FFDB;
            7'd62: rainbow_lut_value = 24'h00FFE7;
            7'd63: rainbow_lut_value = 24'h00FFF3;
            7'd64: rainbow_lut_value = 24'h00FFFF;
            7'd65: rainbow_lut_value = 24'h00F3FF;
            7'd66: rainbow_lut_value = 24'h00E7FF;
            7'd67: rainbow_lut_value = 24'h00DBFF;
            7'd68: rainbow_lut_value = 24'h00CFFF;
            7'd69: rainbow_lut_value = 24'h00C3FF;
            7'd70: rainbow_lut_value = 24'h00B7FF;
            7'd71: rainbow_lut_value = 24'h00ABFF;
            7'd72: rainbow_lut_value = 24'h009FFF;
            7'd73: rainbow_lut_value = 24'h0093FF;
            7'd74: rainbow_lut_value = 24'h0087FF;
            7'd75: rainbow_lut_value = 24'h007BFF;
            7'd76: rainbow_lut_value = 24'h006FFF;
            7'd77: rainbow_lut_value = 24'h0063FF;
            7'd78: rainbow_lut_value = 24'h0057FF;
            7'd79: rainbow_lut_value = 24'h004BFF;
            7'd80: rainbow_lut_value = 24'h003FFF;
            7'd81: rainbow_lut_value = 24'h0033FF;
            7'd82: rainbow_lut_value = 24'h0027FF;
            7'd83: rainbow_lut_value = 24'h001BFF;
            7'd84: rainbow_lut_value = 24'h000FFF;
            7'd85: rainbow_lut_value = 24'h0003FF;
            7'd86: rainbow_lut_value = 24'h0700FF;
            7'd87: rainbow_lut_value = 24'h1300FF;
            7'd88: rainbow_lut_value = 24'h1F00FF;
            7'd89: rainbow_lut_value = 24'h2B00FF;
            7'd90: rainbow_lut_value = 24'h3700FF;
            7'd91: rainbow_lut_value = 24'h4300FF;
            7'd92: rainbow_lut_value = 24'h4F00FF;
            7'd93: rainbow_lut_value = 24'h5B00FF;
            7'd94: rainbow_lut_value = 24'h6700FF;
            7'd95: rainbow_lut_value = 24'h7300FF;
            7'd96: rainbow_lut_value = 24'h7F00FF;
            7'd97: rainbow_lut_value = 24'h8B00FF;
            7'd98: rainbow_lut_value = 24'h9700FF;
            7'd99: rainbow_lut_value = 24'hA300FF;
            7'd100: rainbow_lut_value = 24'hAF00FF;
            7'd101: rainbow_lut_value = 24'hBB00FF;
            7'd102: rainbow_lut_value = 24'hC700FF;
            7'd103: rainbow_lut_value = 24'hD300FF;
            7'd104: rainbow_lut_value = 24'hDF00FF;
            7'd105: rainbow_lut_value = 24'hEB00FF;
            7'd106: rainbow_lut_value = 24'hF700FF;
            7'd107: rainbow_lut_value = 24'hFF00FB;
            7'd108: rainbow_lut_value = 24'hFF00EF;
            7'd109: rainbow_lut_value = 24'hFF00E3;
            7'd110: rainbow_lut_value = 24'hFF00D7;
            7'd111: rainbow_lut_value = 24'hFF00CB;
            7'd112: rainbow_lut_value = 24'hFF00BF;
            7'd113: rainbow_lut_value = 24'hFF00B3;
            7'd114: rainbow_lut_value = 24'hFF00A7;
            7'd115: rainbow_lut_value = 24'hFF009B;
            7'd116: rainbow_lut_value = 24'hFF008F;
            7'd117: rainbow_lut_value = 24'hFF0083;
            7'd118: rainbow_lut_value = 24'hFF0077;
            7'd119: rainbow_lut_value = 24'hFF006B;
            7'd120: rainbow_lut_value = 24'hFF005F;
            7'd121: rainbow_lut_value = 24'hFF0053;
            7'd122: rainbow_lut_value = 24'hFF0047;
            7'd123: rainbow_lut_value = 24'hFF003B;
            7'd124: rainbow_lut_value = 24'hFF002F;
            7'd125: rainbow_lut_value = 24'hFF0023;
            7'd126: rainbow_lut_value = 24'hFF0017;
            7'd127: rainbow_lut_value = 24'hFF000B;
                default: rainbow_lut_value = 24'hFF0000;
            endcase
        end
    endfunction


    reg [7:0]  phase_cnt;
    reg [6:0]  lut_idx;
    reg [23:0] rgb_val;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase_cnt <= 8'd0;
            lut_idx   <= 7'd0;
        end else if (!enable) begin
            phase_cnt <= 8'd0;
            lut_idx   <= 7'd0;
        end else begin
            if (phase_cnt >= speed) begin
                phase_cnt <= 8'd0;
                lut_idx   <= lut_idx + 7'd1;
            end else begin
                phase_cnt <= phase_cnt + 8'd1;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rgb_val <= 24'd0;
        end else begin
            rgb_val <= rainbow_lut_value(lut_idx);
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_out <= 8'd0;
            g_out <= 8'd0;
            b_out <= 8'd0;
        end else begin
            r_out <= rgb_val[23:16];
            g_out <= rgb_val[15:8];
            b_out <= rgb_val[7:0];
        end
    end

endmodule
