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
