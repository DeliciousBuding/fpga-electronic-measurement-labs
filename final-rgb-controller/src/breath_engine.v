module breath_engine (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] r_in, g_in, b_in,
    input  wire [7:0] period,
    input  wire       enable,
    output reg [7:0]  r_out, g_out, b_out
);

    reg [7:0]  sin_lut [0:63];

    reg [7:0]  phase_cnt;
    reg [7:0]  phase_acc;
    reg [5:0]  lut_idx;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sin_lut[0]  <= 8'd127; sin_lut[1]  <= 8'd139; sin_lut[2]  <= 8'd152; sin_lut[3]  <= 8'd164;
            sin_lut[4]  <= 8'd176; sin_lut[5]  <= 8'd187; sin_lut[6]  <= 8'd198; sin_lut[7]  <= 8'd208;
            sin_lut[8]  <= 8'd217; sin_lut[9]  <= 8'd226; sin_lut[10] <= 8'd233; sin_lut[11] <= 8'd239;
            sin_lut[12] <= 8'd245; sin_lut[13] <= 8'd249; sin_lut[14] <= 8'd252; sin_lut[15] <= 8'd254;
            sin_lut[16] <= 8'd255; sin_lut[17] <= 8'd254; sin_lut[18] <= 8'd252; sin_lut[19] <= 8'd249;
            sin_lut[20] <= 8'd245; sin_lut[21] <= 8'd239; sin_lut[22] <= 8'd233; sin_lut[23] <= 8'd226;
            sin_lut[24] <= 8'd217; sin_lut[25] <= 8'd208; sin_lut[26] <= 8'd198; sin_lut[27] <= 8'd187;
            sin_lut[28] <= 8'd176; sin_lut[29] <= 8'd164; sin_lut[30] <= 8'd152; sin_lut[31] <= 8'd139;
            sin_lut[32] <= 8'd127; sin_lut[33] <= 8'd115; sin_lut[34] <= 8'd102; sin_lut[35] <= 8'd90;
            sin_lut[36] <= 8'd78;  sin_lut[37] <= 8'd67;  sin_lut[38] <= 8'd56;  sin_lut[39] <= 8'd46;
            sin_lut[40] <= 8'd37;  sin_lut[41] <= 8'd28;  sin_lut[42] <= 8'd21;  sin_lut[43] <= 8'd15;
            sin_lut[44] <= 8'd9;   sin_lut[45] <= 8'd5;   sin_lut[46] <= 8'd2;   sin_lut[47] <= 8'd0;
            sin_lut[48] <= 8'd0;   sin_lut[49] <= 8'd0;   sin_lut[50] <= 8'd2;   sin_lut[51] <= 8'd5;
            sin_lut[52] <= 8'd9;   sin_lut[53] <= 8'd15;  sin_lut[54] <= 8'd21;  sin_lut[55] <= 8'd28;
            sin_lut[56] <= 8'd37;  sin_lut[57] <= 8'd46;  sin_lut[58] <= 8'd56;  sin_lut[59] <= 8'd67;
            sin_lut[60] <= 8'd78;  sin_lut[61] <= 8'd90;  sin_lut[62] <= 8'd102; sin_lut[63] <= 8'd115;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase_cnt <= 8'd0;
            phase_acc <= 8'd0;
            lut_idx   <= 6'd0;
        end else if (!enable) begin
            phase_cnt <= 8'd0;
            phase_acc <= 8'd0;
            lut_idx   <= 6'd0;
        end else begin
            if (phase_cnt >= period) begin
                phase_cnt <= 8'd0;
                lut_idx   <= lut_idx + 6'd1;
            end else begin
                phase_cnt <= phase_cnt + 8'd1;
            end
        end
    end

    wire [7:0] lut_val = sin_lut[lut_idx];

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
