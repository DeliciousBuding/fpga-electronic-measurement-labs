`timescale 1ns/1ps

module lpm_counter_demo #(
    parameter WIDTH = 4
)(
    input  wire             clock,
    input  wire             aclr,
    input  wire             clk_en,
    input  wire             cnt_en,
    input  wire             sset,
    output reg  [WIDTH-1:0] q,
    output wire             cout
);

    assign cout = clk_en && cnt_en && (&q);

    always @(posedge clock or posedge aclr) begin
        if (aclr) begin
            q <= {WIDTH{1'b0}};
        end else if (clk_en) begin
            if (sset) begin
                q <= {WIDTH{1'b1}};
            end else if (cnt_en) begin
                q <= q + {{WIDTH-1{1'b0}}, 1'b1};
            end
        end
    end

endmodule

module pll_observe_stub(
    input  wire inclk0,
    input  wire areset,
    output wire c0,
    output reg  c1,
    output wire c2,
    output reg  locked
);

    reg [7:0] lock_cnt;

    assign c0 = inclk0;
    assign c2 = c1;

    // SIM-only: generate 100MHz from 50MHz inclk0 by toggling on both edges.
    // Non-synthesizable; only used under `ifdef SIM for behavioral simulation.
    always @(posedge inclk0 or negedge inclk0 or posedge areset) begin
        if (areset) begin
            c1 <= 1'b0;
            lock_cnt <= 8'd0;
            locked <= 1'b0;
        end else begin
            c1 <= ~c1;
            if (!locked) begin
                lock_cnt <= lock_cnt + 8'd1;
                if (lock_cnt == 8'd40) begin
                    locked <= 1'b1;
                end
            end
        end
    end

endmodule

module reset_sync(
    input  wire clk,
    input  wire arst_n,
    input  wire pll_locked,
    output wire srst_n
);

    reg [1:0] sync_ff;

    assign srst_n = sync_ff[1];

    always @(posedge clk or negedge arst_n) begin
        if (!arst_n) begin
            sync_ff <= 2'b00;
        end else if (!pll_locked) begin
            sync_ff <= 2'b00;
        end else begin
            sync_ff <= {sync_ff[0], 1'b1};
        end
    end

endmodule

module byte_uart_tx #(
    parameter BAUD_DIV = 434
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       tx_start,
    input  wire [7:0] tx_data,
    output reg        tx_dout,
    output wire       tx_busy,
    output reg        tx_done
);

    localparam ST_IDLE = 1'b0;
    localparam ST_SEND = 1'b1;

    reg state;
    reg [15:0] baud_cnt;
    reg [3:0] bit_idx;
    reg [9:0] shifter;

    assign tx_busy = (state == ST_SEND);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE;
            baud_cnt <= 16'd0;
            bit_idx <= 4'd0;
            shifter <= 10'h3ff;
            tx_dout <= 1'b1;
            tx_done <= 1'b0;
        end else begin
            tx_done <= 1'b0;
            case (state)
                ST_IDLE: begin
                    tx_dout <= 1'b1;
                    baud_cnt <= 16'd0;
                    bit_idx <= 4'd0;
                    if (tx_start) begin
                        shifter <= {1'b1, tx_data, 1'b0};
                        tx_dout <= 1'b0;
                        state <= ST_SEND;
                    end
                end
                ST_SEND: begin
                    if (baud_cnt == BAUD_DIV - 1) begin
                        baud_cnt <= 16'd0;
                        shifter <= {1'b1, shifter[9:1]};
                        bit_idx <= bit_idx + 4'd1;
                        if (bit_idx == 4'd9) begin
                            state <= ST_IDLE;
                            tx_dout <= 1'b1;
                            tx_done <= 1'b1;
                        end else begin
                            tx_dout <= shifter[1];
                        end
                    end else begin
                        baud_cnt <= baud_cnt + 16'd1;
                    end
                end
            endcase
        end
    end

endmodule
