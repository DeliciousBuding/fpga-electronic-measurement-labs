module debug_rx_edge_top (
    input  wire clk,
    input  wire nrst,
    input  wire tx_en,
    input  wire rx_din,
    output wire tx_dout,
    output wire tx_busy_flag_qn,
    output wire led_din
);

    localparam integer BAUD_DIV = 434;

    wire key_pulse;
    key_pulse_low u_key (
        .clk(clk),
        .rst_n(nrst),
        .key_n(tx_en),
        .pulse(key_pulse)
    );

    reg [2:0] rx_sync;
    reg       rx_prev;
    always @(posedge clk or negedge nrst) begin
        if (!nrst) begin
            rx_sync <= 3'b111;
            rx_prev <= 1'b1;
        end else begin
            rx_sync <= {rx_sync[1:0], rx_din};
            rx_prev <= rx_sync[2];
        end
    end

    wire rx_falling = (rx_prev == 1'b1) && (rx_sync[2] == 1'b0);
    wire rx_rising  = (rx_prev == 1'b0) && (rx_sync[2] == 1'b1);

    reg [23:0] inhibit_cnt;
    wire rx_fall_event = rx_falling && (inhibit_cnt == 24'd0);
    wire rx_rise_event = rx_rising && (inhibit_cnt == 24'd0);
    wire rx_event = rx_fall_event || rx_rise_event;

    always @(posedge clk or negedge nrst) begin
        if (!nrst) begin
            inhibit_cnt <= 24'd0;
        end else if (rx_event) begin
            inhibit_cnt <= 24'd5_000_000;
        end else if (inhibit_cnt != 24'd0) begin
            inhibit_cnt <= inhibit_cnt - 24'd1;
        end
    end

    reg       tx_start;
    reg [7:0] tx_data;
    wire      tx_busy;

    uart_tx_byte #(
        .BAUD_DIV(BAUD_DIV)
    ) u_tx (
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
            tx_data  <= 8'h00;
        end else begin
            tx_start <= 1'b0;
            if (!tx_busy && rx_fall_event) begin
                tx_data  <= 8'h46; // 'F': rx_din saw a falling edge
                tx_start <= 1'b1;
            end else if (!tx_busy && rx_rise_event) begin
                tx_data  <= 8'h45; // 'E': rx_din saw a rising edge
                tx_start <= 1'b1;
            end else if (!tx_busy && key_pulse) begin
                tx_data  <= rx_sync[2] ? 8'h48 : 8'h4C; // 'H' or 'L': current rx level
                tx_start <= 1'b1;
            end
        end
    end

    assign tx_busy_flag_qn = ~tx_busy;
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

module key_pulse_low (
    input  wire clk,
    input  wire rst_n,
    input  wire key_n,
    output reg  pulse
);

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
            end else if (cnt >= DEBOUNCE_MAX - 1) begin
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

endmodule
