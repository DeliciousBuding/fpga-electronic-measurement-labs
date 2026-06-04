module gradient_engine (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] speed,
    input  wire       enable,
    output reg [7:0]  r_out, g_out, b_out
);

    reg [23:0] rainbow_lut [0:127];

    reg [7:0]  phase_cnt;
    reg [6:0]  lut_idx;
    reg [23:0] rgb_val;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rainbow_lut[0]   <= 24'hFF0000; rainbow_lut[1]   <= 24'hFF0B00; rainbow_lut[2]   <= 24'hFF1700; rainbow_lut[3]   <= 24'hFF2300;
            rainbow_lut[4]   <= 24'hFF2F00; rainbow_lut[5]   <= 24'hFF3B00; rainbow_lut[6]   <= 24'hFF4700; rainbow_lut[7]   <= 24'hFF5300;
            rainbow_lut[8]   <= 24'hFF5F00; rainbow_lut[9]   <= 24'hFF6B00; rainbow_lut[10]  <= 24'hFF7700; rainbow_lut[11]  <= 24'hFF8300;
            rainbow_lut[12]  <= 24'hFF8F00; rainbow_lut[13]  <= 24'hFF9B00; rainbow_lut[14]  <= 24'hFFA700; rainbow_lut[15]  <= 24'hFFB300;
            rainbow_lut[16]  <= 24'hFFBF00; rainbow_lut[17]  <= 24'hFFCB00; rainbow_lut[18]  <= 24'hFFD700; rainbow_lut[19]  <= 24'hFFE300;
            rainbow_lut[20]  <= 24'hFFEF00; rainbow_lut[21]  <= 24'hFFFB00; rainbow_lut[22]  <= 24'hF7FF00; rainbow_lut[23]  <= 24'hEBFF00;
            rainbow_lut[24]  <= 24'hDFFF00; rainbow_lut[25]  <= 24'hD3FF00; rainbow_lut[26]  <= 24'hC7FF00; rainbow_lut[27]  <= 24'hBBFF00;
            rainbow_lut[28]  <= 24'hAFFF00; rainbow_lut[29]  <= 24'hA3FF00; rainbow_lut[30]  <= 24'h97FF00; rainbow_lut[31]  <= 24'h8BFF00;
            rainbow_lut[32]  <= 24'h7FFF00; rainbow_lut[33]  <= 24'h73FF00; rainbow_lut[34]  <= 24'h67FF00; rainbow_lut[35]  <= 24'h5BFF00;
            rainbow_lut[36]  <= 24'h4FFF00; rainbow_lut[37]  <= 24'h43FF00; rainbow_lut[38]  <= 24'h37FF00; rainbow_lut[39]  <= 24'h2BFF00;
            rainbow_lut[40]  <= 24'h1FFF00; rainbow_lut[41]  <= 24'h13FF00; rainbow_lut[42]  <= 24'h07FF00; rainbow_lut[43]  <= 24'h00FF03;
            rainbow_lut[44]  <= 24'h00FF0F; rainbow_lut[45]  <= 24'h00FF1B; rainbow_lut[46]  <= 24'h00FF27; rainbow_lut[47]  <= 24'h00FF33;
            rainbow_lut[48]  <= 24'h00FF3F; rainbow_lut[49]  <= 24'h00FF4B; rainbow_lut[50]  <= 24'h00FF57; rainbow_lut[51]  <= 24'h00FF63;
            rainbow_lut[52]  <= 24'h00FF6F; rainbow_lut[53]  <= 24'h00FF7B; rainbow_lut[54]  <= 24'h00FF87; rainbow_lut[55]  <= 24'h00FF93;
            rainbow_lut[56]  <= 24'h00FF9F; rainbow_lut[57]  <= 24'h00FFAB; rainbow_lut[58]  <= 24'h00FFB7; rainbow_lut[59]  <= 24'h00FFC3;
            rainbow_lut[60]  <= 24'h00FFCF; rainbow_lut[61]  <= 24'h00FFDB; rainbow_lut[62]  <= 24'h00FFE7; rainbow_lut[63]  <= 24'h00FFF3;
            rainbow_lut[64]  <= 24'h00FFFF; rainbow_lut[65]  <= 24'h00F3FF; rainbow_lut[66]  <= 24'h00E7FF; rainbow_lut[67]  <= 24'h00DBFF;
            rainbow_lut[68]  <= 24'h00CFFF; rainbow_lut[69]  <= 24'h00C3FF; rainbow_lut[70]  <= 24'h00B7FF; rainbow_lut[71]  <= 24'h00ABFF;
            rainbow_lut[72]  <= 24'h009FFF; rainbow_lut[73]  <= 24'h0093FF; rainbow_lut[74]  <= 24'h0087FF; rainbow_lut[75]  <= 24'h007BFF;
            rainbow_lut[76]  <= 24'h006FFF; rainbow_lut[77]  <= 24'h0063FF; rainbow_lut[78]  <= 24'h0057FF; rainbow_lut[79]  <= 24'h004BFF;
            rainbow_lut[80]  <= 24'h003FFF; rainbow_lut[81]  <= 24'h0033FF; rainbow_lut[82]  <= 24'h0027FF; rainbow_lut[83]  <= 24'h001BFF;
            rainbow_lut[84]  <= 24'h000FFF; rainbow_lut[85]  <= 24'h0003FF; rainbow_lut[86]  <= 24'h0700FF; rainbow_lut[87]  <= 24'h1300FF;
            rainbow_lut[88]  <= 24'h1F00FF; rainbow_lut[89]  <= 24'h2B00FF; rainbow_lut[90]  <= 24'h3700FF; rainbow_lut[91]  <= 24'h4300FF;
            rainbow_lut[92]  <= 24'h4F00FF; rainbow_lut[93]  <= 24'h5B00FF; rainbow_lut[94]  <= 24'h6700FF; rainbow_lut[95]  <= 24'h7300FF;
            rainbow_lut[96]  <= 24'h7F00FF; rainbow_lut[97]  <= 24'h8B00FF; rainbow_lut[98]  <= 24'h9700FF; rainbow_lut[99]  <= 24'hA300FF;
            rainbow_lut[100] <= 24'hAF00FF; rainbow_lut[101] <= 24'hBB00FF; rainbow_lut[102] <= 24'hC700FF; rainbow_lut[103] <= 24'hD300FF;
            rainbow_lut[104] <= 24'hDF00FF; rainbow_lut[105] <= 24'hEB00FF; rainbow_lut[106] <= 24'hF700FF; rainbow_lut[107] <= 24'hFF00FB;
            rainbow_lut[108] <= 24'hFF00EF; rainbow_lut[109] <= 24'hFF00E3; rainbow_lut[110] <= 24'hFF00D7; rainbow_lut[111] <= 24'hFF00CB;
            rainbow_lut[112] <= 24'hFF00BF; rainbow_lut[113] <= 24'hFF00B3; rainbow_lut[114] <= 24'hFF00A7; rainbow_lut[115] <= 24'hFF009B;
            rainbow_lut[116] <= 24'hFF008F; rainbow_lut[117] <= 24'hFF0083; rainbow_lut[118] <= 24'hFF0077; rainbow_lut[119] <= 24'hFF006B;
            rainbow_lut[120] <= 24'hFF005F; rainbow_lut[121] <= 24'hFF0053; rainbow_lut[122] <= 24'hFF0047; rainbow_lut[123] <= 24'hFF003B;
            rainbow_lut[124] <= 24'hFF002F; rainbow_lut[125] <= 24'hFF0023; rainbow_lut[126] <= 24'hFF0017; rainbow_lut[127] <= 24'hFF000B;
        end
    end

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
            rgb_val <= rainbow_lut[lut_idx];
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
