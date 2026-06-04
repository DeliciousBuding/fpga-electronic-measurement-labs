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
