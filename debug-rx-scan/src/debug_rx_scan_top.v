module debug_rx_scan_top (
    input  wire clk,
    input  wire nrst,
    input  wire tx_en,

    input wire p00, input wire p01, input wire p02, input wire p03,
    input wire p04, input wire p05, input wire p06, input wire p07,
    input wire p08, input wire p09, input wire p10, input wire p11,
    input wire p12, input wire p13, input wire p14, input wire p15,
    input wire p16, input wire p17, input wire p18, input wire p19,
    input wire p20, input wire p21, input wire p22, input wire p23,
    input wire p24,

    output wire tx_dout,
    output wire led_din
);
    localparam integer BAUD_DIV = 434;

    wire key_pulse;
    key_pulse_low u_key(.clk(clk), .rst_n(nrst), .key_n(tx_en), .pulse(key_pulse));

    wire [24:0] pins = {p24,p23,p22,p21,p20,p19,p18,p17,p16,p15,p14,p13,p12,p11,p10,p09,p08,p07,p06,p05,p04,p03,p02,p01,p00};
    reg [24:0] sync0;
    reg [24:0] sync1;
    reg [24:0] prev;
    always @(posedge clk or negedge nrst) begin
        if (!nrst) begin
            sync0 <= 25'h1FFFFFF;
            sync1 <= 25'h1FFFFFF;
            prev  <= 25'h1FFFFFF;
        end else begin
            sync0 <= pins;
            sync1 <= sync0;
            prev  <= sync1;
        end
    end

    wire [24:0] changed = (prev ^ sync1);

    reg [4:0] first_idx;
    integer i;
    always @(*) begin
        first_idx = 5'd31;
        for (i = 0; i < 25; i = i + 1) begin
            if (changed[i] && first_idx == 5'd31) begin
                first_idx = i[4:0];
            end
        end
    end

    reg [23:0] inhibit_cnt;
    wire edge_event = (first_idx != 5'd31) && (inhibit_cnt == 24'd0);

    always @(posedge clk or negedge nrst) begin
        if (!nrst) begin
            inhibit_cnt <= 24'd0;
        end else if (edge_event) begin
            inhibit_cnt <= 24'd2_000_000;
        end else if (inhibit_cnt != 24'd0) begin
            inhibit_cnt <= inhibit_cnt - 24'd1;
        end
    end

    reg       tx_start;
    reg [7:0] tx_data;
    wire      tx_busy;

    uart_tx_byte #(.BAUD_DIV(BAUD_DIV)) u_tx (
        .clk(clk),
        .rst_n(nrst),
        .tx_start(tx_start),
        .tx_data(tx_data),
        .tx_dout(tx_dout),
        .tx_busy(tx_busy)
    );

    always @(posedge clk or negedge nrst) begin
        if (!nrst) begin
            tx_start <= 1'b0;
            tx_data <= 8'h00;
        end else begin
            tx_start <= 1'b0;
            if (!tx_busy && edge_event) begin
                tx_data <= (first_idx < 5'd10) ? (8'h30 + {3'b000, first_idx}) : (8'h41 + {3'b000, first_idx - 5'd10});
                tx_start <= 1'b1;
            end else if (!tx_busy && key_pulse) begin
                tx_data <= 8'h53; // 'S'
                tx_start <= 1'b1;
            end
        end
    end

    assign led_din = 1'b0;
endmodule

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
            baud_cnt <= 16'd0; bit_cnt <= 4'd0; tx_shift <= 10'h3FF; sending <= 1'b0; tx_dout_r <= 1'b1;
        end else if (!sending) begin
            baud_cnt <= 16'd0; bit_cnt <= 4'd0; tx_dout_r <= 1'b1;
            if (tx_start) begin
                tx_shift <= {1'b1, tx_data, 1'b0}; sending <= 1'b1; tx_dout_r <= 1'b0;
            end
        end else if (baud_cnt == BAUD_DIV - 1) begin
            baud_cnt <= 16'd0;
            if (bit_cnt == 4'd9) begin
                sending <= 1'b0; bit_cnt <= 4'd0; tx_dout_r <= 1'b1;
            end else begin
                bit_cnt <= bit_cnt + 4'd1; tx_shift <= {1'b1, tx_shift[9:1]}; tx_dout_r <= tx_shift[1];
            end
        end else begin
            baud_cnt <= baud_cnt + 16'd1;
        end
    end
endmodule

module key_pulse_low(input wire clk, input wire rst_n, input wire key_n, output reg pulse);
    localparam integer DEBOUNCE_MAX = 1_000_000;
    reg [1:0] key_sync;
    reg key_state;
    reg [20:0] cnt;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) key_sync <= 2'b11;
        else key_sync <= {key_sync[0], key_n};
    end
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin key_state <= 1'b1; cnt <= 21'd0; pulse <= 1'b0; end
        else begin
            pulse <= 1'b0;
            if (key_sync[1] == key_state) cnt <= 21'd0;
            else if (cnt >= DEBOUNCE_MAX - 1) begin
                cnt <= 21'd0;
                if (key_state == 1'b1 && key_sync[1] == 1'b0) pulse <= 1'b1;
                key_state <= key_sync[1];
            end else cnt <= cnt + 21'd1;
        end
    end
endmodule
